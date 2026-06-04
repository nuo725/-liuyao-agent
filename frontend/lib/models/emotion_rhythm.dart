/// 晨晚节律 - 每日 greeting data
class DailyGreeting {
  /// 问候语，如"早安，Roy。"
  final String greeting;

  /// 问候时段：morning | evening
  final String timeOfDay;

  /// 核心承接文案
  final String contextText;

  /// 前情关键词标签
  final List<String> emotionTags;

  /// 关联的前情问题
  final String? relatedQuestion;

  const DailyGreeting({
    required this.greeting,
    required this.timeOfDay,
    required this.contextText,
    this.emotionTags = const [],
    this.relatedQuestion,
  });

  Map<String, dynamic> toJson() => {
        'greeting': greeting,
        'timeOfDay': timeOfDay,
        'contextText': contextText,
        'emotionTags': emotionTags,
        'relatedQuestion': relatedQuestion,
      };

  factory DailyGreeting.fromJson(Map<String, dynamic> json) {
    return DailyGreeting(
      greeting: json['greeting'] as String,
      timeOfDay: json['timeOfDay'] as String,
      contextText: json['contextText'] as String,
      emotionTags: (json['emotionTags'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      relatedQuestion: json['relatedQuestion'] as String?,
    );
  }
}

/// 用户次日校准结果
class CalibrationResult {
  final String id;
  final String feedback;
  final String? customText;
  final DateTime submittedAt;

  const CalibrationResult({
    required this.id,
    required this.feedback,
    this.customText,
    required this.submittedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'feedback': feedback,
        'customText': customText,
        'submittedAt': submittedAt.toIso8601String(),
      };

  factory CalibrationResult.fromJson(Map<String, dynamic> json) {
    return CalibrationResult(
      id: json['id'] as String,
      feedback: json['feedback'] as String,
      customText: json['customText'] as String?,
      submittedAt: DateTime.parse(json['submittedAt'] as String),
    );
  }
}

/// 周期回看报告
class PeriodicReport {
  /// 周报或月报
  final String period;

  /// 周期起始日期
  final DateTime startDate;

  /// 周期结束日期
  final DateTime endDate;

  /// 过去 N 天留下的回响次数
  final int resonanceCount;

  /// 高频情绪标签
  final List<String> topEmotions;

  /// 关键词云（情绪词 + 对应权重 0-100）
  final Map<String, int> emotionCloud;

  /// 期间最常访问的日期（weekday 0-6）
  final List<int> activeWeekdays;

  const PeriodicReport({
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.resonanceCount,
    this.topEmotions = const [],
    this.emotionCloud = const {},
    this.activeWeekdays = const [],
  });

  Map<String, dynamic> toJson() => {
        'period': period,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'resonanceCount': resonanceCount,
        'topEmotions': topEmotions,
        'emotionCloud': emotionCloud,
        'activeWeekdays': activeWeekdays,
      };

  factory PeriodicReport.fromJson(Map<String, dynamic> json) {
    return PeriodicReport(
      period: json['period'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      resonanceCount: json['resonanceCount'] as int,
      topEmotions: (json['topEmotions'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      emotionCloud: (json['emotionCloud'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), v as int),
          ) ??
          const {},
      activeWeekdays: (json['activeWeekdays'] as List?)
              ?.map((e) => e as int)
              .toList() ??
          const [],
    );
  }
}
