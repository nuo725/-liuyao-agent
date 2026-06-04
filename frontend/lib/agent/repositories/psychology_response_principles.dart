/// lib/agent/repositories/psychology_response_principles.dart
///
/// 说明：
/// - 当前为心理回应原则库 v1
/// - 不是心理诊断库，不是治疗库，不是鸡汤库
/// - 用于辅助首轮与追问的语言转译
/// - 第一阶段先放少量高质量原则样本，后续再扩充
library psychology_response_principles;

import '../domain/direction_profile.dart';
import '../domain/psychology_response_principle.dart';

const Map<String, Map<String, dynamic>> psychologyResponsePrinciples = {
  "P01": {
    "principleId": "P01",
    "name": "高负荷时先承接，不急着推进",
    "applicableTags": ["高负荷", "疲惫", "失控感", "节奏失衡"],
    "guideline":
        "当用户明显处于疲惫、过载、一直撑着的状态时，优先帮助其命名和承接当前体验，不要立刻把回复推向行动建议或效率语言。",
    "languageDo": [
      "先承认疲惫的存在",
      "先帮助用户分辨‘事情重’和‘自己不行’不是一回事",
      "语言放慢，给出缓冲感"
    ],
    "languageDont": [
      "先拆任务",
      "强调执行力",
      "把疲惫解释成意志不足",
      "催促立刻行动"
    ],
    "microBridgeExamples": [
      "更重的，也许不是这件事本身，而是你已经撑了太久。",
      "累不一定是在说明你不够好，也可能只是一直没有真正停下来。",
      "先不用急着往前推，先看见自己已经承受到哪里了。"
    ],
    "avoidEscalation": [
      "不要把疲惫升级成能力否定",
      "不要把暂停升级成落后焦虑"
    ]
  },

  "P02": {
    "principleId": "P02",
    "name": "迟疑时先照见拉扯，不急着做决定",
    "applicableTags": ["迟疑", "推进焦虑", "拉扯", "转折"],
    "guideline":
        "当用户表现出明显的犹豫、卡住、想推进又不敢推进时，先帮助其看见拉扯本身，而不是立刻把迟疑处理成行动缺失。",
    "languageDo": [
      "命名拉扯",
      "允许迟疑暂时存在",
      "帮助区分‘不想动’与‘不敢动’"
    ],
    "languageDont": [
      "把迟疑说成懦弱",
      "把犹豫说成拖延",
      "直接给出推进命令"
    ],
    "microBridgeExamples": [
      "这里更像是一种拉扯，而不只是简单的不行动。",
      "你未必是在回避，也可能是在某些东西还没真正看清之前，不想草率往前。",
      "先看见自己卡在哪，比急着突破更重要。"
    ],
    "avoidEscalation": [
      "不要把迟疑升级成失败焦虑",
      "不要把未决升级成自我否定"
    ]
  },

  "P03": {
    "principleId": "P03",
    "name": "自责时先区分事实与自我审判",
    "applicableTags": ["自责", "羞耻", "关系焦虑", "高压"],
    "guideline":
        "当用户明显在责怪自己、怀疑自己不够好时，优先帮助其把‘发生了什么’与‘我是不是不行’区分开，避免语言继续加重羞耻。",
    "languageDo": [
      "先拆开事实和评价",
      "减少责任叠加",
      "不要顺着用户一起审判自己"
    ],
    "languageDont": [
      "强调成长教训",
      "强调你该反思自己",
      "把问题都归给用户",
      "说用户只是太敏感"
    ],
    "microBridgeExamples": [
      "眼下更值得分开的，也许是事情本身和你对自己的那层审判。",
      "这不一定是在说明你不够好，也可能只是你已经把很多压力都往自己身上收了。",
      "先不要急着把问题全归到自己身上。"
    ],
    "avoidEscalation": [
      "不要把失误升级成价值否定",
      "不要把关系受挫升级成‘我不值得’"
    ]
  },

  "P04": {
    "principleId": "P04",
    "name": "未明时允许不确定，不强求定论",
    "applicableTags": ["未明", "不确定", "迷茫", "关系摇摆"],
    "guideline":
        "当用户处于说不清、看不懂、没有定形的状态时，允许‘未明’作为当前状态存在，不要逼迫用户立刻得出定义或结论。",
    "languageDo": [
      "允许模糊和未成形",
      "帮助用户看见‘还没清楚’本身",
      "减少立刻判断的压力"
    ],
    "languageDont": [
      "逼用户马上想明白",
      "快速给结论",
      "把未明解释成坏迹象"
    ],
    "microBridgeExamples": [
      "有时候还没看清，并不意味着你就错过了什么。",
      "这更像是未明，不一定要马上把它说成答案。",
      "允许事情暂时没有定形，也是一种稳住自己。"
    ],
    "avoidEscalation": [
      "不要把不确定升级成灾难想象",
      "不要把未明升级成失败预告"
    ]
  },

  "P05": {
    "principleId": "P05",
    "name": "边界受损时先照见消耗，不替对方辩护",
    "applicableTags": ["边界", "关系焦虑", "委屈", "消耗"],
    "guideline":
        "当用户处在边界模糊、长期迁就、关系中被消耗的状态时，优先帮助其照见自己正在承受什么，不替另一方辩护，也不立刻裁决关系。",
    "languageDo": [
      "先看见委屈和消耗",
      "帮助识别边界在哪里松了",
      "保持中性，不替用户下关系判断"
    ],
    "languageDont": [
      "说你太敏感了",
      "替对方合理化",
      "直接建议分开或继续"
    ],
    "microBridgeExamples": [
      "更值得先看见的，也许不是对方对不对，而是你已经被消耗到了哪里。",
      "这里像是有些边界慢慢变薄了，而不是你想太多。",
      "先守住一点分寸，不一定是在拒绝谁，也可能是在照顾自己。"
    ],
    "avoidEscalation": [
      "不要把边界问题升级成关系裁决",
      "不要把委屈升级成自我怀疑"
    ]
  },

  "P06": {
    "principleId": "P06",
    "name": "关系未明时不替对方下结论",
    "applicableTags": ["关系焦虑", "未明", "期待落差", "边界"],
    "guideline":
        "涉及关系、他人想法、他人态度时，系统不能替对方发言，也不能把用户快速推向去留判断，应优先回到用户自己此刻的感受与在意。",
    "languageDo": [
      "回到用户自己的体验",
      "强调‘你在承受什么’",
      "帮助识别期待落差"
    ],
    "languageDont": [
      "他就是不爱你",
      "他一定怎样想",
      "你应该离开",
      "对方不会改变"
    ],
    "microBridgeExamples": [
      "也许此刻更值得先看见的，不是对方到底会不会，而是你为这份不确定承担了多久。",
      "这件事更重的部分，可能是期待没有落地之后一直悬着的那种感觉。",
      "先回到你自己：你最在意的究竟是什么？"
    ],
    "avoidEscalation": [
      "不要把关系未明升级成自我价值审判",
      "不要把对方沉默升级成确定性否定"
    ]
  },

  "P07": {
    "principleId": "P07",
    "name": "失控感强时先恢复节奏感",
    "applicableTags": ["失控感", "节奏失衡", "高负荷", "焦虑"],
    "guideline":
        "当用户明显觉得事情失控、被推着走、心里很乱时，优先帮助其找回一点节奏感与落脚感，而不是继续加快推进速度。",
    "languageDo": [
      "帮助恢复一点点节奏感",
      "强调‘先落脚’而不是‘先突破’",
      "降低语速感和压迫感"
    ],
    "languageDont": [
      "继续加速",
      "强调马上处理",
      "制造时间压力"
    ],
    "microBridgeExamples": [
      "现在更需要的，也许不是再往前一步，而是先让自己落一下脚。",
      "当事情都往前涌的时候，先稳住节奏，本身就是一种回应。",
      "先把心里的乱落下一点，再去看下一层，也不算慢。"
    ],
    "avoidEscalation": [
      "不要把失控感升级成全面崩坏感",
      "不要把混乱升级成灾难叙事"
    ]
  },

  "P08": {
    "principleId": "P08",
    "name": "允许微量推进，但不把行动神化",
    "applicableTags": ["推进焦虑", "迟疑", "转折", "内里待发"],
    "guideline":
        "在适合轻推进的方向中，可以给出非常轻的现实落点，但不能把行动包装成唯一出口，也不能滑向效率工具语气。",
    "languageDo": [
      "给很轻的现实落点",
      "强调步幅、火候、渐进",
      "保留用户自主性"
    ],
    "languageDont": [
      "行动教练腔",
      "待办清单腔",
      "只讲执行、不讲感受"
    ],
    "microBridgeExamples": [
      "也许不必一下走很远，只先走到自己心里能承受的那一步。",
      "这里不是不能动，而是更适合用小一些的步幅。",
      "先让动作和内心跟得上彼此，比一味往前更重要。"
    ],
    "avoidEscalation": [
      "不要把轻推进升级成强执行压力",
      "不要把行动建议升级成价值评判"
    ]
  },

  "P09": {
    "principleId": "P09",
    "name": "保护尚未成形的部分，不急着见光",
    "applicableTags": ["未明", "谨慎", "内里待发", "期待与不安并存"],
    "guideline":
        "当用户处在想法刚萌动、方向刚成形、还不敢确认的时候，优先保护其尚未定形的部分，不催促其立刻公开、表态或证明。",
    "languageDo": [
      "允许尚未成形",
      "保护萌动",
      "减少证明压力"
    ],
    "languageDont": [
      "催促表态",
      "强调立刻确认",
      "鼓动立刻公开化"
    ],
    "microBridgeExamples": [
      "有些东西刚刚在心里成形时，并不适合立刻见光。",
      "还没说出口，不一定是没有方向，也可能是在保护它。",
      "先让它在你心里多停一会儿，也是一种认真。"
    ],
    "avoidEscalation": [
      "不要把谨慎升级成胆怯",
      "不要把未说出口升级成没有价值"
    ]
  },

  "P10": {
    "principleId": "P10",
    "name": "先照见真正压着的那一层",
    "applicableTags": ["高负荷", "内耗", "关系焦虑", "迷茫", "转折"],
    "guideline":
        "当用户问题比较混杂、层次很多时，优先帮助其看见最压着自己的那一层，而不是一次性把所有层都分析完。",
    "languageDo": [
      "帮助聚焦最重的一层",
      "减少层层分析",
      "让体验有落脚点"
    ],
    "languageDont": [
      "全面分析一切",
      "一次抛出太多视角",
      "把回复写成报告"
    ],
    "microBridgeExamples": [
      "也许先不用把所有层都理清，只先看见最压着你的那一层。",
      "有时候最有帮助的，不是解释更多，而是先认出最重的那一下来自哪里。",
      "先把最重的一层放到眼前，其他的不用一次都处理。"
    ],
    "avoidEscalation": [
      "不要把复杂体验升级成信息压迫",
      "不要把多层拉扯升级成更深的混乱"
    ]
  },
};

Map<String, dynamic>? getPsychologyPrincipleById(String principleId) {
  return psychologyResponsePrinciples[principleId];
}

List<Map<String, dynamic>> getAllPsychologyPrinciples() {
  return psychologyResponsePrinciples.values.toList();
}

/// 根据 psych tags 粗筛原则
List<Map<String, dynamic>> findPrinciplesByTags(List<String> tags) {
  final tagSet = tags.toSet();

  return psychologyResponsePrinciples.values.where((item) {
    final applicable =
        (item["applicableTags"] as List<dynamic>).cast<String>().toSet();
    return applicable.intersection(tagSet).isNotEmpty;
  }).toList();
}

/// 根据 direction_profile 的 psychTags 粗筛
List<Map<String, dynamic>> findPrinciplesForDirectionProfile(
  Map<String, dynamic> directionProfile,
) {
  final psychTags =
      (directionProfile["psychTags"] as List<dynamic>? ?? const [])
          .cast<String>();

  if (psychTags.isEmpty) {
    return getAllPsychologyPrinciples();
  }

  return findPrinciplesByTags(psychTags);
}

class PsychologyResponsePrinciplesRepository {
  const PsychologyResponsePrinciplesRepository();

  List<PsychologyResponsePrinciple> selectForDirection({
    required DirectionProfile profile,
    required String userText,
    required bool isFollowup,
  }) {
    final base = findPrinciplesByTags(profile.psychTags);
    final pool = base.isEmpty ? getAllPsychologyPrinciples() : base;

    final scored = pool
        .map((p) => (item: p, score: _score(p, profile, userText, isFollowup)))
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return scored.take(2).map((e) => _toPrinciple(e.item)).toList();
  }

  int _score(
    Map<String, dynamic> item,
    DirectionProfile profile,
    String userText,
    bool isFollowup,
  ) {
    var score = 0;
    final tags = _toStringList(item['applicableTags']);
    final text = userText.trim();
    for (final t in tags) {
      if (profile.psychTags.contains(t)) score += 3;
      if (text.contains(t)) score += 2;
    }
    if (isFollowup) {
      final name = item['name']?.toString() ?? '';
      if (name.contains('承接') || name.contains('照见')) score += 2;
    }
    return score;
  }

  PsychologyResponsePrinciple _toPrinciple(Map<String, dynamic> item) {
    return PsychologyResponsePrinciple(
      principleId: item['principleId']?.toString() ?? '',
      name: item['name']?.toString() ?? '',
      tags: _toStringList(item['applicableTags']),
      guideline: item['guideline']?.toString() ?? '',
      languageDo: _toStringList(item['languageDo']),
      languageDont: _toStringList(item['languageDont']),
      avoidEscalation: _toStringList(item['avoidEscalation']),
      microPrompts: _toStringList(item['microBridgeExamples']),
    );
  }

  List<String> _toStringList(dynamic value) {
    if (value is! List) return const [];
    return value.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
  }
}
