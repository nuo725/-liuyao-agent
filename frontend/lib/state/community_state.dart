import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/feed_item.dart';
import '../services/feed_service.dart';
import 'auth_state.dart';
import 'profile_hub_state.dart';

class CommentEntry {
  final String id;
  final String author;
  final String text;
  final DateTime createdAt;

  const CommentEntry({
    required this.id,
    required this.author,
    required this.text,
    required this.createdAt,
  });
}

class CommunityState {
  final bool loading;
  final String? error;
  final List<FeedItem> recommended;
  final List<FeedItem> deep;
  final bool loadingMoreRecommended;
  final bool loadingMoreDeep;
  final bool hasMoreRecommended;
  final bool hasMoreDeep;
  final int nextRecommendedPage;
  final int nextDeepPage;
  final Set<String> likedIds;
  final Set<String> favoritedIds;
  final Set<String> reportedIds;
  final Set<String> followedAuthorIds;
  final Map<String, bool> expandedDeepMap;
  final Map<String, List<CommentEntry>> commentsByPost;

  const CommunityState({
    this.loading = true,
    this.error,
    this.recommended = const [],
    this.deep = const [],
    this.loadingMoreRecommended = false,
    this.loadingMoreDeep = false,
    this.hasMoreRecommended = false,
    this.hasMoreDeep = false,
    this.nextRecommendedPage = 2,
    this.nextDeepPage = 2,
    this.likedIds = const {},
    this.favoritedIds = const {},
    this.reportedIds = const {},
    this.followedAuthorIds = const {},
    this.expandedDeepMap = const {},
    this.commentsByPost = const {},
  });

  CommunityState copyWith({
    bool? loading,
    String? error,
    bool clearError = false,
    List<FeedItem>? recommended,
    List<FeedItem>? deep,
    bool? loadingMoreRecommended,
    bool? loadingMoreDeep,
    bool? hasMoreRecommended,
    bool? hasMoreDeep,
    int? nextRecommendedPage,
    int? nextDeepPage,
    Set<String>? likedIds,
    Set<String>? favoritedIds,
    Set<String>? reportedIds,
    Set<String>? followedAuthorIds,
    Map<String, bool>? expandedDeepMap,
    Map<String, List<CommentEntry>>? commentsByPost,
  }) {
    return CommunityState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      recommended: recommended ?? this.recommended,
      deep: deep ?? this.deep,
      loadingMoreRecommended:
          loadingMoreRecommended ?? this.loadingMoreRecommended,
      loadingMoreDeep: loadingMoreDeep ?? this.loadingMoreDeep,
      hasMoreRecommended: hasMoreRecommended ?? this.hasMoreRecommended,
      hasMoreDeep: hasMoreDeep ?? this.hasMoreDeep,
      nextRecommendedPage: nextRecommendedPage ?? this.nextRecommendedPage,
      nextDeepPage: nextDeepPage ?? this.nextDeepPage,
      likedIds: likedIds ?? this.likedIds,
      favoritedIds: favoritedIds ?? this.favoritedIds,
      reportedIds: reportedIds ?? this.reportedIds,
      followedAuthorIds: followedAuthorIds ?? this.followedAuthorIds,
      expandedDeepMap: expandedDeepMap ?? this.expandedDeepMap,
      commentsByPost: commentsByPost ?? this.commentsByPost,
    );
  }
}

class CommunityNotifier extends Notifier<CommunityState> {
  @override
  CommunityState build() {
    Future.microtask(() => loadFeeds(showLoading: true));
    return const CommunityState();
  }

  String get _activeUserId {
    final user = ref.read(authStateProvider).user;
    return user?.id ?? 'guest-local';
  }

  String get activeUserName {
    final user = ref.read(authStateProvider).user;
    final name = (user?.username ?? '').trim();
    return name.isEmpty ? '你' : name;
  }

  Future<void> loadFeeds({required bool showLoading}) async {
    if (showLoading) {
      state = state.copyWith(loading: true, clearError: true);
    }
    try {
      final results = await Future.wait<FeedResult>([
        feedServiceProvider.getRecommendFeed(
          tab: 'recommended',
          page: 1,
          pageSize: 3,
        ),
        feedServiceProvider.getRecommendFeed(
          tab: 'deep',
          page: 1,
          pageSize: 3,
        ),
      ]);
      state = state.copyWith(
        recommended: results[0].items,
        deep: results[1].items,
        hasMoreRecommended: results[0].hasMore,
        hasMoreDeep: results[1].hasMore,
        nextRecommendedPage: results[0].nextPage,
        nextDeepPage: results[1].nextPage,
        loadingMoreRecommended: false,
        loadingMoreDeep: false,
        loading: false,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: '加载社区内容失败，请稍后重试（$e）',
      );
    }
  }

  Future<void> loadMore({required bool deepMode}) async {
    if (deepMode) {
      if (state.loadingMoreDeep || !state.hasMoreDeep) return;
      state = state.copyWith(loadingMoreDeep: true);
      try {
        final result = await feedServiceProvider.getRecommendFeed(
          tab: 'deep',
          page: state.nextDeepPage,
          pageSize: 3,
        );
        state = state.copyWith(
          deep: [...state.deep, ...result.items],
          hasMoreDeep: result.hasMore,
          nextDeepPage: result.nextPage,
          loadingMoreDeep: false,
        );
      } catch (_) {
        state = state.copyWith(loadingMoreDeep: false);
      }
      return;
    }

    if (state.loadingMoreRecommended || !state.hasMoreRecommended) return;
    state = state.copyWith(loadingMoreRecommended: true);
    try {
      final result = await feedServiceProvider.getRecommendFeed(
        tab: 'recommended',
        page: state.nextRecommendedPage,
        pageSize: 3,
      );
      state = state.copyWith(
        recommended: [...state.recommended, ...result.items],
        hasMoreRecommended: result.hasMore,
        nextRecommendedPage: result.nextPage,
        loadingMoreRecommended: false,
      );
    } catch (_) {
      state = state.copyWith(loadingMoreRecommended: false);
    }
  }

  FeedItem? findById(String id) {
    for (final item in state.recommended) {
      if (item.id == id) return item;
    }
    for (final item in state.deep) {
      if (item.id == id) return item;
    }
    return null;
  }

  void _replaceItem(FeedItem updated) {
    state = state.copyWith(
      recommended: state.recommended
          .map((item) => item.id == updated.id ? updated : item)
          .toList(growable: false),
      deep: state.deep
          .map((item) => item.id == updated.id ? updated : item)
          .toList(growable: false),
    );
  }

  List<CommentEntry> ensureComments(FeedItem item) {
    final existing = state.commentsByPost[item.id];
    if (existing != null) return existing;
    final seed = <CommentEntry>[
      CommentEntry(
        id: '${item.id}-seed-1',
        author: '空山',
        text: '这个角度很有共鸣，我也在经历类似阶段。',
        createdAt: DateTime.now().subtract(const Duration(minutes: 18)),
      ),
      CommentEntry(
        id: '${item.id}-seed-2',
        author: '木月',
        text: '我会先从一句可执行的小行动开始，挺有用。',
        createdAt: DateTime.now().subtract(const Duration(minutes: 6)),
      ),
    ];
    state = state.copyWith(
      commentsByPost: {...state.commentsByPost, item.id: seed},
    );
    return seed;
  }

  int commentCount(FeedItem item) => ensureComments(item).length;

  bool isExpanded(FeedItem item) => state.expandedDeepMap[item.id] ?? false;

  void toggleDeepExpand(FeedItem item) {
    final current = state.expandedDeepMap[item.id] ?? false;
    state = state.copyWith(
      expandedDeepMap: {...state.expandedDeepMap, item.id: !current},
    );
  }

  Future<void> toggleLike(FeedItem item) async {
    final userId = _activeUserId;
    final alreadyLiked = state.likedIds.contains(item.id);
    if (alreadyLiked) {
      await feedServiceProvider.unlike(item.id, userId);
      state = state.copyWith(
        likedIds: {...state.likedIds}..remove(item.id),
      );
      await ref
          .read(profileHubStateProvider.notifier)
          .removeLike(source: 'community_like', contentKey: item.id);
    } else {
      await feedServiceProvider.like(item.id, userId);
      state = state.copyWith(likedIds: {...state.likedIds, item.id});
      await ref.read(profileHubStateProvider.notifier).recordLike(
            source: 'community_like',
            contentKey: item.id,
            title: '有人点赞了你的内容',
            detail: item.displaySummary,
          );
    }
    final current = findById(item.id);
    if (current != null) {
      _replaceItem(
        current.copyWith(
          metrics: current.metrics.copyWith(
            likes: alreadyLiked
                ? (current.metrics.likes - 1).clamp(0, 999999)
                : current.metrics.likes + 1,
          ),
        ),
      );
    }
  }

  Future<void> toggleFavorite(FeedItem item) async {
    final userId = _activeUserId;
    final alreadyFavorited = state.favoritedIds.contains(item.id);
    if (alreadyFavorited) {
      await feedServiceProvider.unfavorite(item.id, userId);
      state = state.copyWith(
        favoritedIds: {...state.favoritedIds}..remove(item.id),
      );
    } else {
      await feedServiceProvider.favorite(item.id, userId);
      state = state.copyWith(
        favoritedIds: {...state.favoritedIds, item.id},
      );
      await ref.read(profileHubStateProvider.notifier).recordLike(
            source: 'community_favorite',
            contentKey: '${item.id}-favorite',
            title: '你收藏了一条内容',
            detail: item.displaySummary,
          );
    }
    final current = findById(item.id);
    if (current != null) {
      _replaceItem(
        current.copyWith(
          metrics: current.metrics.copyWith(
            favorites: alreadyFavorited
                ? (current.metrics.favorites - 1).clamp(0, 999999)
                : current.metrics.favorites + 1,
          ),
        ),
      );
    }
  }

  Future<bool> report(FeedItem item, {String reason = '不适宜内容'}) async {
    if (state.reportedIds.contains(item.id)) return false;
    await feedServiceProvider.report(item.id, _activeUserId, reason);
    state = state.copyWith(reportedIds: {...state.reportedIds, item.id});
    final current = findById(item.id);
    if (current != null) {
      _replaceItem(
        current.copyWith(
          metrics: current.metrics.copyWith(
            reports: current.metrics.reports + 1,
          ),
        ),
      );
    }
    return true;
  }

  Future<void> recordView(FeedItem item) async {
    try {
      await feedServiceProvider.recordView(item.id);
      await ref.read(profileHubStateProvider.notifier).recordBrowse(
            source: 'community_view',
            contentKey: item.id,
            title: item.displaySummary,
            snippet: item.authorUsername,
          );
      final current = findById(item.id);
      if (current != null) {
        _replaceItem(
          current.copyWith(
            metrics: current.metrics.copyWith(
              views: current.metrics.views + 1,
            ),
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> addComment(FeedItem item, String text) async {
    final entry = CommentEntry(
      id: '${item.id}-${DateTime.now().microsecondsSinceEpoch}',
      author: activeUserName,
      text: text,
      createdAt: DateTime.now(),
    );
    final existing = ensureComments(item);
    state = state.copyWith(
      commentsByPost: {
        ...state.commentsByPost,
        item.id: [...existing, entry],
      },
    );
    await ref.read(profileHubStateProvider.notifier).recordLike(
          source: 'community_comment',
          contentKey: entry.id,
          title: '你参与了评论讨论',
          detail: text,
        );
  }

  Future<void> toggleFollow(String authorId, String authorName) async {
    final followed = state.followedAuthorIds.contains(authorId);
    if (followed) {
      state = state.copyWith(
        followedAuthorIds: {...state.followedAuthorIds}..remove(authorId),
      );
      await ref.read(profileHubStateProvider.notifier).removeLike(
            source: 'community_follow',
            contentKey: 'follow-$authorId',
          );
    } else {
      state = state.copyWith(
        followedAuthorIds: {...state.followedAuthorIds, authorId},
      );
      await ref.read(profileHubStateProvider.notifier).recordLike(
            source: 'community_follow',
            contentKey: 'follow-$authorId',
            title: '你关注了 $authorName',
            detail: '后续更新将进入消息提醒（模拟）',
          );
    }
  }
}

final communityStateProvider =
    NotifierProvider<CommunityNotifier, CommunityState>(
      CommunityNotifier.new,
    );
