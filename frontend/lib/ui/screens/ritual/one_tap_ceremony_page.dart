import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../models/interpretation_card.dart';
import '../../../models/pattern.dart';
import '../../../models/ritual_record.dart';
import '../../../models/session.dart';
import '../../../services/first_launch_flow_service.dart';
import '../../../state/ritual_state.dart';
import 'first_ritual_response_page.dart';
import 'response_screen.dart';

const _yaoLabels = ['初', '二', '三', '四', '五', '上'];

class OneTapCeremonyPage extends ConsumerStatefulWidget {
  const OneTapCeremonyPage({super.key});

  @override
  ConsumerState<OneTapCeremonyPage> createState() => _OneTapCeremonyPageState();
}

class _OneTapCeremonyPageState extends ConsumerState<OneTapCeremonyPage>
    with TickerProviderStateMixin {
  late final List<int> _lines;
  late final List<AnimationController> _coinControllers;
  late final List<Animation<double>> _coinBounceAnims;
  late final List<Animation<double>> _coinRotAnims;
  late final List<Animation<double>> _coinScaleAnims;
  late final List<Animation<double>> _coinOpacityAnims;

  bool _navigated = false;
  int _visibleLineCount = 0;

  @override
  void initState() {
    super.initState();

    final random = math.Random();
    _lines = List<int>.generate(6, (_) => random.nextBool() ? 1 : 0);

    _coinControllers = List.generate(
      3,
      (i) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 700 + i * 80),
      ),
    );

    _coinBounceAnims = _coinControllers.map((c) {
      return TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween<double>(
            begin: 1.0,
            end: 1.12,
          ).chain(CurveTween(curve: Curves.easeOut)),
          weight: 20,
        ),
        TweenSequenceItem(
          tween: Tween<double>(
            begin: 1.12,
            end: 1.0,
          ).chain(CurveTween(curve: Curves.easeIn)),
          weight: 20,
        ),
        TweenSequenceItem(
          tween: Tween<double>(
            begin: 1.0,
            end: 1.06,
          ).chain(CurveTween(curve: Curves.easeOut)),
          weight: 15,
        ),
        TweenSequenceItem(
          tween: Tween<double>(
            begin: 1.06,
            end: 1.0,
          ).chain(CurveTween(curve: Curves.easeIn)),
          weight: 15,
        ),
        TweenSequenceItem(
          tween: Tween<double>(
            begin: 1.0,
            end: 1.03,
          ).chain(CurveTween(curve: Curves.easeOut)),
          weight: 10,
        ),
        TweenSequenceItem(
          tween: Tween<double>(
            begin: 1.03,
            end: 1.0,
          ).chain(CurveTween(curve: Curves.easeIn)),
          weight: 20,
        ),
      ]).animate(c);
    }).toList();

    _coinRotAnims = _coinControllers.map((c) {
      return Tween<double>(
        begin: 0,
        end: 4 * math.pi,
      ).animate(CurvedAnimation(parent: c, curve: Curves.easeInOut));
    }).toList();

    _coinScaleAnims = _coinControllers.map((c) {
      return TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween<double>(
            begin: 0.3,
            end: 1.0,
          ).chain(CurveTween(curve: Curves.easeOut)),
          weight: 50,
        ),
        TweenSequenceItem(
          tween: Tween<double>(begin: 1.0, end: 1.0),
          weight: 30,
        ),
        TweenSequenceItem(
          tween: Tween<double>(
            begin: 1.0,
            end: 0.6,
          ).chain(CurveTween(curve: Curves.easeIn)),
          weight: 20,
        ),
      ]).animate(c);
    }).toList();

    _coinOpacityAnims = _coinControllers.map((c) {
      return TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween<double>(
            begin: 0.0,
            end: 1.0,
          ).chain(CurveTween(curve: Curves.easeOut)),
          weight: 30,
        ),
        TweenSequenceItem(
          tween: Tween<double>(begin: 1.0, end: 1.0),
          weight: 50,
        ),
        TweenSequenceItem(
          tween: Tween<double>(
            begin: 1.0,
            end: 0.0,
          ).chain(CurveTween(curve: Curves.easeIn)),
          weight: 20,
        ),
      ]).animate(c);
    }).toList();

    _runAnimation();
  }

  Future<void> _runAnimation() async {
    for (int i = 0; i < 3; i++) {
      final delay = Duration(milliseconds: i * 80);
      final duration = 700 + i * 80;
      Future.delayed(delay, () async {
        if (!mounted || _navigated) return;
        _coinControllers[i].forward(from: 0);

        Future.delayed(Duration(milliseconds: (duration * 0.4).toInt()), () {
          if (!mounted || _navigated) return;
          HapticFeedback.mediumImpact();
        });
        Future.delayed(Duration(milliseconds: (duration * 0.6).toInt()), () {
          if (!mounted || _navigated) return;
          HapticFeedback.lightImpact();
        });
        Future.delayed(Duration(milliseconds: (duration * 0.78).toInt()), () {
          if (!mounted || _navigated) return;
          HapticFeedback.lightImpact();
        });
      });
    }

    for (int i = 0; i < 6; i++) {
      Future.delayed(Duration(milliseconds: 600 + i * 200), () {
        if (!mounted || _navigated) return;
        setState(() => _visibleLineCount = i + 1);
        HapticFeedback.lightImpact();
      });
    }

    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted || _navigated) return;

    await _performAndNavigate();
  }

  Future<void> _performAndNavigate() async {
    if (_navigated || !mounted) return;
    _navigated = true;

    try {
      await ref
          .read(ritualStateProvider.notifier)
          .performRitual(sourceLines: _lines);
    } catch (e) {
      debugPrint('[OneTapCeremony] performRitual failed: $e, using local mock');
      _buildMockAndNavigate();
      return;
    }

    final ritual = ref.read(ritualStateProvider);
    if (ritual.phase != RitualPhase.response || ritual.session == null) {
      _buildMockAndNavigate();
      return;
    }

    await _navigateToResponsePage();
  }

  void _buildMockAndNavigate() {
    if (!mounted) return;

    const pool = [
      '你正在经历一个“旧秩序松动、新方向未明”的阶段。先别急着下结论，先看清当下最真实的感受。',
      '你对自己的要求很高，这不是问题本身；问题在于你把“探索”误当成了“必须立刻正确”。',
      '当身体说“想安静”，头脑说“应该热闹”时，先尊重身体，答案会更快出现。',
    ];

    final body = pool[DateTime.now().millisecond % pool.length];
    final pattern = Pattern(
      lines: _lines,
      movingLines: const <int>[],
      createdAt: DateTime.now(),
    );

    final card = InterpretationCard(
      id: 'mock-${DateTime.now().millisecondsSinceEpoch}',
      question: ref.read(ritualStateProvider).question ?? '',
      pattern: pattern,
      riskLevel: RiskLevel.low,
      createdAt: DateTime.now(),
      content: InterpretationContent(
        summary: body,
        focusPoints: const <String>[],
        afterglow: '',
        followupDirections: const <String>[
          '我可以从哪里开始？',
          '这种感觉是从什么时候开始的？',
          '有没有一次经历让我看见了不同的可能？',
        ],
        body: body,
        quoteText: null,
        quoteSource: null,
        visualBlocks: const <ResponseVisualBlock>[],
      ),
      needsClarification: false,
    );

    final session = Session(
      id: card.id,
      question: card.question,
      tag: null,
      pattern: pattern,
      initialCard: card,
      messages: const <FollowupMessage>[],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final record = RitualRecord(
      mood: card.question,
      hexagram: pattern.lines,
      dateTime: DateTime.now(),
    );

    ref
        .read(ritualStateProvider.notifier)
        .forceSetSession(
          pattern: pattern,
          card: card,
          session: session,
          record: record,
        );

    _navigateToResponsePage();
  }

  Future<void> _navigateToResponsePage() async {
    final isFirstRitual = !(await firstLaunchFlowServiceProvider
        .isFirstRitualDone());
    if (!mounted) return;

    // TODO(Backend Integration)[ritual_api#preview-gate]:
    // 首次门禁与会话绑定目前由本地标记驱动，后续由服务端会话状态返回。
    if (isFirstRitual) {
      await firstLaunchFlowServiceProvider.markFirstRitualDone();
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => isFirstRitual
            ? const FirstRitualResponsePage()
            : const ResponseScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _navigated = true;
    for (final c in _coinControllers) {
      if (c.isAnimating) c.stop();
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            SizedBox(
              height: 150,
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    3,
                    (i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: _FreshCoin(
                        controllers: _coinControllers,
                        bounceAnims: _coinBounceAnims,
                        rotAnims: _coinRotAnims,
                        scaleAnims: _coinScaleAnims,
                        opacityAnims: _coinOpacityAnims,
                        index: i,
                        value: _lines[i % _lines.length],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 140,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(6, (idx) {
                              return SizedBox(
                                height: 18,
                                width: 20,
                                child: Text(
                                  _yaoLabels[5 - idx],
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textTertiary,
                                    fontSize: 11,
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(6, (idx) {
                              final reversedIdx = 5 - idx;
                              final hasLine = reversedIdx < _visibleLineCount;
                              return _AnimatedHexLine(
                                key: ValueKey('line_$reversedIdx'),
                                value: hasLine ? _lines[reversedIdx] : null,
                                visible: hasLine,
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        _visibleLineCount < 6 ? '投掷中…' : '完成',
                        key: ValueKey(_visibleLineCount),
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FreshCoin extends StatelessWidget {
  final List<AnimationController> controllers;
  final List<Animation<double>> bounceAnims;
  final List<Animation<double>> rotAnims;
  final List<Animation<double>> scaleAnims;
  final List<Animation<double>> opacityAnims;
  final int index;
  final int value;

  const _FreshCoin({
    required this.controllers,
    required this.bounceAnims,
    required this.rotAnims,
    required this.scaleAnims,
    required this.opacityAnims,
    required this.index,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final ctrl = controllers[index];

    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, child) {
        final bounce = bounceAnims[index].value;
        final rotation = rotAnims[index].value;
        final scale = scaleAnims[index].value * bounce;
        final opacity = opacityAnims[index].value;

        return FadeTransition(
          opacity: AlwaysStoppedAnimation(opacity.clamp(0.0, 1.0)),
          child: ScaleTransition(
            scale: AlwaysStoppedAnimation(scale.clamp(0.0, 1.5)),
            child: RotationTransition(
              turns: AlwaysStoppedAnimation(rotation / (2 * math.pi)),
              child: Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF8F8F8),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFE8F5F0),
                    ),
                    child: Center(
                      child: value == 1
                          ? Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary.withValues(
                                  alpha: 0.85,
                                ),
                              ),
                            )
                          : Container(
                              width: 14,
                              height: 2,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(1),
                                color: AppColors.primary.withValues(
                                  alpha: 0.85,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AnimatedHexLine extends StatefulWidget {
  final int? value;
  final bool visible;

  const _AnimatedHexLine({
    super.key,
    required this.value,
    required this.visible,
  });

  @override
  State<_AnimatedHexLine> createState() => _AnimatedHexLineState();
}

class _AnimatedHexLineState extends State<_AnimatedHexLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _fadeAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    if (widget.visible) {
      _ctrl.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(_AnimatedHexLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Opacity(
          opacity: widget.value == null ? 0.15 : _fadeAnim.value,
          child: SlideTransition(
            position: _slideAnim,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: SizedBox(
                height: 18,
                width: 130,
                child: widget.value == 1
                    ? const _YangLine()
                    : widget.value == 0
                    ? const _YinLine()
                    : const _EmptyLine(),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _YangLine extends StatelessWidget {
  const _YangLine();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        height: 8,
        width: 130,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: const Color(0xFF1A1A1A),
        ),
      ),
    );
  }
}

class _YinLine extends StatelessWidget {
  const _YinLine();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        height: 8,
        width: 130,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 8,
              width: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              height: 8,
              width: 52,
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

class _EmptyLine extends StatelessWidget {
  const _EmptyLine();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        height: 8,
        width: 130,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: AppColors.border,
        ),
      ),
    );
  }
}
