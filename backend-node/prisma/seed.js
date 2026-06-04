// Prisma Seed Script
// Creates demo data for local development and testing.
// Run with: npm run db:seed

const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Seeding database...');

  // --- Demo User ---
  const demoUser = await prisma.user.upsert({
    where: { id: 'user_demo' },
    update: {},
    create: {
      id: 'user_demo',
      phone: '13800000000',
      username: '宽窄体验官',
      bio: '带着真实困惑，在宽窄之间寻找角度。',
      avatarUrl: '',
      coverUrl: '',
      shortId: 'demo001',
    },
  });
  console.log(`  ✅ Demo user: ${demoUser.id}`);

  // --- Profile Settings ---
  await prisma.profileSettings.upsert({
    where: { userId: demoUser.id },
    update: {},
    create: {
      userId: demoUser.id,
      pushEnabled: true,
      vibrationEnabled: true,
      ambientSoundEnabled: true,
      publicProfile: true,
    },
  });

  // --- Credit Account ---
  await prisma.creditAccount.upsert({
    where: { userId: demoUser.id },
    update: {},
    create: {
      userId: demoUser.id,
      castBalance: 1,
      followupBalance: 1,
      isVip: false,
      lastResetDate: new Date().toISOString().split('T')[0],
    },
  });
  console.log(`  ✅ Credit account for: ${demoUser.id}`);

  // --- Second User (for social features) ---
  const secondUser = await prisma.user.upsert({
    where: { id: 'user_peer' },
    update: {},
    create: {
      id: 'user_peer',
      phone: '13800000001',
      username: '星辰旅人',
      bio: '在不确定中寻找自己的节奏。',
      shortId: 'peer001',
    },
  });

  await prisma.profileSettings.upsert({
    where: { userId: secondUser.id },
    update: {},
    create: { userId: secondUser.id },
  });

  await prisma.creditAccount.upsert({
    where: { userId: secondUser.id },
    update: {},
    create: {
      userId: secondUser.id,
      castBalance: 1,
      followupBalance: 1,
      lastResetDate: new Date().toISOString().split('T')[0],
    },
  });
  console.log(`  ✅ Peer user: ${secondUser.id}`);

  // --- Agreement Consents ---
  for (const user of [demoUser, secondUser]) {
    await prisma.agreementConsent.create({
      data: {
        userId: user.id,
        agreementVersion: 'v1.0',
        privacyVersion: 'v1.0',
        consentedAt: new Date(),
      },
    });
  }
  console.log('  ✅ Agreement consents');

  // --- Demo Ritual Session ---
  const ritualSession = await prisma.ritualSession.create({
    data: {
      userId: demoUser.id,
      question: '最近工作上有些迷茫，不知道该不该换一个方向。',
      tag: 'career',
      pattern: {
        lines: [0, 1, 0, 1, 1, 0],
        movingLines: [1, 4],
      },
      status: 'completed',
      riskLevel: 'low',
    },
  });
  console.log(`  ✅ Demo ritual session: ${ritualSession.id}`);

  // --- Interpretation Card ---
  const card = await prisma.interpretationCard.create({
    data: {
      sessionId: ritualSession.id,
      privateContent: {
        summary: '当前局面像是站在一个分岔口，两边都有路，但看不太远。',
        body: '从这组结构来看，你目前的状态处在一个变化的过渡期。工作上的迷茫感并不是突然出现的，而是积累了一段时间。这个结构提示你，现在不是急于做决定的时候，而是先理清楚自己真正在意的是什么。',
        followupDirections: [
          '你可以想想，最近一次感到有成就感是什么时候？',
          '如果不用考虑收入，你更想做什么？',
          '有没有一个你信任的人，可以聊聊这个话题？',
        ],
        needsClarification: false,
        microActions: [
          '今天花 10 分钟写下三个让你感到充实的工作瞬间。',
          '这周找一个你信任的人聊一聊最近的状态。',
        ],
      },
      communitySafeContent: {
        summary: '站在分岔口，两边都有路。',
        body: '从这组结构看，当前处在一个过渡期。迷茫感不是突然出现的，而是积累了一段时间。现在不是急于做决定的时候，而是先理清楚自己真正在意的是什么。',
        focusPoints: ['变化中的稳定', '内心的真实需求'],
      },
      riskLevel: 'low',
    },
  });
  console.log(`  ✅ Interpretation card: ${card.id}`);

  // --- Follow-up Messages ---
  await prisma.followupMessage.createMany({
    data: [
      {
        sessionId: ritualSession.id,
        type: 'question',
        content: '那我应该怎么判断是不是该换了呢？',
      },
      {
        sessionId: ritualSession.id,
        type: 'answer',
        content: '与其问"该不该换"，不如先问自己"现在的工作里，最让我不舒服的到底是什么"。是内容、是环境、还是成长空间？把这个问题拆开来看，答案会更清晰。',
      },
    ],
  });
  console.log('  ✅ Follow-up messages');

  // --- Demo Community Post ---
  const post = await prisma.communityPost.create({
    data: {
      authorId: demoUser.id,
      cardId: card.id,
      shareText: '最近工作上有些迷茫，起了一卦，结果让我停下来想了想。不是给我答案，而是让我看到了自己一直在回避的问题。分享给也在纠结的你。',
      tabTags: ['career', 'reflection'],
      status: 'published',
      metrics: { likes: 3, favorites: 1, views: 42, comments: 0 },
    },
  });
  console.log(`  ✅ Demo post: ${post.id}`);

  // --- Demo Comment ---
  await prisma.comment.create({
    data: {
      postId: post.id,
      authorId: secondUser.id,
      text: '我也有过类似的阶段，后来发现最难受的不是选哪个方向，而是不敢面对自己真正想要什么。加油！',
    },
  });
  console.log('  ✅ Demo comment');

  // --- Demo Like & Favorite ---
  await prisma.postLike.create({
    data: { userId: secondUser.id, postId: post.id },
  });
  await prisma.postFavorite.create({
    data: { userId: secondUser.id, postId: post.id },
  });
  console.log('  ✅ Demo like & favorite');

  // --- Demo Activity ---
  const activity = await prisma.activity.create({
    data: {
      title: '七日情绪记录挑战',
      description: '连续七天，每天用一段话记录自己的情绪变化。不需要文采，只需要真实。',
      status: 'registering',
      startAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
      capacity: 100,
      participantCount: 1,
    },
  });

  await prisma.activityJoin.create({
    data: {
      activityId: activity.id,
      userId: demoUser.id,
      status: 'approved',
    },
  });
  console.log(`  ✅ Demo activity: ${activity.id}`);

  // --- Demo Notification ---
  await prisma.notification.create({
    data: {
      userId: demoUser.id,
      type: 'interaction',
      title: '星辰旅人 评论了你的帖子',
      body: '我也有过类似的阶段...',
      data: { targetId: post.id, targetType: 'feed' },
    },
  });
  console.log('  ✅ Demo notification');

  // --- Billing Plans ---
  await prisma.billingPlan.createMany({
    data: [
      { name: '7天VIP体验', days: 7, priceCents: 990, currency: 'CNY' },
      { name: '30天VIP', days: 30, priceCents: 2990, currency: 'CNY' },
      { name: '90天VIP', days: 90, priceCents: 6990, currency: 'CNY' },
    ],
    skipDuplicates: true,
  });
  console.log('  ✅ Billing plans');

  // --- Daily Completion Record ---
  const today = new Date().toISOString().split('T')[0];
  await prisma.dailyCompletion.upsert({
    where: { userId_dateKey: { userId: demoUser.id, dateKey: today } },
    update: {},
    create: {
      userId: demoUser.id,
      dateKey: today,
      completed: true,
    },
  });
  console.log('  ✅ Daily completion record');

  // --- Checkin Record ---
  await prisma.checkinRecord.create({
    data: {
      userId: demoUser.id,
      dateKey: today,
    },
  });
  console.log('  ✅ Checkin record');

  console.log('\n🎉 Seed completed successfully!');
}

main()
  .catch((e) => {
    console.error('❌ Seed failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
