import 'interpretation_card.dart';
import 'pattern.dart';

/// 会话记录 - 用于追问链
class Session {
  final String id;
  final String? userId;
  final String question;
  final QuestionTag? tag;
  final Pattern pattern;
  final InterpretationCard? initialCard;
  final List<FollowupMessage> messages;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SessionStatus status;
  final int followupCount;

  const Session({
    required this.id,
    this.userId,
    required this.question,
    this.tag,
    required this.pattern,
    this.initialCard,
    this.messages = const [],
    required this.createdAt,
    required this.updatedAt,
    this.status = SessionStatus.active,
    this.followupCount = 0,
  });

  /// 是否还能追问
  bool get canFollowup => followupCount < maxFollowups;

  /// 最大追问次数
  static const int maxFollowups = 6;

  /// 是否达到追问上限
  bool get isFollowupExhausted => followupCount >= maxFollowups;

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'question': question,
    'tag': tag?.value,
    'pattern': pattern.toJson(),
    'initialCard': initialCard?.toJson(),
    'messages': messages.map((m) => m.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'status': status.value,
    'followupCount': followupCount,
  };

  factory Session.fromJson(Map<String, dynamic> json) => Session(
    id: json['id'] as String,
    userId: json['userId'] as String?,
    question: json['question'] as String,
    tag: json['tag'] != null
        ? QuestionTag.values.firstWhere(
            (t) => t.value == json['tag'],
            orElse: () => QuestionTag.other,
          )
        : null,
    pattern: Pattern.fromJson(json['pattern'] as Map<String, dynamic>),
    initialCard: json['initialCard'] != null
        ? InterpretationCard.fromJson(
            json['initialCard'] as Map<String, dynamic>)
        : null,
    messages: (json['messages'] as List?)
        ?.map((m) => FollowupMessage.fromJson(m as Map<String, dynamic>))
        .toList() ?? [],
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    status: SessionStatus.values.firstWhere(
      (s) => s.value == json['status'],
      orElse: () => SessionStatus.active,
    ),
    followupCount: json['followupCount'] as int? ?? 0,
  );

  Session copyWith({
    String? id,
    String? userId,
    String? question,
    QuestionTag? tag,
    Pattern? pattern,
    InterpretationCard? initialCard,
    List<FollowupMessage>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
    SessionStatus? status,
    int? followupCount,
  }) {
    return Session(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      question: question ?? this.question,
      tag: tag ?? this.tag,
      pattern: pattern ?? this.pattern,
      initialCard: initialCard ?? this.initialCard,
      messages: messages ?? this.messages,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      followupCount: followupCount ?? this.followupCount,
    );
  }
}

/// 会话状态
enum SessionStatus {
  active('进行中', 'active'),
  completed('已完成', 'completed'),
  expired('已过期', 'expired');

  final String label;
  final String value;
  const SessionStatus(this.label, this.value);
}

/// 追问消息
class FollowupMessage {
  final String id;
  final String content;
  final FollowupMessageType type;
  final DateTime createdAt;
  final List<String>? suggestedDirections;

  const FollowupMessage({
    required this.id,
    required this.content,
    required this.type,
    required this.createdAt,
    this.suggestedDirections,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'content': content,
    'type': type.value,
    'createdAt': createdAt.toIso8601String(),
    'suggestedDirections': suggestedDirections,
  };

  factory FollowupMessage.fromJson(Map<String, dynamic> json) =>
    FollowupMessage(
      id: json['id'] as String,
      content: json['content'] as String,
      type: FollowupMessageType.values.firstWhere(
        (t) => t.value == json['type'],
        orElse: () => FollowupMessageType.answer,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      suggestedDirections: json['suggestedDirections'] != null
          ? List<String>.from(json['suggestedDirections'] as List)
          : null,
    );
}

/// 消息类型
enum FollowupMessageType {
  question('追问', 'question'),
  answer('回应', 'answer');

  final String label;
  final String value;
  const FollowupMessageType(this.label, this.value);
}
