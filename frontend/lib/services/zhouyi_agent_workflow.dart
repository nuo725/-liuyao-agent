import '../agent/domain/cultural_quote.dart';
import '../agent/domain/direction_profile.dart';
import '../agent/domain/psychology_response_principle.dart';
import '../agent/repositories/cultural_quote_repository.dart';
import '../agent/repositories/psychology_response_principles.dart';
import '../agent/repositories/ritual_direction_profiles.dart';
import '../models/pattern.dart';
import 'web_search_service.dart';

class WorkflowContext {
  final DirectionProfile direction;
  final CulturalQuote quote;
  final List<PsychologyResponsePrinciple> principles;
  final List<String> searchSnippets;
  final String lineCode;
  final String structureDigest;

  const WorkflowContext({
    required this.direction,
    required this.quote,
    required this.principles,
    this.searchSnippets = const [],
    required this.lineCode,
    required this.structureDigest,
  });
}

/// Workflow order:
/// 1) 6-line pattern -> stable direction_profile
/// 2) direction_profile -> local verified quote + psych principles
/// 3) optional web snippets as supplement only (never main driver)
class ZhouyiAgentWorkflow {
  final RitualDirectionProfilesRepository _directionRepository;
  final CulturalQuoteRepository _quoteRepository;
  final PsychologyResponsePrinciplesRepository _psychRepository;
  final WebSearchService _searchService;

  ZhouyiAgentWorkflow({
    RitualDirectionProfilesRepository directionRepository =
        const RitualDirectionProfilesRepository(),
    CulturalQuoteRepository quoteRepository = const CulturalQuoteRepository(),
    PsychologyResponsePrinciplesRepository psychRepository =
        const PsychologyResponsePrinciplesRepository(),
    WebSearchService? searchService,
  }) : _directionRepository = directionRepository,
       _quoteRepository = quoteRepository,
       _psychRepository = psychRepository,
       _searchService = searchService ?? webSearchServiceProvider;

  Future<WorkflowContext> buildInitialContext({
    required Pattern pattern,
    required String question,
    bool enableSearch = true,
  }) async {
    final normalized = _normalizeLines(pattern.lines);
    final direction = _directionRepository.resolveByLines(pattern.lines);
    final structureDigest = _buildStructureDigest(normalized, direction);
    final principles = _psychRepository.selectForDirection(
      profile: direction,
      userText: question,
      isFollowup: false,
    );

    final searchSnippets = enableSearch
        ? await _searchSupplement(direction: direction, question: question)
        : const <String>[];

    final quote = _quoteRepository.pickForDirection(
      profile: direction,
      userQuestion: question,
      searchSnippets: searchSnippets,
    );

    return WorkflowContext(
      direction: direction,
      quote: quote,
      principles: principles,
      searchSnippets: searchSnippets,
      lineCode: normalized.join(),
      structureDigest: structureDigest,
    );
  }

  Future<WorkflowContext> buildFollowupContext({
    required Pattern pattern,
    required String rootQuestion,
    required String followupQuestion,
    bool enableSearch = true,
  }) async {
    final normalized = _normalizeLines(pattern.lines);
    final direction = _directionRepository.resolveByLines(pattern.lines);
    final structureDigest = _buildStructureDigest(normalized, direction);
    final principles = _psychRepository.selectForDirection(
      profile: direction,
      userText: followupQuestion,
      isFollowup: true,
    );

    final searchSnippets = enableSearch
        ? await _searchSupplement(
            direction: direction,
            question: '$rootQuestion $followupQuestion',
          )
        : const <String>[];

    final quote = _quoteRepository.pickForDirection(
      profile: direction,
      userQuestion: followupQuestion,
      searchSnippets: searchSnippets,
    );

    return WorkflowContext(
      direction: direction,
      quote: quote,
      principles: principles,
      searchSnippets: searchSnippets,
      lineCode: normalized.join(),
      structureDigest: structureDigest,
    );
  }

  Future<List<String>> _searchSupplement({
    required DirectionProfile direction,
    required String question,
  }) async {
    final intentCue = _inferIntentCue(question);
    final query = [
      direction.hexagramName,
      direction.stateName,
      direction.upperTrigram,
      direction.lowerTrigram,
      intentCue,
      question,
      '古文 原句 出处',
    ].where((e) => e.trim().isNotEmpty).join(' ');

    if (query.trim().isEmpty) return const [];

    try {
      final result = await _searchService.search(query: query, maxResults: 3);
      return result.take(3).toList();
    } catch (_) {
      return const [];
    }
  }

  String _inferIntentCue(String question) {
    final q = question.trim();
    if (RegExp(r'(关系|感情|喜欢|分手|复合|想她|想他|暧昧|失恋)').hasMatch(q)) {
      return '关系 思念 离别 诗词';
    }
    if (RegExp(r'(工作|职业|离职|同事|老板|项目|晋升)').hasMatch(q)) {
      return '节奏 取舍 进退 古文';
    }
    if (RegExp(r'(钱|财务|负债|投资|还款|现金流)').hasMatch(q)) {
      return '节用 止损 持守 箴言';
    }
    if (RegExp(r'(焦虑|疲惫|内耗|压抑|崩溃|迷茫)').hasMatch(q)) {
      return '安住 修身 节奏 古文';
    }
    return '修身 观照 古文';
  }

  List<int> _normalizeLines(List<int> lines) {
    final out = List<int>.filled(6, 0);
    for (int i = 0; i < 6; i++) {
      out[i] = (i < lines.length && lines[i] > 0) ? 1 : 0;
    }
    return out;
  }

  String _buildStructureDigest(List<int> lines, DirectionProfile direction) {
    final lower = lines.sublist(0, 3);
    final upper = lines.sublist(3, 6);
    final lowerYang = lower.where((e) => e == 1).length;
    final upperYang = upper.where((e) => e == 1).length;

    final pivotLines = <int>[];
    for (int i = 1; i < lines.length; i++) {
      if (lines[i] != lines[i - 1]) {
        pivotLines.add(i + 1);
      }
    }

    final lowerTone = lowerYang >= 2 ? '下段更偏主动承接' : '下段更偏稳住与观察';
    final upperTone = upperYang >= 2 ? '上段有外推与表达' : '上段更倾向收束与回看';

    final pivotText = pivotLines.isEmpty
        ? '节奏相对连贯，变化点不多。'
        : '变化集中在第${pivotLines.join('、')}段，说明内外在不断换挡。';

    final shape = lines
        .map((e) => e == 1 ? '实' : '虚')
        .toList(growable: false)
        .join(' / ');

    return '''
这次六段结构落在「${direction.hexagramName}」，上${direction.upperTrigram}下${direction.lowerTrigram}。
六段气势：$shape。
$lowerTone；$upperTone。
$pivotText
当前更贴近「${direction.stateName}」：${direction.stateSummary}
'''
        .trim();
  }
}
