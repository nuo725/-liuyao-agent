class RitualCopy {
  const RitualCopy._();

  static const String askTitle = '问一问';
  static const String askHint = '请尽量清晰描述你的问题，我们先把感受放在当下。';
  static const String askInputHint = '例如：我该继续这份工作，还是先停一停？';
  static const String askCategoryTitle = '问题分类';
  static const String simulationTitle = '模拟模式';
  static const String simulationSuccess = '成功';
  static const String simulationDelayed = '延迟';
  static const String simulationTimeout = '超时';
  static const String simulationError = '错误';
  static const String simulationRetryRecovery = '重试恢复';
  static const String simulationHint = '仅用于 UI 演示与测试，不接真实后端。';
  static const String askSubmit = '开始起卦';
  static const String back = '返回';

  static const String categoryRelationship = '关系';
  static const String categoryCareer = '事业';
  static const String categoryEmotion = '情绪';
  static const String categoryChoice = '选择';
  static const String categoryOther = '其他';

  static const String calibrationPrompt = '你现在的感受更接近哪一种？';
  static const String calibrationCustom = '自定义';
  static const String calibrationInputHint = '写下你此刻的感受...';

  static const String responseTitle = '继续深谈';
  static const String responsePreparing = '正在生成回应...';
  static const String responseErrorTitle = '解读暂时不可用';
  static const String responseRestart = '重新开始仪式';
  static const String responseBack = '返回上一页';
  static const String responseFollowupHint = '输入你的追问...';
  static const String responseLimitReached = '本轮追问次数已用完，请重新开始新的仪式。';

  static const String loginRequiredTitle = '继续追问需要登录';
  static const String loginRequiredSubtitle = '你可以先体验核心流程，登录后再继续追问。';

  static const String mockQuestionA = '最近工作压力太大，我有点撑不住';
  static const String mockAnswerA = '你现在更像处在“旧结构失效、新方向未明”的过渡阶段。先别急着做二选一，先做一件能立刻减压的小动作，把节奏稳住。';
  static const String mockQuestionB = '我总觉得自己做得不够好';
  static const String mockAnswerB = '这更像是内在苛责，而不是客观结论。把“完美”改成“推进一点点”，今天完成一个最小行动，先重建对自己的信任。';
  static const String mockQuestionC = '我想安静下来，但总在被外界拉走';
  static const String mockAnswerC = '身体在要休息，头脑在要刺激，这是边界疲惫时的常见冲突。先给自己一段短暂安静，再决定是否继续投入外界。';
  static const String mockQuestionD = '关系里我总在付出，却很少被回应';
  static const String mockAnswerD = '过度付出常常来自“通过努力换安全感”。关键不是别人是否立刻回报，而是你是否允许关系回到平衡：这周设一个边界，并提出一个明确需求。';

  static const String followupA = '我现在可以先从哪一步开始？';
  static const String followupB = '这种感受是从什么时候开始的？';
  static const String followupC = '我过去有什么经验是有效的？';
}
