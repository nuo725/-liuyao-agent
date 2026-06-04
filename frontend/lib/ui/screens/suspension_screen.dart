import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../common/ink_background.dart';

class SuspensionScreen extends StatefulWidget {
  const SuspensionScreen({super.key});

  @override
  State<SuspensionScreen> createState() => _SuspensionScreenState();
}

class _SuspensionScreenState extends State<SuspensionScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkBackground(
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = Curves.easeInOut.transform(_controller.value);
            final scaleA = 0.85 + t * 0.35;
            final scaleB = 1.05 + (1 - t) * 0.28;
            final alphaA = 0.11 + (1 - t) * 0.08;
            final alphaB = 0.06 + t * 0.05;

            return SizedBox(
              width: 280,
              height: 280,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.scale(scale: scaleA, child: _ring(alphaA)),
                  Transform.scale(scale: scaleB, child: _ring(alphaB)),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('汇流中', style: AppTypography.headlineMedium),
                      const SizedBox(height: 8),
                      Text(
                        '请给自己 6-8 秒呼吸',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _ring(double alpha) {
    return Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.jade.withValues(alpha: alpha),
          width: 1.2,
        ),
        gradient: RadialGradient(
          colors: [
            AppColors.jade.withValues(alpha: alpha * 0.6),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}
