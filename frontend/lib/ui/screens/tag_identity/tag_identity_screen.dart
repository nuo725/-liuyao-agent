import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../models/tag_identity.dart';

class TagIdentityScreen extends StatelessWidget {
  final TagIdentitySnapshot snapshot;

  const TagIdentityScreen({super.key, required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCFCF8),
      appBar: AppBar(
        title: const Text('标签身份'),
        backgroundColor: const Color(0xFFFCFCF8),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
        children: [
          _SnapshotCard(snapshot: snapshot),
          const SizedBox(height: 16),
          _TimelineCard(snapshot: snapshot),
          const SizedBox(height: 16),
          TagDistributionCard(
            tag: snapshot.primaryTag,
            title: '标签流向',
            subtitle: '用于说明同一身份标签在不同场景中的展示方式。',
            segments: const [
              TagDistributionSegment(
                label: 'ritual 生成',
                value: 0.42,
                color: Color(0xFF4CAF82),
              ),
              TagDistributionSegment(
                label: 'profile 复看',
                value: 0.28,
                color: Color(0xFF6C8EF5),
              ),
              TagDistributionSegment(
                label: 'community 订阅',
                value: 0.18,
                color: Color(0xFFF2B35C),
              ),
              TagDistributionSegment(
                label: 'activity 参与',
                value: 0.12,
                color: Color(0xFFF08A6B),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ActionCard(snapshot: snapshot),
        ],
      ),
    );
  }
}

class TagFeedScreen extends StatelessWidget {
  final TagIdentitySnapshot snapshot;

  const TagFeedScreen({super.key, required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final items = _buildFeedItems(snapshot);

    return Scaffold(
      backgroundColor: const Color(0xFFFCFCF8),
      appBar: AppBar(
        title: Text(snapshot.primaryTag),
        backgroundColor: const Color(0xFFFCFCF8),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
        children: [
          _FeedHeader(snapshot: snapshot),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${snapshot.primaryTag} 已订阅为本地演示标签流'),
                ),
              );
            },
            icon: const Icon(Icons.notifications_active_outlined, size: 18),
            label: const Text('订阅当前标签流'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TagIdentityScreen(snapshot: snapshot),
                ),
              );
            },
            icon: const Icon(Icons.auto_awesome_outlined, size: 18),
            label: const Text('查看标签身份'),
          ),
          const SizedBox(height: 18),
          Text(
            '同标签内容',
            style: AppTypography.labelLarge.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ...items.map((item) => _TagFeedItemCard(item: item, tag: snapshot.primaryTag)),
        ],
      ),
    );
  }
}

class TagDistributionCard extends StatelessWidget {
  final String tag;
  final String title;
  final String subtitle;
  final List<TagDistributionSegment> segments;

  const TagDistributionCard({
    super.key,
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.segments,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEAEAEA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  tag,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...segments.map(
            (segment) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DistributionRow(segment: segment),
            ),
          ),
        ],
      ),
    );
  }
}

class TagDistributionSegment {
  final String label;
  final double value;
  final Color color;

  const TagDistributionSegment({
    required this.label,
    required this.value,
    required this.color,
  });
}

class _SnapshotCard extends StatelessWidget {
  final TagIdentitySnapshot snapshot;

  const _SnapshotCard({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFDF7EA), Color(0xFFF4F8FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0E8D6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '当前标签',
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            snapshot.primaryTag,
            style: AppTypography.headlineMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: snapshot.secondaryTags
                .map(
                  (tag) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      tag,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          Text(
            snapshot.explanation,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '来源',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  snapshot.sourceTitle,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatDate(snapshot.createdAt),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  final TagIdentitySnapshot snapshot;

  const _TimelineCard({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEAEAEA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '标签时间线',
            style: AppTypography.labelLarge.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...snapshot.timeline.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TimelineRow(entry: entry),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final TagTimelineEntry entry;

  const _TimelineRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final icon = switch (entry.eventType) {
      'generated' => Icons.auto_awesome_rounded,
      'subscribed' => Icons.notifications_active_outlined,
      'published' => Icons.publish_outlined,
      'joined' => Icons.hub_outlined,
      _ => Icons.visibility_outlined,
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.summary,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${entry.tag} · ${_formatDate(entry.createdAt)}',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final TagIdentitySnapshot snapshot;

  const _ActionCard({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEAEAEA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '继续使用这个标签',
            style: AppTypography.labelLarge.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '这个页面只负责展示和回看标签身份，不改变当前的模拟会话。',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TagFeedScreen(snapshot: snapshot),
                  ),
                );
              },
              icon: const Icon(Icons.dynamic_feed_outlined, size: 18),
              label: const Text('浏览同标签内容'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedHeader extends StatelessWidget {
  final TagIdentitySnapshot snapshot;

  const _FeedHeader({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEAEAEA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '标签流',
            style: AppTypography.labelLarge.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            snapshot.explanation,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: snapshot.secondaryTags
                .map(
                  (tag) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      tag,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _TagFeedItemCard extends StatelessWidget {
  final _TagFeedItem item;
  final String tag;

  const _TagFeedItemCard({required this.item, required this.tag});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEAEAEA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: const Color(0xFFEAEAEA),
                child: Text(
                  item.author.characters.first,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.author,
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.timeLabel,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  tag,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.title,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.summary,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _TagFeedItem {
  final String author;
  final String title;
  final String summary;
  final String timeLabel;

  const _TagFeedItem({
    required this.author,
    required this.title,
    required this.summary,
    required this.timeLabel,
  });
}

List<_TagFeedItem> _buildFeedItems(TagIdentitySnapshot snapshot) {
  final base = snapshot.primaryTag;
  return [
    _TagFeedItem(
      author: '岚木',
      title: '$base 的一段安静复读',
      summary: '把最近这次 ritual 结果拆成 3 个可回看的句子，方便以后再次打开。',
      timeLabel: '3 分钟前',
    ),
    _TagFeedItem(
      author: '绒语',
      title: '$base 的同频回应',
      summary: '社区里有人把相似主题整理成了更短的表达，适合收藏和继续追问。',
      timeLabel: '1 小时前',
    ),
    _TagFeedItem(
      author: '云石',
      title: '$base 的活动延展',
      summary: '活动页也开始沿用这组标签，让参与感和身份感保持在同一条线上。',
      timeLabel: '昨天',
    ),
  ];
}

class _DistributionRow extends StatelessWidget {
  final TagDistributionSegment segment;

  const _DistributionRow({required this.segment});

  @override
  Widget build(BuildContext context) {
    final percent = (segment.value * 100).clamp(0, 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                segment.label,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Text(
              '$percent%',
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: segment.value,
            backgroundColor: AppColors.surfaceVariant,
            valueColor: AlwaysStoppedAnimation<Color>(segment.color),
          ),
        ),
      ],
    );
  }
}

String _formatDate(DateTime value) {
  final y = value.year.toString();
  final m = value.month.toString().padLeft(2, '0');
  final d = value.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
