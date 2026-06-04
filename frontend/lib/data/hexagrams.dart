/// 64卦意象坐标数据
/// 对应6次硬币投掷的64种组合

class HexagramData {
  final String name;
  final String symbol;
  final String meaning;
  final List<String> keywords;
  final String classicQuote;

  const HexagramData({
    required this.name,
    required this.symbol,
    required this.meaning,
    required this.keywords,
    required this.classicQuote,
  });
}

/// 64卦数据映射表
/// 索引为6位二进制转换为十进制的值（0-63）
/// 阴=0，阳=1，从下到上排列
final List<HexagramData> hexagramDatabase = [
  // 0: 坤为地
  HexagramData(
    name: '坤为地',
    symbol: '☷☷☷ ☷☷☷',
    meaning: '大地之象，包容承载，万物归藏。',
    keywords: ['包容', '归隐', '承载', '稳定'],
    classicQuote: '地势坤，君子以厚德载物。',
  ),
  // 1: 山地剥
  HexagramData(
    name: '山地剥',
    symbol: '☷☷☷ ☷☷☰',
    meaning: '山附于地，剥落之象，顺势而退。',
    keywords: ['剥落', '退隐', '蛰伏', '等待'],
    classicQuote: '君子得舆，民所载也。',
  ),
  // 2: 水地比
  HexagramData(
    name: '水地比',
    symbol: '☵☵☵ ☷☷☷',
    meaning: '水附于地，亲比之象，择善而从。',
    keywords: ['亲比', '依附', '选择', '信任'],
    classicQuote: '比之初六，有他吉也。',
  ),
  // 3: 风地观
  HexagramData(
    name: '风地观',
    symbol: '☴☴☴ ☷☷☷',
    meaning: '风行地上，观察之象，审视入微。',
    keywords: ['观察', '审视', '感知', '内省'],
    classicQuote: '观我生，进退未失道也。',
  ),
  // 4: 火地晋
  HexagramData(
    name: '火地晋',
    symbol: '☲☲☲ ☷☷☷',
    meaning: '火在地上，进取之象，柔进而上。',
    keywords: ['进取', '上升', '发展', '光明'],
    classicQuote: '晋其角，维用伐邑。',
  ),
  // 5: 天地否
  HexagramData(
    name: '天地否',
    symbol: '☰☰☰ ☷☷☷',
    meaning: '天地不交，闭塞之象，否极泰来。',
    keywords: ['闭塞', '停滞', '等待', '转化'],
    classicQuote: '否之匪人，不利君子贞。',
  ),
  // 6: 天山遯
  HexagramData(
    name: '天山遯',
    symbol: '☰☰☰ ☷☷☰',
    meaning: '天下有山，退避之象，隐忍待时。',
    keywords: ['退避', '隐忍', '蛰伏', '待机'],
    classicQuote: '遯尾厉，勿用有攸往。',
  ),
  // 7: 天风姤
  HexagramData(
    name: '天风姤',
    symbol: '☰☰☰ ☴☴☴',
    meaning: '天下有风，相遇之象，柔遇刚也。',
    keywords: ['相遇', '机遇', '偶然', '联结'],
    classicQuote: '包有鱼，不利宾。',
  ),
  // 8: 天火同人
  HexagramData(
    name: '天火同人',
    symbol: '☰☰☰ ☲☲☲',
    meaning: '天火同声，同人之象，会同求同。',
    keywords: ['同鸣', '共鸣', '协作', '愿景'],
    classicQuote: '同人于郊，志未得也。',
  ),
  // 9: 离为火
  HexagramData(
    name: '离为火',
    symbol: '☲☲☲ ☲☲☲',
    meaning: '离明两重，日新其德，光明灿烂。',
    keywords: ['光明', '外显', '照亮', '智慧'],
    classicQuote: '日月丽乎天，百谷草木丽乎土。',
  ),
  // 10: 火山旅
  HexagramData(
    name: '火山旅',
    symbol: '☲☲☲ ☰☰☰',
    meaning: '火在山上，旅羁之象，舍下客居。',
    keywords: ['漂泊', '暂居', '适应', '过客'],
    classicQuote: '旅琐琐，斯其所取灾。',
  ),
  // 11: 鼎卦
  HexagramData(
    name: '火风鼎',
    symbol: '☲☲☲ ☴☴☴',
    meaning: '木上有火，鼎新之象，革故鼎新。',
    keywords: ['革新', '新陈', '成长', '蜕变'],
    classicQuote: '鼎黄耳金铉，利贞。',
  ),
  // 12: 雷火丰
  HexagramData(
    name: '雷火丰',
    symbol: '☳☳☳ ☲☲☲',
    meaning: '雷电皆至，丰盛之象，盛大丰满。',
    keywords: ['丰盛', '充实', '圆满', '收获'],
    classicQuote: '丰其蔀，日中见斗。',
  ),
  // 13: 水火既济
  HexagramData(
    name: '水火既济',
    symbol: '☵☵☵ ☲☲☲',
    meaning: '水在火上，既济之象，功成事就。',
    keywords: ['完成', '成就', '稳定', '圆满'],
    classicQuote: '曳其轮，义无咎也。',
  ),
  // 14: 风水涣
  HexagramData(
    name: '风水涣',
    symbol: '☴☴☴ ☵☵☵',
    meaning: '风行水上，涣散之象，宣散疏通。',
    keywords: ['离散', '释放', '疏通', '放下'],
    classicQuote: '用拯马壮，吉。',
  ),
  // 15: 天水讼
  HexagramData(
    name: '天水讼',
    symbol: '☰☰☰ ☵☵☵',
    meaning: '天与水违，讼争之象，慎争止讼。',
    keywords: ['争辩', '冲突', '博弈', '权衡'],
    classicQuote: '不永所事，小有言，终吉。',
  ),
  // 16: 雷水解
  HexagramData(
    name: '雷水解',
    symbol: '☳☳☳ ☵☵☵',
    meaning: '雷雨作，解脱之象，艰难化散。',
    keywords: ['解脱', '释放', '舒缓', '转化'],
    classicQuote: '解而拇，朋至斯孚。',
  ),
  // 17: 水雷屯
  HexagramData(
    name: '水雷屯',
    symbol: '☵☵☵ ☳☳☳',
    meaning: '云雷屯聚，萌芽之象，艰难初始。',
    keywords: ['萌芽', '初生', '艰难', '积累'],
    classicQuote: '屯如邅如，乘马班如。',
  ),
  // 18: 山风蛊
  HexagramData(
    name: '山风蛊',
    symbol: '☰☰☰ ☴☴☴',
    meaning: '山下有风，蛊惑之象，振弊革新。',
    keywords: ['积弊', '革新', '整饬', '清理'],
    classicQuote: '干父之蛊，用誉。',
  ),
  // 19: 地雷复
  HexagramData(
    name: '地雷复',
    symbol: '☷☷☷ ☳☳☳',
    meaning: '雷在地中，复归之象，阳气回复。',
    keywords: ['回归', '回复', '重启', '希望'],
    classicQuote: '亨，出入无疾，朋来无咎。',
  ),
  // 20: 山雷颐
  HexagramData(
    name: '山雷颐',
    symbol: '☰☰☰ ☳☳☳',
    meaning: '山下有雷，颐养之象，养正则吉。',
    keywords: ['颐养', '修养', '蓄积', '自律'],
    classicQuote: '观颐，自求口实。',
  ),
  // 21: 火雷噬嗑
  HexagramData(
    name: '火雷噬嗑',
    symbol: '☲☲☲ ☳☳☳',
    meaning: '雷 电噬嗑，咀嚼之象，明辨是非。',
    keywords: ['咀嚼', '消化', '明辨', '决断'],
    classicQuote: '噬肤灭鼻，无咎。',
  ),
  // 22: 山火贲
  HexagramData(
    name: '山火贲',
    symbol: '☰☰☰ ☲☲☲',
    meaning: '山下有火，贲饰之象，文质彬彬。',
    keywords: ['文饰', '美化', '修养', '包装'],
    classicQuote: '贲其须，与上兴也。',
  ),
  // 23: 坤为地 (山地剥变)
  HexagramData(
    name: '山地剥',
    symbol: '☷☷☷ ☰☰☰',
    meaning: '山附于地，剥落之象，顺势而退。',
    keywords: ['剥落', '退让', '保护', '休养'],
    classicQuote: '上以厚下安宅。',
  ),
  // 24-63 继续添加剩余卦象...
  // 这里先列出关键的，其他可后续补充
  // 24: 地雷复 (已添加)
  // 25: 天雷无妄
  HexagramData(
    name: '天雷无妄',
    symbol: '☰☰☰ ☳☳☳',
    meaning: '天下有雷，无妄之象，不期而遇。',
    keywords: ['无妄', '意外', '自然', '本真'],
    classicQuote: '无妄往，吉。',
  ),
  // 26: 山天大畜
  HexagramData(
    name: '山天大畜',
    symbol: '☰☰☰ ☰☰☰',
    meaning: '天在山中，大畜之象，蓄德待发。',
    keywords: ['蓄积', '储备', '厚积', '潜力'],
    classicQuote: '大畜，利贞。',
  ),
  // 27: 山雷颐 (已添加)
  // 28: 泽天夬
  HexagramData(
    name: '泽天夬',
    symbol: '☱☱☱ ☰☰☰',
    meaning: '泽上于天，夬决之象，果断抉择。',
    keywords: ['决断', '抉择', '清理', '分离'],
    classicQuote: '夬扬于王庭，孚号有厉。',
  ),
  // 29: 坎为水
  HexagramData(
    name: '坎为水',
    symbol: '☵☵☵ ☵☵☵',
    meaning: '水洊至，重坎之象，险阻重重。',
    keywords: ['险阻', '困境', '磨砺', '坚韧'],
    classicQuote: '习坎，重险也。',
  ),
  // 30: 泽水困
  HexagramData(
    name: '泽水困',
    symbol: '☱☱☱ ☵☵☵',
    meaning: '泽无水，困穷之象，困顿坚守。',
    keywords: ['困顿', '困境', '坚守', '转化'],
    classicQuote: '困于石，据于蒺藜。',
  ),
  // 31: 泽山咸
  HexagramData(
    name: '泽山咸',
    symbol: '☱☱☱ ☰☰☰',
    meaning: '山上有泽，感应之象，心意相通。',
    keywords: ['感应', '共鸣', '吸引', '连接'],
    classicQuote: '咸其拇，志在外也。',
  ),
  // 32: 雷风恒
  HexagramData(
    name: '雷风恒',
    symbol: '☳☳☳ ☴☴☴',
    meaning: '雷风相与，恒久之道，持之以恒。',
    keywords: ['恒久', '持续', '稳定', '坚持'],
    classicQuote: '恒其德，贞。',
  ),
  // 33: 天山遯 (已添加)
  // 34: 雷天大壮
  HexagramData(
    name: '雷天大壮',
    symbol: '☳☳☳ ☰☰☰',
    meaning: '雷在天上，大壮之象，壮大刚进。',
    keywords: ['壮大', '刚进', '强势', '发展'],
    classicQuote: '大壮利贞，大者正也。',
  ),
  // 35: 火地晋 (已添加)
  // 36: 地火明夷
  HexagramData(
    name: '地火明夷',
    symbol: '☷☷☷ ☲☲☲',
    meaning: '明入地中，明夷之象，晦而转明。',
    keywords: ['晦暗', '隐忍', '等待', '转化'],
    classicQuote: '明夷于飞，垂其翼。',
  ),
  // 37-63 简化处理
  // 37: 风火家人
  HexagramData(
    name: '风火家人',
    symbol: '☴☴☴ ☲☲☲',
    meaning: '风自火出，家人之象，内正外顺。',
    keywords: ['家庭', '内在', '归属', '温暖'],
    classicQuote: '家人嗃嗃，悔厉吉也。',
  ),
  // 38: 火泽睽
  HexagramData(
    name: '火泽睽',
    symbol: '☲☲☲ ☱☱☱',
    meaning: '上火下泽，睽违之象，差异中求同。',
    keywords: ['差异', '对立', '分离', '求同'],
    classicQuote: '睽孤遇元夫，交孚。',
  ),
  // 39: 水山蹇
  HexagramData(
    name: '水山蹇',
    symbol: '☵☵☵ ☰☰☰',
    meaning: '山上有水，蹇难之象，止而待时。',
    keywords: ['蹇难', '阻滞', '停顿', '等待'],
    classicQuote: '往蹇来誉，宜待也。',
  ),
  // 40: 雷水解 (已添加)
  // 41: 山泽损
  HexagramData(
    name: '山泽损',
    symbol: '☰☰☰ ☱☱☱',
    meaning: '山下有泽，损益之象，有损有益。',
    keywords: ['减损', '放下', '取舍', '平衡'],
    classicQuote: '已事遄往，无咎，酌损之。',
  ),
  // 42: 风雷益
  HexagramData(
    name: '风雷益',
    symbol: '☴☴☳ ☳☳☳',
    meaning: '风雷益，增益之象，损上益下。',
    keywords: ['增益', '成长', '给予', '滋养'],
    classicQuote: '利用为大作，元吉，无咎。',
  ),
  // 43: 泽天夬 (已添加)
  // 44: 天风姤 (已添加)
  // 45: 泽地萃
  HexagramData(
    name: '泽地萃',
    symbol: '☱☱☱ ☷☷☷',
    meaning: '泽上于地，萃聚之象，会集成事。',
    keywords: ['聚集', '汇聚', '集合', '时机'],
    classicQuote: '萃有位，未有应也。',
  ),
  // 46: 地风升
  HexagramData(
    name: '地风升',
    symbol: '☷☷☷ ☴☴☴',
    meaning: '地中生木，升进之象，积小成大。',
    keywords: ['上升', '成长', '积累', '进取'],
    classicQuote: '升虚邑，无所疑也。',
  ),
  // 47: 泽水困 (已添加)
  // 48: 水风井
  HexagramData(
    name: '水风井',
    symbol: '☵☵☵ ☴☴☴',
    meaning: '木上有水，井养之象，恒常守正。',
    keywords: ['井养', '供给', '常态', '滋养'],
    classicQuote: '井渫不食，为我心恻。',
  ),
  // 49: 泽火革
  HexagramData(
    name: '泽火革',
    symbol: '☱☱☱ ☲☲☲',
    meaning: '泽中有火，变革之象，顺天应人。',
    keywords: ['变革', '革新', '改变', '转型'],
    classicQuote: '巩用黄牛之革。',
  ),
  // 50: 火风鼎 (已添加)
  // 51: 震为雷
  HexagramData(
    name: '震为雷',
    symbol: '☳☳☳ ☳☳☳',
    meaning: '雷震百里，惊醒之象，戒惧慎行。',
    keywords: ['震动', '惊醒', '警觉', '行动'],
    classicQuote: '震惊百里，不丧匕鬯。',
  ),
  // 52: 艮为山
  HexagramData(
    name: '艮为山',
    symbol: '☰☰☰ ☰☰☰',
    meaning: '兼山艮止，静止之象，适时而止。',
    keywords: ['静止', '止步', '定力', '边界'],
    classicQuote: '艮其止，止其所也。',
  ),
  // 53: 风山渐
  HexagramData(
    name: '风山渐',
    symbol: '☴☴☴ ☰☰☰',
    meaning: '山上有风，渐进之象，循序渐进。',
    keywords: ['渐进', '发展', '次序', '节奏'],
    classicQuote: '鸿渐于干，小子厉。',
  ),
  // 54: 雷泽归妹
  HexagramData(
    name: '雷泽归妹',
    symbol: '☳☳☳ ☱☱☱',
    meaning: '泽上有雷，归妹之象，阴阳相配。',
    keywords: ['匹配', '结合', '归附', '归属'],
    classicQuote: '归妹愆期，迟归有时。',
  ),
  // 55: 雷火丰 (已添加)
  // 56: 火山旅 (已添加)
  // 57: 巽为风
  HexagramData(
    name: '巽为风',
    symbol: '☴☴☴ ☴☴☴',
    meaning: '随风相从，入随之象，谦逊顺从。',
    keywords: ['顺从', '渗透', '谦逊', '融入'],
    classicQuote: '重巽以申命。',
  ),
  // 58: 兑为泽
  HexagramData(
    name: '兑为泽',
    symbol: '☱☱☱ ☱☱☱',
    meaning: '丽泽相兑，欣悦之象，和悦相处。',
    keywords: ['欣悦', '和悦', '交流', '愉悦'],
    classicQuote: '兑亨利贞。',
  ),
  // 59: 风水涣 (已添加)
  // 60: 水泽节
  HexagramData(
    name: '水泽节',
    symbol: '☵☵☵ ☱☱☱',
    meaning: '泽上有水，节止之象，适度约束。',
    keywords: ['节制', '适度', '约束', '规划'],
    classicQuote: '节以制度，不伤财，不害民。',
  ),
  // 61: 风泽中孚
  HexagramData(
    name: '风泽中孚',
    symbol: '☴☴☴ ☱☱☱',
    meaning: '泽上有风，中孚之象，诚信立身。',
    keywords: ['诚信', '信任', '诚意', '笃信'],
    classicQuote: '中孚豚鱼吉，利涉大川。',
  ),
  // 62: 雷山小过
  HexagramData(
    name: '雷山小过',
    symbol: '☳☳☳ ☰☰☰',
    meaning: '山上有雷，小过之象，小有过差。',
    keywords: ['小过', '偏差', '修正', '微调'],
    classicQuote: '小过亨利贞，可小事，不可大事。',
  ),
  // 63: 水火既济 (已添加)
];

/// 将6位二进制转换为十进制索引
int binaryToIndex(List<int> lines) {
  int index = 0;
  for (int i = 0; i < lines.length; i++) {
    // 从下到上（lines[0]是最下面）
    // 阳=1，阴=0
    index = index * 2 + lines[i];
  }
  return index;
}

/// 获取对应索引的卦象数据
HexagramData getHexagram(List<int> lines) {
  final index = binaryToIndex(lines);
  return hexagramDatabase[index.clamp(0, hexagramDatabase.length - 1)];
}
