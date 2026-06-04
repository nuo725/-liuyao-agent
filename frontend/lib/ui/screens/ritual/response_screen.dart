import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../models/emotion_rhythm.dart';
import '../../../models/interpretation_card.dart';
import '../../../models/session.dart';
import '../../../models/tag_identity.dart';
import '../../../models/ui_flow_state.dart';
import '../../../services/emotion_rhythm_service.dart';
import '../../../state/auth_state.dart';
import '../../../state/credit_state.dart';
import '../../../state/ritual_state.dart';
import '../auth/login_gate_screen.dart';
import 'share_card_workflow_screen.dart';
import '../tag_identity/tag_identity_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
// 流式 UI 组件
// ═══════════════════════════════════════════════════════════════════════════

/// Blinking cursor shown during typewriter streaming
class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Opacity(
          opacity: _ctrl.value,
          child: Container(
            width: 2,
            height: 16,
            margin: const EdgeInsets.only(left: 2, top: 4),
            color: AppColors.textTertiary,
          ),
        );
      },
    );
  }
}

/// 打字机加载动画（光标闪烁 + 文案）
class _TypewriterLoadingIndicator extends StatefulWidget {
  const _TypewriterLoadingIndicator();

  @override
  State<_TypewriterLoadingIndicator> createState() =>
      _TypewriterLoadingIndicatorState();
}

class _TypewriterLoadingIndicatorState
    extends State<_TypewriterLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _cursorCtrl;

  @override
  void initState() {
    super.initState();
    _cursorCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _cursorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.primaryDark,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Text(
            '窄',
            style: AppTypography.labelSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Text(
                  '正在整理回应',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.7,
                  ),
                ),
                AnimatedBuilder(
                  animation: _cursorCtrl,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _cursorCtrl.value,
                      child: Container(
                        width: 2,
                        height: 16,
                        margin: const EdgeInsets.only(left: 2, top: 4),
                        color: AppColors.textTertiary,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ResponseScreen
// ═══════════════════════════════════════════════════════════════════════════

class ResponseScreen extends ConsumerStatefulWidget {
  const ResponseScreen({super.key});

  @override
  ConsumerState<ResponseScreen> createState() => _ResponseScreenState();
}

class _ResponseScreenState extends ConsumerState<ResponseScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();

  DailyGreeting? _greeting;
  bool _calibrationSubmitted = false;

  // 流式对话状态
  String _displayedText = ''; // 当前已显示的文字
  bool _isStreaming = false;
  Timer? _streamTimer;

  @override
  void initState() {
    super.initState();
    _fetchGreeting();
  }

  bool _hasStartedStreaming = false;

  @override
  void didUpdateWidget(ResponseScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final state = ref.read(ritualStateProvider);
    final session = state.session;

    // 当 initialCard 首次出现时，触发流式输出
    if (session != null &&
        session.initialCard != null &&
        !_hasStartedStreaming) {
      final card = session.initialCard!;
      final text = (card.content.body ?? card.content.summary).trim();
      if (text.isNotEmpty) {
        _hasStartedStreaming = true;
        _startStreaming(text);
      }
    }
  }

  Future<void> _fetchGreeting() async {
    try {
      final greeting = await emotionRhythmService.fetchDailyGreeting();
      if (mounted) {
        setState(() {
          _greeting = greeting;
        });
      }
    } catch (_) {
      // greeting is optional; keep silent in production
    }
  }

  Future<void> _submitCalibration(String feedback, {String? customText}) async {
    if (_calibrationSubmitted) return;
    await emotionRhythmService.submitCalibration(
      feedback,
      customText: customText,
    );
    if (mounted) {
      setState(() {
        _calibrationSubmitted = true;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _streamTimer?.cancel();
    super.dispose();
  }

  void _startStreaming(String fullText) {
    _streamTimer?.cancel();
    setState(() {
      _displayedText = '';
      _isStreaming = true;
    });

    int index = 0;
    _streamTimer = Timer.periodic(const Duration(milliseconds: 45), (timer) {
      if (index >= fullText.length) {
        timer.cancel();
        setState(() => _isStreaming = false);
        return;
      }
      setState(() {
        _displayedText = fullText.substring(0, index + 1);
      });
      index++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ritualStateProvider);
    final auth = ref.watch(authStateProvider);
    final credit = ref.watch(creditStateProvider);
    final session = state.session;
    final InterpretationCard? cardForShare = state.card ?? session?.initialCard;

    // Show error message if request failed (session not set yet)
    if (session == null) {
      if (state.error != null && state.error!.isNotEmpty) {
        return Scaffold(
          backgroundColor: AppColors.surface,
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      size: 52,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '解读暂时无法完成',
                      style: AppTypography.headlineSmall.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      state.error!,
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 28),
                    GestureDetector(
                      onTap: () {
                        ref.read(ritualStateProvider.notifier).reset();
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            '重新开始仪式',
                            style: AppTypography.labelMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        '返回上一页',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    final suggestions =
        session.initialCard?.content.followupDirections
            .map(_toFirstPersonQuestion)
            .toList() ??
        const <String>[];
    final tagSnapshot = TagIdentitySnapshot.preview(
      questionTag: session.tag ?? state.questionTag,
      sourceTitle: session.question,
      history: state.history,
      origin: TagIdentityOrigin.ritual,
      createdAt: session.createdAt,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('继续探索', style: AppTypography.headlineLarge),
                  const Spacer(),
                  Text(
                    '${session.followupCount}/${Session.maxFollowups}',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _quotaBanner(
                gateState: _resolveGateState(
                  auth.isLoggedIn,
                  credit.canFollowup,
                ),
                isVip: credit.isVip,
                castBalance: credit.castBalance,
                followupBalance: credit.followupBalance,
                followupCount: session.followupCount,
              ),
              const SizedBox(height: 2),
              Text(
                session.question,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openShareCard(cardForShare),
                  icon: const Icon(Icons.style_outlined, size: 18),
                  label: const Text('生成解读卡'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: BorderSide(
                      color: cardForShare != null
                          ? AppColors.border
                          : AppColors.border.withValues(alpha: 0.5),
                    ),
                    minimumSize: const Size.fromHeight(42),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openTagIdentity(tagSnapshot),
                  icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                  label: const Text('查看标签身份'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                    minimumSize: const Size.fromHeight(42),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(bottom: 8),
                  children: [
                    if (_greeting != null && !_calibrationSubmitted)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _DailyGreetingCard(
                          greeting: _greeting!,
                          onCalibrationSubmit: _submitCalibration,
                        ),
                      ),

                    // User question — right bubble
                    _userBubble(session.question, emphasize: true),
                    const SizedBox(height: 8),

                    // AI response — left bubble (streaming typewriter)
                    if (session.initialCard != null)
                      _aiBubble(
                        _displayedText.isNotEmpty
                            ? _displayedText
                            : _normalizeDisplayText(
                                session.initialCard!.content.body ??
                                    session.initialCard!.content.summary,
                              ),
                        isStreaming: _isStreaming,
                      )
                    else if (state.isLoading &&
                        _isStreaming &&
                        _displayedText.isNotEmpty)
                      _aiBubble(_displayedText, isStreaming: true)
                    else if (state.isLoading && !_isStreaming)
                      _TypewriterLoadingIndicator(),

                    // Followup exchanges — pure chat bubbles
                    ...session.messages.map((m) {
                      final text = _normalizeDisplayText(m.content);
                      if (m.type == FollowupMessageType.question) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _userBubble(text),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _aiBubble(text),
                      );
                    }),
                    if (state.isLoading)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.jade.withValues(alpha: 0.9),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '正在整理回应…',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (state.error != null) ...[
                const SizedBox(height: 4),
                Text(
                  state.error!,
                  style: AppTypography.caption.copyWith(color: AppColors.error),
                ),
              ],
              if (session.canFollowup) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: suggestions
                        .map((text) => _suggestionChip(text, state.isLoading))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 8),
                _composer(state.isLoading),
              ] else ...[
                const SizedBox(height: 8),
                Text(
                  '本轮追问已达到上限，可返回重新开始。',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // _visualBlockTile removed (not used by current UI layout).

  Widget _aiBubble(String text, {bool isStreaming = false}) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.primaryDark,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Text(
            '窄',
            style: AppTypography.labelSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    text,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.7,
                    ),
                  ),
                ),
                if (isStreaming) _BlinkingCursor(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _userBubble(String text, {bool emphasize = false}) {
    final maxWidth = MediaQuery.of(context).size.width * 0.75;
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.jade.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.jade.withValues(alpha: 0.4)),
          ),
          child: Text(
            text,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              height: 1.6,
            ),
          ),
        ),
      ),
    );
  }

  String _normalizeDisplayText(String text) {
    final out = _extractDisplayBody(text);
    if (out.isEmpty) return text.trim();
    return out;
  }

  String _extractDisplayBody(dynamic source) {
    dynamic current = source;
    for (int i = 0; i < 5; i++) {
      if (current is! String) {
        final nested = _extractBodyFromAny(current);
        if (nested == null) break;
        current = nested;
        continue;
      }

      var out = current.trim();
      out = out.replaceAll(RegExp(r'^```(?:json)?\s*', multiLine: true), '');
      out = out.replaceAll(RegExp(r'```$', multiLine: true), '');
      out = out
          .replaceAll(RegExp(r'\bjson\b', caseSensitive: false), '')
          .trim();
      out = _resolveEmbeddedJsonBody(out);

      final parsed = _tryReadJson(out) ?? _tryReadJson(_extractJsonObject(out));
      if (parsed == null) {
        return out;
      }
      final nested = _extractBodyFromAny(parsed);
      if (nested == null) return '';
      current = nested;
    }

    return current.toString().trim();
  }

  String _resolveEmbeddedJsonBody(String text) {
    var out = text;
    for (int i = 0; i < 3; i++) {
      final start = out.indexOf('{');
      if (start < 0) break;
      final end = _findBalancedBraceEnd(out, start);
      if (end <= start) break;

      final objectText = out.substring(start, end + 1);
      final parsed = _tryReadJson(objectText);
      if (parsed == null) {
        out = out.replaceRange(start, end + 1, '');
        continue;
      }

      final nested = _extractBodyFromAny(parsed)?.toString().trim();
      if (nested == null || nested.isEmpty) {
        out = out.replaceRange(start, end + 1, '');
        continue;
      }

      final prefix = out.substring(0, start).trimRight();
      final suffix = out.substring(end + 1).trimLeft();
      out = [
        if (prefix.isNotEmpty) prefix,
        nested,
        if (suffix.isNotEmpty) suffix,
      ].join('\n');
    }
    return out.trim();
  }

  int _findBalancedBraceEnd(String text, int start) {
    var depth = 0;
    var inString = false;
    var escaped = false;
    for (int i = start; i < text.length; i++) {
      final ch = text[i];
      if (escaped) {
        escaped = false;
        continue;
      }
      if (ch == '\\') {
        escaped = true;
        continue;
      }
      if (ch == '"') {
        inString = !inString;
        continue;
      }
      if (inString) continue;
      if (ch == '{') {
        depth++;
      } else if (ch == '}') {
        depth--;
        if (depth == 0) return i;
      }
    }
    return -1;
  }

  dynamic _extractBodyFromAny(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value['body'] ??
          value['summary'] ??
          value['content'] ??
          value['text'] ??
          value['message'];
    }
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      return _extractBodyFromAny(map);
    }
    if (value is List) {
      for (final item in value) {
        final nested = _extractBodyFromAny(item);
        if (nested != null) return nested;
      }
      return null;
    }
    if (value is String) return value;
    return null;
  }

  String _extractJsonObject(String text) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) return '';
    return text.substring(start, end + 1);
  }

  Map<String, dynamic>? _tryReadJson(String text) {
    if (text.isEmpty) return null;
    try {
      final obj = jsonDecode(text);
      if (obj is Map<String, dynamic>) return obj;
      if (obj is Map) return Map<String, dynamic>.from(obj);
      return null;
    } catch (_) {
      return null;
    }
  }

  String _toFirstPersonQuestion(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '我还可以继续追问什么？';
    final normalized = trimmed
        .replaceFirst(RegExp(r'^(你|您)'), '我')
        .replaceFirst(RegExp(r'^(是否|有没有|能否)'), '我是否');
    if (normalized.endsWith('？') || normalized.endsWith('?')) {
      return normalized;
    }
    return '$normalized？';
  }

  String _compactChipText(String text) {
    final cleaned = text.trim();
    if (cleaned.length <= 18) return cleaned;
    final parts = cleaned.split(RegExp(r'[？?!。]'));
    if (parts.isNotEmpty && parts.first.trim().length >= 6) {
      return '${parts.first.trim()}…';
    }
    return '${cleaned.substring(0, 18)}…';
  }

  // _iconFor removed (no longer used by current UI layout).

  Widget _suggestionChip(String text, bool isLoading) {
    final label = _compactChipText(text);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: isLoading
            ? null
            : () {
                _controller.text = text;
                _controller.selection = TextSelection.collapsed(
                  offset: _controller.text.length,
                );
                _focusNode.requestFocus();
              },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: AppColors.surface,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _composer(bool isLoading) {
    Future<void> submit() async {
      if (isLoading) return;
      final q = _controller.text.trim();
      if (q.isEmpty) return;
      final loggedIn = await _ensureLoggedInForFollowup();
      if (!loggedIn) return;
      final consumed = await ref
          .read(creditStateProvider.notifier)
          .consumeFollowup();
      if (!consumed) {
        if (!mounted) return;
        await _showFollowupQuotaSheet();
        return;
      }
      _controller.clear();
      // TODO(Backend Integration)[ritual_api#followup-auth]:
      // 当前在前端执行追问登录门禁，后续应以后端会话鉴权结果为准。
      await ref.read(ritualStateProvider.notifier).freeFollowup(q);
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                style: AppTypography.bodyMedium,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => submit(),
                decoration: const InputDecoration(
                  hintText: '输入你的追问…',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
            IconButton(
              onPressed: isLoading ? null : submit,
              icon: const Icon(Icons.north_east_rounded),
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _ensureLoggedInForFollowup() async {
    final auth = ref.read(authStateProvider);
    if (auth.isLoggedIn) return true;

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const LoginGateScreen(
          title: '继续追问需要登录',
          subtitle: '首次可免登录体验主流程；继续追问时请先完成登录。',
        ),
      ),
    );
    if (!mounted) return false;
    return result == true && ref.read(authStateProvider).isLoggedIn;
  }

  FollowupGateState _resolveGateState(bool isLoggedIn, bool canFollowup) {
    if (!isLoggedIn) return FollowupGateState.needLogin;
    if (!canFollowup) return FollowupGateState.quotaInsufficient;
    return FollowupGateState.ready;
  }

  Widget _quotaBanner({
    required FollowupGateState gateState,
    required bool isVip,
    required int castBalance,
    required int followupBalance,
    required int followupCount,
  }) {
    final hint = switch (gateState) {
      FollowupGateState.ready when followupCount == 0 =>
        '本轮先完成解读，追问会在继续对话时显示。当前解读剩余 $castBalance 次',
      FollowupGateState.ready =>
        '今日剩余：解读 $castBalance 次，追问 $followupBalance 次',
      FollowupGateState.needLogin => '登录后可使用每日额度（普通 1/1，VIP 2/4）',
      FollowupGateState.quotaInsufficient => '追问额度不足，可开通 VIP 或购买补给',
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        '${isVip ? 'VIP' : '普通'} · $hint',
        style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
      ),
    );
  }

  Future<void> _showFollowupQuotaSheet() async {
    final notifier = ref.read(creditStateProvider.notifier);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('今日追问次数已用完', style: AppTypography.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  '普通用户每天 1 次追问；VIP 每天 4 次追问。',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      // TODO(Backend Integration)[billing_api#purchase-confirm]:
                      // 后续替换为真实订单确认。
                      await notifier.subscribe(30);
                      if (!mounted) return;
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已开通 VIP（月卡模拟）')),
                      );
                    },
                    child: const Text('开通 VIP（模拟）'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () async {
                      await notifier.purchaseFollowup(1);
                      if (!mounted) return;
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已补充 1 次追问额度（模拟）')),
                      );
                    },
                    child: const Text('购买补给（模拟）'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openTagIdentity(TagIdentitySnapshot snapshot) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TagIdentityScreen(snapshot: snapshot),
      ),
    );
  }

  Future<void> _openShareCard(InterpretationCard? card) async {
    if (card == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前解读尚未生成，暂时无法创建解读卡。')),
      );
      return;
    }
    // TODO(Backend Integration)[share_api#entry-response]:
    // 当前由结果页直接跳转分享卡工作流，后端接入后可在此增加模板/权限校验。
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShareCardWorkflowScreen(card: card),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Daily Greeting Card — 晨晚节律 + 承接 + 校准
// ═══════════════════════════════════════════════════════════════════════════

class _DailyGreetingCard extends ConsumerStatefulWidget {
  final DailyGreeting greeting;
  final void Function(String feedback, {String? customText})
  onCalibrationSubmit;

  const _DailyGreetingCard({
    required this.greeting,
    required this.onCalibrationSubmit,
  });

  @override
  ConsumerState<_DailyGreetingCard> createState() => _DailyGreetingCardState();
}

class _DailyGreetingCardState extends ConsumerState<_DailyGreetingCard> {
  final _customController = TextEditingController();
  bool _customExpanded = false;

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final options = emotionRhythmService.calibrationOptions;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: AppColors.mintLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.mintDark.withValues(alpha: 0.4),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // greeting
          Text(
            widget.greeting.greeting,
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 7),

          // 承接文案
          Text(
            widget.greeting.contextText,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              height: 1.6,
            ),
          ),

          // emotion tags
          if (widget.greeting.emotionTags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 5,
              children: widget.greeting.emotionTags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.mint,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    tag,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.primaryDark,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 12),

          // calibration label
          Text(
            '此刻感觉如何？',
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 7),

          // preset options
          Wrap(
            spacing: 7,
            runSpacing: 6,
            children: [
              ...options.map(
                (opt) => _CalibrationChip(
                  label: opt,
                  onTap: () => widget.onCalibrationSubmit(opt),
                ),
              ),
              _CalibrationChip(
                label: '写点什么',
                onTap: () => setState(() => _customExpanded = !_customExpanded),
                isActive: _customExpanded,
              ),
            ],
          ),

          // custom text input
          if (_customExpanded) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: TextField(
                      controller: _customController,
                      style: AppTypography.bodySmall,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _submitCustom(),
                      decoration: InputDecoration(
                        hintText: '说说你的感受…',
                        hintStyle: AppTypography.bodySmall.copyWith(
                          color: AppColors.textTertiary,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 9),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                GestureDetector(
                  onTap: _submitCustom,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.north_east_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _submitCustom() {
    final text = _customController.text.trim();
    if (text.isEmpty) return;
    widget.onCalibrationSubmit('写点什么', customText: text);
    _customController.clear();
    setState(() => _customExpanded = false);
  }
}

class _CalibrationChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  const _CalibrationChip({
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.border,
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: isActive ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
