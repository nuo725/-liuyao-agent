// Media Module - Local storage adapter.

const fs = require('fs/promises');
const path = require('path');
const { randomUUID } = require('crypto');
const { getPrisma } = require('../../db/prisma');
const { ApiError } = require('../../shared/api-error');
const { createLogger } = require('../../shared/logger');

const logger = createLogger('media-service');

const MAX_FILE_SIZE = 5 * 1024 * 1024;
const ALLOWED_MIME = new Set(['image/jpeg', 'image/png', 'image/webp', 'image/gif']);
const PURPOSES = new Set(['avatar', 'cover', 'post', 'share']);

async function uploadMedia(userId, req) {
  const contentType = req.headers['content-type'] || '';
  if (contentType.startsWith('multipart/form-data')) {
    return uploadMultipart(userId, req, contentType);
  }
  return registerRemoteMedia(userId, req.body || {});
}

async function registerRemoteMedia(userId, body) {
  const purpose = normalizePurpose(body.purpose);
  const url = String(body.url || '').trim();
  const mime = String(body.mime || '').trim();
  const size = Number(body.size || 0);

  if (!url || !url.startsWith('http')) {
    throw ApiError.badRequest('url must be an absolute object-storage URL when using JSON upload');
  }
  validateMedia(mime, size, purpose);

  const asset = await createAsset(userId, {
    purpose,
    url,
    mime,
    size,
    width: body.width || null,
    height: body.height || null,
  });
  return formatAsset(asset);
}

async function uploadMultipart(userId, req, contentType) {
  const boundary = extractBoundary(contentType);
  if (!boundary) {
    throw ApiError.badRequest('Missing multipart boundary');
  }

  const body = await readRequestBody(req, MAX_FILE_SIZE + 1024 * 64);
  const parts = parseMultipart(body, boundary);
  const fields = {};
  let file = null;

  for (const part of parts) {
    if (part.filename) {
      file = part;
    } else {
      fields[part.name] = part.content.toString('utf8');
    }
  }

  if (!file) {
    throw ApiError.badRequest('file is required');
  }

  const purpose = normalizePurpose(fields.purpose || 'post');
  const mime = file.contentType || 'application/octet-stream';
  validateMedia(mime, file.content.length, purpose);

  const assetId = `media_${randomUUID().slice(0, 12)}`;
  const ext = extensionFor(file.filename, mime);
  const uploadRoot = path.join(__dirname, '..', '..', '..', 'uploads', userId);
  await fs.mkdir(uploadRoot, { recursive: true });
  await fs.writeFile(path.join(uploadRoot, `${assetId}${ext}`), file.content);

  const asset = await createAsset(userId, {
    purpose,
    url: `/uploads/${userId}/${assetId}${ext}`,
    mime,
    size: file.content.length,
    width: null,
    height: null,
  });

  logger.info({ userId, assetId: asset.id, purpose }, 'Media uploaded');
  return formatAsset(asset);
}

async function createAsset(userId, data) {
  const prisma = getPrisma();
  return prisma.mediaAsset.create({
    data: {
      ownerId: userId,
      purpose: data.purpose,
      url: data.url,
      mime: data.mime,
      size: data.size,
      width: data.width,
      height: data.height,
    },
  });
}

function validateMedia(mime, size, purpose) {
  if (!PURPOSES.has(purpose)) {
    throw ApiError.badRequest('Invalid media purpose');
  }
  if (!ALLOWED_MIME.has(mime)) {
    throw ApiError.badRequest('Only jpeg, png, webp, and gif images are allowed');
  }
  if (!Number.isInteger(size) || size <= 0 || size > MAX_FILE_SIZE) {
    throw ApiError.badRequest(`File size must be between 1 and ${MAX_FILE_SIZE} bytes`);
  }
}

function normalizePurpose(purpose) {
  return PURPOSES.has(purpose) ? purpose : 'post';
}

function extractBoundary(contentType) {
  const match = contentType.match(/boundary="?([^";]+)"?/i);
  return match?.[1] || null;
}

async function readRequestBody(req, limit) {
  const chunks = [];
  let total = 0;
  for await (const chunk of req) {
    total += chunk.length;
    if (total > limit) {
      throw ApiError.badRequest('File too large');
    }
    chunks.push(chunk);
  }
  return Buffer.concat(chunks);
}

function parseMultipart(buffer, boundary) {
  const separator = Buffer.from(`--${boundary}`);
  const chunks = splitBuffer(buffer, separator);
  const parts = [];

  for (const chunk of chunks) {
    let part = trimBoundaryPadding(chunk);
    if (part.length === 0 || part.equals(Buffer.from('--'))) continue;

    const headerEnd = part.indexOf(Buffer.from('\r\n\r\n'));
    if (headerEnd === -1) continue;

    const headerText = part.slice(0, headerEnd).toString('utf8');
    let content = part.slice(headerEnd + 4);
    if (content.length >= 2 && content.slice(-2).equals(Buffer.from('\r\n'))) {
      content = content.slice(0, -2);
    }

    const name = matchHeader(headerText, /name="([^"]+)"/);
    if (!name) continue;

    parts.push({
      name,
      filename: matchHeader(headerText, /filename="([^"]*)"/),
      contentType: matchHeader(headerText, /content-type:\s*([^\r\n]+)/i),
      content,
    });
  }

  return parts;
}

function splitBuffer(buffer, separator) {
  const parts = [];
  let start = 0;
  let index = buffer.indexOf(separator, start);
  while (index !== -1) {
    parts.push(buffer.slice(start, index));
    start = index + separator.length;
    index = buffer.indexOf(separator, start);
  }
  parts.push(buffer.slice(start));
  return parts;
}

function trimBoundaryPadding(part) {
  let output = part;
  if (output.slice(0, 2).equals(Buffer.from('\r\n'))) {
    output = output.slice(2);
  }
  if (output.slice(0, 2).equals(Buffer.from('--'))) {
    return Buffer.alloc(0);
  }
  return output;
}

function matchHeader(headerText, pattern) {
  const match = headerText.match(pattern);
  return match?.[1]?.trim() || null;
}

function extensionFor(filename, mime) {
  const ext = filename ? path.extname(filename).toLowerCase() : '';
  if (['.jpg', '.jpeg', '.png', '.webp', '.gif'].includes(ext)) {
    return ext;
  }
  return {
    'image/jpeg': '.jpg',
    'image/png': '.png',
    'image/webp': '.webp',
    'image/gif': '.gif',
  }[mime] || '.bin';
}

function formatAsset(asset) {
  return {
    id: asset.id,
    url: asset.url,
    purpose: asset.purpose,
    mime: asset.mime,
    size: asset.size,
    width: asset.width,
    height: asset.height,
    status: asset.status,
    createdAt: asset.createdAt,
  };
}

module.exports = {
  uploadMedia,
};
