import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/constants/app_spacing.dart';

/// 标题文本组件
class TitleText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  const TitleText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: style ?? AppTypography.headlineMedium.copyWith(
        color: AppColors.textPrimary,
      ),
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

/// 正文文本组件
class BodyText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  const BodyText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: style ?? AppTypography.bodyMedium.copyWith(
        color: AppColors.textPrimary,
      ),
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

/// 辅助文本组件
class CaptionText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  const CaptionText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: style ?? AppTypography.caption.copyWith(
        color: AppColors.textTertiary,
      ),
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

/// 标签组件
class Tag extends StatelessWidget {
  final String label;
  final Color? backgroundColor;
  final Color? textColor;

  const Tag({
    super.key,
    required this.label,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppSpacing.xs),
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall.copyWith(
          color: textColor ?? AppColors.textSecondary,
        ),
      ),
    );
  }
}

/// 分割线
class AppDivider extends StatelessWidget {
  final double? height;
  final Color? color;

  const AppDivider({
    super.key,
    this.height,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: height ?? 1,
      color: color ?? AppColors.divider,
      thickness: 1,
    );
  }
}
