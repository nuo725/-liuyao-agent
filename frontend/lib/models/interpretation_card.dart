import 'pattern.dart';

enum QuestionTag {
  relationship('关系', 'relationship'),
  career('事业', 'career'),
  emotion('情绪', 'emotion'),
  choice('选择', 'choice'),
  other('其他', 'other');

  final String label;
  final String value;
  const QuestionTag(this.label, this.value);
}

enum RiskLevel {
  low('低风险', 'low'),
  medium('中风险', 'medium'),
  high('高风险', 'high');

  final String label;
  final String value;
  const RiskLevel(this.label, this.value);
}

class InterpretationCard {
  final String id;
  final String question;
  final QuestionTag? tag;
  final Pattern pattern;
  final InterpretationContent content;
  final RiskLevel riskLevel;
  final DateTime createdAt;
  final String? authorId;
  /// 是否需要澄清，true=需要澄清不应建立会话，false=正常解读可以追问
  final bool needsClarification;

  const InterpretationCard({
    required this.id,
    required this.question,
    this.tag,
    required this.pattern,
    required this.content,
    required this.riskLevel,
    required this.createdAt,
    this.authorId,
    this.needsClarification = false,
  });

  InterpretationCard toDesensitized() {
    return InterpretationCard(
      id: id,
      question: '',
      tag: tag,
      pattern: pattern,
      content: content,
      riskLevel: riskLevel,
      createdAt: createdAt,
      authorId: authorId,
      needsClarification: needsClarification,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'question': question,
        'tag': tag?.value,
        'pattern': pattern.toJson(),
        'content': content.toJson(),
        'riskLevel': riskLevel.value,
        'createdAt': createdAt.toIso8601String(),
        'authorId': authorId,
        'needsClarification': needsClarification,
      };

  factory InterpretationCard.fromJson(Map<String, dynamic> json) =>
      InterpretationCard(
        id: json['id'] as String,
        question: json['question'] as String,
        tag: json['tag'] != null
            ? QuestionTag.values.firstWhere(
                (t) => t.value == json['tag'],
                orElse: () => QuestionTag.other,
              )
            : null,
        pattern: Pattern.fromJson(json['pattern'] as Map<String, dynamic>),
        content:
            InterpretationContent.fromJson(json['content'] as Map<String, dynamic>),
        riskLevel: RiskLevel.values.firstWhere(
          (r) => r.value == json['riskLevel'],
          orElse: () => RiskLevel.low,
        ),
        createdAt: DateTime.parse(json['createdAt'] as String),
        authorId: json['authorId'] as String?,
        needsClarification: json['needsClarification'] as bool? ?? false,
      );
}

class InterpretationContent {
  final String summary;
  final List<String> focusPoints;
  final String afterglow;
  final List<String> followupDirections;
  final String? rawResponse;
  final String? microActions;

  // New flexible payload fields.
  final String? body;
  final String? quoteText;
  final String? quoteSource;
  final List<ResponseVisualBlock> visualBlocks;

  const InterpretationContent({
    required this.summary,
    required this.focusPoints,
    required this.afterglow,
    required this.followupDirections,
    this.rawResponse,
    this.microActions,
    this.body,
    this.quoteText,
    this.quoteSource,
    this.visualBlocks = const [],
  });

  String toPlainText() {
    final buffer = StringBuffer();
    if ((body ?? '').trim().isNotEmpty) {
      buffer.writeln(body!.trim());
      return buffer.toString();
    }

    buffer.writeln(summary);
    buffer.writeln();
    for (int i = 0; i < focusPoints.length; i++) {
      buffer.writeln('${i + 1}. ${focusPoints[i]}');
    }
    buffer.writeln();
    buffer.writeln(afterglow);
    return buffer.toString();
  }

  Map<String, dynamic> toJson() => {
        'summary': summary,
        'focusPoints': focusPoints,
        'afterglow': afterglow,
        'followupDirections': followupDirections,
        'rawResponse': rawResponse,
        'microActions': microActions,
        'body': body,
        'quoteText': quoteText,
        'quoteSource': quoteSource,
        'visualBlocks': visualBlocks.map((e) => e.toJson()).toList(),
      };

  factory InterpretationContent.fromJson(Map<String, dynamic> json) =>
      InterpretationContent(
        summary: json['summary'] as String? ?? '',
        focusPoints: List<String>.from(json['focusPoints'] as List? ?? const []),
        afterglow: json['afterglow'] as String? ?? '',
        followupDirections:
            List<String>.from(json['followupDirections'] as List? ?? const []),
        rawResponse: json['rawResponse'] as String?,
        microActions: json['microActions'] as String?,
        body: json['body'] as String?,
        quoteText: json['quoteText'] as String?,
        quoteSource: json['quoteSource'] as String?,
        visualBlocks: (json['visualBlocks'] as List?)
                ?.whereType<Map>()
                .map(
                  (e) =>
                      ResponseVisualBlock.fromJson(Map<String, dynamic>.from(e)),
                )
                .toList() ??
            const [],
      );
}

class ResponseVisualBlock {
  final String icon;
  final String title;
  final String text;

  const ResponseVisualBlock({
    required this.icon,
    required this.title,
    required this.text,
  });

  Map<String, dynamic> toJson() => {
        'icon': icon,
        'title': title,
        'text': text,
      };

  factory ResponseVisualBlock.fromJson(Map<String, dynamic> json) =>
      ResponseVisualBlock(
        icon: (json['icon'] as String? ?? 'insight').trim(),
        title: (json['title'] as String? ?? '').trim(),
        text: (json['text'] as String? ?? '').trim(),
      );
}
