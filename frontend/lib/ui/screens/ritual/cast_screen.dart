import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../services/audio_service.dart';
import '../../../state/ritual_state.dart';
import '../../common/ink_background.dart';

class CastScreen extends ConsumerStatefulWidget {
  const CastScreen({super.key});

  @override
  ConsumerState<CastScreen> createState() => _CastScreenState();
}

enum _CastPhase { idle, animating, completed }

class _CastScreenState extends ConsumerState<CastScreen>
    with TickerProviderStateMixin {
  final _random = math.Random();
  final List<int> _lines = [];

  _CastPhase _phase = _CastPhase.idle;
  int _currentToss = 0;

  // Animation controllers for staggered coin flips
  final List<AnimationController> _coinFlipControllers = [];
  bool _coinsAnimating = false;

  @override
  void initState() {
    super.initState();
    // Pre-create coin animation controllers
    for (int i = 0; i < 3; i++) {
      _coinFlipControllers.add(AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 420 + i * 70),
      ));
    }
  }

  @override
  void dispose() {
    audioService.stop();
    for (var c in _coinFlipControllers) {
      c.dispose();
    }
    super.dispose();
  }

  int _sampleLine() {
    final toss = [_random.nextBool(), _random.nextBool(), _random.nextBool()];
    final heads = toss.where((e) => e).length;
    return heads >= 2 ? 1 : 0;
  }

  void _triggerCoinFlip() {
    // Staggered flip: each coin flips with a slight delay
    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 100), () {
        if (mounted && _coinsAnimating) {
          _coinFlipControllers[i].forward(from: 0);
        }
      });
    }
  }

  Future<void> _startRitual() async {
    if (_phase != _CastPhase.idle) return;

    setState(() {
      _phase = _CastPhase.animating;
      _lines.clear();
      _currentToss = 0;
      _coinsAnimating = true;
    });

    // Reset all coin controllers
    for (var c in _coinFlipControllers) {
      c.reset();
    }

    // Perform 6 tosses
    for (int i = 0; i < 6; i++) {
      if (!mounted || _phase != _CastPhase.animating) return;

      _currentToss = i;
      final line = _sampleLine();
      _lines.add(line);

      // Trigger haptic and sound
      HapticFeedback.mediumImpact();
      audioService.playDropSound();

      // Trigger staggered coin flip animation
      _triggerCoinFlip();

      setState(() {});

      // Wait before next toss
      await Future.delayed(const Duration(milliseconds: 820));
    }

    if (!mounted) return;

    setState(() {
      _phase = _CastPhase.completed;
      _coinsAnimating = false;
    });

    // Stay on completed screen for 1.5s to let user appreciate the hexagram
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    await ref
        .read(ritualStateProvider.notifier)
        .performRitual(sourceLines: _lines);
  }

  @override
  Widget build(BuildContext context) {
    final ritualState = ref.watch(ritualStateProvider);

    return InkBackground(
      child: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _startRitual,
          child: Column(
            children: [
              // Top bar - minimal
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () =>
                          ref.read(ritualStateProvider.notifier).reset(),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                      ),
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '今日投掷',
                      style: AppTypography.headlineSmall.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_lines.length}/6',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),

              // Progress dots
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Row(
                  children: List.generate(6, (index) {
                    final filled = index < _lines.length;
                    return Expanded(
                      child: Container(
                        height: 3,
                        margin: EdgeInsets.only(right: index == 5 ? 0 : 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(1.5),
                          color: filled
                              ? AppColors.textPrimary
                              : AppColors.border,
                        ),
                      ),
                    );
                  }),
                ),
              ),

              // Central animation stage
              Expanded(
                child: _CoinStage(
                  lines: _lines,
                  isAnimating: _phase == _CastPhase.animating,
                  currentToss: _currentToss,
                  coinControllers: _coinFlipControllers,
                ),
              ),

              // Instruction text
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Text(
                  _phase == _CastPhase.idle
                      ? '点击投掷'
                      : _phase == _CastPhase.animating
                          ? '投掷中'
                          : '完成',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),

              if (ritualState.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    ritualState.error!,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Central coin animation stage
class _CoinStage extends StatelessWidget {
  final List<int> lines;
  final bool isAnimating;
  final int currentToss;
  final List<AnimationController> coinControllers;

  const _CoinStage({
    required this.lines,
    required this.isAnimating,
    required this.currentToss,
    required this.coinControllers,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // The 3 coins with 3D staggered flip
        _ThreeCoins(
          lines: lines,
          isAnimating: isAnimating,
          coinControllers: coinControllers,
        ),

        const SizedBox(height: 32),

        // Stacked hexagram lines with fade-in + slide-up
        SizedBox(
          height: 108,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: List.generate(6, (index) {
              final lineIndex = 5 - index; // Reverse order: bottom to top
              final hasLine = lineIndex < lines.length;
              final lineValue = hasLine ? lines[lineIndex] : null;

              return _AnimatedHexagramLine(
                key: ValueKey('line_$lineIndex'),
                lineValue: lineValue,
                index: lineIndex,
                hasAppeared: hasLine,
              );
            }),
          ),
        ),
      ],
    );
  }
}

/// Single animated hexagram line with fade-in + slide-up
class _AnimatedHexagramLine extends StatefulWidget {
  final int? lineValue;
  final int index;
  final bool hasAppeared;

  const _AnimatedHexagramLine({
    super.key,
    required this.lineValue,
    required this.index,
    required this.hasAppeared,
  });

  @override
  State<_AnimatedHexagramLine> createState() => _AnimatedHexagramLineState();
}

class _AnimatedHexagramLineState extends State<_AnimatedHexagramLine>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    if (widget.hasAppeared) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(_AnimatedHexagramLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasAppeared && !oldWidget.hasAppeared) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: widget.lineValue == null ? 0.15 : _fadeAnim.value,
          child: SlideTransition(
            position: _slideAnim,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: widget.lineValue == 1
                  ? _YangLine()
                  : widget.lineValue == 0
                      ? _YinLine()
                      : _EmptyLine(),
            ),
          ),
        );
      },
    );
  }
}

/// 3 coins displayed horizontally with 3D staggered flip
class _ThreeCoins extends StatelessWidget {
  final List<int> lines;
  final bool isAnimating;
  final List<AnimationController> coinControllers;

  const _ThreeCoins({
    required this.lines,
    required this.isAnimating,
    required this.coinControllers,
  });

  @override
  Widget build(BuildContext context) {
    final currentLine = lines.isNotEmpty ? lines.last : null;

    return Column(
      children: [
        // Coin row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            final coinValue = _getCoinValue(index);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _Coin3D(
                value: coinValue,
                controller: coinControllers[index],
                index: index,
              ),
            );
          }),
        ),

        if (currentLine != null) ...[
          const SizedBox(height: 12),
          // Result indicator
          AnimatedOpacity(
            opacity: isAnimating ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Text(
              currentLine == 1 ? '阳' : '阴',
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ),
        ],
      ],
    );
  }

  int _getCoinValue(int index) {
    if (lines.isEmpty) return 1;
    final lastLine = lines.last;
    // Mix lastLine value with index for visual variety
    return (lastLine + index) % 2;
  }
}

/// Single coin with true 3D flip animation
class _Coin3D extends StatelessWidget {
  final int value; // 1 = yang (solid), 0 = yin (split)
  final AnimationController controller;
  final int index;

  const _Coin3D({
    required this.value,
    required this.controller,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        // Calculate 3D rotation angle (0 to pi for half flip, then settle)
        final t = controller.value;
        // Use easeOutBack for satisfying bounce effect
        final eased = Curves.easeOutBack.transform(t);
        final angle = eased * math.pi; // Half rotation (180 degrees)

        // Scale bounce effect
        final scale = 1.0 + math.sin(t * math.pi) * 0.15;

        // Determine which face to show based on rotation
        final showYang = value == 1;

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001) // Perspective
            ..rotateY(angle) // Y-axis rotation for flip
            ..scale(scale),
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: showYang
                    ? [
                        const Color(0xFFE0E0E0),
                        const Color(0xFFF8F8F8),
                        const Color(0xFFE8E8E8),
                      ]
                    : [
                        const Color(0xFFF5F5F5),
                        const Color(0xFFFAFAFA),
                        const Color(0xFFE0E0E0),
                      ],
              ),
              border: Border.all(
                color: const Color(0xFFDDDDDD),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: showYang
                  ? Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF1A1A1A),
                      ),
                    )
                  : Container(
                      width: 22,
                      height: 3,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(1.5),
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}

/// 阳爻 - solid line
class _YangLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        height: 8,
        width: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: const Color(0xFF1A1A1A),
        ),
      ),
    );
  }
}

/// 阴爻 - split line
class _YinLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        height: 8,
        width: 120,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 8,
              width: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              height: 8,
              width: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: const Color(0xFF1A1A1A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty placeholder line
class _EmptyLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        height: 8,
        width: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: AppColors.border,
        ),
      ),
    );
  }
}
