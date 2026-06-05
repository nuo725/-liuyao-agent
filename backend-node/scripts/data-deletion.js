#!/usr/bin/env node
// Data Deletion Script (OPS-007)
// Handles user data export and deletion for privacy compliance.
// Usage: node scripts/data-deletion.js --userId=<id> --action=<export|delete>

const { parseArgs } = require('node:util');

function maskPhone(phone) {
  if (!phone || phone.length < 7) return '***';
  return phone.slice(0, 3) + '****' + phone.slice(-4);
}

function getDeletionOperations(prisma, userId) {
  return [
    { name: 'Push tokens', fn: () => prisma.pushToken.deleteMany({ where: { userId } }) },
    { name: 'Notifications', fn: () => prisma.notification.deleteMany({ where: { userId } }) },
    { name: 'Checkin records', fn: () => prisma.checkinRecord.deleteMany({ where: { userId } }) },
    { name: 'Support tickets', fn: () => prisma.supportTicket.deleteMany({ where: { userId } }) },
    { name: 'Activity joins', fn: () => prisma.activityJoin.deleteMany({ where: { userId } }) },
    { name: 'Media assets', fn: () => prisma.mediaAsset.deleteMany({ where: { ownerId: userId } }) },
    { name: 'Orders', fn: () => prisma.billingOrder.deleteMany({ where: { userId } }) },
    { name: 'Credit ledger', fn: () => prisma.creditLedger.deleteMany({ where: { userId } }) },
    { name: 'Credit account', fn: () => prisma.creditAccount.deleteMany({ where: { userId } }) },
    { name: 'Post reports', fn: () => prisma.postReport.deleteMany({ where: { reporterId: userId } }) },
    { name: 'Post favorites', fn: () => prisma.postFavorite.deleteMany({ where: { userId } }) },
    { name: 'Post likes', fn: () => prisma.postLike.deleteMany({ where: { userId } }) },
    { name: 'Comments', fn: () => prisma.comment.deleteMany({ where: { userId } }) },
    { name: 'User blocks', fn: () => prisma.userBlock.deleteMany({ where: { OR: [{ blockerId: userId }, { blockedUserId: userId }] } }) },
    { name: 'User follows', fn: () => prisma.userFollow.deleteMany({ where: { OR: [{ followerId: userId }, { followingId: userId }] } }) },
    {
      name: 'Followup messages', fn: async () => {
        const sessions = await prisma.ritualSession.findMany({ where: { userId }, select: { id: true } });
        const sessionIds = sessions.map(s => s.id);
        if (sessionIds.length > 0) {
          await prisma.followupMessage.deleteMany({ where: { sessionId: { in: sessionIds } } });
        }
      },
    },
    {
      name: 'Interpretation cards', fn: async () => {
        const sessions = await prisma.ritualSession.findMany({ where: { userId }, select: { id: true } });
        const sessionIds = sessions.map(s => s.id);
        if (sessionIds.length > 0) {
          await prisma.interpretationCard.deleteMany({ where: { sessionId: { in: sessionIds } } });
        }
      },
    },
    { name: 'Ritual sessions', fn: () => prisma.ritualSession.deleteMany({ where: { userId } }) },
    { name: 'Emotion calibrations', fn: () => prisma.emotionCalibration.deleteMany({ where: { userId } }) },
    { name: 'Community posts', fn: () => prisma.communityPost.deleteMany({ where: { authorId: userId } }) },
    { name: 'Agreement consents', fn: () => prisma.agreementConsent.deleteMany({ where: { userId } }) },
    { name: 'Auth sessions', fn: () => prisma.authSession.deleteMany({ where: { userId } }) },
    { name: 'Profile settings', fn: () => prisma.profileSettings.deleteMany({ where: { userId } }) },
  ];
}

function getExportQueries(prisma, userId) {
  return [
    { name: 'User profile', query: () => prisma.user.findUnique({ where: { id: userId }, include: { profileSettings: true } }) },
    { name: 'Agreement consents', query: () => prisma.agreementConsent.findMany({ where: { userId } }) },
    { name: 'Auth sessions', query: () => prisma.authSession.findMany({ where: { userId } }) },
    { name: 'Credit account', query: () => prisma.creditAccount.findUnique({ where: { userId } }) },
    { name: 'Credit ledger', query: () => prisma.creditLedger.findMany({ where: { userId } }) },
    { name: 'Ritual sessions', query: () => prisma.ritualSession.findMany({ where: { userId }, include: { interpretationCard: true, followupMessages: true } }) },
    { name: 'Community posts', query: () => prisma.communityPost.findMany({ where: { authorId: userId } }) },
    { name: 'Comments', query: () => prisma.comment.findMany({ where: { userId } }) },
    { name: 'Likes', query: () => prisma.postLike.findMany({ where: { userId } }) },
    { name: 'Favorites', query: () => prisma.postFavorite.findMany({ where: { userId } }) },
    { name: 'Following', query: () => prisma.userFollow.findMany({ where: { followerId: userId } }) },
    { name: 'Followers', query: () => prisma.userFollow.findMany({ where: { followingId: userId } }) },
    { name: 'Blocking', query: () => prisma.userBlock.findMany({ where: { blockerId: userId } }) },
    { name: 'Notifications', query: () => prisma.notification.findMany({ where: { userId } }) },
    { name: 'Orders', query: () => prisma.billingOrder.findMany({ where: { userId } }) },
    { name: 'Media assets', query: () => prisma.mediaAsset.findMany({ where: { ownerId: userId } }) },
    { name: 'Checkin records', query: () => prisma.checkinRecord.findMany({ where: { userId } }) },
    { name: 'Support tickets', query: () => prisma.supportTicket.findMany({ where: { userId } }) },
    { name: 'Activity joins', query: () => prisma.activityJoin.findMany({ where: { userId } }) },
  ];
}

async function exportUserData(prisma, userId, dryRun) {
  console.log('📦 Exporting user data...\n');

  const queries = getExportQueries(prisma, userId);
  const data = {};

  for (const { name, query } of queries) {
    const result = await query();
    const key = name.toLowerCase().replace(/\s+/g, '_');
    data[key] = result;
    const count = Array.isArray(result) ? result.length : (result ? 1 : 0);
    console.log(`  ${name}: ${count} records`);
  }

  if (!dryRun) {
    const fs = require('fs');
    const path = require('path');
    const exportDir = path.join(__dirname, '..', 'exports');
    fs.mkdirSync(exportDir, { recursive: true });
    const exportFile = path.join(exportDir, `user-${userId}-export.json`);
    fs.writeFileSync(exportFile, JSON.stringify(data, null, 2));
    console.log(`\n📁 Export saved to: ${exportFile}`);
  } else {
    console.log('\n📁 (dry-run) Export not saved');
  }
}

async function deleteUserData(prisma, userId, dryRun) {
  console.log('🗑️  Deleting user data...\n');

  const operations = getDeletionOperations(prisma, userId);
  let totalDeleted = 0;

  for (const op of operations) {
    if (dryRun) {
      console.log(`  [dry-run] ${op.name}`);
    } else {
      try {
        const result = await op.fn();
        const count = result.count || 0;
        totalDeleted += count;
        console.log(`  ✅ ${op.name}: ${count} records`);
      } catch (err) {
        console.log(`  ⚠️  ${op.name}: ${err.message}`);
      }
    }
  }

  // Finally, anonymize or delete the user record
  if (!dryRun) {
    await prisma.user.update({
      where: { id: userId },
      data: {
        phone: null,
        username: '已注销用户',
        bio: '',
        avatarUrl: '',
        coverUrl: '',
        status: 'deleted',
      },
    });
    console.log(`\n  ✅ User record anonymized`);
    console.log(`  Total records deleted: ${totalDeleted}`);
  } else {
    console.log('\n  [dry-run] User record would be anonymized');
  }

  console.log(`\n${dryRun ? '🔍 Dry run complete' : '✅ Deletion complete'}`);
}

async function main() {
  const { values } = parseArgs({
    options: {
      userId: { type: 'string' },
      action: { type: 'string', default: 'export' },
      dryRun: { type: 'boolean', default: false },
      confirm: { type: 'boolean', default: false },
    },
  });

  if (!values.userId) {
    console.error('❌ --userId is required');
    console.error('Usage: node scripts/data-deletion.js --userId=<id> --action=<export|delete> [--dry-run] [--confirm]');
    process.exit(1);
  }

  const { userId, action, dryRun, confirm } = values;

  // Load env
  require('dotenv').config();
  const { getEnv } = require('../src/config/env');
  getEnv();

  const { getPrisma } = require('../src/db/prisma');
  const prisma = getPrisma();

  try {
    // Verify user exists
    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      console.error(`❌ User not found: ${userId}`);
      process.exit(1);
    }

    console.log(`\n${'='.repeat(60)}`);
    console.log(`User: ${user.username} (${user.id})`);
    console.log(`Phone: ${user.phone ? maskPhone(user.phone) : 'N/A'}`);
    console.log(`Action: ${action}`);
    console.log(`Dry run: ${dryRun}`);
    console.log(`${'='.repeat(60)}\n`);

    if (action === 'export') {
      await exportUserData(prisma, userId, dryRun);
    } else if (action === 'delete') {
      if (!confirm) {
        console.error('❌ --confirm is required for deletion');
        console.error('Add --confirm to proceed with actual deletion');
        process.exit(1);
      }
      await deleteUserData(prisma, userId, dryRun);
    } else {
      console.error(`❌ Unknown action: ${action}`);
      process.exit(1);
    }
  } catch (err) {
    console.error('❌ Error:', err.message);
    process.exit(1);
  } finally {
    await prisma.$disconnect();
  }
}

module.exports = {
  maskPhone,
  getDeletionOperations,
  getExportQueries,
};

if (require.main === module) {
  main();
}
