import '../domain/cultural_quote.dart';
import '../domain/direction_profile.dart';
import '../domain/psychology_response_principle.dart';

class AgentModelPromptPlan {
  final String systemPrompt;
  final String userPrompt;

  const AgentModelPromptPlan({
    required this.systemPrompt,
    required this.userPrompt,
  });
}

class AgentPromptBuilder {
  const AgentPromptBuilder();

  AgentModelPromptPlan buildInitialPlan({
    required String question,
    required DirectionProfile direction,
    required String lineCode,
    required String structureDigest,
    required CulturalQuote quote,
    required List<PsychologyResponsePrinciple> principles,
    required List<String> searchSnippets,
  }) {
    final systemPrompt = _buildSystemPrompt(isFollowup: false);
    final userPrompt = '''
【用户问题】
$question

【结构方向（已确定，不可改写）】
- directionId: ${direction.directionId}
- hexagramName: ${direction.hexagramName}
- stateName: ${direction.stateName}
- theme: ${direction.theme}
- coreTension: ${direction.coreTension}
- stateSummary: ${direction.stateSummary}
- responseMode: ${direction.responseMode}
- avoid: ${direction.avoid.join(' / ')}
- bestForInnerTensions: ${direction.bestForInnerTensions.join(' / ')}
- avoidEmphasis: ${direction.avoidEmphasis.join(' / ')}
- guaCi: ${direction.guaCi}
- xiangCi: ${direction.xiangCi}
- lineRule: ${direction.lineRule}

【六段结构摘要】
- lineCode: $lineCode
- structureDigest: $structureDigest

【文化素材（首选本地 verified）】
- quote: ${quote.text}
- source: ${quote.source}
- tags: ${quote.tags.join(' / ')}
- tone: ${quote.tone}

【心理回应原则（轻量）】
${_formatPrinciples(principles)}

【搜索校准（仅辅助）】
${_formatSearch(searchSnippets)}

【输出要求】
1. 第一段必须是“结构解读”，让用户明确感到回应来自刚才六段结果。
2. 第二段再进行情绪承接与现代转译。
3. 至少包含一句真实传统文化原句（优先使用给定 quote）。
4. followups 必须是第一人称、具体、可问出口的短句。
5. 输出必须是 JSON，不要 markdown，不要代码块，不要解释。

JSON schema:
{
  "body": "两段式正文",
  "quote": {"text": "原句", "source": "出处"},
  "followups": ["第一人称追问1", "第一人称追问2"],
  "blocks": [
    {"icon":"anchor","title":"状态锚点","text":"..."},
    {"icon":"insight","title":"内在张力","text":"..."},
    {"icon":"action","title":"此刻可做","text":"..."}
  ],
  "meta": {"tone":"温和克制","mode":"${direction.responseMode}"}
}
''';

    return AgentModelPromptPlan(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
    );
  }

  AgentModelPromptPlan buildFollowupPlan({
    required String rootQuestion,
    required String followupQuestion,
    required DirectionProfile direction,
    required String structureDigest,
    required CulturalQuote quote,
    required List<PsychologyResponsePrinciple> principles,
    required List<String> historyTurns,
    required List<String> searchSnippets,
  }) {
    final systemPrompt = _buildSystemPrompt(isFollowup: true);
    final userPrompt = '''
【主问题】
$rootQuestion

【本轮追问】
$followupQuestion

【对话上下文】
${_formatHistory(historyTurns)}

【结构方向（固定）】
- directionId: ${direction.directionId}
- hexagramName: ${direction.hexagramName}
- stateName: ${direction.stateName}
- coreTension: ${direction.coreTension}
- responseMode: ${direction.responseMode}
- avoid: ${direction.avoid.join(' / ')}
- structureDigest: $structureDigest

【文化素材（可选复用，不强制每轮都引）】
- ${quote.text}（${quote.source}）

【心理回应原则】
${_formatPrinciples(principles)}

【搜索校准（仅辅助）】
${_formatSearch(searchSnippets)}

【输出要求】
1. 接住用户本轮追问，不重开完整首轮。
2. 给一个新的观察角度，并留继续空间。
3. followups 仍用第一人称，避免空泛。
4. 输出 JSON，不要 markdown。

JSON schema:
{
  "body": "追问回复正文",
  "followups": ["第一人称追问1", "第一人称追问2"],
  "blocks": [
    {"icon":"insight","title":"新的观察","text":"..."},
    {"icon":"action","title":"继续入口","text":"..."}
  ],
  "meta": {"stage":"followup","mode":"${direction.responseMode}"}
}
''';

    return AgentModelPromptPlan(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
    );
  }

  String _buildSystemPrompt({required bool isFollowup}) {
    final stage = isFollowup ? '追问阶段' : '首轮阶段';
    return '''
你是“结构结果的传统文化转译者”，不是算命师、不是心理咨询师、不是现实决策替代者。
当前是$stage。

硬边界：
1) 不预测未来，不给时间点承诺。
2) 不做“该/不该、会/不会”裁决。
3) 不替用户做重大现实决策。
4) 不制造宿命感、恐惧感。
5) 不输出“六爻、卦、爻、起卦、解卦、吉凶、运势、卜卦”等术语。
6) 结构方向已由工作流确定，你不能改写方向。
7) 搜索结果只可校准素材，不可主导结论。

写作要求：
- 温和、克制、有留白。
- 语言自然，不模板化，不鸡汤，不论文体。
- 保证可读性与具体性，追问句必须可直接点击使用。
''';
  }

  String _formatPrinciples(List<PsychologyResponsePrinciple> principles) {
    if (principles.isEmpty) return '- 无';
    return principles
        .map(
          (e) =>
              '- ${e.name}: ${e.guideline}；avoidEscalation: ${e.avoidEscalation.join(' / ')}',
        )
        .join('\n');
  }

  String _formatSearch(List<String> snippets) {
    if (snippets.isEmpty) return '- 无';
    return snippets.map((e) => '- $e').join('\n');
  }

  String _formatHistory(List<String> historyTurns) {
    if (historyTurns.isEmpty) return '- 无';
    return historyTurns.map((e) => '- $e').join('\n');
  }
}
