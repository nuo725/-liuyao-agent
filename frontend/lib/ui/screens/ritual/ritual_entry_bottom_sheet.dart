import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../models/emotion_rhythm.dart';
import '../../../services/emotion_rhythm_service.dart';
import '../../../state/auth_state.dart';
import '../../../state/credit_state.dart';
import '../../../state/ritual_state.dart';

/// Structured result from the entry bottom sheet.
sealed class RitualEntryResult {
  const RitualEntryResult();
}

class RitualEntryStartNew extends RitualEntryResult {
  const RitualEntryStartNew();
}

class RitualEntryContinueChat extends RitualEntryResult {
  const RitualEntryContinueChat();
}

class RitualEntryBottomSheet extends ConsumerStatefulWidget {
  const RitualEntryBottomSheet({super.key});

  @override
  ConsumerState<RitualEntryBottomSheet> createState() =>
      _RitualEntryBottomSheetState();
}

class _RitualEntryBottomSheetState
    extends ConsumerState<RitualEntryBottomSheet> {
  DailyGreeting? _greeting;
  bool _greetingLoading = true;
  String? _selectedEmotion;
  bool _calibrationSubmitted = false;

  @override
  void initState() {
    super.initState();
    _fetchGreeting();
  }

  Future<void> _fetchGreeting() async {
    try {
      final ritual = ref.read(ritualStateProvider);
      emotionRhythmService.lastRitualQuestion = ritual.question;
      final greeting = await emotionRhythmService.fetchDailyGreeting();
      if (mounted) {
        setState(() {
          _greeting = greeting;
          _greetingLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _greetingLoading = false);
    }
  }

  Future<void> _submitCalibration(String feedback) async {
    if (_calibrationSubmitted) return;
    await emotionRhythmService.submitCalibration(feedback);
    if (mounted) setState(() => _calibrationSubmitted = true);
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _startNewTap() {
    Navigator.of(context).pop(const RitualEntryStartNew());
  }

  void _continueChatTap() {
    Navigator.of(context).pop(const RitualEntryContinueChat());
  }

  @override
  Widget build(BuildContext context) {
    final ritual = ref.watch(ritualStateProvider);
    final auth = ref.watch(authStateProvider);
    final credit = ref.watch(creditStateProvider);
    final completedToday = ritual.completedToday;
    final canRecast =
        completedToday && auth.isLoggedIn && credit.castBalance > 0;
    final recastDisabled = completedToday && !canRecast;
    final selectedInputMode = ritual.inputMode;

    return Material(
      color: AppColors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Greeting card — always shown, enhanced interaction
            if (_greeting != null) ...[
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _MiniGreetingCard(
                  greeting: _greeting!,
                  selectedEmotion: _selectedEmotion,
                  calibrationSubmitted: _calibrationSubmitted,
                  onEmotionSelected: (e) {
                    setState(() => _selectedEmotion = e);
                    _submitCalibration(e);
                  },
                ),
              ),
            ] else if (_greetingLoading) ...[
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.mintLight,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _InputModeSelector(
                value: selectedInputMode,
                onChanged: (mode) =>
                    ref.read(ritualStateProvider.notifier).setInputMode(mode),
              ),
            ),

            const SizedBox(height: 12),

            if (completedToday) ...[
              // --- Mode B: Today completed → show summary + continue chat ---
              _TodaySummaryCard(ritual: ritual),
              const SizedBox(height: 14),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  24, 0, 24,
                  MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: GestureDetector(
                        onTap: _continueChatTap,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            color: AppColors.mintLight,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '继续对话',
                            style: AppTypography.labelMedium.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: recastDisabled ? null : _startNewTap,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.surfaceVariant,
                          foregroundColor: AppColors.textPrimary,
                          minimumSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: Text(recastDisabled ? '再次解读（今日已用完）' : '再次解读'),
                      ),
                    ),
                    if (recastDisabled) ...[
                      const SizedBox(height: 8),
                      Text(
                        auth.isLoggedIn
                            ? '普通用户每天 1 次解读；VIP 每天 2 次解读。可去权益中心补给。'
                            : '游客每天 1 次体验；登录后可解锁权益并补给次数。',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textTertiary,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ] else ...[
              // --- Mode A: Not completed → start new (question happens next) ---
              Padding(
                padding: EdgeInsets.fromLTRB(
                  24, 0, 24,
                  MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _startNewTap,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: const Text('开始解读'),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Greeting card with richer interaction options.
class _MiniGreetingCard extends StatelessWidget {
  final DailyGreeting greeting;
  final String? selectedEmotion;
  final bool calibrationSubmitted;
  final ValueChanged<String> onEmotionSelected;

  const _MiniGreetingCard({
    required this.greeting,
    this.selectedEmotion,
    required this.calibrationSubmitted,
    required this.onEmotionSelected,
  });

  static const _defaultOptions = ['好多了', '还是有点乱', '有了新想法'];

  @override
  Widget build(BuildContext context) {
    final options = emotionRhythmService.calibrationOptions.isNotEmpty
        ? emotionRhythmService.calibrationOptions
        : _defaultOptions;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.mintLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            greeting.greeting,
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textTertiary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            greeting.contextText,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textPrimary,
              height: 1.7,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          if (calibrationSubmitted)
            Text(
              '已收到你的状态，今天也陪着你。',
              style: AppTypography.caption.copyWith(
                color: AppColors.primary,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: options.map((opt) {
                final selected = selectedEmotion == opt;
                return GestureDetector(
                  onTap: () => onEmotionSelected(opt),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color:
                          selected ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color:
                            selected ? AppColors.primary : AppColors.border,
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      opt,
                      style: AppTypography.caption.copyWith(
                        color: selected
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _InputModeSelector extends StatelessWidget {
  final RitualInputMode value;
  final ValueChanged<RitualInputMode> onChanged;

  const _InputModeSelector({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '卦象输入方式',
            style: AppTypography.labelLarge.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '前端只做方式切换，不接真实硬件或后端。',
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ModeChip(
                selected: value == RitualInputMode.manualThrow,
                icon: Icons.touch_app_outlined,
                title: '手动投掷',
                subtitle: '自己完成投掷',
                onTap: () => onChanged(RitualInputMode.manualThrow),
              ),
              _ModeChip(
                selected: value == RitualInputMode.hardwareLink,
                icon: Icons.bluetooth_connected_rounded,
                title: '蓝牙硬件',
                subtitle: '连接外设输入',
                onTap: () => onChanged(RitualInputMode.hardwareLink),
              ),
              _ModeChip(
                selected: value == RitualInputMode.localAnimation,
                icon: Icons.auto_awesome_rounded,
                title: '本地一键',
                subtitle: '动画生成卦象',
                onTap: () => onChanged(RitualInputMode.localAnimation),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ModeChip({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 104,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? AppColors.mintLight : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? AppColors.primaryDark : AppColors.textSecondary,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact card showing today's ritual result summary.
class _TodaySummaryCard extends StatelessWidget {
  final RitualState ritual;

  const _TodaySummaryCard({required this.ritual});

  @override
  Widget build(BuildContext context) {
    final card = ritual.card;
    final lines = ritual.pattern?.lines ?? [];
    final coordinateName = _buildCoordinateName(lines);
    final summary = card?.content.summary.trim() ?? '';
    final displaySummary = summary.length > 80
        ? '${summary.substring(0, 80)}…'
        : summary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '今日解读',
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
              ],
            ),
            if (displaySummary.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                displaySummary,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _buildCoordinateName(List<int> lines) {
    if (lines.length != 6) return '';
    final seed = int.parse(lines.join(), radix: 2);
    const labels = ['林隙', '晨汐', '远岚', '山脊', '微澜', '夜航', '天镜', '归岸'];
    final a = labels[seed % labels.length];
    final b = labels[(seed ~/ 3 + 2) % labels.length];
    return '$a · $b';
  }
}
