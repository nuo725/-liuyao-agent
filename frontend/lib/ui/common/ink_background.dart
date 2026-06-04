import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Minimal background - cream/white, no gradient
class InkBackground extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;

  const InkBackground({
    super.key,
    required this.child,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor ?? AppColors.cream,
      child: child,
    );
  }
}

/// Simple card with color fill and optional border
class InkCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final VoidCallback? onTap;

  const InkCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? Colors.transparent;
    final hasFrame = color != null;

    final body = Container(
      decoration: BoxDecoration(
        color: resolvedColor,
        borderRadius: BorderRadius.circular(14),
        border: hasFrame ? Border.all(color: AppColors.border) : null,
      ),
      child: Padding(padding: padding, child: child),
    );

    if (onTap == null) return body;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: body,
    );
  }
}

/// Solid color container - for sections that need emphasis
class ColorBlock extends StatelessWidget {
  final Widget child;
  final Color color;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;

  const ColorBlock({
    super.key,
    required this.child,
    required this.color,
    this.padding,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius,
      ),
      child: child,
    );
  }
}
