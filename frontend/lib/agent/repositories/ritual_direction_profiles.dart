/// lib/agent/repositories/ritual_direction_profiles.dart
///
/// 说明：
/// - 当前为方向画像库 v1
/// - 第一阶段先放少量高质量样本，验证 Agent 链路
/// - 后续再扩充到完整 64 条
/// - key 使用 6 位 code，保证同码同义、稳定映射
library ritual_direction_profiles;

import '../domain/direction_profile.dart';

const Map<String, Map<String, dynamic>> ritualDirectionProfiles = {
  "001101": {
    "directionId": "D42",
    "code": "001101",
    "theme": "收束中的照见",
    "stateName": "收束里的照见",
    "coreTension": "事情并非不能动，而是边界和重点还没有被真正看清。",
    "stateSummary": "更适合先稳住边界，再看清真正值得处理的部分。",
    "responseMode": "收束 / 澄清 / 缓行",
    "bestForInnerTensions": [
      "内耗",
      "信息过载",
      "想推进但心里没站稳",
      "节奏混乱"
    ],
    "avoidEmphasis": [
      "立刻行动",
      "快速定论",
      "强结果导向",
      "制造紧迫感"
    ],
    "culturalThemeRange": [
      "止",
      "静",
      "收锋",
      "照见",
      "澄明",
      "守拙"
    ],
    "psychTags": [
      "高负荷",
      "未明",
      "内耗",
      "节奏失衡"
    ],
    "followupCandidates": [
      "现在最压着我的，究竟是哪一层？",
      "我是在怕停下来，还是怕继续往前？",
      "这件事里，什么是我真正不想失去的？"
    ],
    "hardAvoid": [
      "预测结果",
      "催促行动",
      "把迟疑解释成软弱",
      "将疲惫归因为能力不足"
    ]
  },

  "100111": {
    "directionId": "D61",
    "code": "100111",
    "theme": "启动里的推进",
    "stateName": "将动未稳",
    "coreTension": "有明显的推进冲动，但内部承载和节奏尚未完全跟上。",
    "stateSummary": "可以动，但不宜猛推，更适合先稳住步幅。",
    "responseMode": "轻推进 / 稳节奏 / 缩小动作",
    "bestForInnerTensions": [
      "急于摆脱停滞",
      "想立刻证明自己",
      "对拖延的焦虑",
      "行动冲动和不安并存"
    ],
    "avoidEmphasis": [
      "结果承诺",
      "过度自我施压",
      "硬拆任务",
      "把行动神化为唯一出口"
    ],
    "culturalThemeRange": [
      "火候",
      "渐进",
      "行而不迫",
      "未成先养"
    ],
    "psychTags": [
      "迟疑",
      "推进焦虑",
      "自我施压",
      "节奏不稳"
    ],
    "followupCandidates": [
      "我现在最想快点摆脱的，究竟是什么？",
      "如果不追求立刻见效，我愿意先走到哪一步？",
      "我是在行动，还是在逃离停下来的不安？"
    ],
    "hardAvoid": [
      "立刻执行命令",
      "效率工具腔",
      "把迟缓等同失败",
      "强推任务拆解"
    ]
  },

  "010110": {
    "directionId": "D18",
    "code": "010110",
    "theme": "未明中的守候",
    "stateName": "将明未明",
    "coreTension": "不是没有变化，而是变化尚未显形，急着定论只会放大失真。",
    "stateSummary": "更适合允许未明存在，而不是逼自己马上看懂。",
    "responseMode": "承接 / 等待 / 不急于定论",
    "bestForInnerTensions": [
      "迷茫",
      "不确定",
      "说不清",
      "过度解读"
    ],
    "avoidEmphasis": [
      "马上决定",
      "替未来下判断",
      "逼迫自己立刻想明白"
    ],
    "culturalThemeRange": [
      "未明",
      "夜色",
      "候时",
      "薄霜",
      "微光"
    ],
    "psychTags": [
      "未明",
      "不确定",
      "焦虑",
      "关系摇摆"
    ],
    "followupCandidates": [
      "我最着急想确认的，究竟是什么？",
      "如果暂时不逼自己得出结论，会发生什么？",
      "眼下更值得先看见的是事实，还是心里的不安？"
    ],
    "hardAvoid": [
      "给出明确预言",
      "制造错失焦虑",
      "把未明解释成坏兆头"
    ]
  },

  "111000": {
    "directionId": "D07",
    "code": "111000",
    "theme": "外推内滞",
    "stateName": "往前的力很足，心里却还卡着",
    "coreTension": "外在推进欲望明显，但内里仍有未处理的迟疑或牵扯。",
    "stateSummary": "问题不在于不能动，而在于动得太快会掩盖真正的牵扯。",
    "responseMode": "照见拉扯 / 放慢 / 分清外推与内滞",
    "bestForInnerTensions": [
      "强行推进",
      "压着不安往前冲",
      "外在积极但内在发紧"
    ],
    "avoidEmphasis": [
      "歌颂行动力",
      "把冲劲当成清晰",
      "催促用户证明自己"
    ],
    "culturalThemeRange": [
      "逆风",
      "回身",
      "止马",
      "照影",
      "收步"
    ],
    "psychTags": [
      "内耗",
      "推进焦虑",
      "边界模糊"
    ],
    "followupCandidates": [
      "我一直想往前推的，真的是这件事本身吗？",
      "心里最卡着的那一下，具体卡在哪里？",
      "如果我放慢一点，会更看见什么？"
    ],
    "hardAvoid": [
      "鼓吹快速突破",
      "单向成功叙事",
      "把犹豫说成懦弱"
    ]
  },

  "000111": {
    "directionId": "D08",
    "code": "000111",
    "theme": "内里待发",
    "stateName": "心里已经在动，只是还没到外显的时候",
    "coreTension": "内在方向感正在形成，但外部行动条件仍未完全成熟。",
    "stateSummary": "不是没有动，而是还处在蓄势和辨认阶段。",
    "responseMode": "蓄势 / 允许未外显 / 保护萌动",
    "bestForInnerTensions": [
      "想法刚成形",
      "还不敢说出口",
      "担心一动就散"
    ],
    "avoidEmphasis": [
      "立刻证明",
      "催促表态",
      "过早公开化"
    ],
    "culturalThemeRange": [
      "初芽",
      "微澜",
      "晨光",
      "将起未起"
    ],
    "psychTags": [
      "未明",
      "谨慎",
      "期待与不安并存"
    ],
    "followupCandidates": [
      "我心里已经开始成形的，是什么？",
      "我现在最怕它被什么打断？",
      "如果先不让它立刻见光，我会更安心吗？"
    ],
    "hardAvoid": [
      "鼓动表态",
      "强推曝光",
      "把犹疑解释成没有方向"
    ]
  },

  "011001": {
    "directionId": "D23",
    "code": "011001",
    "theme": "过载后的回身",
    "stateName": "有些撑过头了",
    "coreTension": "问题不一定在事情本身，而在于已经承受过量，心和节奏都在发硬。",
    "stateSummary": "更适合先减压和回身，而不是再向前加码。",
    "responseMode": "减压 / 回身 / 恢复感受力",
    "bestForInnerTensions": [
      "疲惫",
      "高负荷",
      "麻木",
      "一直撑着"
    ],
    "avoidEmphasis": [
      "更努力",
      "再坚持一下",
      "继续扛",
      "把疲惫合理化"
    ],
    "culturalThemeRange": [
      "息",
      "回舟",
      "落潮",
      "缓岸",
      "松手"
    ],
    "psychTags": [
      "高负荷",
      "疲惫",
      "自我消耗",
      "失控感"
    ],
    "followupCandidates": [
      "我到底已经撑了多久？",
      "如果现在允许自己退半步，最怕失去什么？",
      "是事情重，还是我一直没有真正放下？"
    ],
    "hardAvoid": [
      "继续打鸡血",
      "把疲惫解释为意志不坚定",
      "效率话术"
    ]
  },

  "101010": {
    "directionId": "D31",
    "code": "101010",
    "theme": "边界松动",
    "stateName": "有些地方开始渗进来了",
    "coreTension": "让你难受的未必是事件本身，而可能是边界慢慢变薄之后的消耗。",
    "stateSummary": "更适合先看见哪里被侵入，而不是先责怪自己太敏感。",
    "responseMode": "边界照见 / 轻止损 / 自我辨认",
    "bestForInnerTensions": [
      "边界模糊",
      "关系消耗",
      "总在迁就",
      "不敢拒绝"
    ],
    "avoidEmphasis": [
      "继续忍耐",
      "一味体谅别人",
      "把委屈归因为自己想太多"
    ],
    "culturalThemeRange": [
      "门限",
      "岸线",
      "潮痕",
      "界石",
      "风入帘"
    ],
    "psychTags": [
      "边界",
      "关系焦虑",
      "消耗",
      "委屈"
    ],
    "followupCandidates": [
      "最近最让我发紧的那一处边界，是哪里？",
      "我是在害怕冲突，还是害怕失去连接？",
      "如果先守住一点点分寸，会是什么样子？"
    ],
    "hardAvoid": [
      "替对方辩护",
      "要求用户继续忍",
      "关系裁决"
    ]
  },

  "110011": {
    "directionId": "D54",
    "code": "110011",
    "theme": "临界转向",
    "stateName": "有些东西已经快到拐点了",
    "coreTension": "旧的推进方式正在失效，但新的方向还没有完全显形。",
    "stateSummary": "更适合先识别转向信号，而不是继续沿旧路径用力。",
    "responseMode": "识别转向 / 停看 / 不沿旧法加码",
    "bestForInnerTensions": [
      "反复无效努力",
      "明知不对却还在硬撑",
      "旧路径失效"
    ],
    "avoidEmphasis": [
      "沿原路径更用力",
      "把变化看成失败",
      "急着给拐点命名"
    ],
    "culturalThemeRange": [
      "转舵",
      "回潮",
      "岔路",
      "云开未尽",
      "换岸"
    ],
    "psychTags": [
      "转折",
      "迟疑",
      "旧模式松动",
      "不确定"
    ],
    "followupCandidates": [
      "我其实已经看见了哪些旧方法不再有效？",
      "如果不再沿原路加码，我最担心的是什么？",
      "新的方向现在只是模糊，还是我还不愿承认？"
    ],
    "hardAvoid": [
      "沿旧路径鸡血式推进",
      "把转向解释成失败",
      "直接替用户决定下一步"
    ]
  },
};

Map<String, dynamic>? getDirectionProfileByCode(String code) {
  return ritualDirectionProfiles[code];
}

class RitualDirectionProfilesRepository {
  const RitualDirectionProfilesRepository();

  DirectionProfile resolveByLines(List<int> lines) {
    final code = _normalizeLines(lines).join();
    final raw = getDirectionProfileByCode(code) ?? ritualDirectionProfiles.values.first;
    return _toDirectionProfile(raw);
  }

  DirectionProfile _toDirectionProfile(Map<String, dynamic> raw) {
    final code = raw['code']?.toString() ?? '000000';
    return DirectionProfile(
      directionId: raw['directionId']?.toString() ?? 'D00',
      code: code,
      theme: raw['theme']?.toString() ?? '',
      stateName: raw['stateName']?.toString() ?? '',
      coreTension: raw['coreTension']?.toString() ?? '',
      stateSummary: raw['stateSummary']?.toString() ?? '',
      responseMode: raw['responseMode']?.toString() ?? '',
      hexagramName: 'D-${raw['directionId']?.toString() ?? '00'}',
      upperTrigram: code.substring(3, 6),
      lowerTrigram: code.substring(0, 3),
      guaCi: '',
      xiangCi: '',
      lineRule: '',
      avoid: _toStringList(raw['hardAvoid']),
      culturalTags: _toStringList(raw['culturalThemeRange']),
      psychTags: _toStringList(raw['psychTags']),
      bestForInnerTensions: _toStringList(raw['bestForInnerTensions']),
      avoidEmphasis: _toStringList(raw['avoidEmphasis']),
      culturalThemeRange: _toStringList(raw['culturalThemeRange']),
      followupCandidates: _toStringList(raw['followupCandidates']),
    );
  }

  List<int> _normalizeLines(List<int> lines) {
    final out = List<int>.filled(6, 0);
    for (int i = 0; i < 6; i++) {
      out[i] = (i < lines.length && lines[i] > 0) ? 1 : 0;
    }
    return out;
  }

  List<String> _toStringList(dynamic value) {
    if (value is! List) return const [];
    return value.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
  }
}
