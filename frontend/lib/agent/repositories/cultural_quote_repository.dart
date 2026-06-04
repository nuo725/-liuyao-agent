/// lib/agent/repositories/cultural_quote_repository.dart
///
/// 说明：
/// - 当前为文化引文库 v1
/// - 优先放本地 verified 素材，便于调试和回归测试
/// - 第一阶段先用少量高质量引文跑通链路
/// - 后续再扩展中外文本、多语言、分层来源等能力
library cultural_quote_repository;

import '../domain/cultural_quote.dart';
import '../domain/direction_profile.dart';

const Map<String, Map<String, dynamic>> culturalQuoteRepository = {
  "Q01": {
    "quoteId": "Q01",
    "text": "知止而后有定，定而后能静。",
    "source": "《礼记·大学》",
    "tags": ["止", "静", "收束", "澄明"],
    "tone": "克制",
    "suitableFor": ["收束中的照见", "将明未明", "边界松动", "过载后的回身"],
    "avoidFor": ["强行动推进", "激烈鼓动"],
    "verified": true
  },

  "Q02": {
    "quoteId": "Q02",
    "text": "欲速则不达，见小利则大事不成。",
    "source": "《论语·子路》",
    "tags": ["火候", "节制", "勿躁进"],
    "tone": "警醒但不压迫",
    "suitableFor": ["启动里的推进", "外推内滞", "临界转向"],
    "avoidFor": ["高羞耻感", "强自责"],
    "verified": true
  },

  "Q03": {
    "quoteId": "Q03",
    "text": "行到水穷处，坐看云起时。",
    "source": "王维《终南别业》",
    "tags": ["回身", "未明", "候时", "云起"],
    "tone": "舒展",
    "suitableFor": ["将明未明", "收束中的照见", "临界转向"],
    "avoidFor": ["需要立即现实提醒的高风险场景"],
    "verified": true
  },

  "Q04": {
    "quoteId": "Q04",
    "text": "山重水复疑无路，柳暗花明又一村。",
    "source": "陆游《游山西村》",
    "tags": ["转向", "未尽", "回潮", "见路"],
    "tone": "舒缓向前",
    "suitableFor": ["临界转向", "将明未明", "外推内滞"],
    "avoidFor": ["不宜过早乐观的脆弱场景"],
    "verified": true
  },

  "Q05": {
    "quoteId": "Q05",
    "text": "采菊东篱下，悠然见南山。",
    "source": "陶渊明《饮酒·其五》",
    "tags": ["安住", "缓行", "守拙", "自得"],
    "tone": "安静",
    "suitableFor": ["过载后的回身", "收束中的照见", "边界松动"],
    "avoidFor": ["需要较强提振的场景"],
    "verified": true
  },

  "Q06": {
    "quoteId": "Q06",
    "text": "不以物喜，不以己悲。",
    "source": "范仲淹《岳阳楼记》",
    "tags": ["边界", "分寸", "定力", "不被裹挟"],
    "tone": "稳重",
    "suitableFor": ["边界松动", "外推内滞", "关系期待落差相关方向"],
    "avoidFor": ["情绪极低落、需要先承接的场景"],
    "verified": true
  },

  "Q07": {
    "quoteId": "Q07",
    "text": "水流心不竞，云在意俱迟。",
    "source": "杜甫《江亭》",
    "tags": ["缓行", "不争", "云水", "节奏放慢"],
    "tone": "从容",
    "suitableFor": ["过载后的回身", "收束中的照见", "将明未明"],
    "avoidFor": ["需要明确现实提醒的高风险场景"],
    "verified": true
  },

  "Q08": {
    "quoteId": "Q08",
    "text": "山光悦鸟性，潭影空人心。",
    "source": "常建《题破山寺后禅院》",
    "tags": ["澄明", "照见", "空心", "静观"],
    "tone": "澄净",
    "suitableFor": ["收束中的照见", "将明未明", "边界松动"],
    "avoidFor": ["过于激烈的现实冲突场景"],
    "verified": true
  },

  "Q09": {
    "quoteId": "Q09",
    "text": "人生如逆旅，我亦是行人。",
    "source": "苏轼《临江仙·送钱穆父》",
    "tags": ["行路", "逆旅", "不执", "暂居"],
    "tone": "旷达",
    "suitableFor": ["将明未明", "临界转向", "外推内滞"],
    "avoidFor": ["需要更具体承接的高负荷场景"],
    "verified": true
  },

  "Q10": {
    "quoteId": "Q10",
    "text": "开荒南野际，守拙归园田。",
    "source": "陶渊明《归园田居·其一》",
    "tags": ["守拙", "归身", "还原", "不逞强"],
    "tone": "朴素",
    "suitableFor": ["过载后的回身", "收束中的照见", "边界松动"],
    "avoidFor": ["需要轻推进而非完全收束的场景"],
    "verified": true
  },

  "Q11": {
    "quoteId": "Q11",
    "text": "合抱之木，生于毫末；九层之台，起于累土。",
    "source": "《老子》",
    "tags": ["渐进", "起势", "微量推进", "积累"],
    "tone": "平实",
    "suitableFor": ["启动里的推进", "内里待发", "临界转向"],
    "avoidFor": ["高负荷且需要先休息的场景"],
    "verified": true
  },

  "Q12": {
    "quoteId": "Q12",
    "text": "千里之行，始于足下。",
    "source": "《老子》",
    "tags": ["起步", "微行动", "不必过大"],
    "tone": "简洁",
    "suitableFor": ["启动里的推进", "内里待发"],
    "avoidFor": ["已经明显疲惫过载的场景"],
    "verified": true
  },

  "Q13": {
    "quoteId": "Q13",
    "text": "为者败之，执者失之。",
    "source": "《老子》",
    "tags": ["不强推", "不执", "节制用力"],
    "tone": "提醒",
    "suitableFor": ["外推内滞", "启动里的推进", "临界转向"],
    "avoidFor": ["高羞耻感用户"],
    "verified": true
  },

  "Q14": {
    "quoteId": "Q14",
    "text": "人皆知有用之用，而莫知无用之用也。",
    "source": "《庄子》",
    "tags": ["留白", "未显", "无用之用", "不急于证明"],
    "tone": "松弛",
    "suitableFor": ["内里待发", "将明未明", "收束中的照见"],
    "avoidFor": ["需要非常明确现实落点的场景"],
    "verified": true
  },

  "Q15": {
    "quoteId": "Q15",
    "text": "天地有大美而不言。",
    "source": "《庄子·知北游》",
    "tags": ["不言", "大美", "静观", "留白"],
    "tone": "空灵",
    "suitableFor": ["收束中的照见", "将明未明", "过载后的回身"],
    "avoidFor": ["高风险场景"],
    "verified": true
  },

  "Q16": {
    "quoteId": "Q16",
    "text": "明月松间照，清泉石上流。",
    "source": "王维《山居秋暝》",
    "tags": ["明净", "松间", "清流", "澄明"],
    "tone": "清润",
    "suitableFor": ["收束中的照见", "边界松动", "将明未明"],
    "avoidFor": ["过于需要现实信息提醒的场景"],
    "verified": true
  },

  "Q17": {
    "quoteId": "Q17",
    "text": "会心不在远，得趣不在多。",
    "source": "程颢《秋日偶成》",
    "tags": ["会心", "节制", "不必过量", "轻得趣"],
    "tone": "轻巧",
    "suitableFor": ["过载后的回身", "收束中的照见"],
    "avoidFor": ["强关系焦虑场景"],
    "verified": true
  },

  "Q18": {
    "quoteId": "Q18",
    "text": "莫听穿林打叶声，何妨吟啸且徐行。",
    "source": "苏轼《定风波·莫听穿林打叶声》",
    "tags": ["徐行", "风雨", "缓步", "不迫"],
    "tone": "从容",
    "suitableFor": ["启动里的推进", "外推内滞", "临界转向"],
    "avoidFor": ["需要先明显承接伤痛的场景"],
    "verified": true
  },

  "Q19": {
    "quoteId": "Q19",
    "text": "谁道人生无再少？门前流水尚能西。",
    "source": "苏轼《浣溪沙·游蕲水清泉寺》",
    "tags": ["回转", "未尽", "再起", "不封死"],
    "tone": "提气但不鼓噪",
    "suitableFor": ["临界转向", "将明未明"],
    "avoidFor": ["不宜过早提振的沉重场景"],
    "verified": true
  },

  "Q20": {
    "quoteId": "Q20",
    "text": "草木有本心，何求美人折。",
    "source": "张九龄《感遇·其一》",
    "tags": ["本心", "不求证明", "边界", "自持"],
    "tone": "清峻",
    "suitableFor": ["边界松动", "关系期待落差相关方向", "内里待发"],
    "avoidFor": ["明显自责且脆弱的场景"],
    "verified": true
  },
};

Map<String, dynamic>? getQuoteById(String quoteId) {
  return culturalQuoteRepository[quoteId];
}

List<Map<String, dynamic>> getAllVerifiedQuotes() {
  return culturalQuoteRepository.values
      .where((item) => item["verified"] == true)
      .toList();
}

/// 根据主题标签粗筛
List<Map<String, dynamic>> findQuotesByTags(List<String> tags) {
  final tagSet = tags.toSet();

  return culturalQuoteRepository.values.where((item) {
    final itemTags = (item["tags"] as List<dynamic>).cast<String>().toSet();
    return itemTags.intersection(tagSet).isNotEmpty;
  }).toList();
}

/// 根据 direction_profile 的 culturalThemeRange 粗筛
List<Map<String, dynamic>> findQuotesForDirectionProfile(
  Map<String, dynamic> directionProfile,
) {
  final culturalThemes =
      (directionProfile["culturalThemeRange"] as List<dynamic>? ?? const [])
          .cast<String>();

  if (culturalThemes.isEmpty) {
    return getAllVerifiedQuotes();
  }

  return findQuotesByTags(culturalThemes);
}

class CulturalQuoteRepository {
  const CulturalQuoteRepository();

  CulturalQuote pickForDirection({
    required DirectionProfile profile,
    required String userQuestion,
    List<String> searchSnippets = const [],
  }) {
    final base = findQuotesByTags(profile.culturalThemeRange);
    final pool = base.isEmpty ? getAllVerifiedQuotes() : base;
    final scored = pool
        .map((q) => (quote: q, score: _score(q, profile, userQuestion, searchSnippets)))
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    final selected = scored.isEmpty ? culturalQuoteRepository.values.first : scored.first.quote;
    return _toQuote(selected);
  }

  int _score(
    Map<String, dynamic> item,
    DirectionProfile profile,
    String userQuestion,
    List<String> searchSnippets,
  ) {
    var score = 0;
    final text = userQuestion.trim();
    final tags = _toStringList(item['tags']);
    final suitableFor = _toStringList(item['suitableFor']);

    for (final t in tags) {
      if (profile.culturalThemeRange.contains(t)) score += 4;
      if (profile.psychTags.contains(t)) score += 2;
      if (text.contains(t)) score += 2;
      if (searchSnippets.any((s) => s.contains(t))) score += 1;
    }
    for (final t in suitableFor) {
      if (text.contains(t)) score += 1;
    }
    if (item['verified'] == true) score += 2;
    return score;
  }

  CulturalQuote _toQuote(Map<String, dynamic> item) {
    return CulturalQuote(
      quoteId: item['quoteId']?.toString() ?? '',
      text: item['text']?.toString() ?? '',
      source: item['source']?.toString() ?? '',
      tags: _toStringList(item['tags']),
      tone: item['tone']?.toString() ?? '',
      suitableFor: _toStringList(item['suitableFor']),
      avoidFor: _toStringList(item['avoidFor']),
      verified: item['verified'] == true,
      sourceType: 'local',
    );
  }

  List<String> _toStringList(dynamic value) {
    if (value is! List) return const [];
    return value.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
  }
}
