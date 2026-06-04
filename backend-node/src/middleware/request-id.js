// Zhouyi Backend - Request ID Middleware (BE-008)

const { randomUUID } = require('crypto');

function requestIdMiddleware(req, res, next) {
  const requestId = req.headers['x-request-id'] || `req_${randomUUID().slice(0, 12)}`;
  req.requestId = requestId;
  res.setHeader('X-Request-Id', requestId);
  next();
}

module.exports = { requestIdMiddleware };
