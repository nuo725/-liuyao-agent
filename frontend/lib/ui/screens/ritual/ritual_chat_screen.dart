import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../models/session.dart';
import '../../../state/auth_state.dart';
import '../../../state/ritual_state.dart';
import '../auth/login_gate_screen.dart';

/// Hybrid chat screen: today's interpretation summary + conversation.
class RitualChatScreen extends ConsumerStatefulWidget {
  const RitualChatScreen({super.key});

  @override
  ConsumerState<RitualChatScreen> createState() => _RitualChatScreenState();
}

class _RitualChatScreenState extends ConsumerState<RitualChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  bool _summaryExpanded = true;
  bool _isSending = false;
  int _lastMessageCount = 0;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    final ritual = ref.read(ritualStateProvider);
    if (text.isEmpty || _isSending || ritual.isLoading) return;

    final loggedIn = await _ensureLoggedIn();
    if (!loggedIn) return;

    _isSending = true;
    _controller.clear();
    if (mounted) setState(() {});
    _scrollToBottom();

    try {
      await ref.read(ritualStateProvider.notifier).freeFollowup(text);
      if (!mounted) return;
      _scrollToBottom();
    } finally {
      _isSending = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final ritual = ref.watch(ritualStateProvider);
    final card = ritual.card;
    final session = ritual.session;
    final messages = session?.messages ?? const <FollowupMessage>[];
    final lines = ritual.pattern?.lines ?? const <int>[];
    final coordinateName = _buildCoordinateName(lines);
    final summary = card?.content.summary.trim() ?? '';
    final afterglow = card?.content.afterglow.trim() ?? '';
    final isLoading = ritual.isLoading;
    final isBusy = isLoading || _isSending;

    if (messages.length != _lastMessageCount) {
      _lastMessageCount = messages.length;
      _scrollToBottom();
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          '继续对话',
          style: AppTypography.labelLarge.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          color: AppColors.textSecondary,
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _SummaryCard(
                  coordinateName: coordinateName,
                  summary: summary,
                  afterglow: afterglow,
                  expanded: _summaryExpanded,
                  onToggle: () =>
                      setState(() => _summaryExpanded = !_summaryExpanded),
                ),
                Container(height: 0.5, color: AppColors.divider),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isQuestion =
                          msg.type == FollowupMessageType.question;
                      return _ChatBubble(
                        text: msg.content,
                        isUser: isQuestion,
                        suggestions:
                            isQuestion ? null : msg.suggestedDirections,
                        onSuggestionTap: (s) {
                          _controller.text = s;
                          _focusNode.requestFocus();
                          _send();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
            if (isLoading)
              Positioned(
                left: 16,
                bottom: 84,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: AppColors.textTertiary,
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
            AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: _ComposerBar(
                  controller: _controller,
                  focusNode: _focusNode,
                  isBusy: isBusy,
                  onSend: _send,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _ensureLoggedIn() async {
    final auth = ref.read(authStateProvider);
    if (auth.isLoggedIn) return true;

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const LoginGateScreen(
          title: '继续追问需要登录',
          subtitle: '首次可先体验主流程；继续追问时请先完成登录。',
        ),
      ),
    );
    if (!mounted) return false;
    return result == true && ref.read(authStateProvider).isLoggedIn;
  }

  String _buildCoordinateName(List<int> lines) {
    if (lines.length != 6) return '';
    final seed = int.parse(lines.join(), radix: 2);
    const labels = ['林隙', '晨洄', '远矚', '山胤', '微澜', '夜航', '天镜', '归岸'];
    final a = labels[seed % labels.length];
    final b = labels[(seed ~/ 3 + 2) % labels.length];
    return '$a · $b';
  }
}

class _SummaryCard extends StatelessWidget {
  final String coordinateName;
  final String summary;
  final String afterglow;
  final bool expanded;
  final VoidCallback onToggle;

  const _SummaryCard({
    required this.coordinateName,
    required this.summary,
    required this.afterglow,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: AppColors.mintLight,
          border: Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '今日回应',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                const Spacer(),
                Text(
                  coordinateName,
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
            if (expanded) ...[
              const SizedBox(height: 8),
              if (summary.isNotEmpty)
                Text(
                  summary,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.65,
                  ),
                ),
              if (afterglow.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  afterglow,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.55,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final List<String>? suggestions;
  final ValueChanged<String>? onSuggestionTap;

  const _ChatBubble({
    required this.text,
    required this.isUser,
    this.suggestions,
    this.onSuggestionTap,
  });

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();

    final bubbleColor =
        isUser ? AppColors.jade.withValues(alpha: 0.14) : Colors.white;
    final alignment =
        isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isUser
                    ? AppColors.jade.withValues(alpha: 0.26)
                    : AppColors.border,
              ),
            ),
            child: Text(
              text,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                height: 1.65,
              ),
            ),
          ),
          if (!isUser && suggestions != null && suggestions!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: suggestions!
                  .map(
                    (s) => ActionChip(
                      label: Text(s),
                      onPressed: onSuggestionTap == null
                          ? null
                          : () => onSuggestionTap!(s),
                      labelStyle: AppTypography.labelSmall.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      backgroundColor: AppColors.surfaceVariant,
                      side: BorderSide(color: AppColors.border),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _ComposerBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isBusy;
  final VoidCallback onSend;

  const _ComposerBar({
    required this.controller,
    required this.focusNode,
    required this.isBusy,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: !isBusy,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => isBusy ? null : onSend(),
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: '想聊什么…',
                hintStyle: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textTertiary,
                ),
                isDense: true,
                filled: true,
                fillColor: AppColors.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: isBusy ? null : onSend,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isBusy ? AppColors.border : AppColors.primary,
              ),
              child: Icon(
                Icons.arrow_upward_rounded,
                size: 18,
                color: isBusy ? AppColors.textTertiary : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
