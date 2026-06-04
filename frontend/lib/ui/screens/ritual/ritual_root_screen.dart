import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../services/first_launch_flow_service.dart';
import '../../../state/ritual_state.dart';
import '../../common/ink_background.dart';
import '../auth/login_gate_screen.dart';
import '../closure_screen.dart';
import '../suspension_screen.dart';
import 'cast_screen.dart';
import 'hardware_complete_screen.dart';
import 'hardware_connect_screen.dart';
import 'question_input_screen.dart';
import 'response_screen.dart';

class RitualRootScreen extends ConsumerWidget {
  const RitualRootScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ritual = ref.watch(ritualStateProvider);
    final phase = ritual.phase;

    return PopScope(
      canPop: phase != RitualPhase.action &&
          phase != RitualPhase.hardwareAction &&
          phase != RitualPhase.suspension,
      onPopInvokedWithResult: (didPop, _) {
        // Avoid force-reset on blocked pop; that caused unexpected
        // fallback to mode-entry page after users completed ritual flow.
        if (didPop) return;
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SizedBox.expand(
          child: InkBackground(child: _buildBody(ritual.phase, ritual.flowMode)),
        ),
      ),
    );
  }

  Widget _buildBody(RitualPhase phase, RitualFlowMode flowMode) {
    switch (phase) {
      case RitualPhase.entry:
        // Keep mode-entry only for hardware path;
        // software path should ask question directly.
        if (flowMode == RitualFlowMode.hardware) {
          return const _ModeEntryScreen();
        }
        return const QuestionInputScreen();
      case RitualPhase.hardwareConnect:
        return const HardwareConnectScreen();
      case RitualPhase.moodInput:
        return const QuestionInputScreen();
      case RitualPhase.action:
      case RitualPhase.hardwareAction:
        return const CastScreen();
      case RitualPhase.hardwareComplete:
        return const HardwareCompleteScreen();
      case RitualPhase.suspension:
        return const SuspensionScreen();
      case RitualPhase.presentation:
      case RitualPhase.response:
        return const ResponseScreen();
      case RitualPhase.closure:
        return const ClosureScreen();
    }
  }
}

class _ModeEntryScreen extends ConsumerWidget {
  const _ModeEntryScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ritual = ref.watch(ritualStateProvider);
    final selectedMode = ritual.inputMode;

    Future<void> enterMode(RitualInputMode mode) async {
      final notifier = ref.read(ritualStateProvider.notifier);
      notifier.setInputMode(mode);
      if (mode == RitualInputMode.hardwareLink) {
        await notifier.startHardwareFlow();
      } else {
        notifier.startSoftwareFlow();
      }
    }

    String modeLabel(RitualInputMode mode) {
      return switch (mode) {
        RitualInputMode.manualThrow => '手动投掷页',
        RitualInputMode.hardwareLink => '蓝牙连接页',
        RitualInputMode.localAnimation => '本地一键页',
      };
    }

    String modeSubtitle(RitualInputMode mode) {
      return switch (mode) {
        RitualInputMode.manualThrow => '自己完成投掷，进入手动起卦流程。',
        RitualInputMode.hardwareLink => '先连接外设，再继续采集卦象。',
        RitualInputMode.localAnimation => '本地动画一键生成卦象，再进入解读。',
      };
    }

    IconData modeIcon(RitualInputMode mode) {
      return switch (mode) {
        RitualInputMode.manualThrow => Icons.touch_app_outlined,
        RitualInputMode.hardwareLink => Icons.bluetooth_connected_rounded,
        RitualInputMode.localAnimation => Icons.auto_awesome_rounded,
      };
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
        child: ListView(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () async {
                  await firstLaunchFlowServiceProvider.markCompleted();
                  if (!context.mounted) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const LoginGateScreen(
                        title: '注册 / 登录',
                        subtitle: '可使用手机号、微信、QQ、抖音登录。',
                      ),
                    ),
                  );
                },
                child: const Text('跳过并登录'),
              ),
            ),
            Text('选择卦象输入入口', style: AppTypography.headlineLarge),
            const SizedBox(height: 8),
            Text(
              '每种方式都会进入对应的前端页面：手动投掷、蓝牙连接、本地一键。',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            _ModeCard(
              icon: modeIcon(RitualInputMode.manualThrow),
              title: modeLabel(RitualInputMode.manualThrow),
              subtitle: modeSubtitle(RitualInputMode.manualThrow),
              selected: selectedMode == RitualInputMode.manualThrow,
              onTap: () => enterMode(RitualInputMode.manualThrow),
            ),
            const SizedBox(height: 12),
            _ModeCard(
              icon: modeIcon(RitualInputMode.hardwareLink),
              title: modeLabel(RitualInputMode.hardwareLink),
              subtitle: modeSubtitle(RitualInputMode.hardwareLink),
              selected: selectedMode == RitualInputMode.hardwareLink,
              onTap: () => enterMode(RitualInputMode.hardwareLink),
            ),
            const SizedBox(height: 12),
            _ModeCard(
              icon: modeIcon(RitualInputMode.localAnimation),
              title: modeLabel(RitualInputMode.localAnimation),
              subtitle: modeSubtitle(RitualInputMode.localAnimation),
              selected: selectedMode == RitualInputMode.localAnimation,
              onTap: () => enterMode(RitualInputMode.localAnimation),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => enterMode(selectedMode),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: Text('进入${modeLabel(selectedMode)}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.mintLight : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: selected ? Colors.white : AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: selected ? AppColors.primaryDark : AppColors.textSecondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.labelLarge),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: selected ? AppColors.primary : AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
