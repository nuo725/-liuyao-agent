import 'interpretation_card.dart';
import 'ritual_record.dart';

enum TagIdentityOrigin {
  ritual('ritual'),
  profile('profile'),
  community('community'),
  activity('activity');

  final String value;
  const TagIdentityOrigin(this.value);
}

class TagTimelineEntry {
  final String id;
  final String tag;
  final String eventType;
  final String summary;
  final String? sourceId;
  final DateTime createdAt;

  const TagTimelineEntry({
    required this.id,
    required this.tag,
    required this.eventType,
    required this.summary,
    this.sourceId,
    required this.createdAt,
  });
}

class TagIdentitySnapshot {
  final String primaryTag;
  final List<String> secondaryTags;
  final String explanation;
  final TagIdentityOrigin origin;
  final String sourceTitle;
  final DateTime createdAt;
  final List<TagTimelineEntry> timeline;

  const TagIdentitySnapshot({
    required this.primaryTag,
    required this.secondaryTags,
    required this.explanation,
    required this.origin,
    required this.sourceTitle,
    required this.createdAt,
    required this.timeline,
  });

  factory TagIdentitySnapshot.preview({
    QuestionTag? questionTag,
    required String sourceTitle,
    List<RitualRecord> history = const [],
    TagIdentityOrigin origin = TagIdentityOrigin.ritual,
    DateTime? createdAt,
  }) {
    final tag = questionTag ?? QuestionTag.other;
    final tagLabel = _prefixTag(tag.label);
    final secondaryTags = _secondaryTagsFor(tag);
    final generatedAt = createdAt ?? _latestHistoryTime(history) ?? DateTime.now();

    final timeline = <TagTimelineEntry>[
      TagTimelineEntry(
        id: 'tag-${generatedAt.millisecondsSinceEpoch}',
        tag: tagLabel,
        eventType: 'generated',
        summary: '从“$sourceTitle”生成，作为当前身份的可回看起点。',
        sourceId: sourceTitle,
        createdAt: generatedAt,
      ),
      if (history.isEmpty)
        TagTimelineEntry(
          id: 'tag-${generatedAt.microsecondsSinceEpoch}',
          tag: tagLabel,
          eventType: 'viewed',
          summary: '当前暂时没有更多历史条目，先保留这次生成记录。',
          sourceId: null,
          createdAt: generatedAt.add(const Duration(minutes: 5)),
        )
      else
        ...history.take(4).map(
          (record) => TagTimelineEntry(
            id: 'tag-${record.dateTime.millisecondsSinceEpoch}',
            tag: tagLabel,
            eventType: 'viewed',
            summary: '回看 ${record.seasonInfo} 的记录时，再次确认这组标签仍然适合当前状态。',
            sourceId: record.mood.isEmpty ? null : record.mood,
            createdAt: record.dateTime,
          ),
        ),
    ];

    return TagIdentitySnapshot(
      primaryTag: tagLabel,
      secondaryTags: secondaryTags,
      explanation: _buildExplanation(tag, sourceTitle, origin),
      origin: origin,
      sourceTitle: sourceTitle,
      createdAt: generatedAt,
      timeline: timeline,
    );
  }

  static String _buildExplanation(
    QuestionTag tag,
    String sourceTitle,
    TagIdentityOrigin origin,
  ) {
    final topic = switch (tag) {
      QuestionTag.relationship => '关系边界',
      QuestionTag.career => '选择与节奏',
      QuestionTag.emotion => '情绪承接',
      QuestionTag.choice => '分岔判断',
      QuestionTag.other => '当前主题',
    };
    final originLabel = switch (origin) {
      TagIdentityOrigin.ritual => 'ritual 结果',
      TagIdentityOrigin.profile => 'profile 复看',
      TagIdentityOrigin.community => 'community 发现',
      TagIdentityOrigin.activity => 'activity 参与',
    };
    return '这组标签来自 $originLabel 的可读化整理，重点围绕“$topic”展开。'
        '它不替你下结论，只把“$sourceTitle”翻译成能继续回看的身份线索。';
  }

  static List<String> _secondaryTagsFor(QuestionTag tag) {
    return switch (tag) {
      QuestionTag.relationship => const ['#边界感', '#回应方式'],
      QuestionTag.career => const ['#节奏安排', '#路径选择'],
      QuestionTag.emotion => const ['#自我照拂', '#情绪承接'],
      QuestionTag.choice => const ['#分岔判断', '#下一步'],
      QuestionTag.other => const ['#当前主题', '#继续观察'],
    };
  }

  static String _prefixTag(String value) {
    final cleaned = value.trim();
    if (cleaned.startsWith('#')) return cleaned;
    return '#$cleaned';
  }

  static DateTime? _latestHistoryTime(List<RitualRecord> history) {
    if (history.isEmpty) return null;
    return history.last.dateTime;
  }
}
