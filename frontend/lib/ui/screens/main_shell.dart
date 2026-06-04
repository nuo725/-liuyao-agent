import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/constants/app_spacing.dart';
import '../../state/ritual_state.dart';
import '../common/ink_background.dart';
import 'activity/activity_list_screen.dart';
import 'community_screen.dart';
import 'match_screen.dart';
import 'profile_screen.dart';
import 'ritual/ritual_root_screen.dart';
import 'ritual/ritual_chat_screen.dart';
import 'ritual/ritual_entry_bottom_sheet.dart';

class MainShell extends ConsumerStatefulWidget {
  final bool autoOpenRitualOnStart;

  const MainShell({super.key, this.autoOpenRitualOnStart = false});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0;
  bool _openedStartupRitual = false;
  final GlobalKey<CommunityScreenState> _communityKey =
      GlobalKey<CommunityScreenState>();

  late final List<Widget> _screens = [
    CommunityScreen(key: _communityKey),
    const MatchScreen(),
    const ActivityListScreen(),
    const ProfileScreen(),
  ];

  static const _items = [
    _NavItem(icon: Icons.forum_outlined, label: '宽窄之间'),
    _NavItem(icon: Icons.explore_outlined, label: '此刻'),
    _NavItem(icon: Icons.event_outlined, label: '活动'),
    _NavItem(icon: Icons.person_outline_rounded, label: '我的'),
  ];

  /// 首次体验直接进入仪式，跳过 ritual_entry_bottom_sheet
  Future<void> _openFirstExperienceRitual() async {
    ref.read(ritualStateProvider.notifier).reset();
    ref.read(ritualStateProvider.notifier).setInputMode(
          RitualInputMode.manualThrow,
        );

    await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => const RitualRootScreen(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );

    if (!mounted) return;
    _communityKey.currentState?.refreshPublished();
  }

  Future<void> _openRitual() async {
    final ritual = ref.read(ritualStateProvider);

    if (ritual.phase == RitualPhase.closure) {
      ref.read(ritualStateProvider.notifier).reset();
    }

    final result = await showModalBottomSheet<RitualEntryResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const RitualEntryBottomSheet(),
    );

    if (!mounted || result == null) return;

    switch (result) {
      case RitualEntryStartNew():
        final selectedMode = ref.read(ritualStateProvider).inputMode;
        ref.read(ritualStateProvider.notifier).reset();
        ref
            .read(ritualStateProvider.notifier)
            .setInputMode(selectedMode);
        await Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (_, animation, __) => const RitualRootScreen(),
            transitionsBuilder: (_, animation, __, child) => FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
              child: child,
            ),
            transitionDuration: const Duration(milliseconds: 350),
          ),
        );
      case RitualEntryContinueChat():
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const RitualChatScreen(),
          ),
        );
    }

    final refreshFuture = _communityKey.currentState?.refreshPublished();
    if (refreshFuture != null) {
      await refreshFuture;
    }
  }

  void _handleTabTap(int i) {
    setState(() => _currentIndex = i);
    if (i == 0) {
      _communityKey.currentState?.refreshPublished();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.autoOpenRitualOnStart && !_openedStartupRitual) {
      _openedStartupRitual = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _openFirstExperienceRitual();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: InkBackground(
        child: IndexedStack(index: _currentIndex, children: _screens),
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        items: _items,
        onTap: _handleTabTap,
        onCenterTap: _openRitual,
        darkMode: _currentIndex == 1,
      ),
    );
  }
}

class _BottomNav extends StatefulWidget {
  final int currentIndex;
  final List<_NavItem> items;
  final ValueChanged<int> onTap;
  final VoidCallback onCenterTap;
  final bool darkMode;

  const _BottomNav({
    required this.currentIndex,
    required this.items,
    required this.onTap,
    required this.onCenterTap,
    this.darkMode = false,
  });

  @override
  State<_BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<_BottomNav>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathController;
  late final Animation<double> _breathScale;

  // Track press state for visual feedback
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _breathScale = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _breathController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails details) {
    if (_isPressed) {
      setState(() => _isPressed = false);
      widget.onCenterTap();
    }
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: widget.darkMode ? const Color(0xFF0B1020) : AppColors.surface,
          border: Border(
            top: BorderSide(
              color: widget.darkMode
                  ? Colors.white.withValues(alpha: 0.12)
                  : AppColors.border,
              width: 0.5,
            ),
          ),
        ),
        child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
          children: [
            // Nav items
            Row(
              children: [
                Expanded(
                  child: _NavCell(
                    item: widget.items[0],
                    selected: widget.currentIndex == 0,
                    onTap: () => widget.onTap(0),
                    darkMode: widget.darkMode,
                  ),
                ),
                Expanded(
                  child: _NavCell(
                    item: widget.items[1],
                    selected: widget.currentIndex == 1,
                    onTap: () => widget.onTap(1),
                    darkMode: widget.darkMode,
                  ),
                ),
                // Space for center button
                const SizedBox(width: 64),
                Expanded(
                  child: _NavCell(
                    item: widget.items[2],
                    selected: widget.currentIndex == 2,
                    onTap: () => widget.onTap(2),
                    darkMode: widget.darkMode,
                  ),
                ),
                Expanded(
                  child: _NavCell(
                    item: widget.items[3],
                    selected: widget.currentIndex == 3,
                    onTap: () => widget.onTap(3),
                    darkMode: widget.darkMode,
                  ),
                ),
              ],
            ),

            // Center floating button - filled circle with breathing icon
            Positioned(
              top: 12,
              child: Semantics(
                button: true,
                label: '开始体验',
                child: GestureDetector(
                  onTapDown: _handleTapDown,
                  onTapUp: _handleTapUp,
                  onTapCancel: _handleTapCancel,
                  child: AnimatedScale(
                    scale: _isPressed ? 0.88 : 1.0,
                    duration: const Duration(milliseconds: 100),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                        // Clean flat design — no outer shadow
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                            spreadRadius: -2,
                          ),
                        ],
                      ),
                      child: AnimatedBuilder(
                        animation: _breathScale,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _breathScale.value,
                            child: const Icon(
                              Icons.auto_awesome_rounded,
                              size: 22,
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavCell extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;
  final bool darkMode;

  const _NavCell({
    required this.item,
    required this.selected,
    required this.onTap,
    this.darkMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = darkMode
        ? (selected
              ? Colors.white.withValues(alpha: 0.95)
              : Colors.white.withValues(alpha: 0.58))
        : (selected ? AppColors.textPrimary : AppColors.textTertiary);

    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, size: AppSpacing.iconMedium, color: color),
            const SizedBox(height: 4),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelSmall.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            // Dot indicator — 6px circle when selected
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: selected ? 6 : 0,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: darkMode ? const Color(0xFF56D7AF) : AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem({required this.icon, required this.label});
}
