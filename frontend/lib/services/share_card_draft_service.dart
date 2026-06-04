import '../models/interpretation_card.dart';

enum ShareCardDraftStyle {
  concise('精简', '短句卡片，信息密度高'),
  poetic('诗意', '更有留白和意象感'),
  practical('行动', '更强调可落地的一步'),
  social('社交', '更适合发布到社群/朋友圈');

  final String label;
  final String description;
  const ShareCardDraftStyle(this.label, this.description);
}

class ShareCardDraftService {
  Future<String> generateDraft({
    required InterpretationCard card,
    required ShareCardDraftStyle style,
    String customPrompt = '',
  }) async {
    // 使用本地 fallback 生成分享文案
    return buildFallbackDraft(
      card: card,
      style: style,
      customPrompt: customPrompt,
    );
  }

  String buildFallbackDraft({
    required InterpretationCard card,
    required ShareCardDraftStyle style,
    String customPrompt = '',
  }) {
    final body = _normalizeBody(card.content.body ?? card.content.toPlainText());
    final structure = card.content.summary.trim();
    final quote = card.content.quoteText?.trim() ?? '';
    final source = card.content.quoteSource?.trim() ?? '';

    final conciseBody = _truncateByLength(_firstParagraph(body), maxChars: 120);
    final conciseStructure = _truncateByLength(
      structure.replaceAll('\n', '，').trim(),
      maxChars: 72,
    );

    final styleLead = switch (style) {
      ShareCardDraftStyle.concise => '这次我更看清了自己的节奏。',
      ShareCardDraftStyle.poetic => '风没有停，我先把心安放好。',
      ShareCardDraftStyle.practical => '先稳住，再推进，今天只做一步。',
      ShareCardDraftStyle.social => '给今天留一条轻一点的注脚。',
    };

    final promptLine = customPrompt.trim().isEmpty
        ? ''
        : '\n我想把重点放在：${_truncateByLength(customPrompt.trim(), maxChars: 34)}';
    final quoteLine = quote.isEmpty ? '' : '\n"$quote"\n——$source';

    return '''
$styleLead
结构线索：$conciseStructure
$conciseBody$promptLine$quoteLine
'''
        .trim();
  }

  String _normalizeBody(String raw) {
    return raw.trim();
  }

  String _firstParagraph(String text) {
    final lines = text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (lines.isEmpty) return '';
    return lines.first;
  }

  String _truncateByLength(String text, {required int maxChars}) {
    if (text.length <= maxChars) return text;
    return '${text.substring(0, maxChars)}…';
  }
}

final shareCardDraftServiceProvider = ShareCardDraftService();