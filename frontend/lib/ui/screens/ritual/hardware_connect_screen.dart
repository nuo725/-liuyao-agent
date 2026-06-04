import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../state/ritual_trigger_state.dart';
import '../../../state/ritual_state.dart';
import '../../common/buttons.dart';
import '../../common/ink_background.dart';

class HardwareConnectScreen extends ConsumerWidget {
  const HardwareConnectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trigger = ref.watch(ritualTriggerProvider);
    final ritualState = ref.watch(ritualStateProvider);

    return InkBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('硬件共鸣', style: AppTypography.headlineLarge),
              const SizedBox(height: 8),
              Text(
                '已进入硬件模式。请先连接设备，再继续本次体验。',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 26),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      trigger.deviceConnected
                          ? Icons.bluetooth_connected_rounded
                          : Icons.bluetooth_searching_rounded,
                      color: trigger.deviceConnected
                          ? AppColors.jade
                          : AppColors.textTertiary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        trigger.deviceConnected ? '设备已连接' : '等待设备连接',
                        style: AppTypography.labelLarge.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (trigger.errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  trigger.errorMessage!,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ],
              if (ritualState.error != null) ...[
                const SizedBox(height: 8),
                Text(
                  ritualState.error!,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ],
              const Spacer(),
              PrimaryButton(
                label: trigger.deviceConnected ? '继续提问' : '刷新连接状态',
                onPressed: trigger.deviceConnected
                    ? () => ref
                          .read(ritualStateProvider.notifier)
                          .continueFromHardwareConnect()
                    : () => ref
                          .read(ritualTriggerProvider.notifier)
                          .refreshHardwareState(),
              ),
              const SizedBox(height: 10),
              SecondaryButton(
                label: '改为触控模式',
                onPressed: () =>
                    ref.read(ritualStateProvider.notifier).startSoftwareFlow(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
