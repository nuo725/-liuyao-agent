import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../state/profile_hub_state.dart';
import '../../state/ritual_state.dart';
import '../../state/same_frequency_unlock_state.dart';

class MatchScreen extends ConsumerStatefulWidget {
  const MatchScreen({super.key});

  @override
  ConsumerState<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends ConsumerState<MatchScreen> {
  final _sameFrequencyPool = const <_MomentPost>[
    _MomentPost(
      signature: '101101',
      author: '若闻',
      role: '心理咨询师',
      content: '你拒绝，别人就知道了你的边界；你表达，别人就知道了你的观点。',
      imageUrl:
          'https://images.unsplash.com/photo-1511988617509-a57c8a288659?auto=format&fit=crop&w=1200&q=80',
    ),
    _MomentPost(
      signature: '101101',
      author: '季风',
      role: '纪录片导演',
      content: '先让自己坐下来，再讨论要不要继续冲，顺序比力度更重要。',
    ),
    _MomentPost(
      signature: '110010',
      author: '鹿野',
      role: '研究员',
      content: '你不是没有行动力，你只是还没决定先做哪一步。',
    ),
    _MomentPost(
      signature: '001100',
      author: '余海',
      role: '自由撰稿人',
      content: '今天只做一件小事：把最想逃避的一条消息，认真回完。',
      imageUrl:
          'https://images.unsplash.com/photo-1521572267360-ee0c2909d518?auto=format&fit=crop&w=1200&q=80',
    ),
    _MomentPost(
      signature: '010111',
      author: '林原',
      role: '摄影师',
      content: '这周最有价值的决定：停止“同时做三件事”。',
    ),
  ];

  final _historyStories = const <_MomentPost>[
    _MomentPost(
      author: '王阳明',
      role: '龙场悟道',
      content: '困境里最难的不是路，而是心。先把心安住，路会自己浮现。',
      imageUrl:
          'https://images.unsplash.com/photo-1454359179127-a9f7f9e75823?auto=format&fit=crop&w=1200&q=80',
    ),
    _MomentPost(
      author: '苏轼',
      role: '黄州岁月',
      content: '被推入低谷后，反而学会了把日常过成新的秩序与审美。',
    ),
    _MomentPost(
      author: '张骞',
      role: '出使西域',
      content: '方向不清的时候，不一定后退，也可以先去看更大的地图。',
      imageUrl:
          'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=1200&q=80',
    ),
  ];

  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  DateTime? _lastShakeTime;

  bool _showUnlockCard = false;
  bool _closingUnlockCard = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sameFrequencyUnlockProvider.notifier).initialize();
    });
    _startShakeDetection();
  }

  void _startShakeDetection() {
    _accelSubscription = accelerometerEventStream().listen((event) {
      final magnitude = math.sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );
      if (magnitude > 20) {
        _handleShake();
      }
    });
  }

  void _handleShake() {
    final now = DateTime.now();
    if (_lastShakeTime == null ||
        now.difference(_lastShakeTime!) > const Duration(seconds: 2)) {
      _lastShakeTime = now;
      if (!ref.read(sameFrequencyUnlockProvider)) {
        _triggerUnlock();
      }
    }
  }

  Future<void> _triggerUnlock() async {
    HapticFeedback.mediumImpact();
    // TODO(Backend Integration)[match_api#unlock-entry]:
    // 当前通过本地状态解锁同频入口；后端接入后由 unlock token 驱动。
    await ref.read(sameFrequencyUnlockProvider.notifier).unlock();
    if (!mounted) return;
    setState(() {
      _showUnlockCard = true;
      _closingUnlockCard = false;
    });
  }

  Future<void> _closeUnlockCard() async {
    if (!_showUnlockCard || _closingUnlockCard) return;
    setState(() => _closingUnlockCard = true);
    await Future.delayed(const Duration(milliseconds: 360));
    if (!mounted) return;
    setState(() {
      _showUnlockCard = false;
      _closingUnlockCard = false;
    });
  }

  Future<void> _openSameFrequencyHub({int initialTab = 0}) async {
    // TODO(Backend Integration)[match_api#samefreq-page]:
    // 同频页当前使用本地模拟数据；后端接入后替换为同频分页接口。
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _SameFrequencyHubScreen(
          initialTab: initialTab,
          currentSignature: _currentSignature(),
          matchedPosts: _matchedPosts(_currentSignature()),
          historyPosts: _historyStories,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _accelSubscription?.cancel();
    super.dispose();
  }

  String _currentSignature() {
    final lines = ref.read(ritualStateProvider).pattern?.lines;
    if (lines != null && lines.length == 6) {
      return lines.map((e) => e == 1 ? '1' : '0').join();
    }
    final today = DateTime.now();
    final base = today.year * 10000 + today.month * 100 + today.day;
    final random = math.Random(base);
    return List.generate(6, (_) => random.nextBool() ? '1' : '0').join();
  }

  List<_MomentPost> _matchedPosts(String signature) {
    final direct = _sameFrequencyPool
        .where((p) => p.signature == signature)
        .toList();
    if (direct.isNotEmpty) return direct;

    final ranked = [..._sameFrequencyPool]
      ..sort((a, b) {
        final da = _hammingDistance(a.signature ?? '', signature);
        final db = _hammingDistance(b.signature ?? '', signature);
        return da.compareTo(db);
      });
    return ranked.take(3).toList();
  }

  int _hammingDistance(String a, String b) {
    final n = math.min(a.length, b.length);
    var d = 0;
    for (int i = 0; i < n; i++) {
      if (a[i] != b[i]) d++;
    }
    return d + (a.length - b.length).abs();
  }

  @override
  Widget build(BuildContext context) {
    final isUnlocked = ref.watch(sameFrequencyUnlockProvider);

    return Container(
      color: const Color(0xFF070A12),
      child: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.24),
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
                    child: Row(
                      children: [
                        Text(
                          '此刻',
                          style: AppTypography.labelMedium.copyWith(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        if (isUnlocked)
                          GestureDetector(
                            onTap: () => _openSameFrequencyHub(initialTab: 0),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                Icons.hub_rounded,
                                size: 22,
                                color: Colors.white.withValues(alpha: 0.88),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: _GalaxyPlaza(
                    isUnlocked: isUnlocked,
                    signature: _currentSignature(),
                    onTriggerShake: _triggerUnlock,
                    onOpenHub: () => _openSameFrequencyHub(initialTab: 0),
                  ),
                ),
              ],
            ),

            if (_showUnlockCard)
              Positioned.fill(
                child: _UnlockGuideOverlay(
                  closing: _closingUnlockCard,
                  onOpenUsers: () async {
                    await _openSameFrequencyHub(initialTab: 0);
                  },
                  onOpenHistory: () async {
                    await _openSameFrequencyHub(initialTab: 1);
                  },
                  onClose: _closeUnlockCard,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Galaxy plaza: persistent "此刻" background ───

class _GalaxyPlaza extends StatefulWidget {
  final bool isUnlocked;
  final String signature;
  final Future<void> Function() onTriggerShake;
  final Future<void> Function() onOpenHub;

  const _GalaxyPlaza({
    required this.isUnlocked,
    required this.signature,
    required this.onTriggerShake,
    required this.onOpenHub,
  });

  @override
  State<_GalaxyPlaza> createState() => _GalaxyPlazaState();
}

class _GalaxyPlazaState extends State<_GalaxyPlaza>
    with SingleTickerProviderStateMixin {
  late final AnimationController _galaxyController;
  static const _orbitCenterAlignment = Alignment(0, -0.04);

  @override
  void initState() {
    super.initState();
    _galaxyController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _galaxyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _galaxyController,
            builder: (_, __) {
              return CustomPaint(
                painter: _GalaxyPainter(t: _galaxyController.value),
              );
            },
          ),
        ),
        Positioned.fill(
          child: SafeArea(
            child: Stack(
              children: [
                Align(
                  alignment: _orbitCenterAlignment,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      widget.isUnlocked
                          ? Icons.hub_rounded
                          : Icons.vibration_rounded,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ),
                Align(
                  alignment: const Alignment(0, 0.58),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.isUnlocked ? '同频已解锁' : '摇一摇，寻找同频',
                          style: AppTypography.labelLarge.copyWith(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.isUnlocked
                              ? '今日签名：${widget.signature}'
                              : '轻摇手机，触发一次探索',
                          style: AppTypography.bodySmall.copyWith(
                            color: Colors.white.withValues(alpha: 0.6),
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (widget.isUnlocked) ...[
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: () => widget.onOpenHub(),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF4B5F86),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(184, 44),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            child: const Text('查看同频'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GalaxyPainter extends CustomPainter {
  final double t; // 0..1

  _GalaxyPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    const bg0 = Color(0xFF070A12);
    const bg1 = Color(0xFF0B1020);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [bg0, bg1],
        ).createShader(rect),
    );

    final center = Offset(size.width * 0.5, size.height * 0.48);
    final maxR = math.min(size.width, size.height) * 0.42;

    // soft glow
    canvas.drawCircle(
      center,
      maxR * 0.62,
      Paint()
        ..color = const Color(0xFF6EE7FF).withValues(alpha: 0.06)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28),
    );

    // stars (deterministic)
    final rng = math.Random(42);
    for (int i = 0; i < 110; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = 0.6 + rng.nextDouble() * 1.4;
      final twinkle =
          (0.45 + 0.55 * math.sin((t * 2 * math.pi) + i * 0.37)).abs();
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()..color = Colors.white.withValues(alpha: 0.12 + 0.18 * twinkle),
      );
    }

    // orbit rings
    final orbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (int i = 1; i <= 3; i++) {
      orbitPaint.color = Colors.white.withValues(alpha: 0.08);
      canvas.drawCircle(center, maxR * i / 3, orbitPaint);
    }

    // orbiting star (one full loop every 12s)
    final a = t * 2 * math.pi;
    final p = Offset(
      center.dx + (maxR * 0.78) * math.cos(a),
      center.dy + (maxR * 0.48) * math.sin(a),
    );
    canvas.drawCircle(
      p,
      2.2,
      Paint()
        ..color = const Color(0xFFB7F4FF).withValues(alpha: 0.95)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // subtle trail
    for (int i = 1; i <= 10; i++) {
      final ta = a - i * 0.08;
      final tp = Offset(
        center.dx + (maxR * 0.78) * math.cos(ta),
        center.dy + (maxR * 0.48) * math.sin(ta),
      );
      canvas.drawCircle(
        tp,
        1.6,
        Paint()
          ..color = const Color(0xFFB7F4FF).withValues(alpha: 0.05 * (11 - i)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GalaxyPainter old) => old.t != t;
}

class _UnlockGuideOverlay extends StatelessWidget {
  final bool closing;
  final Future<void> Function() onOpenUsers;
  final Future<void> Function() onOpenHistory;
  final Future<void> Function() onClose;

  const _UnlockGuideOverlay({
    required this.closing,
    required this.onOpenUsers,
    required this.onOpenHistory,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: closing,
      child: AnimatedOpacity(
        opacity: closing ? 0 : 1,
        duration: const Duration(milliseconds: 260),
        child: Container(
          color: Colors.black.withValues(alpha: 0.28),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeInOutCubic,
            alignment: closing ? const Alignment(0.86, -0.9) : Alignment.center,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeInOutCubic,
              scale: closing ? 0.14 : 1,
              child: Container(
                width: 286,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 26,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '同频入口已解锁',
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '你可以查看当前同频用户，或进入历史同频。',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _GuideButton(
                      label: '查看同频用户',
                      icon: Icons.people_alt_outlined,
                      onTap: onOpenUsers,
                    ),
                    const SizedBox(height: 8),
                    _GuideButton(
                      label: '查看历史同频',
                      icon: Icons.history,
                      onTap: onOpenHistory,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: onClose,
                        child: const Text('关闭'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GuideButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Future<void> Function() onTap;

  const _GuideButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _ShakeHintToast extends StatefulWidget {
  const _ShakeHintToast();

  @override
  State<_ShakeHintToast> createState() => _ShakeHintToastState();
}

class _ShakeHintToastState extends State<_ShakeHintToast> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.night.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.vibration_rounded,
              size: 16,
              color: Colors.white.withValues(alpha: 0.9),
            ),
            const SizedBox(width: 8),
            Text(
              '摇一摇手机，解锁同频入口',
              style: AppTypography.labelMedium.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SameFrequencyHubScreen extends StatelessWidget {
  final int initialTab;
  final String currentSignature;
  final List<_MomentPost> matchedPosts;
  final List<_MomentPost> historyPosts;

  const _SameFrequencyHubScreen({
    required this.initialTab,
    required this.currentSignature,
    required this.matchedPosts,
    required this.historyPosts,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          title: const Text('同频'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '同频用户'),
              Tab(text: '历史同频'),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16, top: 2),
              child: Center(
                child: Text(
                  currentSignature,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiary,
                    fontFamily: 'monospace',
                    letterSpacing: 1.8,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _SameFrequencyTab(posts: matchedPosts),
            _HistoryTab(posts: historyPosts),
          ],
        ),
      ),
    );
  }
}

class _SameFrequencyTab extends ConsumerWidget {
  final List<_MomentPost> posts;

  const _SameFrequencyTab({required this.posts});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 40,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 12),
            Text(
              '暂无匹配内容',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '完成一次仪式后再来看看',
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      itemCount: posts.length,
      separatorBuilder: (context, index) => Container(
        height: 0.5,
        color: AppColors.divider,
        margin: const EdgeInsets.symmetric(vertical: 8),
      ),
      itemBuilder: (context, index) {
        return _MomentCard(post: posts[index], feedSource: '此刻-同频用户');
      },
    );
  }
}

class _HistoryTab extends ConsumerWidget {
  final List<_MomentPost> posts;

  const _HistoryTab({required this.posts});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      itemCount: posts.length,
      separatorBuilder: (context, index) => Container(
        height: 0.5,
        color: AppColors.divider,
        margin: const EdgeInsets.symmetric(vertical: 8),
      ),
      itemBuilder: (context, index) {
        return _MomentCard(post: posts[index], feedSource: '此刻-历史同频');
      },
    );
  }
}

class _MomentCard extends ConsumerStatefulWidget {
  final _MomentPost post;
  final String feedSource;

  const _MomentCard({required this.post, required this.feedSource});

  @override
  ConsumerState<_MomentCard> createState() => _MomentCardState();
}

class _MomentCardState extends ConsumerState<_MomentCard> {
  bool _liked = false;
  late int _likeCount;

  @override
  void initState() {
    super.initState();
    _likeCount = 36 + (widget.post.content.length % 120);
  }

  String get _key => '${widget.post.author}::${widget.post.content}';

  void _recordBrowse() {
    ref
        .read(profileHubStateProvider.notifier)
        .recordBrowse(
          source: widget.feedSource,
          contentKey: _key,
          title: widget.post.content.length > 20
              ? '${widget.post.content.substring(0, 20)}...'
              : widget.post.content,
          snippet: widget.post.content,
        );
  }

  void _toggleLike() {
    setState(() {
      if (_liked) {
        _liked = false;
        _likeCount--;
      } else {
        _liked = true;
        _likeCount++;
      }
    });
    final notifier = ref.read(profileHubStateProvider.notifier);
    if (_liked) {
      notifier.recordLike(
        source: widget.feedSource,
        contentKey: _key,
        title: widget.post.content.length > 20
            ? '${widget.post.content.substring(0, 20)}...'
            : widget.post.content,
        detail: widget.post.content,
      );
    } else {
      notifier.removeLike(source: widget.feedSource, contentKey: _key);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _recordBrowse,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                widget.post.author,
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.post.role,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          if (widget.post.imageUrl != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                widget.post.imageUrl!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: 180,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 180,
                  color: AppColors.surfaceVariant,
                  child: const Center(
                    child: Icon(Icons.image_outlined, color: Color(0xFFAAAAAA)),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            widget.post.content,
            style: AppTypography.bodyMedium.copyWith(
              height: 1.72,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              GestureDetector(
                onTap: _toggleLike,
                child: Icon(
                  _liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 16,
                  color: _liked
                      ? AppColors.primaryDark
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '$_likeCount',
                style: AppTypography.caption.copyWith(
                  color: _liked
                      ? AppColors.primaryDark
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MomentPost {
  final String? signature;
  final String author;
  final String role;
  final String content;
  final String? imageUrl;

  const _MomentPost({
    this.signature,
    required this.author,
    required this.role,
    required this.content,
    this.imageUrl,
  });
}
