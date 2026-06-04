import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../models/feed_item.dart';
import '../../../services/activity_service.dart';
import '../../../services/feed_service.dart';
import '../publish_page.dart';
import '../../../state/auth_state.dart';
import '../../../state/profile_hub_state.dart';
import '../tag_identity/tag_identity_screen.dart';

class ActivityDetailScreen extends ConsumerStatefulWidget {
  final Activity activity;

  const ActivityDetailScreen({super.key, required this.activity});

  @override
  ConsumerState<ActivityDetailScreen> createState() =>
      _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends ConsumerState<ActivityDetailScreen> {
  late Activity _activity;
  bool _isJoining = false;
  bool _loadingLeaderboard = false;
  List<_JokeRankEntry> _jokeRanks = const [];

  static const _coldJokeTag = '#冷笑话大赛';
  bool get _isColdJokeActivity => _activity.id == 'act_cold_joke_001';

  @override
  void initState() {
    super.initState();
    _activity = widget.activity;
    unawaited(_loadDetail());
    unawaited(_loadColdJokeLeaderboard());
  }

  Future<void> _loadDetail() async {
    final userId = ref.read(authStateProvider).user?.id;
    // TODO(Backend Integration)[activity_api#detail]:
    // 当前详情页由本地服务模拟，后续替换为真实详情接口并返回用户报名状态。
    try {
      final detail = await activityServiceProvider.getActivityDetail(
        _activity.id,
        userId: userId,
      );
      if (mounted) {
        setState(() {
          _activity = detail;
        });
      }
    } catch (_) {
      // 详情加载失败时保留列表传入数据，不阻断页面展示。
    }
  }

  Future<void> _openColdJokePublish() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const PublishPage(
          presetTag: _coldJokeTag,
          initialText: '今天我参赛的冷笑话：',
        ),
      ),
    );
    if (!mounted) return;
    await _loadColdJokeLeaderboard();
  }

  Future<void> _loadColdJokeLeaderboard() async {
    if (!_isColdJokeActivity) return;
    setState(() => _loadingLeaderboard = true);
    try {
      final rec = await feedServiceProvider.getRecommendFeed(
        tab: 'recommended',
        page: 1,
        pageSize: 60,
      );
      final deep = await feedServiceProvider.getRecommendFeed(
        tab: 'deep',
        page: 1,
        pageSize: 60,
      );
      final all = [...rec.items, ...deep.items];
      final tagged = all.where((item) {
        final text = (item.shareText ?? item.displaySummary).trim();
        return text.contains(_coldJokeTag);
      }).toList();

      final ranks = tagged
          .map(
            (item) => _JokeRankEntry(
              item: item,
              upVotes: item.metrics.likes,
              downVotes: (item.id.hashCode.abs() % 37) + 1,
            ),
          )
          .toList()
        ..sort((a, b) => b.upVotes.compareTo(a.upVotes));

      if (!mounted) return;
      setState(() => _jokeRanks = ranks);
    } finally {
      if (mounted) setState(() => _loadingLeaderboard = false);
    }
  }

  Future<void> _joinActivity() async {
    if (_isJoining || _activity.joinStatus != ActivityJoinStatus.none) return;
    final auth = ref.read(authStateProvider);
    final userId = auth.user?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先登录后再参与活动'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isJoining = true);
    try {
      // TODO(Backend Integration)[activity_api#join]:
      // 当前为 UI 模拟报名，后续替换为真实报名接口。
      // TODO(Backend Integration)[activity_api#join-status]:
      // 当前状态由本地规则生成（待确认/已通过/候补中）。
      final updated = await activityServiceProvider.joinActivity(
        _activity.id,
        userId,
      );
      if (mounted) {
        setState(() => _activity = updated);
      }

      await ref
          .read(profileHubStateProvider.notifier)
          .recordInteraction(
            source: 'activity_join',
            contentKey: '${_activity.id}-${updated.joinStatus.value}',
            title: '活动报名状态更新：${updated.joinStatus.label}',
            detail: updated.title,
            uniqueBySourceAndKey: false,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('报名结果：${updated.joinStatus.label}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('报名失败：$e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  ({String label, bool enabled, Color color}) _ctaMeta() {
    if (_isJoining) {
      return (label: '提交中...', enabled: false, color: const Color(0xFFBDBDBD));
    }
    switch (_activity.joinStatus) {
      case ActivityJoinStatus.none:
        return (label: '立即报名', enabled: true, color: const Color(0xFF4CAF82));
      case ActivityJoinStatus.pending:
        return (label: '报名待确认', enabled: false, color: const Color(0xFFE7A64A));
      case ActivityJoinStatus.approved:
        return (label: '已通过', enabled: false, color: const Color(0xFF67B48A));
      case ActivityJoinStatus.waitlist:
        return (label: '候补中', enabled: false, color: const Color(0xFF9E9E9E));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cta = _ctaMeta();
    return Scaffold(
      backgroundColor: const Color(0xFFFCFCF8),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 240,
                pinned: true,
                backgroundColor: const Color(0xFFFFFFFF),
                foregroundColor: const Color(0xFF1A1A1A),
                leading: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Image.network(
                    _activity.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: AppColors.surfaceVariant,
                      child: const Center(
                        child: Icon(
                          Icons.image_outlined,
                          color: Color(0xFFAAAAAA),
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _StatusChip(
                              text: _activity.status,
                              bg: AppColors.mintLight,
                              fg: const Color(0xFF4CAF82),
                            ),
                            _StatusChip(
                              text: _activity.joinStatus.label,
                              bg: const Color(0xFFF7F0E1),
                              fg: const Color(0xFFC0862B),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _activity.title,
                          style: AppTypography.headlineMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 15,
                              color: AppColors.textTertiary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _activity.dateText,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 20),
                            Icon(
                              Icons.person_outline_rounded,
                              size: 15,
                              color: AppColors.textTertiary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${_activity.participantCount} 人参与',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Container(height: 0.5, color: AppColors.border),
                        const SizedBox(height: 24),
                        Text(
                          '活动介绍',
                          style: AppTypography.labelLarge.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _activity.description,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.8,
                          ),
                        ),
                        if ((_activity.content ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Text(
                            '更多说明',
                            style: AppTypography.labelLarge.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _activity.content!.trim(),
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.8,
                            ),
                          ),
                        ],
                        if (_isColdJokeActivity) ...[
                          const SizedBox(height: 24),
                          Text(
                            '参赛入口',
                            style: AppTypography.labelLarge.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _activity.joinStatus ==
                                      ActivityJoinStatus.none
                                  ? null
                                  : _openColdJokePublish,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF2F3F62),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                _activity.joinStatus == ActivityJoinStatus.none
                                    ? '先报名后发布'
                                    : '发布冷笑话（自动带 #冷笑话大赛）',
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TagDistributionCard(
                            tag: _coldJokeTag,
                            title: '标签分布',
                            subtitle:
                                '展示这次活动中，标签如何在投稿、榜单和回看页之间流动。',
                            segments: const [
                              TagDistributionSegment(
                                label: '投稿占比',
                                value: 0.48,
                                color: Color(0xFF4CAF82),
                              ),
                              TagDistributionSegment(
                                label: '榜单曝光',
                                value: 0.28,
                                color: Color(0xFF6C8EF5),
                              ),
                              TagDistributionSegment(
                                label: '回看收藏',
                                value: 0.16,
                                color: Color(0xFFF2B35C),
                              ),
                              TagDistributionSegment(
                                label: '继续传播',
                                value: 0.08,
                                color: Color(0xFFF08A6B),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text(
                            '实时榜单（本地模拟）',
                            style: AppTypography.labelLarge.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (_loadingLeaderboard)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: LinearProgressIndicator(minHeight: 2),
                            )
                          else if (_jokeRanks.isEmpty)
                            Text(
                              '还没有带 #冷笑话大赛 的投稿，快去发布第一条！',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.6,
                              ),
                            )
                          else
                            _JokeLeaderboard(ranks: _jokeRanks),
                        ],
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.pageHorizontal,
                16,
                AppSpacing.pageHorizontal,
                32,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: cta.enabled ? _joinActivity : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: cta.color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    cta.label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JokeRankEntry {
  final FeedItem item;
  final int upVotes;
  final int downVotes;

  const _JokeRankEntry({
    required this.item,
    required this.upVotes,
    required this.downVotes,
  });
}

class _JokeLeaderboard extends StatelessWidget {
  final List<_JokeRankEntry> ranks;

  const _JokeLeaderboard({required this.ranks});

  @override
  Widget build(BuildContext context) {
    final topLikes = [...ranks]..sort((a, b) => b.upVotes.compareTo(a.upVotes));
    final topDown = [...ranks]
      ..sort((a, b) => b.downVotes.compareTo(a.downVotes));
    final likeKing = topLikes.first;
    final downKing = topDown.first;

    Widget badge({
      required String title,
      required String author,
      required String score,
      required Color bg,
      required Color fg,
    }) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTypography.labelSmall.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              author,
              style: AppTypography.labelMedium.copyWith(color: fg),
            ),
            const SizedBox(height: 2),
            Text(
              score,
              style: AppTypography.caption.copyWith(
                color: fg.withValues(alpha: 0.88),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: badge(
                title: '点赞王',
                author: likeKing.item.authorUsername ?? '匿名',
                score: '${likeKing.upVotes} 赞',
                bg: AppColors.mintLight,
                fg: AppColors.primaryDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: badge(
                title: '点踩王',
                author: downKing.item.authorUsername ?? '匿名',
                score: '${downKing.downVotes} 踩（模拟）',
                bg: const Color(0xFFF3EEF7),
                fg: const Color(0xFF5B4E73),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...topLikes.take(5).map((entry) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8FB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#${topLikes.indexOf(entry) + 1}',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    entry.item.displaySummary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '👍 ${entry.upVotes}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;

  const _StatusChip({required this.text, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: AppTypography.labelSmall.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
