#!/usr/bin/env node
// Data Deletion Script (OPS-007)
// Handles user data export and deletion for privacy compliance.
// Usage: node scripts/data-deletion.js --userId=<id> --action=<export|delete>

const { parseArgs } = require('node:util');

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

async function exportUserData(prisma, userId, dryRun) {
  console.log('📦 Exporting user data...\n');

  const data = {};

  // User profile
  data.user = await prisma.user.findUnique({
    where: { id: userId },
    include: { profileSettings: true },
  });
  console.log(`  User profile: ${data.user ? '✅' : '❌'}`);

  // Agreement consents
  data.agreements = await prisma.agreementConsent.findMany({ where: { userId } });
  console.log(`  Agreement consents: ${data.agreements.length} records`);

  // Auth sessions
  data.sessions = await prisma.authSession.findMany({ where: { userId } });
  console.log(`  Auth sessions: ${data.sessions.length} records`);

  // Credit account & ledger
  data.creditAccount = await prisma.creditAccount.findUnique({ where: { userId } });
  data.creditLedger = await prisma.creditLedger.findMany({ where: { userId } });
  console.log(`  Credit account: ${data.creditAccount ? '✅' : '❌'}`);
  console.log(`  Credit ledger: ${data.creditLedger.length} records`);

  // Ritual sessions & cards
  data.ritualSessions = await prisma.ritualSession.findMany({
    where: { userId },
    include: { interpretationCard: true, followupMessages: true },
  });
  console.log(`  Ritual sessions: ${data.ritualSessions.length} records`);

  // Community posts
  data.posts = await prisma.communityPost.findMany({ where: { authorId: userId } });
  console.log(`  Community posts: ${data.posts.length} records`);

  // Comments
  data.comments = await prisma.comment.findMany({ where: { userId } });
  console.log(`  Comments: ${data.comments.length} records`);

  // Likes & favorites
  data.likes = await prisma.postLike.findMany({ where: { userId } });
  data.favorites = await prisma.postFavorite.findMany({ where: { userId } });
  console.log(`  Likes: ${data.likes.length}, Favorites: ${data.favorites.length}`);

  // Follows & blocks
  data.following = await prisma.userFollow.findMany({ where: { followerId: userId } });
  data.followers = await prisma.userFollow.findMany({ where: { followingId: userId } });
  data.blocking = await prisma.userBlock.findMany({ where: { blockerId: userId } });
  console.log(`  Following: ${data.following.length}, Followers: ${data.followers.length}, Blocking: ${data.blocking.length}`);

  // Notifications
  data.notifications = await prisma.notification.findMany({ where: { userId } });
  console.log(`  Notifications: ${data.notifications.length} records`);

  // Orders
  data.orders = await prisma.billingOrder.findMany({ where: { userId } });
  console.log(`  Orders: ${data.orders.length} records`);

  // Media assets
  data.media = await prisma.mediaAsset.findMany({ where: { ownerId: userId } });
  console.log(`  Media assets: ${data.media.length} records`);

  // Checkin records
  data.checkins = await prisma.checkinRecord.findMany({ where: { userId } });
  console.log(`  Checkin records: ${data.checkins.length} records`);

  // Support tickets
  data.tickets = await prisma.supportTicket.findMany({ where: { userId } });
  console.log(`  Support tickets: ${data.tickets.length} records`);

  // Activity joins
  data.activityJoins = await prisma.activityJoin.findMany({ where: { userId } });
  console.log(`  Activity joins: ${data.activityJoins.length} records`);

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

  const operations = [
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
    { name: 'Followup messages', fn: async () => {
      const sessions = await prisma.ritualSession.findMany({ where: { userId }, select: { id: true } });
      const sessionIds = sessions.map(s => s.id);
      if (sessionIds.length > 0) {
        await prisma.followupMessage.deleteMany({ where: { sessionId: { in: sessionIds } } });
      }
    }},
    { name: 'Interpretation cards', fn: async () => {
      const sessions = await prisma.ritualSession.findMany({ where: { userId }, select: { id: true } });
      const sessionIds = sessions.map(s => s.id);
      if (sessionIds.length > 0) {
        await prisma.interpretationCard.deleteMany({ where: { sessionId: { in: sessionIds } } });
      }
    }},
    { name: 'Ritual sessions', fn: () => prisma.ritualSession.deleteMany({ where: { userId } }) },
    { name: 'Emotion calibrations', fn: () => prisma.emotionCalibration.deleteMany({ where: { userId } }) },
    { name: 'Community posts', fn: () => prisma.communityPost.deleteMany({ where: { authorId: userId } }) },
    { name: 'Agreement consents', fn: () => prisma.agreementConsent.deleteMany({ where: { userId } }) },
    { name: 'Auth sessions', fn: () => prisma.authSession.deleteMany({ where: { userId } }) },
    { name: 'Profile settings', fn: () => prisma.profileSettings.deleteMany({ where: { userId } }) },
  ];

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
        username: `已注销用户`,
        bio: '',
        avatarUrl: '',
        coverUrl: '',
        status: 'deleted',
      },
    });
    console.log(`\n  ✅ User record anonymized`);
    console.log(`  Total records deleted: ${totalDeleted}`);
  } else {
    console.log(`\n  [dry-run] User record would be anonymized`);
  }

  console.log(`\n${dryRun ? '🔍 Dry run complete' : '✅ Deletion complete'}`);
}

function maskPhone(phone) {
  if (!phone || phone.length < 7) return '***';
  return phone.slice(0, 3) + '****' + phone.slice(-4);
}

main();
