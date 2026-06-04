import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/feed_item.dart';
import '../models/interpretation_card.dart';
import '../models/pattern.dart';

abstract class FeedService {
  Future<FeedResult> getRecommendFeed({
    required String tab,
    int page = 1,
    int pageSize = 20,
  });

  Future<FeedResult> getMyFeed(
    String userId, {
    int page = 1,
    int pageSize = 20,
  });

  Future<FeedItem> publish({
    required InterpretationCard card,
    required String? authorId,
    required String? authorUsername,
    String? shareText,
    String? coverImageUrl,
  });

  Future<void> like(String feedItemId, String userId);

  Future<void> unlike(String feedItemId, String userId);

  Future<void> favorite(String feedItemId, String userId);

  Future<void> unfavorite(String feedItemId, String userId);

  Future<void> report(String feedItemId, String userId, String reason);

  Future<void> recordView(String feedItemId);
}

class FeedResult {
  final List<FeedItem> items;
  final bool hasMore;
  final int nextPage;

  const FeedResult({
    required this.items,
    required this.hasMore,
    required this.nextPage,
  });
}

class FeedApiClient {
  static const String _baseUrl = String.fromEnvironment(
    'BUSINESS_API_BASE_URL',
    defaultValue: '',
  );

  final http.Client _client;

  FeedApiClient({http.Client? client}) : _client = client ?? http.Client();

  bool get enabled => _baseUrl.trim().isNotEmpty;

  Future<FeedResult> getRecommendFeed({
    required String tab,
    required int page,
    required int pageSize,
  }) async {
    _ensureEnabled();
    final uri = Uri.parse('$_baseUrl/feed/recommend').replace(
      queryParameters: {'tab': tab, 'page': '$page', 'pageSize': '$pageSize'},
    );
    final resp = await _client.get(uri).timeout(const Duration(seconds: 12));
    _checkStatus(resp);
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return _parseFeedResult(data['data'] as Map<String, dynamic>? ?? data);
  }

  Future<FeedResult> getMyFeed({
    required String userId,
    required int page,
    required int pageSize,
  }) async {
    _ensureEnabled();
    final uri = Uri.parse('$_baseUrl/feed/mine').replace(
      queryParameters: {
        'userId': userId,
        'page': '$page',
        'pageSize': '$pageSize',
      },
    );
    final resp = await _client.get(uri).timeout(const Duration(seconds: 12));
    _checkStatus(resp);
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return _parseFeedResult(data['data'] as Map<String, dynamic>? ?? data);
  }

  Future<FeedItem> publish({
    required String cardId,
    required String? authorId,
    required String? authorUsername,
    String? shareText,
    String? coverImageUrl,
  }) async {
    _ensureEnabled();
    final uri = Uri.parse('$_baseUrl/feed/publish');
    final payload = {
      'cardId': cardId,
      'authorId': authorId,
      'authorUsername': authorUsername,
      ...?((shareText != null) ? {'shareText': shareText} : null),
      ...?((coverImageUrl != null) ? {'coverImageUrl': coverImageUrl} : null),
    };
    final resp = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 12));
    _checkStatus(resp);
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return _parseFeedItem(data['data'] as Map<String, dynamic>);
  }

  Future<void> like(String feedItemId, String userId) async {
    await _postSimple('/feed/$feedItemId/like', {'userId': userId});
  }

  Future<void> unlike(String feedItemId, String userId) async {
    await _postSimple('/feed/$feedItemId/unlike', {'userId': userId});
  }

  Future<void> favorite(String feedItemId, String userId) async {
    await _postSimple('/feed/$feedItemId/favorite', {'userId': userId});
  }

  Future<void> unfavorite(String feedItemId, String userId) async {
    await _postSimple('/feed/$feedItemId/unfavorite', {'userId': userId});
  }

  Future<void> report(String feedItemId, String userId, String reason) async {
    await _postSimple('/feed/$feedItemId/report', {
      'userId': userId,
      'reason': reason,
    });
  }

  Future<void> recordView(String feedItemId) async {
    await _postSimple('/feed/$feedItemId/view', {});
  }

  Future<void> _postSimple(String path, Map<String, dynamic> body) async {
    _ensureEnabled();
    final uri = Uri.parse('$_baseUrl$path');
    final resp = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));
    _checkStatus(resp);
  }

  void _ensureEnabled() {
    if (!enabled) {
      throw const FeedException('未配置 Feed API 地址。');
    }
  }

  void _checkStatus(http.Response resp) {
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw FeedException('Feed 服务异常(${resp.statusCode})');
    }
  }

  FeedResult _parseFeedResult(Map<String, dynamic> data) {
    final rawItems = data['items'] as List? ?? const [];
    final items = rawItems
        .whereType<Map>()
        .map((e) => _parseFeedItem(Map<String, dynamic>.from(e)))
        .toList();
    return FeedResult(
      items: items,
      hasMore: data['hasMore'] as bool? ?? false,
      nextPage: data['nextPage'] as int? ?? 2,
    );
  }

  FeedItem _parseFeedItem(Map<String, dynamic> data) {
    return FeedItem(
      id: (data['id'] ?? '').toString(),
      cardId: (data['cardId'] ?? '').toString(),
      card: data['card'] != null
          ? InterpretationCard.fromJson(Map<String, dynamic>.from(data['card']))
          : throw const FeedException('FeedItem 缺少 card 字段'),
      shareText: data['shareText']?.toString(),
      coverImageUrl: data['coverImageUrl']?.toString(),
      authorId: data['authorId']?.toString(),
      authorUsername: data['authorUsername']?.toString(),
      authorHandle: data['authorHandle']?.toString(),
      authorAvatarUrl: data['authorAvatarUrl']?.toString(),
      createdAt:
          DateTime.tryParse((data['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      status: FeedItemStatus.values.firstWhere(
        (s) => s.value == data['status'],
        orElse: () => FeedItemStatus.published,
      ),
      metrics: data['metrics'] != null
          ? FeedItemMetrics.fromJson(Map<String, dynamic>.from(data['metrics']))
          : const FeedItemMetrics(),
    );
  }
}

class FeedException implements Exception {
  final String message;
  const FeedException(this.message);

  @override
  String toString() => message;
}

class LocalFeedStore {
  static const String _feedKey = 'feed_items_v2';
  static const String _seededKey = 'feed_seeded_v3';

  SharedPreferences? _prefs;
  final List<FeedItem> _items = <FeedItem>[];
  bool _loaded = false;
  int _idCounter = 0;

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await _preferences;
    final raw = prefs.getString(_feedKey);
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final parsed = jsonDecode(raw);
        if (parsed is List) {
          _items
            ..clear()
            ..addAll(
              parsed.whereType<Map>().map(
                (e) => FeedItem.fromJson(Map<String, dynamic>.from(e)),
              ),
            );
        }
      } catch (_) {
        _items.clear();
      }
    }

    final seededV3 = prefs.getBool(_seededKey) ?? false;
    final needsLegacySeedMigration = _needsLegacySeedMigration(_items);
    if (!seededV3 || needsLegacySeedMigration) {
      _items.clear();
      _seedInitialDemoItems();
      await prefs.setBool(_seededKey, true);
      await persist();
    }

    _idCounter = _deriveMaxCounter(_items);
    _loaded = true;
  }

  int _deriveMaxCounter(List<FeedItem> items) {
    var maxId = 0;
    for (final item in items) {
      final m = RegExp(r'feed_(\d+)$').firstMatch(item.id);
      final v = int.tryParse(m?.group(1) ?? '');
      if (v != null && v > maxId) maxId = v;
    }
    return maxId;
  }

  bool _needsLegacySeedMigration(List<FeedItem> items) {
    if (items.isEmpty) return false;
    final allSeedLike = items.every((item) => item.cardId.startsWith('seed_'));
    if (!allSeedLike) return false;
    final hasAnyCover = items.any(
      (item) => (item.coverImageUrl ?? '').trim().isNotEmpty,
    );
    final hasAnyHandle = items.any(
      (item) => (item.authorHandle ?? '').trim().isNotEmpty,
    );
    return !hasAnyCover || !hasAnyHandle;
  }

  Future<void> persist() async {
    final prefs = await _preferences;
    await prefs.setString(
      _feedKey,
      jsonEncode(_items.map((e) => e.toJson()).toList()),
    );
  }

  List<FeedItem> get items => _items;

  int nextId() => ++_idCounter;

  // TODO(Backend Integration)[community_api#feed-image-cdn]:
  // Replace Picsum with your CDN + signed URLs in production.
  /// Picsum is generally more reachable than Unsplash in some regions.
  static String _picsumCover(String seed) =>
      'https://picsum.photos/seed/orbit_cv_$seed/1080/1350';

  static String _picsumAvatar(String seed) =>
      'https://picsum.photos/seed/orbit_av_$seed/128/128';

  void _seedInitialDemoItems() {
    final now = DateTime.now();
    _items.addAll(<FeedItem>[
      // ── Recommended tab (4 posts: 3 with images, 1 text-only) ──
      _seedItem(
        cardId: 'seed_recommended_1',
        author: '若闻',
        handle: 'ruowen',
        avatarSeed: 'r1',
        text: '你拒绝，别人就知道了你的边界。不需要解释太多，温柔而坚定就好。',
        createdAt: now.subtract(const Duration(minutes: 12)),
        imageUrl: _picsumCover('r1'),
        likes: 47,
        views: 230,
      ),
      _seedItem(
        cardId: 'seed_recommended_2',
        author: '余海',
        handle: 'yuhai_orbit',
        avatarSeed: 'r2',
        text: '今天只做一件小事：把最想逃避的一条消息，认真回完。剩下的，明天再说。',
        createdAt: now.subtract(const Duration(minutes: 38)),
        imageUrl: _picsumCover('r2'),
        likes: 32,
        views: 178,
      ),
      _seedItem(
        cardId: 'seed_recommended_3',
        author: '清辞',
        handle: 'qingci',
        avatarSeed: 'r3',
        text: '把期待放低一点，不是妥协，是给自己留出被惊喜的余地。',
        createdAt: now.subtract(const Duration(hours: 1, minutes: 15)),
        likes: 89,
        views: 320,
      ),
      _seedItem(
        cardId: 'seed_recommended_4',
        author: '一念',
        handle: 'yinian',
        avatarSeed: 'r4',
        text: '窗外下着小雨，泡了一杯白茶。突然觉得，慢下来本身就是一种答案。不是所有问题都需要立刻回应。',
        createdAt: now.subtract(const Duration(hours: 3)),
        imageUrl: _picsumCover('r4'),
        likes: 56,
        views: 195,
      ),

      // ── Deep tab (4 posts: 2 with images, 2 text-only) ──
      _seedItem(
        cardId: 'seed_deep_1',
        author: '心安',
        handle: 'xinan',
        avatarSeed: 'd1',
        text: '焦虑不是因为做得不够，而是你试图同时满足太多方向。允许自己一次只走一条路，反而会走得更远。',
        createdAt: now.subtract(const Duration(hours: 2)),
        imageUrl: _picsumCover('d1'),
        likes: 73,
        views: 289,
      ),
      _seedItem(
        cardId: 'seed_deep_2',
        author: '明远',
        handle: 'mingyuan',
        avatarSeed: 'd2',
        text: '复杂问题里，顺序比强度更重要。先选第一步，再谈后续。很多时候我们不是缺少答案，而是问错了问题。',
        createdAt: now.subtract(const Duration(hours: 6)),
        likes: 28,
        views: 156,
      ),
      _seedItem(
        cardId: 'seed_deep_3',
        author: '栖迟',
        handle: 'qichi',
        avatarSeed: 'd3',
        text: '有时候沉默不是没有话说，而是终于不再需要用语言来证明什么。安静地待着，也是一种表达。',
        createdAt: now.subtract(const Duration(hours: 8)),
        imageUrl: _picsumCover('d3'),
        likes: 41,
        views: 210,
      ),
      _seedItem(
        cardId: 'seed_deep_4',
        author: '渡澜',
        handle: 'dulan',
        avatarSeed: 'd4',
        text: '你以为放下是一瞬间的事，其实它是无数个「算了」慢慢堆出来的。不急，每一次松手都算数。',
        createdAt: now.subtract(const Duration(hours: 12)),
        likes: 62,
        views: 275,
      ),
    ]);
  }

  FeedItem _seedItem({
    required String cardId,
    required String author,
    required String handle,
    required String avatarSeed,
    required String text,
    required DateTime createdAt,
    String? imageUrl,
    int likes = 0,
    int views = 0,
  }) {
    final n = nextId();
    return FeedItem(
      id: 'feed_$n',
      cardId: cardId,
      card: InterpretationCard(
        id: cardId,
        question: '',
        tag: QuestionTag.other,
        pattern: Pattern(lines: const [1, 0, 1, 1, 0, 1], createdAt: createdAt),
        content: InterpretationContent(
          summary: text,
          focusPoints: const <String>[],
          afterglow: '',
          followupDirections: const <String>[],
          body: text,
        ),
        riskLevel: RiskLevel.low,
        createdAt: createdAt,
      ),
      shareText: text,
      coverImageUrl: imageUrl,
      authorId: 'seed_user_$n',
      authorUsername: author,
      authorHandle: handle,
      authorAvatarUrl: _picsumAvatar(avatarSeed),
      createdAt: createdAt,
      status: FeedItemStatus.published,
      metrics: FeedItemMetrics(likes: likes, views: views),
    );
  }

  bool isDeepItem(FeedItem item) {
    if (item.cardId.startsWith('seed_deep_')) return true;
    if (item.cardId.startsWith('seed_recommended_')) return false;
    return item.displaySummary.trim().length >= 55;
  }
}

class SharedPrefsFeedService implements FeedService {
  final LocalFeedStore _store = LocalFeedStore();

  @override
  Future<FeedResult> getRecommendFeed({
    required String tab,
    int page = 1,
    int pageSize = 20,
  }) async {
    await _store.ensureLoaded();
    final normalizedTab = tab.trim().toLowerCase();
    final published = _store.items
        .where((item) => item.status == FeedItemStatus.published)
        .toList();
    final deepItems = published.where(_store.isDeepItem).toList();
    final recommendedItems = published
        .where((item) => !_store.isDeepItem(item))
        .toList();

    // TODO(Backend Integration)[community_api#recommended-stable]:
    // 当前推荐空态由前端兜底，后续由后端推荐策略保证首屏可见数据。
    final items = switch (normalizedTab) {
      'deep' => deepItems,
      _ =>
        recommendedItems.isNotEmpty
            ? recommendedItems
            : deepItems.take(3).toList(),
    };

    return _paginate(items, page, pageSize);
  }

  @override
  Future<FeedResult> getMyFeed(
    String userId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    await _store.ensureLoaded();
    final items = _store.items
        .where((item) => item.authorId == userId)
        .toList();
    return _paginate(items, page, pageSize);
  }

  @override
  Future<FeedItem> publish({
    required InterpretationCard card,
    required String? authorId,
    required String? authorUsername,
    String? shareText,
    String? coverImageUrl,
  }) async {
    await _store.ensureLoaded();
    final item = FeedItem(
      id: 'feed_${_store.nextId()}',
      cardId: card.id,
      card: card.toDesensitized(),
      shareText: shareText,
      coverImageUrl: coverImageUrl,
      authorId: authorId,
      authorUsername: authorUsername,
      createdAt: DateTime.now(),
      status: FeedItemStatus.published,
    );
    _store.items.insert(0, item);
    await _store.persist();
    return item;
  }

  @override
  Future<void> like(String feedItemId, String userId) =>
      _bump(feedItemId, like: 1);

  @override
  Future<void> unlike(String feedItemId, String userId) =>
      _bump(feedItemId, like: -1);

  @override
  Future<void> favorite(String feedItemId, String userId) =>
      _bump(feedItemId, favorite: 1);

  @override
  Future<void> unfavorite(String feedItemId, String userId) =>
      _bump(feedItemId, favorite: -1);

  @override
  Future<void> report(String feedItemId, String userId, String reason) =>
      _bump(feedItemId, report: 1);

  @override
  Future<void> recordView(String feedItemId) => _bump(feedItemId, view: 1);

  Future<void> _bump(
    String feedItemId, {
    int like = 0,
    int favorite = 0,
    int report = 0,
    int view = 0,
  }) async {
    await _store.ensureLoaded();
    final index = _store.items.indexWhere((item) => item.id == feedItemId);
    if (index < 0) return;
    final item = _store.items[index];
    _store.items[index] = item.copyWith(
      metrics: item.metrics.copyWith(
        likes: (item.metrics.likes + like).clamp(0, 999999),
        favorites: (item.metrics.favorites + favorite).clamp(0, 999999),
        reports: (item.metrics.reports + report).clamp(0, 999999),
        views: (item.metrics.views + view).clamp(0, 999999),
      ),
    );
    await _store.persist();
  }

  FeedResult _paginate(List<FeedItem> source, int page, int pageSize) {
    final sorted = [...source]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final start = (page - 1) * pageSize;
    final items = sorted.skip(start).take(pageSize).toList();
    return FeedResult(
      items: items,
      hasMore: start + pageSize < sorted.length,
      nextPage: page + 1,
    );
  }
}

final feedServiceProvider = SharedPrefsFeedService();

class HybridFeedServiceImpl implements FeedService {
  final FeedApiClient _api;
  final SharedPrefsFeedService _local;

  HybridFeedServiceImpl({FeedApiClient? api, SharedPrefsFeedService? local})
    : _api = api ?? FeedApiClient(),
      _local = local ?? SharedPrefsFeedService();

  @override
  Future<FeedResult> getRecommendFeed({
    required String tab,
    int page = 1,
    int pageSize = 20,
  }) async {
    if (_api.enabled) {
      try {
        return await _api.getRecommendFeed(
          tab: tab,
          page: page,
          pageSize: pageSize,
        );
      } catch (_) {}
    }
    return _local.getRecommendFeed(tab: tab, page: page, pageSize: pageSize);
  }

  @override
  Future<FeedResult> getMyFeed(
    String userId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    if (_api.enabled) {
      try {
        return await _api.getMyFeed(
          userId: userId,
          page: page,
          pageSize: pageSize,
        );
      } catch (_) {}
    }
    return _local.getMyFeed(userId, page: page, pageSize: pageSize);
  }

  @override
  Future<FeedItem> publish({
    required InterpretationCard card,
    required String? authorId,
    required String? authorUsername,
    String? shareText,
    String? coverImageUrl,
  }) async {
    if (_api.enabled) {
      try {
        return await _api.publish(
          cardId: card.id,
          authorId: authorId,
          authorUsername: authorUsername,
          shareText: shareText,
          coverImageUrl: coverImageUrl,
        );
      } catch (_) {}
    }
    return _local.publish(
      card: card,
      authorId: authorId,
      authorUsername: authorUsername,
      shareText: shareText,
      coverImageUrl: coverImageUrl,
    );
  }

  @override
  Future<void> like(String feedItemId, String userId) async {
    if (_api.enabled) {
      try {
        await _api.like(feedItemId, userId);
        return;
      } catch (_) {}
    }
    await _local.like(feedItemId, userId);
  }

  @override
  Future<void> unlike(String feedItemId, String userId) async {
    if (_api.enabled) {
      try {
        await _api.unlike(feedItemId, userId);
        return;
      } catch (_) {}
    }
    await _local.unlike(feedItemId, userId);
  }

  @override
  Future<void> favorite(String feedItemId, String userId) async {
    if (_api.enabled) {
      try {
        await _api.favorite(feedItemId, userId);
        return;
      } catch (_) {}
    }
    await _local.favorite(feedItemId, userId);
  }

  @override
  Future<void> unfavorite(String feedItemId, String userId) async {
    if (_api.enabled) {
      try {
        await _api.unfavorite(feedItemId, userId);
        return;
      } catch (_) {}
    }
    await _local.unfavorite(feedItemId, userId);
  }

  @override
  Future<void> report(String feedItemId, String userId, String reason) async {
    if (_api.enabled) {
      try {
        await _api.report(feedItemId, userId, reason);
        return;
      } catch (_) {}
    }
    await _local.report(feedItemId, userId, reason);
  }

  @override
  Future<void> recordView(String feedItemId) async {
    if (_api.enabled) {
      try {
        await _api.recordView(feedItemId);
        return;
      } catch (_) {}
    }
    await _local.recordView(feedItemId);
  }
}
