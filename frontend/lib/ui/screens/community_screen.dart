import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../models/feed_item.dart';
import '../../models/tag_identity.dart';
import '../../state/community_state.dart';
import '../../state/ritual_state.dart';
import 'message_screen.dart';
import 'publish_page.dart';
import 'tag_identity/tag_identity_screen.dart';

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => CommunityScreenState();
}

class CommunityScreenState extends ConsumerState<CommunityScreen> {
  Future<void> refreshPublished() async {
    await ref
        .read(communityStateProvider.notifier)
        .loadFeeds(showLoading: false);
  }

  Future<void> _openPublish() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PublishPage()));
    if (!mounted) return;
    await refreshPublished();
  }

  void _openNotifications() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NotificationSheet(),
    );
  }

  Future<void> _openTagFeed() async {
    final ritual = ref.read(ritualStateProvider);
    final snapshot = TagIdentitySnapshot.preview(
      questionTag: ritual.session?.tag ?? ritual.questionTag,
      sourceTitle: ritual.session?.question ?? '社区标签流',
      history: ritual.history,
      origin: TagIdentityOrigin.community,
      createdAt: ritual.session?.createdAt,
    );
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TagFeedScreen(snapshot: snapshot),
      ),
    );
  }

  Future<void> _openPostDetail(FeedItem item) async {
    final notifier = ref.read(communityStateProvider.notifier);
    await notifier.recordView(item);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _PostDetailScreen(
          item: item,
          onLike: () => notifier.toggleLike(item),
          onComment: () => _openCommentSheet(item),
          commentCount: notifier.commentCount(item),
        ),
      ),
    );
  }

  Future<void> _openCommentSheet(FeedItem item) async {
    // TODO(Backend Integration)[community_api#comment-thread]:
    // 当前评论线程为本地模拟数据；接后端后替换为真实评论分页、回复链与发送接口。
    final editor = TextEditingController();
    final notifier = ref.read(communityStateProvider.notifier);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Consumer(
          builder: (context, innerRef, _) {
            final cs = innerRef.watch(communityStateProvider);
            final comments = cs.commentsByPost[item.id] ??
                notifier.ensureComments(item);
            return Container(
              height: MediaQuery.of(context).size.height * 0.78,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '评论 ${comments.length}',
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.separated(
                        padding:
                            const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        itemCount: comments.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (_, index) {
                          final entry = comments[index];
                          return Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor:
                                    AppColors.surfaceVariant,
                                child: Text(
                                  entry.author.characters.first,
                                  style:
                                      AppTypography.caption.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.author,
                                      style: AppTypography.labelMedium
                                          .copyWith(
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      entry.text,
                                      style: AppTypography.bodyMedium
                                          .copyWith(
                                        color: AppColors.textPrimary,
                                        height: 1.6,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatTimeAgo(entry.createdAt),
                                      style: AppTypography.caption
                                          .copyWith(
                                        color: AppColors.textTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    Container(
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: AppColors.border),
                        ),
                      ),
                      padding: EdgeInsets.only(
                        left: 12,
                        right: 12,
                        top: 10,
                        bottom:
                            MediaQuery.of(context).viewInsets.bottom +
                                10,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: editor,
                              decoration: InputDecoration(
                                hintText: '写下你的想法...',
                                isDense: true,
                                filled: true,
                                fillColor: AppColors.surfaceVariant,
                                border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(999),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () async {
                              final text = editor.text.trim();
                              if (text.isEmpty) return;
                              await notifier.addComment(item, text);
                              editor.clear();
                            },
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(56, 42),
                              backgroundColor: AppColors.primaryDark,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(999),
                              ),
                            ),
                            child: const Text('发送'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    editor.dispose();
  }

  Future<void> _openAuthorProfile(FeedItem item) async {
    // TODO(Backend Integration)[community_api#author-profile]:
    // 当前作者主页为 UI 模拟弹层；接后端后替换为作者详情页与关注关系接口。
    final authorId = item.authorId ?? 'anonymous';
    final authorName = item.authorUsername?.trim().isNotEmpty == true
        ? item.authorUsername!.trim()
        : '匿名作者';
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Consumer(
          builder: (context, innerRef, _) {
            final cs = innerRef.watch(communityStateProvider);
            final followed = cs.followedAuthorIds.contains(authorId);
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: AppColors.surfaceVariant,
                        child: Text(
                          authorName.characters.first,
                          style: AppTypography.headlineSmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        authorName,
                        style: AppTypography.headlineSmall.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '这里是作者主页模拟页，可查看作者简介与历史内容。',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () async {
                            final notifier = innerRef
                                .read(communityStateProvider.notifier);
                            await notifier.toggleFollow(
                              authorId,
                              authorName,
                            );
                            if (!context.mounted) return;
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  followed
                                      ? '已取消关注 $authorName'
                                      : '已关注 $authorName',
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: followed
                                ? AppColors.surfaceVariant
                                : AppColors.primaryDark,
                            foregroundColor: followed
                                ? AppColors.textSecondary
                                : Colors.white,
                          ),
                          child:
                              Text(followed ? '取消关注' : '关注作者'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = ref.watch(communityStateProvider);
    final notifier = ref.read(communityStateProvider.notifier);

    if (cs.loading) {
      return const _LoadingState();
    }
    if (cs.error != null) {
      return _ErrorState(
        message: cs.error!,
        onRetry: () => notifier.loadFeeds(showLoading: true),
      );
    }

    return Container(
      color: AppColors.surface,
      child: SafeArea(
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              _TopBar(
                onPublishTap: _openPublish,
                onTagTap: _openTagFeed,
                onNotificationTap: _openNotifications,
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _FeedList(
                      items: cs.recommended,
                      showStories: false,
                      onRefresh: refreshPublished,
                      hasMore: cs.hasMoreRecommended,
                      loadingMore: cs.loadingMoreRecommended,
                      onLoadMore: () => notifier.loadMore(deepMode: false),
                      likedIds: cs.likedIds,
                      favoritedIds: cs.favoritedIds,
                      followedAuthorIds: cs.followedAuthorIds,
                      onLike: (item) => notifier.toggleLike(item),
                      onFavorite: (item) => notifier.toggleFavorite(item),
                      onReport: _doReport,
                      onView: (item) => notifier.recordView(item),
                      onOpenDetail: _openPostDetail,
                      onComment: _openCommentSheet,
                      onAuthorTap: _openAuthorProfile,
                      onFollow: (item) async {
                        final name =
                            item.authorUsername?.trim().isNotEmpty == true
                                ? item.authorUsername!.trim()
                                : '用户';
                        final id = item.authorId ?? '';
                        if (id.isEmpty) return;
                        await notifier.toggleFollow(id, name);
                      },
                      commentCountFor: (item) => notifier.commentCount(item),
                      isExpanded: (item) => notifier.isExpanded(item),
                      onToggleExpand: (item) =>
                          notifier.toggleDeepExpand(item),
                    ),
                    _FeedList(
                      items: cs.deep,
                      showStories: false,
                      onRefresh: refreshPublished,
                      hasMore: cs.hasMoreDeep,
                      loadingMore: cs.loadingMoreDeep,
                      onLoadMore: () => notifier.loadMore(deepMode: true),
                      likedIds: cs.likedIds,
                      favoritedIds: cs.favoritedIds,
                      followedAuthorIds: cs.followedAuthorIds,
                      onLike: (item) => notifier.toggleLike(item),
                      onFavorite: (item) => notifier.toggleFavorite(item),
                      onReport: _doReport,
                      onView: (item) => notifier.recordView(item),
                      onOpenDetail: _openPostDetail,
                      onComment: _openCommentSheet,
                      onAuthorTap: _openAuthorProfile,
                      onFollow: (item) async {
                        final name =
                            item.authorUsername?.trim().isNotEmpty == true
                                ? item.authorUsername!.trim()
                                : '用户';
                        final id = item.authorId ?? '';
                        if (id.isEmpty) return;
                        await notifier.toggleFollow(id, name);
                      },
                      commentCountFor: (item) => notifier.commentCount(item),
                      isExpanded: (item) => notifier.isExpanded(item),
                      onToggleExpand: (item) =>
                          notifier.toggleDeepExpand(item),
                      deepMode: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _doReport(FeedItem item) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(width: 40, height: 4, decoration: BoxDecoration(
                color: AppColors.border, borderRadius: BorderRadius.circular(999))),
              const SizedBox(height: 14),
              Text('选择操作', style: AppTypography.labelLarge.copyWith(
                color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              _ReportOption(label: '不感兴趣', icon: Icons.visibility_off_outlined,
                  onTap: () => Navigator.pop(sheetContext, 'hide')),
              _ReportOption(label: '色情低俗', icon: Icons.report_outlined,
                  onTap: () => Navigator.pop(sheetContext, 'porn')),
              _ReportOption(label: '广告骚扰', icon: Icons.campaign_outlined,
                  onTap: () => Navigator.pop(sheetContext, 'spam')),
              _ReportOption(label: '人身攻击', icon: Icons.gavel_outlined,
                  onTap: () => Navigator.pop(sheetContext, 'abuse')),
              _ReportOption(label: '屏蔽该用户', icon: Icons.block_outlined,
                  onTap: () => Navigator.pop(sheetContext, 'block'), isDestructive: true),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: Text('取消', style: AppTypography.labelMedium.copyWith(
                      color: AppColors.textTertiary)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;

    String message;
    if (action == 'hide') {
      message = '将减少此类内容的推荐';
    } else if (action == 'block') {
      message = '已屏蔽该用户';
    } else {
      final notifier = ref.read(communityStateProvider.notifier);
      final reason = switch (action) {
        'porn' => '色情低俗',
        'spam' => '广告骚扰',
        'abuse' => '人身攻击',
        _ => '不适宜内容',
      };
      try {
        final ok = await notifier.report(item, reason: reason);
        message = ok ? '已收到你的举报反馈' : '你已经举报过这条内容';
      } catch (e) {
        message = '举报失败：$e';
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    return '${diff.inDays} 天前';
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onPublishTap;
  final VoidCallback onTagTap;
  final VoidCallback onNotificationTap;

  const _TopBar({
    required this.onPublishTap,
    required this.onTagTap,
    required this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    final tc = DefaultTabController.of(context);
    return ListenableBuilder(
      listenable: tc,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 12, 4),
          child: Row(
            children: [
              _MinimalTab(
                label: '推荐',
                selected: tc.index == 0,
                onTap: () => tc.animateTo(0),
              ),
              const SizedBox(width: 24),
              _MinimalTab(
                label: '深谈',
                selected: tc.index == 1,
                onTap: () => tc.animateTo(1),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const _SearchScreen()),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.search_rounded,
                      size: 24, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onPublishTap,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.add_box_outlined,
                      size: 24, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onTagTap,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.local_offer_outlined,
                      size: 22, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onNotificationTap,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.notifications_outlined,
                      size: 24, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MinimalTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MinimalTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTypography.labelMedium.copyWith(
                color: selected
                    ? AppColors.textPrimary
                    : AppColors.textTertiary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 2.5,
              width: selected ? 22 : 0,
              decoration: BoxDecoration(
                color: AppColors.primaryDark,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedList extends StatelessWidget {
  final List<FeedItem> items;
  final bool showStories;
  final bool deepMode;
  final Future<void> Function() onRefresh;
  final bool hasMore;
  final bool loadingMore;
  final Future<void> Function() onLoadMore;
  final Set<String> likedIds;
  final Set<String> favoritedIds;
  final Set<String> followedAuthorIds;
  final Future<void> Function(FeedItem item) onLike;
  final Future<void> Function(FeedItem item) onFavorite;
  final Future<void> Function(FeedItem item) onReport;
  final Future<void> Function(FeedItem item) onView;
  final Future<void> Function(FeedItem item) onOpenDetail;
  final Future<void> Function(FeedItem item) onComment;
  final Future<void> Function(FeedItem item) onAuthorTap;
  final Future<void> Function(FeedItem item) onFollow;
  final int Function(FeedItem item) commentCountFor;
  final bool Function(FeedItem item) isExpanded;
  final void Function(FeedItem item) onToggleExpand;

  const _FeedList({
    required this.items,
    required this.showStories,
    required this.onRefresh,
    required this.hasMore,
    required this.loadingMore,
    required this.onLoadMore,
    required this.likedIds,
    required this.favoritedIds,
    required this.followedAuthorIds,
    required this.onLike,
    required this.onFavorite,
    required this.onReport,
    required this.onView,
    required this.onOpenDetail,
    required this.onComment,
    required this.onAuthorTap,
    required this.onFollow,
    required this.commentCountFor,
    required this.isExpanded,
    required this.onToggleExpand,
    this.deepMode = false,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _EmptyState(onRefresh: onRefresh, deepMode: deepMode);
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: items.length + ((hasMore || loadingMore) ? 1 : 0),
        separatorBuilder: (_, _) => const Divider(
          height: 0.5,
          thickness: 0.5,
          color: AppColors.divider,
        ),
        itemBuilder: (context, index) {
          if (index >= items.length) {
            return _FeedLoadMoreFooter(
              hasMore: hasMore,
              loading: loadingMore,
              onTap: onLoadMore,
            );
          }
          final item = items[index];
          return _PostCard(
            item: item,
            deepMode: deepMode,
            liked: likedIds.contains(item.id),
            favorited: favoritedIds.contains(item.id),
            followed: followedAuthorIds.contains(item.authorId ?? ''),
            commentCount: commentCountFor(item),
            expanded: isExpanded(item),
            onLike: () => onLike(item),
            onFavorite: () => onFavorite(item),
            onReport: () => onReport(item),
            onView: () => onView(item),
            onOpenDetail: () => onOpenDetail(item),
            onComment: () => onComment(item),
            onAuthorTap: () => onAuthorTap(item),
            onFollow: () => onFollow(item),
            onToggleExpand: () => onToggleExpand(item),
          );
        },
      ),
    );
  }
}

// ─── Instagram-style zero-card PostCard ───

class _PostCard extends StatelessWidget {
  final FeedItem item;
  final bool deepMode;
  final bool liked;
  final bool favorited;
  final bool followed;
  final int commentCount;
  final bool expanded;
  final VoidCallback onLike;
  final VoidCallback onFavorite;
  final VoidCallback onReport;
  final VoidCallback onView;
  final VoidCallback onOpenDetail;
  final VoidCallback onComment;
  final VoidCallback onAuthorTap;
  final VoidCallback onFollow;
  final VoidCallback onToggleExpand;

  const _PostCard({
    required this.item,
    required this.deepMode,
    required this.liked,
    required this.favorited,
    required this.followed,
    required this.commentCount,
    required this.expanded,
    required this.onLike,
    required this.onFavorite,
    required this.onReport,
    required this.onView,
    required this.onOpenDetail,
    required this.onComment,
    required this.onAuthorTap,
    required this.onFollow,
    required this.onToggleExpand,
  });

  @override
  Widget build(BuildContext context) {
    final author = (item.authorUsername ?? '').trim().isEmpty
        ? '匿名用户'
        : item.authorUsername!.trim();
    final handleText = _feedDisplayHandle(item);
    final body = item.displaySummary.trim().isEmpty
        ? '（暂无内容）'
        : item.displaySummary.trim();
    final hasImage = (item.coverImageUrl ?? '').trim().isNotEmpty;
    final firstSentence = body.split('。').first.trim();

    String visibleText() {
      if (!deepMode) {
        if (body.length <= 80) return body;
        return '${body.substring(0, 80)}...';
      }
      if (expanded) return body;
      if (body.length <= 98) return body;
      return '${body.substring(0, 98)}...';
    }

    final truncated = visibleText() != body;
    final canFollow =
        (item.authorId ?? '').trim().isNotEmpty && !followed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Author row (two lines, Ins-style) ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: onAuthorTap,
                child: _AuthorAvatar(
                  imageUrl: item.authorAvatarUrl,
                  label: author,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      author,
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$handleText · 宽窄之间',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (canFollow)
                TextButton(
                  onPressed: onFollow,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    '关注',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else if (followed)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    '已关注',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              GestureDetector(
                onTap: onReport,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.more_horiz_rounded,
                    size: 22,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Media: fixed 4:5 aspect (avoids zero height in Column) ──
        if (hasImage)
          GestureDetector(
            onTap: onOpenDetail,
            child: AspectRatio(
              aspectRatio: 4 / 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    item.coverImageUrl!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: AppColors.surfaceVariant,
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            value: progress.expectedTotalBytes != null
                                ? progress.cumulativeBytesLoaded /
                                    progress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      if (kDebugMode) {
                        debugPrint(
                          'Feed cover load failed: ${item.coverImageUrl} — $error',
                        );
                      }
                      return Container(
                        color: AppColors.surfaceVariant,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.image_not_supported_outlined,
                              color: AppColors.textTertiary,
                              size: 40,
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              child: Text(
                                '图片暂不可用（可检查网络）',
                                textAlign: TextAlign.center,
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  if (deepMode && firstSentence.isNotEmpty)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding:
                            const EdgeInsets.fromLTRB(14, 28, 14, 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.55),
                            ],
                          ),
                        ),
                        child: Text(
                          '「$firstSentence」',
                          style: AppTypography.bodySmall.copyWith(
                            color: Colors.white,
                            height: 1.5,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          )
        else
          GestureDetector(
            onTap: onOpenDetail,
            child: _TextOnlyBlock(body: body),
          ),

        // ── Action bar with inline counts ──
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 2, 2, 0),
          child: Row(
            children: [
              _ActionIcon(
                icon: liked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: liked ? AppColors.accent : AppColors.textPrimary,
                label: _formatMetricCount(item.metrics.likes),
                onTap: onLike,
              ),
              _ActionIcon(
                icon: Icons.mode_comment_outlined,
                label: commentCount > 0 ? '$commentCount' : null,
                onTap: onComment,
              ),
              _ActionIcon(
                icon: Icons.send_outlined,
                label: item.metrics.views > 0
                    ? _formatMetricCount(item.metrics.views)
                    : null,
                onTap: onView,
              ),
              const Spacer(),
              _ActionIcon(
                icon: favorited
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                onTap: onFavorite,
              ),
            ],
          ),
        ),

        // ── Caption + date ──
        if (hasImage)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
            child: GestureDetector(
              onTap: onOpenDetail,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '$author ',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(
                          text: visibleText(),
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                            height: 1.5,
                          ),
                        ),
                        if (truncated)
                          TextSpan(
                            text: ' 更多',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                      ],
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _feedFormatPostDate(item.createdAt),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),

        if (commentCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
            child: GestureDetector(
              onTap: onComment,
              child: Text(
                '查看全部 $commentCount 条评论',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ),

        if (deepMode) ...[
          if (body.length > 98)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
              child: GestureDetector(
                onTap: onToggleExpand,
                child: Text(
                  expanded ? '收起' : '展开全文',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
            child: GestureDetector(
              onTap: onComment,
              child: Text(
                '继续追问 →',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],

        const SizedBox(height: 12),
      ],
    );
  }
}

String _feedDisplayHandle(FeedItem item) {
  final h = item.authorHandle?.trim();
  if (h != null && h.isNotEmpty) {
    return h.startsWith('@') ? h : '@$h';
  }
  final id = item.authorId?.trim();
  if (id != null && id.isNotEmpty) {
    final tail = id.length > 10 ? id.substring(id.length - 10) : id;
    return '@$tail';
  }
  return '@anonymous';
}

String _feedFormatPostDate(DateTime dt) {
  return '${dt.month}月${dt.day}日';
}

String _formatMetricCount(int n) {
  if (n >= 10000) {
    final w = n / 10000;
    return '${w.toStringAsFixed(w >= 10 ? 0 : 1)}万';
  }
  return '$n';
}

class _AuthorAvatar extends StatelessWidget {
  final String? imageUrl;
  final String label;

  const _AuthorAvatar({
    required this.imageUrl,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final letter = label.characters.first;
    final url = imageUrl?.trim();
    if (url == null || url.isEmpty) {
      return CircleAvatar(
        radius: 18,
        backgroundColor: AppColors.surfaceVariant,
        child: Text(
          letter,
          style: AppTypography.labelLarge.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: 18,
      backgroundColor: AppColors.surfaceVariant,
      child: ClipOval(
        child: Image.network(
          url,
          width: 36,
          height: 36,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Center(
            child: Text(
              letter,
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded /
                          progress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Full-width text block for image-less posts (no gradient, no card).
class _TextOnlyBlock extends StatelessWidget {
  final String body;

  const _TextOnlyBlock({required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 180),
      color: AppColors.canvasWarm,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      alignment: Alignment.centerLeft,
      child: Text(
        body,
        style: AppTypography.headlineSmall.copyWith(
          color: AppColors.textPrimary,
          height: 1.7,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 6,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Action row: icon + optional compact count (Instagram-style).
class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;
  final String? label;

  const _ActionIcon({
    required this.icon,
    required this.onTap,
    this.color,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textPrimary;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: c),
            if (label != null && label!.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                label!,
                style: AppTypography.labelMedium.copyWith(
                  color: c,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FeedLoadMoreFooter extends StatelessWidget {
  final bool hasMore;
  final bool loading;
  final Future<void> Function() onTap;

  const _FeedLoadMoreFooter({
    required this.hasMore,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : hasMore
                ? TextButton(
                    onPressed: () => unawaited(onTap()),
                    child: const Text('加载更多'),
                  )
                : Text(
                    '没有更多内容了',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool deepMode;
  final Future<void> Function() onRefresh;

  const _EmptyState({required this.onRefresh, required this.deepMode});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        children: [
          const SizedBox(height: 130),
          Center(
            child: Column(
              children: [
                Icon(
                  deepMode ? Icons.menu_book_outlined : Icons.forum_outlined,
                  size: 42,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(height: 12),
                Text(
                  deepMode ? '还没有深谈内容' : '还没有推荐内容',
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '下拉刷新，或发布你的第一条内容',
                  style: AppTypography.bodySmall.copyWith(
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

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 44,
                color: AppColors.textTertiary,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () => unawaited(onRetry()),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchScreen extends StatefulWidget {
  const _SearchScreen();

  @override
  State<_SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<_SearchScreen> {
  final _controller = TextEditingController();
  bool _hasQuery = false;

  static const _hotTopics = [
    '六爻入门', '今日签名', '同频', '情绪价值',
    '解读卡', '仪式感', '摇一摇', '宽窄之间',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        title: Container(
          height: 38,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(999),
          ),
          child: TextField(
            controller: _controller,
            autofocus: true,
            style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary),
            onChanged: (v) => setState(() => _hasQuery = v.trim().isNotEmpty),
            decoration: InputDecoration(
              hintText: '搜索帖子、用户或活动…',
              hintStyle: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
              prefixIcon: Icon(Icons.search_rounded, size: 18, color: AppColors.textTertiary),
              prefixIconConstraints: const BoxConstraints(minWidth: 40),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ),
      body: _hasQuery
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off_rounded, size: 48,
                      color: AppColors.textTertiary),
                  const SizedBox(height: 12),
                  Text('搜索功能将在后端接入后启用',
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text(
                    '当前仅保留本地搜索演示，正式搜索能力会在后续版本接入。',
                    textAlign: TextAlign.center,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textTertiary),
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('热门话题',
                      style: AppTypography.labelLarge
                          .copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _hotTopics.map((t) => GestureDetector(
                      onTap: () {
                        _controller.text = t;
                        setState(() => _hasQuery = true);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(t, style: AppTypography.labelSmall
                            .copyWith(color: AppColors.textSecondary)),
                      ),
                    )).toList(),
                  ),
                ],
              ),
            ),
    );
  }
}

class _PostDetailScreen extends StatelessWidget {
  final FeedItem item;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final int commentCount;

  const _PostDetailScreen({
    required this.item,
    required this.onLike,
    required this.onComment,
    required this.commentCount,
  });

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    return '${diff.inDays} 天前';
  }

  @override
  Widget build(BuildContext context) {
    final author = item.authorUsername?.trim().isNotEmpty == true
        ? item.authorUsername!.trim()
        : '匿名用户';
    final body =
        item.displaySummary.trim().isEmpty ? '（暂无内容）' : item.displaySummary;
    final hasImage =
        item.coverImageUrl != null && item.coverImageUrl!.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(author,
            style: AppTypography.labelLarge
                .copyWith(color: AppColors.textPrimary)),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasImage)
                    Image.network(
                      item.coverImageUrl!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 240,
                        color: AppColors.surfaceVariant,
                        child: const Center(
                          child: Icon(Icons.image_outlined, size: 40,
                              color: Color(0xFFAAAAAA)),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.surfaceVariant,
                          child: Text(author[0],
                              style: AppTypography.labelMedium
                                  .copyWith(color: AppColors.textSecondary)),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(author,
                                style: AppTypography.labelMedium.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600)),
                            Text(_formatTimeAgo(item.createdAt),
                                style: AppTypography.caption.copyWith(
                                    color: AppColors.textTertiary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Text(
                      body,
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppColors.textPrimary,
                        height: 1.85,
                      ),
                    ),
                  ),
                  const Divider(height: 0.5),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Text('评论',
                        style: AppTypography.labelMedium.copyWith(
                            color: AppColors.textSecondary)),
                  ),
                  if (commentCount == 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                      child: Text('暂无评论，来说点什么吧',
                          style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textTertiary)),
                    ),
                  if (commentCount > 0)
                    ...List.generate(
                      commentCount > 3 ? 3 : commentCount,
                      (i) => Padding(
                        padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: AppColors.surfaceVariant,
                              child: Text('U',
                                  style: AppTypography.caption
                                      .copyWith(color: AppColors.textTertiary)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('用户${i + 1}',
                                      style: AppTypography.labelSmall.copyWith(
                                          color: AppColors.textSecondary)),
                                  const SizedBox(height: 2),
                                  Text('这条内容写得真好，很有共鸣。',
                                      style: AppTypography.bodySmall.copyWith(
                                          color: AppColors.textPrimary)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: onLike,
                    child: Row(
                      children: [
                        Icon(Icons.favorite_border_rounded, size: 22,
                            color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text('${item.metrics.likes}',
                            style: AppTypography.labelSmall
                                .copyWith(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  GestureDetector(
                    onTap: onComment,
                    child: Row(
                      children: [
                        Icon(Icons.mode_comment_outlined, size: 20,
                            color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text('$commentCount',
                            style: AppTypography.labelSmall
                                .copyWith(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.bookmark_border_rounded, size: 22,
                      color: AppColors.textSecondary),
                  const SizedBox(width: 16),
                  Icon(Icons.share_outlined, size: 20,
                      color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationSheet extends StatelessWidget {
  const _NotificationSheet();

  static const _mockNotifications = [
    _NotifItem('若闻 赞了你的帖子', '2 分钟前', Icons.favorite_rounded),
    _NotifItem('余海 开始关注你', '15 分钟前', Icons.person_add_rounded),
    _NotifItem('你的帖子获得了 10 次新浏览', '1 小时前', Icons.visibility_rounded),
    _NotifItem('清辞 评论了你的帖子', '3 小时前', Icons.mode_comment_rounded),
    _NotifItem('系统：社区规范已更新', '1 天前', Icons.info_outline_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 480),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  Text(
                    '通知',
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () async {
                      Navigator.pop(context);
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const MessageScreen()),
                      );
                    },
                    child: Text(
                      '消息中心',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已全部标为已读')),
                      );
                    },
                    child: Text(
                      '全部已读',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 0.5),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: _mockNotifications.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 0.5, indent: 56),
                itemBuilder: (_, index) {
                  final n = _mockNotifications[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Icon(n.icon, size: 18,
                              color: AppColors.textSecondary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(n.text,
                                  style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.textPrimary)),
                              const SizedBox(height: 2),
                              Text(n.time,
                                  style: AppTypography.caption.copyWith(
                                      color: AppColors.textTertiary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotifItem {
  final String text;
  final String time;
  final IconData icon;
  const _NotifItem(this.text, this.time, this.icon);
}

class _ReportOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ReportOption({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppColors.accent : AppColors.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 14),
            Text(label, style: AppTypography.bodyMedium.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}
