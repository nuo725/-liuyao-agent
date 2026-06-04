import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../services/audio_service.dart';
import '../common/ink_background.dart';

class ClosureScreen extends ConsumerWidget {
  const ClosureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkBackground(
      child: Stack(
        children: [
          Center(
            child: GestureDetector(
              onTap: () async {
                await audioService.stop();
                if (context.mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline_rounded, size: 42),
                  const SizedBox(height: 12),
                  Text('本次已收束', style: AppTypography.headlineMedium),
                  const SizedBox(height: 8),
                  Text(
                    '轻触返回主界面',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
