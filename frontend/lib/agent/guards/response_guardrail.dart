import 'dart:convert';

import '../domain/agent_response_payload.dart';
import '../domain/cultural_quote.dart';
import '../domain/direction_profile.dart';
import '../domain/psychology_response_principle.dart';

class AgentResponseGuardrail {
  const AgentResponseGuardrail();

  AgentResponsePayload sanitizeInitial({
    required String raw,
    required String userQuestion,
    required DirectionProfile direction,
    required String structureDigest,
    required CulturalQuote quote,
    required List<PsychologyResponsePrinciple> principles,
  }) {
    final parsed = _parsePayload(raw);

    var body = _cleanText(_extractBodyCandidate(parsed?.body ?? raw));
    if (body.isEmpty || _looksLikeTransportError(body)) {
      body = _initialFallback(
        direction: direction,
        structureDigest: structureDigest,
        quote: quote,
        principles: principles,
      );
    }

    final outQuote = parsed?.quote ??
        AgentQuote(
          text: quote.text,
          source: quote.source,
        );

    body = _ensureTwoStageBody(
      body: body,
      structureDigest: structureDigest,
      direction: direction,
    );

    final followups = _normalizeFollowups(
      parsed?.followups,
      direction.followupCandidates,
      seedQuestion: userQuestion,
    );

    final blocks = _sanitizeBlocks(
      parsed?.blocks,
      fallback: _defaultInitialBlocks(direction, principles),
      maxCount: 4,
    );

    return AgentResponsePayload(
      body: body,
      quote: AgentQuote(
        text: _cleanText(outQuote.text),
        source: _cleanText(outQuote.source),
      ),
      followups: followups,
      blocks: blocks,
      meta: {
        ...?parsed?.meta,
        'directionId': direction.directionId,
        'stateName': direction.stateName,
        'hexagramName': direction.hexagramName,
      },
    );
  }

  AgentResponsePayload sanitizeFollowup({
    required String raw,
    required String followupQuestion,
    required DirectionProfile direction,
    required List<PsychologyResponsePrinciple> principles,
  }) {
    final parsed = _parsePayload(raw);

    var body = _cleanText(_extractBodyCandidate(parsed?.body ?? raw));
    if (body.isEmpty || _looksLikeTransportError(body)) {
      body = _followupFallback(direction, principles);
    }

    final followups = _normalizeFollowups(
      parsed?.followups,
      direction.followupCandidates,
      seedQuestion: followupQuestion,
    );

    final blocks = _sanitizeBlocks(
      parsed?.blocks,
      fallback: _defaultFollowupBlocks(direction, principles),
      maxCount: 3,
    );

    return AgentResponsePayload(
      body: body,
      followups: followups,
      blocks: blocks,
      meta: {
        ...?parsed?.meta,
        'directionId': direction.directionId,
        'stateName': direction.stateName,
        'stage': 'followup',
      },
    );
  }

  AgentResponsePayload? _parsePayload(String raw) {
    final cleaned = _stripCodeFence(raw).trim();
    final map = _tryParseJson(cleaned) ?? _tryParseJson(_extractJsonObject(cleaned));
    if (map == null) return null;
    return AgentResponsePayload.fromJson(map);
  }

  String _extractBodyCandidate(String raw) {
    dynamic current = raw;
    for (int i = 0; i < 4; i++) {
      if (current is String) {
        final text = _stripCodeFence(current).trim();
        final map = _tryParseJson(text) ?? _tryParseJson(_extractJsonObject(text));
        if (map == null) return text;
        current = map['body'] ?? map['summary'] ?? map['content'] ?? map['text'] ?? map['message'] ?? '';
      } else if (current is Map) {
        final map = Map<String, dynamic>.from(current);
        current = map['body'] ?? map['summary'] ?? map['content'] ?? map['text'] ?? map['message'] ?? '';
      } else {
        break;
      }
    }
    return current.toString();
  }

  Map<String, dynamic>? _tryParseJson(String text) {
    if (text.isEmpty) return null;
    try {
      final obj = jsonDecode(text);
      if (obj is Map<String, dynamic>) return obj;
      if (obj is Map) return Map<String, dynamic>.from(obj);
    } catch (_) {}
    return null;
  }

  String _extractJsonObject(String text) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) return '';
    return text.substring(start, end + 1);
  }

  String _stripCodeFence(String text) {
    var out = text.trim();
    out = out.replaceAll(RegExp(r'^```(?:json)?\s*', multiLine: true), '');
    out = out.replaceAll(RegExp(r'```$', multiLine: true), '');
    return out.trim();
  }

  String _cleanText(String text) {
    var out = _stripCodeFence(text).trim();
    out = _stripEmbeddedPayload(out);
    out = out.replaceAll(RegExp(r'\bjson\b', caseSensitive: false), '');
    out = out.replaceAll('\r', '');
    out = out.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    out = out.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
    return out.trim();
  }

  String _stripEmbeddedPayload(String text) {
    var out = text;
    for (int i = 0; i < 4; i++) {
      final map = _tryParseJson(out) ?? _tryParseJson(_extractJsonObject(out));
      if (map == null) break;
      final nested = map['body'] ?? map['summary'] ?? map['content'] ?? map['text'];
      if (nested is String && nested.trim().isNotEmpty) {
        out = nested.trim();
        continue;
      }
      break;
    }
    return out;
  }

  String _ensureTwoStageBody({
    required String body,
    required String structureDigest,
    required DirectionProfile direction,
  }) {
    final cleaned = body.trim();
    final hasStructure = cleaned.contains('结构解读');
    final hasResponse = cleaned.contains('当下回应');
    if (hasStructure && hasResponse) return cleaned;

    return '''
结构解读
$structureDigest

当下回应
$cleaned
'''.trim();
  }

  List<String> _normalizeFollowups(
    List<String>? modelFollowups,
    List<String> fallback, {
    required String seedQuestion,
  }) {
    final pool = (modelFollowups ?? const <String>[])
        .map(_cleanText)
        .where((e) => e.isNotEmpty)
        .toList();

    final out = <String>[];
    for (final item in [...pool, ...fallback]) {
      final q = _toFirstPersonQuestion(item);
      if (q.isEmpty || out.contains(q)) continue;
      out.add(q);
      if (out.length >= 3) break;
    }

    if (out.isEmpty) {
      return const [
        '我现在最该先稳住什么？',
        '我下一步先做哪件最小的事？',
      ];
    }
    return out;
  }

  String _toFirstPersonQuestion(String text) {
    var out = text.trim();
    if (out.isEmpty) return '';

    out = out
        .replaceFirst(RegExp(r'^(你是否|是否|有没有|能否)'), '我是否')
        .replaceFirst(RegExp(r'^(你现在|你可以)'), '我现在');

    if (!out.endsWith('？') && !out.endsWith('?')) {
      out = '$out？';
    }
    return _cleanText(out);
  }

  List<AgentVisualBlockPayload> _sanitizeBlocks(
    List<AgentVisualBlockPayload>? blocks, {
    required List<AgentVisualBlockPayload> fallback,
    required int maxCount,
  }) {
    final allowedIcons = {
      'anchor',
      'insight',
      'balance',
      'action',
      'pause',
      'boundary',
      'spark',
    };

    final raw = (blocks == null || blocks.isEmpty) ? fallback : blocks;
    final out = raw
        .map(
          (e) => AgentVisualBlockPayload(
            icon: allowedIcons.contains(e.icon) ? e.icon : 'insight',
            title: _cleanText(e.title),
            text: _cleanText(e.text),
          ),
        )
        .where((e) => e.title.isNotEmpty && e.text.isNotEmpty)
        .take(maxCount)
        .toList();

    return out.isEmpty ? fallback.take(maxCount).toList() : out;
  }

  List<AgentVisualBlockPayload> _defaultInitialBlocks(
    DirectionProfile direction,
    List<PsychologyResponsePrinciple> principles,
  ) {
    final principle = principles.firstOrNull;
    return [
      AgentVisualBlockPayload(
        icon: 'anchor',
        title: '状态锚点',
        text: direction.stateName,
      ),
      AgentVisualBlockPayload(
        icon: 'insight',
        title: '内在张力',
        text: direction.coreTension,
      ),
      AgentVisualBlockPayload(
        icon: 'action',
        title: '此刻可做',
        text: principle?.microPrompts.firstOrNull ?? '先把动作缩到一个可执行的小步。',
      ),
    ];
  }

  List<AgentVisualBlockPayload> _defaultFollowupBlocks(
    DirectionProfile direction,
    List<PsychologyResponsePrinciple> principles,
  ) {
    final principle = principles.firstOrNull;
    return [
      AgentVisualBlockPayload(
        icon: 'insight',
        title: '新的观察',
        text: direction.stateSummary,
      ),
      AgentVisualBlockPayload(
        icon: 'action',
        title: '继续入口',
        text: principle?.microPrompts.firstOrNull ?? '先选一个你现在愿意开始的小动作。',
      ),
    ];
  }

  String _initialFallback({
    required DirectionProfile direction,
    required String structureDigest,
    required CulturalQuote quote,
    required List<PsychologyResponsePrinciple> principles,
  }) {
    final guideline = principles.firstOrNull?.guideline ?? '先承接，再推进。';
    return '''
结构解读
$structureDigest

当下回应
你当前更接近「${direction.stateName}」，不用急着下结论。先把心绪和节奏安放好，再决定下一步。
“${quote.text}”——${quote.source}
$guideline
'''.trim();
  }

  String _followupFallback(
    DirectionProfile direction,
    List<PsychologyResponsePrinciple> principles,
  ) {
    final prompt = principles.firstOrNull?.microPrompts.firstOrNull ?? '你愿意先稳住哪一块？';
    return '''
你这句追问很关键。沿着「${direction.stateName}」继续看，现在更适合先把问题缩小到一个可观察点。

可以先从这句开始：$prompt
'''.trim();
  }

  bool _looksLikeTransportError(String text) {
    final t = text.toLowerCase();
    return t.startsWith('网络错误') ||
        t.startsWith('解析失败') ||
        t.contains('status code') ||
        t.contains('timeout');
  }
}

extension _FirstOrNullExt<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
