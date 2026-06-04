import '../models/interpretation_card.dart';
import '../models/pattern.dart';
import 'package:flutter/foundation.dart';
import 'liuyao_agent_service.dart';

void _dlog(String message) {
  if (kDebugMode) debugPrint(message);
}

/// 解读服务接口
/// 接入独立 Agent 时实现此接口
abstract class InterpretationService {
  Future<InterpretationCard> generateInterpretation({
    required String question,
    QuestionTag? tag,
    required Pattern pattern,
    required RiskLevel riskLevel,
    String? userId,
  });

  Stream<String> streamInterpretation({
    required String question,
    QuestionTag? tag,
    required Pattern pattern,
    required RiskLevel riskLevel,
  });
}

/// Liuyao Agent 解读服务实现
class LiuyaoInterpretationServiceImpl implements InterpretationService {
  final LiuyaoAgentApiService _api;

  LiuyaoInterpretationServiceImpl({LiuyaoAgentApiService? api})
    : _api = api ?? LiuyaoAgentApiService();

  @override
  Future<InterpretationCard> generateInterpretation({
    required String question,
    QuestionTag? tag,
    required Pattern pattern,
    required RiskLevel riskLevel,
    String? userId,
  }) async {
    try {
      // TODO(Backend Integration)[ritual_api#start]: 接入正式仪式后端后保留当前 fallback 兜底策略
      _dlog('[LiuyaoAgent] Calling _api.startChat...');
      final response = await _api.startChat(
        question: question,
        lines: pattern.lines,
        movingLines: _extractMovingLines(pattern),
      );

      _dlog('[LiuyaoAgent] startChat response received');
      _dlog('  mode: ${response.mode}');
      _dlog('  needsClarification: ${response.needsClarification}');
      _dlog('  session.sessionId: ${response.session?.sessionId}');
      final replyText = response.reply.text;
      final preview =
          replyText.length > 50 ? '${replyText.substring(0, 50)}...' : replyText;
      _dlog('  reply.text: $preview');

      return _buildCard(response, question, tag, pattern, riskLevel, userId);
    } catch (e, st) {
      _dlog('[LiuyaoAgent] Error in generateInterpretation: $e');
      _dlog('[LiuyaoAgent] Stack trace: $st');
      // API 不可用时降级返回 mock 数据，确保 UI 阶段流程正常
      return _buildMockCard(
        question: question,
        tag: tag,
        pattern: pattern,
        riskLevel: riskLevel,
        userId: userId,
      );
    }
  }

  InterpretationCard _buildMockCard({
    required String question,
    QuestionTag? tag,
    required Pattern pattern,
    RiskLevel riskLevel = RiskLevel.low,
    String? userId,
  }) {
    const pool = [
      '听起来你正处于一个内在张力逐渐积累的时刻——旧的结构已经无法容纳新的渴望，但新的方向又尚未清晰。这种「悬而未决」的状态本身就是一种真实的生命节奏，不必急于将它压成确定的选择。或许可以先不问「该不该」，而是问问自己：此刻让我感到最沉重的是什么？',
      '你描述的这种状态——内在有一个苛责的声音，时刻在评判「还不够好」——其实是高敏感人群常见的心理模式。这不是软弱，而是一种对生命质量的深层要求，只是它暂时失去了与现实之间的弹性。「不敢开始」的背后往往是害怕那个声音说「你看，果然不行」。但当你允许自己以一个「正在探索的人」而非「必须成功的人」的身份开始时，那个声音的重量会自然减轻。',
      '这个矛盾本身就很有意味：你的身体说「我需要静」，但有一层更表层的念头说「我应该热闹」。这种冲突常常发生在我们开始真正倾听自己的时候——因为真正的声音一旦出现，那个社会性的「应该」就会更明显。假期的热闹是外给的，假日的独处是内生的。没有哪个选择是「应该」的，但当你选择跟随身体真正的渴望时，那种选择的重量感会不同。',
      '「付出更多」的模式，往往不是因为对方真的要求那么多，而是我们在早年学会了用付出换取安全感。这个模式的顽固之处在于：它既让我们疲惫，又让我们感到「如果我不付出，就不值得被爱」的恐惧。不公平感是一个信号，它在说「我把自己放在了一个不平等的位置上」。真正的问题不是「对方是否回报」，而是「我是否允许自己在关系中也成为可以被照顾的一方」。',
    ];
    final body = pool[question.hashCode.abs() % pool.length];
    return InterpretationCard(
      id: 'mock-${DateTime.now().millisecondsSinceEpoch}',
      question: question,
      tag: tag,
      pattern: pattern,
      riskLevel: riskLevel,
      createdAt: DateTime.now(),
      authorId: userId,
      content: InterpretationContent(
        summary: body,
        focusPoints: const [],
        afterglow: '',
        followupDirections: const [
          '我可以从哪里开始？',
          '这种感受是从什么时候开始的？',
          '有没有类似经历曾经让我感到不同？',
        ],
        body: body,
        quoteText: null,
        quoteSource: null,
        visualBlocks: const [],
      ),
      needsClarification: false,
    );
  }

  @override
  Stream<String> streamInterpretation({
    required String question,
    QuestionTag? tag,
    required Pattern pattern,
    required RiskLevel riskLevel,
  }) async* {
    final card = await generateInterpretation(
      question: question,
      tag: tag,
      pattern: pattern,
      riskLevel: riskLevel,
    );
    final text = (card.content.body ?? card.content.summary).trim();
    for (final rune in text.runes) {
      await Future.delayed(const Duration(milliseconds: 30));
      yield String.fromCharCode(rune);
    }
  }

  InterpretationCard _buildCard(
    StartChatResponse response,
    String question,
    QuestionTag? tag,
    Pattern pattern,
    RiskLevel riskLevel,
    String? userId,
  ) {
    final blocks = <ResponseVisualBlock>[];

    // 如果需要澄清，只返回回复文本，不建立会话
    if (response.needsClarification) {
      return InterpretationCard(
        id: 'clarification-${DateTime.now().millisecondsSinceEpoch}',
        question: question,
        tag: tag,
        pattern: pattern,
        riskLevel: riskLevel,
        createdAt: DateTime.now(),
        authorId: userId,
        content: InterpretationContent(
          summary: '需要澄清',
          focusPoints: [],
          afterglow: '',
          followupDirections: [],
          body: response.reply.text,
          quoteText: null,
          quoteSource: null,
          visualBlocks: blocks,
        ),
        // 标记为需要澄清，不建立会话
        needsClarification: true,
      );
    }

    // 正常模式，组装完整卡片
    final summary = response.summary;
    if (summary != null) {
      final original = summary.originalHexagram;
      final changed = summary.changedHexagram;

      blocks.add(
        ResponseVisualBlock(
          icon: 'hexagram',
          title: '本卦',
          text: original != null ? '${original.symbol} ${original.name}' : '未知',
        ),
      );

      if (changed != null) {
        blocks.add(
          ResponseVisualBlock(
            icon: 'changed',
            title: '变卦',
            text: '${changed.symbol} ${changed.name}',
          ),
        );
      }

      if (summary.movingLines.isNotEmpty) {
        blocks.add(
          ResponseVisualBlock(
            icon: 'moving',
            title: '动爻',
            text: summary.movingLines.map((i) => '第${i}爻').join('、'),
          ),
        );
      }
    }

    // 使用 API 返回的 sessionId
    final sessionId =
        response.session?.sessionId ??
        'session-${DateTime.now().millisecondsSinceEpoch}';

    return InterpretationCard(
      id: sessionId,
      question: question,
      tag: tag,
      pattern: pattern,
      riskLevel: riskLevel,
      createdAt: DateTime.now(),
      authorId: userId,
      content: InterpretationContent(
        summary: response.reply.text,
        focusPoints: [],
        afterglow: '',
        followupDirections: [],
        body: response.reply.text,
        quoteText: null,
        quoteSource: null,
        visualBlocks: blocks,
      ),
      // 标记为不需要澄清，可以追问
      needsClarification: false,
    );
  }

  List<int> _extractMovingLines(Pattern pattern) {
    return pattern.movingLines;
  }
}

final interpretationServiceProvider = LiuyaoInterpretationServiceImpl();
