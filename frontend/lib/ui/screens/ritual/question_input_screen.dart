import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/content/ritual_copy.dart';
import '../../../models/emotion_rhythm.dart';
import '../../../services/emotion_rhythm_service.dart';
import '../../../state/auth_state.dart';
import '../../../state/credit_state.dart';
import '../../../state/ritual_state.dart';
import '../../common/buttons.dart';
import '../../common/ink_background.dart';
import 'one_tap_ceremony_page.dart';

class QuestionInputScreen extends ConsumerStatefulWidget {
  const QuestionInputScreen({super.key});

  @override
  ConsumerState<QuestionInputScreen> createState() =>
      _QuestionInputScreenState();
}

class _QuestionInputScreenState extends ConsumerState<QuestionInputScreen> {
  final _controller = TextEditingController();

  DailyGreeting? _greeting;
  bool _greetingLoading = true;
  bool _calibrationSubmitted = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    _fetchGreeting();
  }

  Future<void> _fetchGreeting() async {
    try {
      final greeting = await emotionRhythmService.fetchDailyGreeting();
      if (!mounted) return;
      setState(() {
        _greeting = greeting;
        _greetingLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _greetingLoading = false);
    }
  }

  Future<void> _submitCalibration(String feedback, {String? customText}) async {
    if (_calibrationSubmitted) return;
    await emotionRhythmService.submitCalibration(
      feedback,
      customText: customText,
    );
    if (!mounted) return;
    setState(() => _calibrationSubmitted = true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    _submitAsync();
  }

  Future<void> _submitAsync() async {
    final q = _controller.text.trim();
    if (q.isEmpty) return;

    final accepted = ref
        .read(ritualStateProvider.notifier)
        .setQuestion(q);
    if (!accepted) return;

    final auth = ref.read(authStateProvider);
    if (auth.isLoggedIn) {
      final ok = await ref.read(creditStateProvider.notifier).consumeCast();
      if (!ok) {
        if (!mounted) return;
        await _showCreditInsufficientSheet(
          title: '今日解读次数已用完',
          subtitle: '普通用户每天 1 次解读；VIP 每天 2 次解读。',
          consumeType: 'cast',
        );
        return;
      }
    }

    final inputMode = ref.read(ritualStateProvider).inputMode;
    if (inputMode == RitualInputMode.localAnimation) {
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OneTapCeremonyPage()),
      );
      return;
    }

    ref.read(ritualStateProvider.notifier).advanceFromQuestion();
  }

  Future<void> _showCreditInsufficientSheet({
    required String title,
    required String subtitle,
    required String consumeType,
  }) async {
    final notifier = ref.read(creditStateProvider.notifier);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      await notifier.subscribe(30);
                      if (!mounted) return;
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已模拟开通 VIP（30 天）。')),
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
                      if (consumeType == 'cast') {
                        await notifier.purchaseCast(1);
                      } else {
                        await notifier.purchaseFollowup(1);
                      }
                      if (!mounted) return;
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已补充 1 次额度（模拟）。')),
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

  @override
  Widget build(BuildContext context) {
    final ritual = ref.watch(ritualStateProvider);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    Widget? greetingCard;
    if (!_greetingLoading && _greeting != null && !_calibrationSubmitted) {
      greetingCard = _DailyGreetingCardForInput(
        greeting: _greeting!,
        onCalibrationSubmit: _submitCalibration,
      );
    }

    return InkBackground(
      child: SafeArea(
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: keyboardInset),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      if (greetingCard != null) ...[
                        greetingCard,
                        const SizedBox(height: 12),
                      ],
                      Text(
                        RitualCopy.askTitle,
                        style: AppTypography.headlineLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        RitualCopy.askHint,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      InkCard(
                        child: TextField(
                          controller: _controller,
                          maxLines: 5,
                          style: AppTypography.bodyLarge,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            hintText: RitualCopy.askInputHint,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        RitualCopy.simulationTitle,
                        style: AppTypography.labelLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        RitualCopy.simulationHint,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: RitualSimulationMode.values.map((mode) {
                          final selected = ritual.simulationMode == mode;
                          return GestureDetector(
                            onTap: () => ref
                                .read(ritualStateProvider.notifier)
                                .setSimulationMode(mode),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.mintLight
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.border,
                                ),
                              ),
                              child: Text(
                                _simulationLabel(mode),
                                style: AppTypography.labelMedium.copyWith(
                                  color: selected
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                PrimaryButton(
                  label: RitualCopy.askSubmit,
                  onPressed: _controller.text.trim().isEmpty ? null : _submit,
                ),
                if ((ritual.error ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    ritual.error!,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Center(
                  child: AppTextButton(
                    label: RitualCopy.back,
                    onPressed: () =>
                        ref.read(ritualStateProvider.notifier).reset(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _simulationLabel(RitualSimulationMode mode) {
    return switch (mode) {
      RitualSimulationMode.success => RitualCopy.simulationSuccess,
      RitualSimulationMode.delayed => RitualCopy.simulationDelayed,
      RitualSimulationMode.timeout => RitualCopy.simulationTimeout,
      RitualSimulationMode.error => RitualCopy.simulationError,
      RitualSimulationMode.retryRecovery => RitualCopy.simulationRetryRecovery,
    };
  }
}

class _DailyGreetingCardForInput extends StatefulWidget {
  final DailyGreeting greeting;
  final void Function(String feedback, {String? customText})
  onCalibrationSubmit;

  const _DailyGreetingCardForInput({
    required this.greeting,
    required this.onCalibrationSubmit,
  });

  @override
  State<_DailyGreetingCardForInput> createState() =>
      _DailyGreetingCardForInputState();
}

class _DailyGreetingCardForInputState
    extends State<_DailyGreetingCardForInput> {
  final _customController = TextEditingController();
  bool _customExpanded = false;

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          Text(
            widget.greeting.greeting,
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            widget.greeting.contextText,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              height: 1.6,
            ),
          ),
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
          Text(
            RitualCopy.calibrationPrompt,
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 7,
            runSpacing: 6,
            children: [
              ...emotionRhythmService.calibrationOptions.map(
                (opt) => _MiniCalibrationChip(
                  label: opt,
                  onTap: () => widget.onCalibrationSubmit(opt),
                ),
              ),
              _MiniCalibrationChip(
                label: RitualCopy.calibrationCustom,
                onTap: () => setState(() => _customExpanded = !_customExpanded),
                isActive: _customExpanded,
              ),
            ],
          ),
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
                        hintText: RitualCopy.calibrationInputHint,
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
    widget.onCalibrationSubmit(RitualCopy.calibrationCustom, customText: text);
    _customController.clear();
    setState(() => _customExpanded = false);
  }
}

class _MiniCalibrationChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  const _MiniCalibrationChip({
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
