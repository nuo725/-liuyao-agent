import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../services/first_launch_flow_service.dart';
import 'auth/login_gate_screen.dart';
import 'main_shell.dart';
import 'onboarding_hook_screen.dart';

class LaunchGateScreen extends StatefulWidget {
  const LaunchGateScreen({super.key});

  @override
  State<LaunchGateScreen> createState() => _LaunchGateScreenState();
}

enum _LaunchStage { splash, loading, onboarding, main }

class _LaunchGateScreenState extends State<LaunchGateScreen>
    with SingleTickerProviderStateMixin {
  _LaunchStage _stage = _LaunchStage.splash;
  bool _autoOpenRitualOnMain = false;
  double _splashOpacity = 0.0;
  late final AnimationController _splashController;
  late final Animation<double> _sloganOpacity;
  late final Animation<Offset> _sloganSlide;

  @override
  void initState() {
    super.initState();
    _splashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _sloganOpacity = CurvedAnimation(
      parent: _splashController,
      curve: const Interval(0.62, 1.0, curve: Curves.easeOut),
    );
    _sloganSlide = Tween<Offset>(
      begin: const Offset(0, 0.22),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _splashController,
        curve: const Interval(0.62, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() => _splashOpacity = 1.0);
      _splashController.forward(from: 0);
      _runSplashThenBootstrap();
    });
  }

  Future<void> _runSplashThenBootstrap() async {
    await Future.delayed(const Duration(milliseconds: 2400));
    if (!mounted) return;
    setState(() => _splashOpacity = 0.0);
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _stage = _LaunchStage.loading);
    await _bootstrap();
  }

  @override
  void dispose() {
    _splashController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final firstLaunchDone = await firstLaunchFlowServiceProvider.isCompleted();
      if (!mounted) return;

      setState(() {
        if (firstLaunchDone) {
          _stage = _LaunchStage.main;
          _autoOpenRitualOnMain = false;
        } else {
          _stage = _LaunchStage.onboarding;
          _autoOpenRitualOnMain = false;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _LaunchStage.onboarding;
        _autoOpenRitualOnMain = false;
      });
    }
  }

  Future<void> _startFirstExperience() async {
    await firstLaunchFlowServiceProvider.markCompleted();
    if (!mounted) return;
    setState(() {
      _autoOpenRitualOnMain = true;
      _stage = _LaunchStage.main;
    });
  }

  Future<void> _skipToLogin() async {
    await firstLaunchFlowServiceProvider.markCompleted();
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const LoginGateScreen(
          title: '注册 / 登录',
          subtitle: '登录后可同步你的记录、互动与权益状态。',
        ),
      ),
    );
    if (!mounted) return;

    setState(() {
      _autoOpenRitualOnMain = false;
      _stage = _LaunchStage.main;
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_stage) {
      case _LaunchStage.splash:
        return Scaffold(
          backgroundColor: const Color(0xFF1A1A1A),
          body: AnimatedOpacity(
            opacity: _splashOpacity,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            child: Stack(
              children: [
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _splashController,
                    builder: (_, __) => CustomPaint(
                      painter: _SplashGalaxyPainter(p: _splashController.value),
                    ),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 78,
                        height: 78,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.08),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '窄',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: Colors.white.withValues(alpha: 0.92),
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        '宽窄·Orbit',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FadeTransition(
                        opacity: _sloganOpacity,
                        child: SlideTransition(
                          position: _sloganSlide,
                          child: Text(
                            '每一颗孤星都能找到属于自己的银河',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.68),
                              fontSize: 13,
                              letterSpacing: 0.8,
                            ),
                            textAlign: TextAlign.center,
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
      case _LaunchStage.loading:
        return const Scaffold(
          backgroundColor: AppColors.background,
          body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      case _LaunchStage.onboarding:
        return OnboardingHookScreen(
          onStartExperience: _startFirstExperience,
          onSkipToLogin: _skipToLogin,
        );
      case _LaunchStage.main:
        return MainShell(autoOpenRitualOnStart: _autoOpenRitualOnMain);
    }
  }
}

class _SplashGalaxyPainter extends CustomPainter {
  final double p; // 0..1
  const _SplashGalaxyPainter({required this.p});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    const bg0 = Color(0xFF0A0B10);
    const bg1 = Color(0xFF14192B);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.2, -0.4),
          radius: 1.1,
          colors: [bg1, bg0],
        ).createShader(rect),
    );

    final center = Offset(size.width * 0.5, size.height * 0.42);
    final orbitR = math.min(size.width, size.height) * 0.18;

    // progress mapping: 0..0.65 orbit, 0.65..1 merge into galaxy
    final orbitPhase = (p / 0.65).clamp(0.0, 1.0);
    final mergePhase = ((p - 0.65) / 0.35).clamp(0.0, 1.0);

    // faint orbit ring (fade out on merge)
    final ringAlpha = (0.22 * (1 - mergePhase)).clamp(0.0, 0.22);
    canvas.drawCircle(
      center,
      orbitR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: ringAlpha),
    );

    // single star along orbit (one loop)
    final a = orbitPhase * 2 * math.pi;
    final starPos = Offset(
      center.dx + orbitR * math.cos(a),
      center.dy + orbitR * math.sin(a),
    );

    // galaxy core appears during merge
    final coreR = orbitR * (0.16 + 0.56 * mergePhase);
    canvas.drawCircle(
      center,
      coreR,
      Paint()
        ..color = const Color(0xFF6EE7FF).withValues(alpha: 0.06 + 0.16 * mergePhase)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );

    // star trail
    for (int i = 1; i <= 10; i++) {
      final ta = a - i * 0.12;
      final tp = Offset(
        center.dx + orbitR * math.cos(ta),
        center.dy + orbitR * math.sin(ta),
      );
      canvas.drawCircle(
        tp,
        1.3,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.03 * (11 - i) * (1 - mergePhase)),
      );
    }

    // moving star shrinks into the core
    final collapsed = Offset.lerp(starPos, center, Curves.easeInOut.transform(mergePhase))!;
    final starR = 2.2 * (1 - 0.75 * mergePhase);
    canvas.drawCircle(
      collapsed,
      starR,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // background stars (fade in with merge)
    final rng = math.Random(7);
    for (int i = 0; i < 80; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = 0.6 + rng.nextDouble() * 1.3;
      final tw = (0.5 + 0.5 * math.sin((p * 2 * math.pi) + i * 0.4)).abs();
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..color = Colors.white.withValues(alpha: (0.04 + 0.18 * mergePhase) * (0.55 + 0.45 * tw)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SplashGalaxyPainter oldDelegate) =>
      oldDelegate.p != p;
}
