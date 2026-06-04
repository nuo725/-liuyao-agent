import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';

/// 极简 2 页引导页 — 第一次见面
class OnboardingHookScreen extends StatefulWidget {
  final VoidCallback onStartExperience;
  final VoidCallback onSkipToLogin;

  const OnboardingHookScreen({
    super.key,
    required this.onStartExperience,
    required this.onSkipToLogin,
  });

  @override
  State<OnboardingHookScreen> createState() => _OnboardingHookScreenState();
}

class _OnboardingHookScreenState extends State<OnboardingHookScreen> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == 1;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
              child: Row(
                children: [
                  Text(
                    '第一次见面',
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: widget.onSkipToLogin,
                    child: Text(
                      '跳过并登录',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2 pages
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: 2,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => i == 0
                    ? const _IntroPage()
                    : const _StartPage(),
              ),
            ),

            // Bottom: dots + CTA
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              child: Column(
                children: [
                  // Dot indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(2, (i) {
                      final selected = i == _index;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        width: selected ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color:
                              selected ? AppColors.primary : AppColors.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),

                  // CTA button
                  GestureDetector(
                    onTap: () {
                      if (isLast) {
                        widget.onStartExperience();
                        return;
                      }
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          isLast ? '开始第一次体验' : '继续',
                          style: AppTypography.labelLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Page 1: APP 简介 ────────────────────────────────────────────────────────

class _IntroPage extends StatelessWidget {
  const _IntroPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo / brand mark
          Text(
            '宽窄之间',
            style: AppTypography.displayMedium.copyWith(
              color: AppColors.textPrimary,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '一场与自我的对话',
            style: AppTypography.headlineSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),

          const Spacer(),

          // 功能简洁说明
          Text(
            '在发问之前，先感受此刻的自己。\n六段成形，回应围绕这组结构展开。\n以心为引，映照而非解答。',
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textSecondary,
              height: 2,
            ),
          ),

          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

// ─── Page 2: 开始 ─────────────────────────────────────────────────────────────

class _StartPage extends StatelessWidget {
  const _StartPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '准备好开始了吗？',
            style: AppTypography.headlineLarge.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '你的第一次体验将完整走完整个仪式流程。\n体验结束后可查看简短解读。\n登录后将解锁完整解读与追问功能。',
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textTertiary,
              height: 1.9,
            ),
          ),

          const Spacer(),

          // 底部装饰文字
          Text(
            '不必想清楚再开始\n先走一遍，答案会在路上浮现',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textTertiary,
              height: 2,
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}
