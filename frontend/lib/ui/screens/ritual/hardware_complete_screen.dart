import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../state/ritual_state.dart';
import '../../common/buttons.dart';
import '../../common/ink_background.dart';

class HardwareCompleteScreen extends ConsumerWidget {
  const HardwareCompleteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ritualStateProvider);
    final lines = state.pendingLines ?? const <int>[];

    return InkBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('采集完成', style: AppTypography.headlineLarge),
              const SizedBox(height: 8),
              Text(
                '已接收本次硬件投掷结果，确认后开始生成回应。',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 30),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '已采集 ${lines.length}/6',
                      style: AppTypography.labelLarge,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(6, (index) {
                        final active = index < lines.length;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          width: 36,
                          height: 8,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: active
                                ? AppColors.jade
                                : AppColors.surfaceCard,
                            border: Border.all(
                              color: active ? AppColors.jade : AppColors.border,
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              if (state.error != null) ...[
                const SizedBox(height: 12),
                Text(
                  state.error!,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ],
              const Spacer(),
              PrimaryButton(
                label: '生成回应',
                isLoading: state.isLoading,
                onPressed: lines.length == 6
                    ? () => ref
                          .read(ritualStateProvider.notifier)
                          .runHardwareCompletion()
                    : null,
              ),
              const SizedBox(height: 10),
              SecondaryButton(
                label: '重新采集',
                onPressed: () => ref
                    .read(ritualStateProvider.notifier)
                    .restartHardwareCollection(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
