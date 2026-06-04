import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';

/// Theme presets for the share card visual.
enum ShareCardTheme {
  warm('暖色'),
  cool('冷色'),
  dark('深色');

  final String label;
  const ShareCardTheme(this.label);
}

/// Renders a 3:4 minimalist interpretation card, wrapped in RepaintBoundary
/// so it can be captured as an image.
class ShareCardCanvas extends StatelessWidget {
  final GlobalKey repaintKey;
  final String coordinateName;
  final String summary;
  final List<int> hexagramLines;
  final ShareCardTheme theme;
  final String? backgroundImagePath;

  const ShareCardCanvas({
    super.key,
    required this.repaintKey,
    required this.coordinateName,
    required this.summary,
    required this.hexagramLines,
    this.theme = ShareCardTheme.warm,
    this.backgroundImagePath,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: repaintKey,
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Container(
          decoration: _buildBackground(),
          child: Stack(
            children: [
              if (backgroundImagePath != null)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      File(backgroundImagePath!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              if (backgroundImagePath != null)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: _overlayColor(),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 48, 28, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(flex: 1),

                    // Hexagram lines
                    _HexagramWidget(
                      lines: hexagramLines,
                      color: _textColor(),
                    ),
                    const SizedBox(height: 20),

                    // Coordinate name
                    Text(
                      coordinateName,
                      style: AppTypography.headlineSmall.copyWith(
                        color: _textColor(),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 36,
                      height: 1.5,
                      color: _textColor().withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 16),

                    // Summary text
                    Expanded(
                      flex: 3,
                      child: Text(
                        summary,
                        style: AppTypography.bodyMedium.copyWith(
                          color: _textColor().withValues(alpha: 0.85),
                          height: 1.8,
                        ),
                        overflow: TextOverflow.fade,
                      ),
                    ),

                    const Spacer(flex: 1),

                    // Footer
                    Row(
                      children: [
                        Text(
                          '宽窄 · Orbit',
                          style: AppTypography.caption.copyWith(
                            color: _textColor().withValues(alpha: 0.4),
                            letterSpacing: 0.8,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatDate(DateTime.now()),
                          style: AppTypography.caption.copyWith(
                            color: _textColor().withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration _buildBackground() {
    if (backgroundImagePath != null) {
      return BoxDecoration(borderRadius: BorderRadius.circular(16));
    }
    return BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      gradient: _gradient(),
    );
  }

  LinearGradient _gradient() {
    return switch (theme) {
      ShareCardTheme.warm => const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.canvasWarm, AppColors.mintLight],
        ),
      ShareCardTheme.cool => const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.sky, AppColors.lavender],
        ),
      ShareCardTheme.dark => const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A2A2E), Color(0xFF1A1A20)],
        ),
    };
  }

  Color _textColor() {
    return theme == ShareCardTheme.dark ? Colors.white : AppColors.ink;
  }

  Color _overlayColor() {
    return theme == ShareCardTheme.dark
        ? Colors.black.withValues(alpha: 0.55)
        : Colors.white.withValues(alpha: 0.6);
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
  }

  /// Capture the rendered card as PNG bytes.
  static Future<ui.Image?> capture(GlobalKey key) async {
    final boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    return boundary.toImage(pixelRatio: 3.0);
  }
}

/// Minimalist hexagram display using CustomPaint.
class _HexagramWidget extends StatelessWidget {
  final List<int> lines;
  final Color color;

  const _HexagramWidget({required this.lines, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 60,
      child: CustomPaint(
        painter: _HexagramPainter(lines: lines, color: color),
      ),
    );
  }
}

class _HexagramPainter extends CustomPainter {
  final List<int> lines;
  final Color color;

  _HexagramPainter({required this.lines, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final lineCount = lines.length.clamp(0, 6);
    final spacing = size.height / 6;

    for (int i = 0; i < lineCount; i++) {
      final y = size.height - (i + 0.5) * spacing;
      final isYang = lines[i] == 1;

      if (isYang) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      } else {
        final gap = size.width * 0.15;
        final mid = size.width / 2;
        canvas.drawLine(Offset(0, y), Offset(mid - gap, y), paint);
        canvas.drawLine(Offset(mid + gap, y), Offset(size.width, y), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HexagramPainter old) =>
      old.lines != lines || old.color != color;
}
