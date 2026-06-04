import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../state/ritual_state.dart';
import '../auth/login_gate_screen.dart';
import 'response_screen.dart';

/// 首次仪式简短解读页：
/// 1) 先展示简短解读 + 完整六爻；
/// 2) 查看完整解读与继续追问都需要先登录。
class FirstRitualResponsePage extends ConsumerWidget {
  const FirstRitualResponsePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ritual = ref.watch(ritualStateProvider);
    final pattern = ritual.pattern;
    final card = ritual.card;

    final lines = pattern?.lines ?? const <int>[1, 0, 1, 0, 1, 0];
    final safeLines = lines.length == 6 ? lines : const <int>[1, 0, 1, 0, 1, 0];

    final summary = (card?.content.summary ?? card?.content.body ?? '').trim();
    final shortText = summary.isNotEmpty
        ? summary
        : '你当前的状态已经在这组六爻中显现。先记住这一刻的感受，完整解读会告诉你下一步如何落地。';

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '首次仪式 · 简短解读',
                style: AppTypography.headlineMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '已完成六爻投掷，以下为本次卦象与简要回应。',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              Container(height: 0.5, color: AppColors.divider),
              const SizedBox(height: 18),
              Center(child: _HexagramView(lines: safeLines)),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  shortText,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.8,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 16,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '查看完整解读与继续追问需要先登录。',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              _PrimaryAction(
                label: '查看完整解读（需登录）',
                onTap: () => _loginAndOpenFullRead(context, ref),
              ),
              const SizedBox(height: 10),
              _SecondaryAction(
                label: '继续追问（需登录）',
                onTap: () => _loginAndOpenFullRead(context, ref),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () {
                    ref.read(ritualStateProvider.notifier).reset();
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    '返回首页',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loginAndOpenFullRead(
    BuildContext context,
    WidgetRef ref,
  ) async {
    // TODO(Backend Integration)[ritual_api#preview-gate]:
    // 首次简短解读与会话绑定逻辑在后端接入后由会话令牌驱动。
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const LoginGateScreen(
          title: '登录后解锁完整解读',
          subtitle: '本次卦象已保存，登录成功后将直接进入完整解读。',
        ),
      ),
    );
    if (!context.mounted) return;

    if (result == true && ref.read(ritualStateProvider).session != null) {
      // TODO(Backend Integration)[ritual_api#full-read]:
      // 未来切换为后端完整解读接口拉取，不再使用本地会话对象直出。
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ResponseScreen()),
      );
    }
  }
}

class _HexagramView extends StatelessWidget {
  final List<int> lines;

  const _HexagramView({required this.lines});

  @override
  Widget build(BuildContext context) {
    const yaoLabels = <String>['上', '五', '四', '三', '二', '初'];

    return Container(
      width: 220,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: List.generate(6, (index) {
          final reversedIndex = 5 - index;
          final line = lines[reversedIndex] > 0 ? 1 : 0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child: Text(
                    yaoLabels[index],
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: line == 1 ? const _YangLine() : const _YinLine(),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _YangLine extends StatelessWidget {
  const _YangLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 8,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: const Color(0xFF1A1A1A),
      ),
    );
  }
}

class _YinLine extends StatelessWidget {
  const _YinLine();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: const Color(0xFF1A1A1A),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: const Color(0xFF1A1A1A),
            ),
          ),
        ),
      ],
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PrimaryAction({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTypography.labelLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SecondaryAction({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
