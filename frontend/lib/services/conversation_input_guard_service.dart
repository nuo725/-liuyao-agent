class InputGuardResult {
  final bool accepted;
  final String normalizedText;
  final String message;
  final List<String> suggestedFollowups;

  const InputGuardResult({
    required this.accepted,
    required this.normalizedText,
    required this.message,
    this.suggestedFollowups = const [],
  });
}

abstract class ConversationInputGuardService {
  InputGuardResult validateInitialQuestion(String raw);
  InputGuardResult validateFollowupQuestion(String raw);
}

/// Keep front-end validation minimal.
/// The model workflow should handle semantic abnormality and clarification.
class BasicConversationInputGuardServiceImpl
    implements ConversationInputGuardService {
  @override
  InputGuardResult validateInitialQuestion(String raw) {
    final text = _normalize(raw);
    if (text.isEmpty) {
      return const InputGuardResult(
        accepted: false,
        normalizedText: '',
        message: '先写下你此刻最想问的一句话。',
      );
    }
    return InputGuardResult(accepted: true, normalizedText: text, message: '');
  }

  @override
  InputGuardResult validateFollowupQuestion(String raw) {
    final text = _normalize(raw);
    if (text.isEmpty) {
      return const InputGuardResult(
        accepted: false,
        normalizedText: '',
        message: '追问不能为空。',
      );
    }

    if (_isMeaningless(text)) {
      return InputGuardResult(
        accepted: true,
        normalizedText: text,
        message: '追问可以再具体一点，我先按这句继续。',
        suggestedFollowups: const ['我现在最卡住的是哪一部分？', '我下一步先稳住什么最关键？'],
      );
    }

    return InputGuardResult(
      accepted: true,
      normalizedText: text,
      message: '',
    );
  }

  String _normalize(String raw) {
    var out = raw.trim();
    out = out.replaceAll(RegExp(r'\s+'), ' ');
    out = out.replaceAll(RegExp(r'[`~^]+'), '');
    if (out.length > 280) {
      out = out.substring(0, 280);
    }
    return out;
  }

  bool _isMeaningless(String text) {
    final stripped = text.replaceAll(RegExp(r'\s+'), '');
    if (stripped.length < 2) return true;
    final meaningfulChars = RegExp(r'[A-Za-z\u4e00-\u9fff]').allMatches(text).length;
    if (meaningfulChars < 2) return true;
    if (RegExp(r'^(.)\1{3,}$').hasMatch(stripped)) return true;
    return false;
  }
}

final conversationInputGuardServiceProvider =
    BasicConversationInputGuardServiceImpl();
