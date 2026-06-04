/// 古典文本数据库 - 用于本地RAG检索
/// 根据关键词匹配，返回古典哲学引文

class ClassicalText {
  final String content;     // 引文内容
  final String source;      // 出处
  final List<String> keywords; // 匹配关键词

  const ClassicalText({
    required this.content,
    required this.source,
    required this.keywords,
  });
}

/// 古典文本数据库
const List<ClassicalText> classicalTexts = [
  // 乾卦相关
  ClassicalText(
    content: '天行健，君子以自强不息。',
    source: '周易·乾卦',
    keywords: ['乾', '天', '健', '自强', '不息', '进取', '创业'],
  ),
  ClassicalText(
    content: '九三，君子终日乾乾，夕惕若厉，无咎。',
    source: '周易·乾卦',
    keywords: ['乾乾', '惕', '警惕', '谨慎', '勤奋'],
  ),
  ClassicalText(
    content: '飞龙在天，利见大人。',
    source: '周易·乾卦',
    keywords: ['飞龙', '大人', '领袖', '成就', '腾飞'],
  ),

  // 坤卦相关
  ClassicalText(
    content: '地势坤，君子以厚德载物。',
    source: '周易·坤卦',
    keywords: ['坤', '地', '厚德', '载物', '包容', '承载'],
  ),
  ClassicalText(
    content: '含章可贞，或从王事，无成有终。',
    source: '周易·坤卦',
    keywords: ['含章', '贞', '忠诚', '辅佐', '成就'],
  ),

  // 屯卦相关
  ClassicalText(
    content: '屯如邅如，乘马班如。',
    source: '周易·屯卦',
    keywords: ['屯', '邅', '困难', '艰难', '阻碍'],
  ),
  ClassicalText(
    content: '即鹿无虞，惟入于林中，君子几不如舍。',
    source: '周易·屯卦',
    keywords: ['鹿', '虞', '放弃', '取舍', '审时'],
  ),

  // 蒙卦相关
  ClassicalText(
    content: '匪我求童蒙，童蒙求我。',
    source: '周易·蒙卦',
    keywords: ['蒙', '童蒙', '求学', '启蒙', '请教'],
  ),
  ClassicalText(
    content: '蒙以养正，圣功也。',
    source: '周易·蒙卦',
    keywords: ['养正', '教育', '正道', '启蒙'],
  ),

  // 需卦相关
  ClassicalText(
    content: '需于郊，利用恒，无咎。',
    source: '周易·需卦',
    keywords: ['需', '等待', '郊区', '恒', '耐心'],
  ),
  ClassicalText(
    content: '需于沙，小有言，终吉。',
    source: '周易·需卦',
    keywords: ['沙', '小事', '言语', '耐心等待'],
  ),

  // 讼卦相关
  ClassicalText(
    content: '讼元吉，以中正也。',
    source: '周易·讼卦',
    keywords: ['讼', '争', '诉讼', '中正', '公平'],
  ),
  ClassicalText(
    content: '不永所事，小有言，终吉。',
    source: '周易·讼卦',
    keywords: ['争', '言语', '和解', '终止'],
  ),

  // 师卦相关
  ClassicalText(
    content: '师众也，贞正也，能以众正，可以王矣。',
    source: '周易·师卦',
    keywords: ['师', '众', '带领', '领导', '组织'],
  ),

  // 比卦相关
  ClassicalText(
    content: '比之初六，有他吉也。',
    source: '周易·比卦',
    keywords: ['比', '亲比', '依附', '选择', '信任'],
  ),
  ClassicalText(
    content: '比自内，贞吉。',
    source: '周易·比卦',
    keywords: ['内', '亲近', '内部', '归顺'],
  ),

  // 小畜卦
  ClassicalText(
    content: '密云不雨，自我西郊。',
    source: '周易·小畜卦',
    keywords: ['云', '雨', '等待', '积累', '西郊'],
  ),
  ClassicalText(
    content: '有孚挛如，富以其邻。',
    source: '周易·小畜卦',
    keywords: ['孚', '信', '富', '邻', '分享'],
  ),

  // 履卦
  ClassicalText(
    content: '履虎尾，不咥人，亨。',
    source: '周易·履卦',
    keywords: ['履', '虎', '危险', '谨慎', '通过'],
  ),
  ClassicalText(
    content: '眇能视，跛能履，履虎尾咥人凶。',
    source: '周易·履卦',
    keywords: ['眇', '跛', '不足', '缺陷', '危险'],
  ),

  // 泰卦
  ClassicalText(
    content: '天地交泰，后以财成天地之道。',
    source: '周易·泰卦',
    keywords: ['泰', '通', '天地', '交通', '顺利'],
  ),
  ClassicalText(
    content: '无平不陂，无往不复。',
    source: '周易·泰卦',
    keywords: ['平', '陂', '往', '复', '转化', '循环'],
  ),

  // 否卦
  ClassicalText(
    content: '否之匪人，不利君子贞。',
    source: '周易·否卦',
    keywords: ['否', '闭塞', '不通', '小人', '困境'],
  ),
  ClassicalText(
    content: '倾否，先否后喜。',
    source: '周易·否卦',
    keywords: ['倾否', '倾覆', '转化', '先苦后甜'],
  ),

  // 同人
  ClassicalText(
    content: '同人于野，亨。',
    source: '周易·同人卦',
    keywords: ['同人', '野', '合作', '会同', '广阔'],
  ),
  ClassicalText(
    content: '同人先号咷而后笑，大师克相遇。',
    source: '周易·同人卦',
    keywords: ['号咷', '笑', '相遇', '合作', '克'],
  ),

  // 大有
  ClassicalText(
    content: '火在天上，大有。君子以遏恶扬善。',
    source: '周易·大有卦',
    keywords: ['大有', '火', '天', '收获', '丰盛'],
  ),
  ClassicalText(
    content: '厥孚交如，威如，吉。',
    source: '周易·大有卦',
    keywords: ['孚', '信', '威', '威严', '诚信'],
  ),

  // 谦卦
  ClassicalText(
    content: '谦亨，君子有终。',
    source: '周易·谦卦',
    keywords: ['谦', '亨', '君子', '终', '低调'],
  ),
  ClassicalText(
    content: '劳谦君子，万民服也。',
    source: '周易·谦卦',
    keywords: ['劳', '谦', '付出', '服务', '民服'],
  ),

  // 豫卦
  ClassicalText(
    content: '雷出地奋，豫。',
    source: '周易·豫卦',
    keywords: ['豫', '雷', '奋', '愉悦', '准备'],
  ),
  ClassicalText(
    content: '介于石，不终日，贞吉。',
    source: '周易·豫卦',
    keywords: ['石', '介', '坚定', '果断', '迅速'],
  ),

  // 随卦
  ClassicalText(
    content: '随元亨利贞，无咎。',
    source: '周易·随卦',
    keywords: ['随', '随从', '跟随', '变通', '灵活'],
  ),
  ClassicalText(
    content: '出门交有功，不失也。',
    source: '周易·随卦',
    keywords: ['出门', '交', '功', '外出', '交际'],
  ),

  // 蛊卦
  ClassicalText(
    content: '干父之蛊，用誉。',
    source: '周易·蛊卦',
    keywords: ['蛊', '干', '革新', '整饬', '清理'],
  ),
  ClassicalText(
    content: '不事王侯，高尚其事。',
    source: '周易·蛊卦',
    keywords: ['王侯', '高尚', '隐居', '独立'],
  ),

  // 临卦
  ClassicalText(
    content: '临元亨利贞，至于八月有凶。',
    source: '周易·临卦',
    keywords: ['临', '领导', '统治', '监视', '八月'],
  ),
  ClassicalText(
    content: '知临，大君之宜，吉。',
    source: '周易·临卦',
    keywords: ['知', '临', '智慧', '领导', '适宜'],
  ),

  // 观卦
  ClassicalText(
    content: '盥而不荐，有孚颙若。',
    source: '周易·观卦',
    keywords: ['观', '盥', '荐', '观察', '祭祀'],
  ),
  ClassicalText(
    content: '观我生，进退未失道也。',
    source: '周易·观卦',
    keywords: ['观', '我生', '进退', '观察', '自省'],
  ),

  // 噬嗑
  ClassicalText(
    content: '噬肤灭鼻，无咎。',
    source: '周易·噬嗑卦',
    keywords: ['噬', '肤', '鼻', '决断', '执法'],
  ),
  ClassicalText(
    content: '何校灭耳，凶。',
    source: '周易·噬嗑卦',
    keywords: ['校', '耳', '过错', '惩罚', '凶'],
  ),

  // 贲卦
  ClassicalText(
    content: '贲其须，与上兴也。',
    source: '周易·贲卦',
    keywords: ['贲', '须', '文饰', '美化', '修饰'],
  ),
  ClassicalText(
    content: '贲于丘园，束帛戋戋，吝终吉。',
    source: '周易·贲卦',
    keywords: ['丘园', '束帛', '聘', '礼', '朴素'],
  ),

  // 剥卦
  ClassicalText(
    content: '山附于地，剥。',
    source: '周易·剥卦',
    keywords: ['剥', '山', '地', '消退', '衰落'],
  ),
  ClassicalText(
    content: '上以厚下安宅。',
    source: '周易·剥卦',
    keywords: ['厚下', '安宅', '基础', '稳固'],
  ),

  // 复卦
  ClassicalText(
    content: '亨，出入无疾，朋来无咎。',
    source: '周易·复卦',
    keywords: ['复', '亨', '出入', '疾', '朋友'],
  ),
  ClassicalText(
    content: '复其见天地之心乎。',
    source: '周易·复卦',
    keywords: ['复', '天地', '心', '回归', '希望'],
  ),

  // 无妄
  ClassicalText(
    content: '无妄往，吉。',
    source: '周易·无妄卦',
    keywords: ['无妄', '往', '自然', '真实', '行动'],
  ),
  ClassicalText(
    content: '无妄之疾，勿药有喜。',
    source: '周易·无妄卦',
    keywords: ['疾', '药', '喜', '自然', '恢复'],
  ),

  // 大畜
  ClassicalText(
    content: '大畜利贞，不家食吉，利涉大川。',
    source: '周易·大畜卦',
    keywords: ['大畜', '食', '川', '储备', '成就'],
  ),
  ClassicalText(
    content: '何天之衢，亨。',
    source: '周易·大畜卦',
    keywords: ['衢', '路', '通道', '畅通'],
  ),

  // 颐卦
  ClassicalText(
    content: '观颐，自求口实。',
    source: '周易·颐卦',
    keywords: ['颐', '口', '养', '自养', '修养'],
  ),
  ClassicalText(
    content: '舍尔灵龟，观我朵颐，凶。',
    source: '周易·颐卦',
    keywords: ['灵龟', '朵颐', '贪', '欲望', '凶'],
  ),

  // 大过
  ClassicalText(
    content: '栋桡，凶。',
    source: '周易·大过卦',
    keywords: ['栋', '桡', '过', '超越', '危机'],
  ),
  ClassicalText(
    content: '独立不惧，遁世无闷。',
    source: '周易·大过卦',
    keywords: ['独立', '不惧', '遁世', '闷', '坚守'],
  ),

  // 坎卦
  ClassicalText(
    content: '习坎，重险也。',
    source: '周易·坎卦',
    keywords: ['坎', '险', '习', '重险', '困境'],
  ),
  ClassicalText(
    content: '坎不盈，祗既平，无咎。',
    source: '周易·坎卦',
    keywords: ['盈', '祗', '平', '满', '平衡'],
  ),

  // 离卦
  ClassicalText(
    content: '日月丽乎天，百谷草木丽乎土。',
    source: '周易·离卦',
    keywords: ['离', '丽', '日月', '天', '光明'],
  ),
  ClassicalText(
    content: '突如其来如，焚如，死如，弃如。',
    source: '周易·离卦',
    keywords: ['突如', '焚', '死', '弃', '急变'],
  ),

  // 恒卦
  ClassicalText(
    content: '雷风相与，恒。君子以立不易方。',
    source: '周易·恒卦',
    keywords: ['恒', '雷', '风', '持久', '坚持'],
  ),
  ClassicalText(
    content: '振恒，凶。',
    source: '周易·恒卦',
    keywords: ['振', '恒', '变动', '凶', '不安'],
  ),

  // 遯卦
  ClassicalText(
    content: '天下有山，遯。君子以远小人。',
    source: '周易·遯卦',
    keywords: ['遯', '退', '隐', '退避', '远离'],
  ),
  ClassicalText(
    content: '好遯君子吉，小人不退也。',
    source: '周易·遯卦',
    keywords: ['好遯', '退', '君子', '小人'],
  ),

  // 大壮
  ClassicalText(
    content: '大壮利贞，大者正也。',
    source: '周易·大壮卦',
    keywords: ['大壮', '利贞', '正', '壮大', '刚进'],
  ),
  ClassicalText(
    content: '小人用壮，君子用罔也。',
    source: '周易·大壮卦',
    keywords: ['小人', '壮', '君子', '罔', '手段'],
  ),

  // 晋卦
  ClassicalText(
    content: '明出地上，晋。君子以自昭明德。',
    source: '周易·晋卦',
    keywords: ['晋', '明', '地上', '进', '晋升'],
  ),
  ClassicalText(
    content: '晋其角，维用伐邑。',
    source: '周易·晋卦',
    keywords: ['角', '伐邑', '征讨', '进攻'],
  ),

  // 明夷
  ClassicalText(
    content: '明入地中，明夷。君子以莅众。',
    source: '周易·明夷卦',
    keywords: ['明夷', '明', '地中', '晦', '隐忍'],
  ),
  ClassicalText(
    content: '明夷于飞，垂其翼。',
    source: '周易·明夷卦',
    keywords: ['飞', '翼', '垂', '隐藏', '退避'],
  ),

  // 家人
  ClassicalText(
    content: '风自火出，家人。君子以言有物而行有恒。',
    source: '周易·家人卦',
    keywords: ['家人', '风', '火', '家庭', '规矩'],
  ),
  ClassicalText(
    content: '家人嗃嗃，悔厉吉也。',
    source: '周易·家人卦',
    keywords: ['嗃嗃', '悔厉', '家', '严厉', '教化'],
  ),

  // 睽卦
  ClassicalText(
    content: '上火下泽，睽。君子以同而异。',
    source: '周易·睽卦',
    keywords: ['睽', '火', '泽', '差异', '对立'],
  ),
  ClassicalText(
    content: '睽孤遇元夫，交孚。',
    source: '周易·睽卦',
    keywords: ['睽孤', '元夫', '交孚', '相遇', '信任'],
  ),

  // 蹇卦
  ClassicalText(
    content: '山上有水，蹇。君子以反身修德。',
    source: '周易·蹇卦',
    keywords: ['蹇', '难', '山', '水', '阻碍'],
  ),
  ClassicalText(
    content: '往蹇来誉，宜待也。',
    source: '周易·蹇卦',
    keywords: ['往', '蹇', '誉', '等待', '待时'],
  ),

  // 解卦
  ClassicalText(
    content: '雷雨作，解。君子以赦过宥罪。',
    source: '周易·解卦',
    keywords: ['解', '雷', '雨', '缓解', '释放'],
  ),
  ClassicalText(
    content: '解而拇，朋至斯孚。',
    source: '周易·解卦',
    keywords: ['拇', '朋', '孚', '朋友', '信任'],
  ),

  // 损卦
  ClassicalText(
    content: '山下有泽，损。君子以惩忿窒欲。',
    source: '周易·损卦',
    keywords: ['损', '山', '泽', '减损', '舍弃'],
  ),
  ClassicalText(
    content: '已事遄往，无咎，酌损之。',
    source: '周易·损卦',
    keywords: ['遄往', '酌', '损', '快速', '适量'],
  ),

  // 益卦
  ClassicalText(
    content: '风雷益，君子以见善则迁，有过则改。',
    source: '周易·益卦',
    keywords: ['益', '风', '雷', '增益', '改进'],
  ),
  ClassicalText(
    content: '利用为大作，元吉，无咎。',
    source: '周易·益卦',
    keywords: ['大作', '元吉', '行动', '作为'],
  ),

  // 夬卦
  ClassicalText(
    content: '夬扬于王庭，孚号有厉。',
    source: '周易·夬卦',
    keywords: ['夬', '决', '扬', '王庭', '果断'],
  ),
  ClassicalText(
    content: '无号，终有凶。',
    source: '周易·夬卦',
    keywords: ['号', '凶', '警告', '危险'],
  ),

  // 姤卦
  ClassicalText(
    content: '天下有风，姤。',
    source: '周易·姤卦',
    keywords: ['姤', '风', '天', '相遇', '机遇'],
  ),
  ClassicalText(
    content: '包有鱼，不利宾。',
    source: '周易·姤卦',
    keywords: ['包', '鱼', '宾', '拥有', '控制'],
  ),

  // 萃卦
  ClassicalText(
    content: '泽上于地，萃。君子以除戎器，戒不虞。',
    source: '周易·萃卦',
    keywords: ['萃', '聚', '泽', '地', '聚集'],
  ),
  ClassicalText(
    content: '萃有位，未有应也。',
    source: '周易·萃卦',
    keywords: ['位', '应', '位置', '回应'],
  ),

  // 升卦
  ClassicalText(
    content: '地中生木，升。君子以顺德，积小以高大。',
    source: '周易·升卦',
    keywords: ['升', '木', '地', '上升', '成长'],
  ),
  ClassicalText(
    content: '升虚邑，无所疑也。',
    source: '周易·升卦',
    keywords: ['虚邑', '疑', '上升', '大胆'],
  ),

  // 困卦
  ClassicalText(
    content: '泽无水，困。君子以致命遂志。',
    source: '周易·困卦',
    keywords: ['困', '泽', '无水', '困境', '坚守'],
  ),
  ClassicalText(
    content: '困于石，据于蒺藜。',
    source: '周易·困卦',
    keywords: ['石', '蒺藜', '困境', '阻碍', '艰难'],
  ),

  // 井卦
  ClassicalText(
    content: '木上有水，井。君子以劳民劝相。',
    source: '周易·井卦',
    keywords: ['井', '木', '水', '养', '供给'],
  ),
  ClassicalText(
    content: '井渫不食，为我心恻。',
    source: '周易·井卦',
    keywords: ['渫', '心恻', '井', '清洁', '可惜'],
  ),

  // 革卦
  ClassicalText(
    content: '泽中有火，革。君子以治历明时。',
    source: '周易·革卦',
    keywords: ['革', '泽', '火', '变革', '改革'],
  ),
  ClassicalText(
    content: '巩用黄牛之革。',
    source: '周易·革卦',
    keywords: ['黄牛', '革', '巩固', '稳定'],
  ),

  // 鼎卦
  ClassicalText(
    content: '木上有火，鼎。君子以正位凝命。',
    source: '周易·鼎卦',
    keywords: ['鼎', '木', '火', '重要', '稳定'],
  ),
  ClassicalText(
    content: '鼎黄耳金铉，利贞。',
    source: '周易·鼎卦',
    keywords: ['黄耳', '金铉', '鼎', '尊贵', '稳固'],
  ),

  // 震卦
  ClassicalText(
    content: '洊雷，震。君子以恐惧修省。',
    source: '周易·震卦',
    keywords: ['震', '雷', '惊恐', '警觉', '反省'],
  ),
  ClassicalText(
    content: '震惊百里，不丧匕鬯。',
    source: '周易·震卦',
    keywords: ['震惊', '百里', '匕鬯', '镇定', '从容'],
  ),

  // 艮卦
  ClassicalText(
    content: '兼山，艮。君子以思不出其位。',
    source: '周易·艮卦',
    keywords: ['艮', '山', '止', '静止', '定力'],
  ),
  ClassicalText(
    content: '艮其止，止其所也。',
    source: '周易·艮卦',
    keywords: ['止', '所', '位置', '安分'],
  ),

  // 渐卦
  ClassicalText(
    content: '山上有木，渐。君子以居贤德善俗。',
    source: '周易·渐卦',
    keywords: ['渐', '木', '山', '渐进', '发展'],
  ),
  ClassicalText(
    content: '鸿渐于干，小子厉。',
    source: '周易·渐卦',
    keywords: ['鸿', '干', '渐', '发展', '危险'],
  ),

  // 归妹
  ClassicalText(
    content: '泽上有雷，归妹。君子以永终知敝。',
    source: '周易·归妹卦',
    keywords: ['归妹', '雷', '泽', '归宿', '结合'],
  ),
  ClassicalText(
    content: '归妹愆期，迟归有时。',
    source: '周易·归妹卦',
    keywords: ['愆期', '迟归', '等待', '时机'],
  ),

  // 丰卦
  ClassicalText(
    content: '雷电皆至，丰。君子以折狱致刑。',
    source: '周易·丰卦',
    keywords: ['丰', '雷', '电', '丰盛', '盛大'],
  ),
  ClassicalText(
    content: '丰其蔀，日中见斗。',
    source: '周易·丰卦',
    keywords: ['蔀', '斗', '丰', '遮蔽', '昏暗'],
  ),

  // 旅卦
  ClassicalText(
    content: '山上有火，旅。君子以明慎用刑而不留狱。',
    source: '周易·旅卦',
    keywords: ['旅', '火', '山', '旅行', '漂泊'],
  ),
  ClassicalText(
    content: '旅琐琐，斯其所取灾。',
    source: '周易·旅卦',
    keywords: ['琐琐', '灾', '旅', '小气', '困境'],
  ),

  // 巽卦
  ClassicalText(
    content: '随风，巽。君子以申命行事。',
    source: '周易·巽卦',
    keywords: ['巽', '风', '顺', '服从', '命令'],
  ),
  ClassicalText(
    content: '巽在床下，用史巫纷若，吉无咎。',
    source: '周易·巽卦',
    keywords: ['床下', '史巫', '纷若', '顺从', '虔诚'],
  ),

  // 兑卦
  ClassicalText(
    content: '丽泽，兑。君子以朋友讲习。',
    source: '周易·兑卦',
    keywords: ['兑', '泽', '悦', '朋友', '交流'],
  ),
  ClassicalText(
    content: '来兑，凶。',
    source: '周易·兑卦',
    keywords: ['来兑', '悦', '凶', '诱导'],
  ),

  // 涣卦
  ClassicalText(
    content: '风行水上，涣。君子以享于帝立庙。',
    source: '周易·涣卦',
    keywords: ['涣', '风', '水', '离散', '释放'],
  ),
  ClassicalText(
    content: '用拯马壮，吉。',
    source: '周易·涣卦',
    keywords: ['拯', '马', '壮', '拯救', '帮助'],
  ),

  // 节卦
  ClassicalText(
    content: '泽上有水，节。君子以制数度，议德行。',
    source: '周易·节卦',
    keywords: ['节', '泽', '水', '节制', '约束'],
  ),
  ClassicalText(
    content: '苦节不可贞。',
    source: '周易·节卦',
    keywords: ['苦节', '贞', '过度', '节制'],
  ),

  // 中孚
  ClassicalText(
    content: '泽上有风，中孚。君子以议狱缓死。',
    source: '周易·中孚卦',
    keywords: ['中孚', '风', '泽', '诚信', '信任'],
  ),
  ClassicalText(
    content: '中孚豚鱼吉，利涉大川。',
    source: '周易·中孚卦',
    keywords: ['豚鱼', '吉', '川', '诚信', '真诚'],
  ),

  // 小过
  ClassicalText(
    content: '山上有雷，小过。君子以行过乎恭。',
    source: '周易·小过卦',
    keywords: ['小过', '雷', '山', '小错', '修正'],
  ),
  ClassicalText(
    content: '弗过防之，从或戕之，凶。',
    source: '周易·小过卦',
    keywords: ['过防', '戕', '凶', '防范', '危险'],
  ),

  // 既济
  ClassicalText(
    content: '水在火上，既济。君子以思患而豫防之。',
    source: '周易·既济卦',
    keywords: ['既济', '水', '火', '完成', '成就'],
  ),
  ClassicalText(
    content: '曳其轮，义无咎也。',
    source: '周易·既济卦',
    keywords: ['曳轮', '义', '既济', '控制', '坚守'],
  ),

  // 未济
  ClassicalText(
    content: '火在水上，未济。君子以慎辨物居方。',
    source: '周易·未济卦',
    keywords: ['未济', '火', '水', '未完成', '探索'],
  ),
  ClassicalText(
    content: '未济征凶，利涉大川。',
    source: '周易·未济卦',
    keywords: ['征凶', '川', '未济', '冒险', '尝试'],
  ),

  // 儒家经典
  ClassicalText(
    content: '大学之道，在明明德，在亲民，在止于至善。',
    source: '大学',
    keywords: ['大学', '明德', '亲民', '至善', '修身'],
  ),
  ClassicalText(
    content: '知止而后有定，定而后能静，静而后能安，安而后能虑，虑而后能得。',
    source: '大学',
    keywords: ['知止', '定静安虑得', '修养', '内心', '境界'],
  ),
  ClassicalText(
    content: '君子求诸己，小人求诸人。',
    source: '论语',
    keywords: ['君子', '小人', '求诸己', '求诸人', '自省'],
  ),
  ClassicalText(
    content: '不患无位，患所以立。不患莫已知，求为可知也。',
    source: '论语',
    keywords: ['患', '位', '立', '知', '修养'],
  ),
  ClassicalText(
    content: '子曰：岁寒，然后知松柏之后凋也。',
    source: '论语',
    keywords: ['岁寒', '松柏', '凋', '坚韧', '考验'],
  ),
  ClassicalText(
    content: '君子和而不同，小人同而不和。',
    source: '论语',
    keywords: ['和而不同', '同而不和', '君子', '小人', '和谐'],
  ),
  ClassicalText(
    content: '知之者不如好之者，好之者不如乐之者。',
    source: '论语',
    keywords: ['知之', '好之', '乐之', '兴趣', '境界'],
  ),
  ClassicalText(
    content: '君子坦荡荡，小人长戚戚。',
    source: '论语',
    keywords: ['坦荡荡', '戚戚', '君子', '小人', '心态'],
  ),

  // 道家经典
  ClassicalText(
    content: '道可道，非常道；名可名，非常名。',
    source: '道德经',
    keywords: ['道', '常道', '名', '常名', '玄妙'],
  ),
  ClassicalText(
    content: '上善若水。水善利万物而不争，处众人之所恶，故几于道。',
    source: '道德经',
    keywords: ['上善若水', '不争', '处恶', '道', '智慧'],
  ),
  ClassicalText(
    content: '致虚极，守静笃。万物并作，吾以观复。',
    source: '道德经',
    keywords: ['虚极', '静笃', '观复', '复归', '本质'],
  ),
  ClassicalText(
    content: '知人者智，自知者明。胜人者有力，自胜者强。',
    source: '道德经',
    keywords: ['知人', '自知', '胜人', '自胜', '强大'],
  ),
  ClassicalText(
    content: '大方无隅，大器晚成，大音希声，大象无形。',
    source: '道德经',
    keywords: ['大方无隅', '大器晚成', '大音希声', '大象无形', '境界'],
  ),
  ClassicalText(
    content: '人法地，地法天，天法道，道法自然。',
    source: '道德经',
    keywords: ['人法地', '天法道', '道法自然', '自然', '规律'],
  ),
  ClassicalText(
    content: '反者道之动，弱者道之用。',
    source: '道德经',
    keywords: ['反者道之动', '弱者道之用', '转化', '柔弱', '刚强'],
  ),
  ClassicalText(
    content: '知足不辱，知止不殆，可以长久。',
    source: '道德经',
    keywords: ['知足', '知止', '不辱', '不殆', '长久'],
  ),

  // 其他经典
  ClassicalText(
    content: '天作孽，犹可违；自作孽，不可活。',
    source: '尚书',
    keywords: ['天作孽', '自作孽', '灾祸', '自省', '因果'],
  ),
  ClassicalText(
    content: '苟日新，日日新，又日新。',
    source: '大学',
    keywords: ['苟日新', '日日新', '革新', '进步', '自新'],
  ),
  ClassicalText(
    content: '物有本末，事有终始。知所先后，则近道矣。',
    source: '大学',
    keywords: ['本末', '终始', '先后', '道', '规律'],
  ),
  ClassicalText(
    content: '君子必慎其独也。',
    source: '大学',
    keywords: ['慎独', '君子', '独处', '自律'],
  ),
  ClassicalText(
    content: '富润屋，德润身，心广体胖。',
    source: '大学',
    keywords: ['富润屋', '德润身', '心广体胖', '修养', '品德'],
  ),
  ClassicalText(
    content: '所谓诚其意者，毋自欺也。',
    source: '大学',
    keywords: ['诚其意', '毋自欺', '真诚', '诚实', '自省'],
  ),
  ClassicalText(
    content: '好学近乎知，力行近乎仁，知耻近乎勇。',
    source: '中庸',
    keywords: ['好学', '力行', '知耻', '仁', '勇', '三达德'],
  ),
  ClassicalText(
    content: '博学之，审问之，慎思之，明辨之，笃行之。',
    source: '中庸',
    keywords: ['博学', '审问', '慎思', '明辨', '笃行', '学问'],
  ),
  ClassicalText(
    content: '行有不得者，皆反求诸己。',
    source: '孟子',
    keywords: ['行有不得', '反求诸己', '自省', '内求'],
  ),
  ClassicalText(
    content: '君子以文会友，以友辅仁。',
    source: '论语',
    keywords: ['以文会友', '以友辅仁', '朋友', '仁德'],
  ),
  ClassicalText(
    content: '工欲善其事，必先利其器。',
    source: '论语',
    keywords: ['工欲善其事', '必先利其器', '准备', '工具', '方法'],
  ),
  ClassicalText(
    content: '人无远虑，必有近忧。',
    source: '论语',
    keywords: ['远虑', '近忧', '忧患', '远见', '计划'],
  ),
  ClassicalText(
    content: '己所不欲，勿施于人。',
    source: '论语',
    keywords: ['己所不欲', '勿施于人', '恕道', '推己及人'],
  ),
  ClassicalText(
    content: '见贤思齐焉，见不贤而内自省也。',
    source: '论语',
    keywords: ['见贤思齐', '内自省', '学习', '自省', '榜样'],
  ),
  ClassicalText(
    content: '三人行，必有我师焉。择其善者而从之，其不善者而改之。',
    source: '论语',
    keywords: ['三人行', '有我师', '善者', '不善者', '学习'],
  ),
  ClassicalText(
    content: '其身正，不令而行；其身不正，虽令不从。',
    source: '论语',
    keywords: ['身正', '令行', '身不正', '不从', '领导', '榜样'],
  ),
  ClassicalText(
    content: '知之者不如好之者，好之者不如乐之者。',
    source: '论语',
    keywords: ['知之', '好之', '乐之', '兴趣', '学习'],
  ),
  ClassicalText(
    content: '无欲则刚。',
    source: '论语',
    keywords: ['无欲则刚', '刚', '欲望', '坚韧', '正直'],
  ),
  ClassicalText(
    content: '君子成人之美，不成人之恶。',
    source: '论语',
    keywords: ['成人之美', '成人之恶', '君子', '帮助', '善恶'],
  ),
  ClassicalText(
    content: '不在其位，不谋其政。',
    source: '论语',
    keywords: ['不在其位', '不谋其政', '本分', '责任', '界限'],
  ),
];

/// 根据关键词检索古典文本
List<ClassicalText> searchClassicalTexts(List<String> keywords) {
  if (keywords.isEmpty) return [];

  final results = <ClassicalText>[];
  final keywordSet = keywords.map((k) => k.toLowerCase()).toSet();

  for (final text in classicalTexts) {
    for (final keyword in keywordSet) {
      for (final textKeyword in text.keywords) {
        if (textKeyword.toLowerCase().contains(keyword) ||
            keyword.contains(textKeyword.toLowerCase())) {
          results.add(text);
          break;
        }
      }
    }
  }

  // 去重并返回前3条
  return results.toSet().take(3).toList();
}
