import 'interpretation_card.dart';

/// Feed内容项
class FeedItem {
  final String id;
  final String cardId;
  final InterpretationCard card; // 脱敏版本
  final String? shareText;
  final String? coverImageUrl;
  final String? authorId;
  final String? authorUsername;
  /// Display handle without forcing @; UI may prefix @.
  final String? authorHandle;
  final String? authorAvatarUrl;
  final DateTime createdAt;
  final FeedItemStatus status;
  final FeedItemMetrics metrics;

  const FeedItem({
    required this.id,
    required this.cardId,
    required this.card,
    this.shareText,
    this.coverImageUrl,
    this.authorId,
    this.authorUsername,
    this.authorHandle,
    this.authorAvatarUrl,
    required this.createdAt,
    this.status = FeedItemStatus.published,
    this.metrics = const FeedItemMetrics(),
  });

  /// 获取用于展示的摘要（不含原始问题）
  String get displaySummary {
    final edited = shareText?.trim();
    if (edited != null && edited.isNotEmpty) return edited;
    final body = card.content.body?.trim();
    if (body != null && body.isNotEmpty) return body;
    return card.content.summary;
  }

  /// 获取关注点摘要（前2条）
  String get focusSummary {
    final points = card.content.focusPoints;
    if (points.isEmpty) return '';
    if (points.length == 1) return points[0];
    return '${points[0]} · ${points[1]}';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'cardId': cardId,
    'card': card.toJson(),
    'shareText': shareText,
    'coverImageUrl': coverImageUrl,
    'authorId': authorId,
    'authorUsername': authorUsername,
    'authorHandle': authorHandle,
    'authorAvatarUrl': authorAvatarUrl,
    'createdAt': createdAt.toIso8601String(),
    'status': status.value,
    'metrics': metrics.toJson(),
  };

  factory FeedItem.fromJson(Map<String, dynamic> json) => FeedItem(
    id: json['id'] as String,
    cardId: json['cardId'] as String,
    card: InterpretationCard.fromJson(json['card'] as Map<String, dynamic>),
    shareText: json['shareText'] as String?,
    coverImageUrl: json['coverImageUrl'] as String?,
    authorId: json['authorId'] as String?,
    authorUsername: json['authorUsername'] as String?,
    authorHandle: json['authorHandle'] as String?,
    authorAvatarUrl: json['authorAvatarUrl'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    status: FeedItemStatus.values.firstWhere(
      (s) => s.value == json['status'],
      orElse: () => FeedItemStatus.published,
    ),
    metrics: json['metrics'] != null
        ? FeedItemMetrics.fromJson(json['metrics'] as Map<String, dynamic>)
        : const FeedItemMetrics(),
  );

  FeedItem copyWith({
    String? id,
    String? cardId,
    InterpretationCard? card,
    String? shareText,
    String? coverImageUrl,
    String? authorId,
    String? authorUsername,
    String? authorHandle,
    String? authorAvatarUrl,
    DateTime? createdAt,
    FeedItemStatus? status,
    FeedItemMetrics? metrics,
  }) {
    return FeedItem(
      id: id ?? this.id,
      cardId: cardId ?? this.cardId,
      card: card ?? this.card,
      shareText: shareText ?? this.shareText,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      authorId: authorId ?? this.authorId,
      authorUsername: authorUsername ?? this.authorUsername,
      authorHandle: authorHandle ?? this.authorHandle,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      metrics: metrics ?? this.metrics,
    );
  }
}

/// Feed项状态
enum FeedItemStatus {
  draft('草稿', 'draft'),
  published('已发布', 'published'),
  hidden('已隐藏', 'hidden'),
  deleted('已删除', 'deleted');

  final String label;
  final String value;
  const FeedItemStatus(this.label, this.value);
}

/// Feed项指标
class FeedItemMetrics {
  final int likes;
  final int favorites;
  final int views;
  final int reports;

  const FeedItemMetrics({
    this.likes = 0,
    this.favorites = 0,
    this.views = 0,
    this.reports = 0,
  });

  Map<String, dynamic> toJson() => {
    'likes': likes,
    'favorites': favorites,
    'views': views,
    'reports': reports,
  };

  factory FeedItemMetrics.fromJson(Map<String, dynamic> json) =>
      FeedItemMetrics(
        likes: json['likes'] as int? ?? 0,
        favorites: json['favorites'] as int? ?? 0,
        views: json['views'] as int? ?? 0,
        reports: json['reports'] as int? ?? 0,
      );

  FeedItemMetrics copyWith({
    int? likes,
    int? favorites,
    int? views,
    int? reports,
  }) {
    return FeedItemMetrics(
      likes: likes ?? this.likes,
      favorites: favorites ?? this.favorites,
      views: views ?? this.views,
      reports: reports ?? this.reports,
    );
  }
}
