import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/constants/app_spacing.dart';
import '../../services/audio_service.dart';
import '../../services/auth_service.dart';
import '../../state/auth_state.dart';
import '../../state/credit_state.dart';
import '../../state/profile_hub_state.dart';
import '../../state/ritual_state.dart';
import '../common/buttons.dart';
import 'auth/login_gate_screen.dart';
import 'benefits_center_screen.dart';
import '../../models/tag_identity.dart';
import 'tag_identity/tag_identity_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
// ProfileScreen — Sliver immersive architecture
// ═══════════════════════════════════════════════════════════════════════════

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

Future<void> _showDeleteAccountDialogV2(
  BuildContext context,
  WidgetRef ref,
) async {
  final confirmController = TextEditingController();
  bool agreed = false;

  Future<void> openAgreement(String title) async {
    final content = title == '注销协议'
        ? _kDeleteAgreementText
        : _kDeletePrivacyText;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: AppColors.surface,
          appBar: AppBar(
            title: Text(title),
            backgroundColor: AppColors.surface,
          ),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Text(
                content,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.8,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  try {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        var step = 0;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final canContinue = agreed;
            final canConfirm = confirmController.text.trim() == '注销';

            if (step == 0) {
              return AlertDialog(
                title: const Text('注销账号'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '注销后，你的账号数据将被永久删除，包括：\n\n'
                      '• 个人资料与设置\n'
                      '• 仪式记录与解读\n'
                      '• 社区帖子与互动记录\n'
                      '• 权益与余额\n\n'
                      '此操作不可撤销，请先阅读并确认相关协议。',
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: agreed,
                          activeColor: AppColors.primary,
                          onChanged: (v) {
                            setDialogState(() => agreed = v ?? false);
                          },
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                                children: [
                                  const TextSpan(text: '我已阅读并同意'),
                                  TextSpan(
                                    text: '《注销协议》',
                                    style: const TextStyle(
                                      color: AppColors.primaryDark,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () =>
                                          openAgreement('注销协议'),
                                  ),
                                  const TextSpan(text: '与'),
                                  TextSpan(
                                    text: '《数据处理说明》',
                                    style: const TextStyle(
                                      color: AppColors.primaryDark,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () =>
                                          openAgreement('数据处理说明'),
                                  ),
                                  const TextSpan(text: '，'),
                                  const TextSpan(
                                    text: '并确认该操作会永久删除账号数据。',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('取消'),
                  ),
                  FilledButton(
                    onPressed: canContinue
                        ? () => setDialogState(() => step = 1)
                        : null,
                    child: const Text('继续注销'),
                  ),
                ],
              );
            }

            return AlertDialog(
              title: const Text('确认注销'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('请输入“注销”以确认：'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmController,
                    autofocus: true,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: const InputDecoration(
                      hintText: '注销',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: canConfirm
                      ? () {
                          Navigator.pop(ctx);
                          ref.read(authStateProvider.notifier).logout();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('账号注销请求已提交（模拟）'),
                            ),
                          );
                        }
                      : null,
                  child: const Text('确认注销'),
                ),
              ],
            );
          },
        );
      },
    );
  } finally {
    confirmController.dispose();
  }
}

const String _kDeleteAgreementText = '''注销协议（模拟版本）
更新日期：2026-04-22

一、账号注销说明
注销后，账号关联的数据将被永久删除，且无法恢复。请确保你已了解注销带来的全部后果。

二、数据范围
包括但不限于个人资料、仪式记录、社区互动、分享内容与权益信息。

三、确认责任
你确认当前操作为本人真实意愿，并已充分理解后果。

四、协议变更
正式版本上线后，将以应用内说明为准。''';

const String _kDeletePrivacyText = '''数据处理说明（模拟版本）
更新日期：2026-04-22

一、处理目的
仅用于完成账号注销流程的前端说明与交互演示。

二、删除范围
注销后将清除与你账号关联的本地展示数据与记录。

三、说明
该页面仅为 UI 演示，不代表真实后端处理结果。''';

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final coverHeight = screenHeight * 0.85;
    final collapsedHeight = MediaQuery.of(context).padding.top + 56;

    final ritual = ref.watch(ritualStateProvider);
    final hub = ref.watch(profileHubStateProvider);
    final auth = ref.watch(authStateProvider);

    final user = auth.user;

    final name = (user?.username ?? '').trim().isEmpty
        ? '访客'
        : (user?.username ?? '访客');
    final bio = (user?.bio ?? '').trim().isEmpty
        ? '在探索中，慢慢看清自己'
        : (user?.bio ?? '在探索中，慢慢看清自己');
    final rawId = user?.id ?? '';
    final shortId = rawId.length > 8 ? rawId.substring(0, 8) : rawId;
    final userAvatarUrl = user?.avatarUrl;
    final userCoverUrl = user?.coverUrl;

    final weekCount = ritual.history
        .where((e) => e.dateTime.isAfter(DateTime.now().subtract(const Duration(days: 7))))
        .length;
    final currentTag = ritual.session?.tag ?? ritual.questionTag;
    final tagSnapshot = TagIdentitySnapshot.preview(
      questionTag: currentTag,
      sourceTitle: ritual.session?.question ?? '最近一次解读',
      history: ritual.history,
      origin: TagIdentityOrigin.profile,
      createdAt:
          ritual.session?.createdAt ??
          (ritual.history.isNotEmpty ? ritual.history.last.dateTime : DateTime.now()),
    );

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── SliverAppBar — 85% immersive cover ─────────────────────────
          SliverAppBar(
            expandedHeight: coverHeight,
            collapsedHeight: collapsedHeight,
            pinned: true,
            stretch: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: const SizedBox.shrink(),
            actions: [
              IconButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const _SettingsPage()),
                ),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.75),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.settings_outlined,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _CoverSection(
                coverHeight: coverHeight,
                isAnonymous: auth.isAnonymous,
                isLoggedIn: auth.isLoggedIn,
                name: name,
                shortId: shortId,
                bio: bio,
                avatarUrl: userAvatarUrl,
                coverUrl: userCoverUrl,
                onLoginTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const LoginGateScreen(
                      title: '登录',
                      subtitle: '登录后开启你的共鸣探索之旅',
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── White body — slides up over cover ─────────────────────────
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.cream,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 28),

                  // Stats row
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.pageHorizontal,
                    ),
                    child: Row(
                      children: [
                        _StatPill(label: '累计', value: ritual.history.length.toString()),
                        const SizedBox(width: 10),
                        _StatPill(label: '近7天', value: weekCount.toString()),
                        const SizedBox(width: 10),
                        _StatPill(label: '互动', value: hub.interactions.length.toString()),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.pageHorizontal,
                    ),
                    child: _TagIdentityCard(
                      snapshot: tagSnapshot,
                      onOpenIdentity: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TagIdentityScreen(snapshot: tagSnapshot),
                        ),
                      ),
                      onOpenFeed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TagFeedScreen(snapshot: tagSnapshot),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Divider
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.pageHorizontal,
                    ),
                    child: Container(height: 0.5, color: AppColors.border),
                  ),

                  const SizedBox(height: 4),

                  // Menu list
                  _MenuSection(),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Cover Section — flexible space content
// ═══════════════════════════════════════════════════════════════════════════

class _CoverSection extends ConsumerStatefulWidget {
  final double coverHeight;
  final bool isAnonymous;
  final bool isLoggedIn;
  final String name;
  final String shortId;
  final String bio;
  final String? avatarUrl;
  final String? coverUrl;
  final VoidCallback onLoginTap;

  const _CoverSection({
    required this.coverHeight,
    required this.isAnonymous,
    required this.isLoggedIn,
    required this.name,
    required this.shortId,
    required this.bio,
    this.avatarUrl,
    this.coverUrl,
    required this.onLoginTap,
  });

  @override
  ConsumerState<_CoverSection> createState() => _CoverSectionState();
}

class _CoverSectionState extends ConsumerState<_CoverSection> {
  static const _mockAvatarUrl =
      'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=200&q=80';
  static const _mockCoverUrl =
      'https://images.unsplash.com/photo-1506744626753-eda818c6cce5?auto=format&fit=crop&w=800&q=80';
  static const _mockShortId = '79922df5';
  static const _mockBio = '高开放性，在宽窄之间保持内心的秩序与温良。';

  String get _effectiveCoverUrl => widget.coverUrl ?? _mockCoverUrl;
  String get _effectiveAvatarUrl => widget.avatarUrl ?? _mockAvatarUrl;

  /// 将 URL 字符串转为 ImageProvider，支持 file:// 本地路径
  ImageProvider _resolveImage(String url) {
    if (url.startsWith('file://') || url.startsWith('/')) {
      final path = url.startsWith('file://') ? url.substring(7) : url;
      return FileImage(File(path));
    }
    return NetworkImage(url);
  }

  Future<void> _navigateToEdit() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const _ProfileEditPage()),
    );
  }

  Future<void> _openShareProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ShareProfilePage(
          name: widget.name.isEmpty ? '访客' : widget.name,
          bio: widget.bio.isNotEmpty ? widget.bio : _mockBio,
          coverUrl: _effectiveCoverUrl,
          avatarUrl: _effectiveAvatarUrl,
          shortId: widget.shortId.isEmpty ? _mockShortId : widget.shortId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.isLoggedIn)
          Image(
            image: _resolveImage(_effectiveCoverUrl),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _gradientCover(),
          )
        else
          _gradientCover(),

        if (widget.isLoggedIn)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.1),
                  Colors.black.withValues(alpha: 0.35),
                ],
              ),
            ),
          ),

        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _navigateToEdit,
                onLongPress: () {},
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: widget.isLoggedIn ? 0.3 : 0.14,
                        ),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: widget.isLoggedIn
                      ? ClipOval(
                          child: Image(
                            image: _resolveImage(_effectiveAvatarUrl),
                            width: 88,
                            height: 88,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _defaultAvatar(),
                          ),
                        )
                      : _defaultAvatar(),
                ),
              ),

              const SizedBox(height: 14),

              Text(
                widget.name.isEmpty ? '访客' : widget.name,
                style: AppTypography.headlineMedium.copyWith(
                  color:
                      widget.isLoggedIn ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 6),

              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: widget.isLoggedIn
                      ? Colors.white.withValues(alpha: 0.25)
                      : Colors.white.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  widget.isLoggedIn
                      ? 'ID  $_mockShortId'
                      : 'ID  ${widget.shortId}',
                  style: AppTypography.caption.copyWith(
                    color: widget.isLoggedIn
                        ? Colors.white.withValues(alpha: 0.9)
                        : AppColors.textTertiary,
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  widget.bio.isNotEmpty ? widget.bio : _mockBio,
                  style: AppTypography.bodySmall.copyWith(
                    color: widget.isLoggedIn
                        ? Colors.white.withValues(alpha: 0.85)
                        : AppColors.textSecondary,
                    height: 1.7,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              const SizedBox(height: 18),

              if (widget.isLoggedIn)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: _navigateToEdit,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 9),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.7),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '编辑资料',
                          style: AppTypography.labelMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _openShareProfile,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 9),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '分享主页',
                          style: AppTypography.labelMedium.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else if (widget.isAnonymous)
                GestureDetector(
                  onTap: widget.onLoginTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 9),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '去登录',
                      style: AppTypography.labelMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              else
                GestureDetector(
                  onTap: _navigateToEdit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 9),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.6),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '编辑资料',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _gradientCover() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.mint.withValues(alpha: 0.55),
            AppColors.lavender.withValues(alpha: 0.8),
          ],
        ),
      ),
    );
  }

  Widget _defaultAvatar() {
    return Icon(
      Icons.person_outline_rounded,
      size: 40,
      color: AppColors.textSecondary,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Stat Pill — minimal pill for the stats row
// ═══════════════════════════════════════════════════════════════════════════

class _StatPill extends StatelessWidget {
  final String label;
  final String value;

  const _StatPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: AppTypography.headlineSmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Menu Section — SliverList items
// ═══════════════════════════════════════════════════════════════════════════

class _TagIdentityCard extends StatelessWidget {
  final TagIdentitySnapshot snapshot;
  final VoidCallback onOpenIdentity;
  final VoidCallback onOpenFeed;

  const _TagIdentityCard({
    required this.snapshot,
    required this.onOpenIdentity,
    required this.onOpenFeed,
  });

  @override
  Widget build(BuildContext context) {
    final previewEntries = snapshot.timeline.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEAEAEA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '标签身份',
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '把最近一次解读整理成可持续回看的身份卡。',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  snapshot.primaryTag,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: snapshot.secondaryTags
                .map(
                  (tag) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F7F7),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      tag,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          ...previewEntries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '• ${entry.summary}',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onOpenIdentity,
                  child: const Text('查看完整身份'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: onOpenFeed,
                  child: const Text('浏览同标签内容'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MenuSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final credit = ref.watch(creditStateProvider);

    return Column(
      children: [
        _MenuRow(
          icon: Icons.auto_graph_rounded,
          title: '心绪存档',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const _HistoryPage()),
          ),
        ),
        _MenuRow(
          icon: Icons.favorite_border_rounded,
          title: '我的互动',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const _InteractionsPage()),
          ),
        ),
        _MenuRow(
          icon: Icons.workspace_premium_outlined,
          title: '权益中心',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const BenefitsCenterScreen()),
          ),
        ),
        _MenuRow(
          icon: Icons.calendar_today_outlined,
          title: '签到打卡',
          subtitle: credit.hasCheckedInToday ? '今日已签到' : null,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const _CheckinCalendarPage(),
            ),
          ),
        ),
        _MenuRow(
          icon: Icons.history_rounded,
          title: '浏览记录',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const _BrowsePage()),
          ),
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _MenuRow({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: AppColors.primary.withValues(alpha: 0.04),
      highlightColor: AppColors.primary.withValues(alpha: 0.02),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pageHorizontal,
          vertical: 13,
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textTertiary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: AppColors.border,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Sub-pages: _HistoryPage, _InteractionsPage, _BrowsePage
// _ProfileEditPage, _SettingsPage
// ═══════════════════════════════════════════════════════════════════════════

class _ProfileEditPage extends ConsumerStatefulWidget {
  const _ProfileEditPage();

  @override
  ConsumerState<_ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends ConsumerState<_ProfileEditPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  late final TextEditingController _cityController;

  String _selectedGender = 'not_disclosed';
  DateTime? _selectedBirthday;
  bool _isSaving = false;

  // 新选择的本地图片路径（上传后替换为 URL）
  String? _localAvatarPath;
  String? _localCoverPath;

  // 已有的头像/封面 URL（用于回显）
  String? _originalAvatarUrl;
  String? _originalCoverUrl;

  final ImagePicker _picker = ImagePicker();

  /// 将 URL 字符串转为 ImageProvider，支持 file:// 本地路径
  ImageProvider _resolveImage(String url) {
    if (url.startsWith('file://') || url.startsWith('/')) {
      final path = url.startsWith('file://') ? url.substring(7) : url;
      return FileImage(File(path));
    }
    return NetworkImage(url);
  }

  @override
  void initState() {
    super.initState();
    final user = ref.read(authStateProvider).user;
    _nameController = TextEditingController(text: user?.username ?? '');
    _bioController = TextEditingController(text: user?.bio ?? '');
    _cityController = TextEditingController(text: user?.birthCity ?? '');
    _selectedGender = user?.gender ?? 'not_disclosed';
    _selectedBirthday = user?.birthday;
    // 回显已有头像/封面
    _originalAvatarUrl = user?.avatarUrl;
    _originalCoverUrl = user?.coverUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (image == null) return;
      setState(() => _localAvatarPath = image.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法选择图片：$e'), duration: const Duration(seconds: 2)),
        );
      }
    }
  }

  Future<void> _pickCover() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 675,
        imageQuality: 90,
      );
      if (image == null) return;
      setState(() => _localCoverPath = image.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法选择图片：$e'), duration: const Duration(seconds: 2)),
        );
      }
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入昵称'), duration: Duration(seconds: 2)),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // 头像/封面：后端不可用时直接用 file:// 本地路径作为 URL 显示
      String? newAvatarUrl;
      if (_localAvatarPath != null) {
        newAvatarUrl = await authServiceProvider.uploadAvatar(_localAvatarPath!);
        // 如果后端不可用返回 null，用本地路径（协议前缀表示本地预览）
        newAvatarUrl ??= _localAvatarPath;
      }

      String? newCoverUrl;
      if (_localCoverPath != null) {
        newCoverUrl = await authServiceProvider.uploadCover(_localCoverPath!);
        newCoverUrl ??= _localCoverPath;
      }

      await ref.read(authStateProvider.notifier).updateProfile(
        username: name,
        bio: _bioController.text.trim(),
        avatarUrl: newAvatarUrl,
        coverUrl: newCoverUrl,
      );

      if (_selectedBirthday != null) {
        await ref.read(authStateProvider.notifier).setBirthInfo(
          birthday: _selectedBirthday!,
        );
      }
      if (_selectedGender != 'not_disclosed') {
        await ref.read(authStateProvider.notifier).updateGender(
          _selectedGender,
        );
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败：$e'), duration: const Duration(seconds: 3)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthday ?? DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(1950),
      lastDate: DateTime(now.year, now.month, now.day),
      builder: (_, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedBirthday = picked);
    }
  }

  String _formatBirthday(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  Widget _fieldCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE), width: 0.5),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCFCF8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFCFCF8),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '编辑资料',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
          children: [
            // ── Cover + Avatar ─────────────────────────────────────────────
            Stack(
              clipBehavior: Clip.none,
              children: [
                GestureDetector(
                  onTap: _pickCover,
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: AppColors.surfaceVariant,
                      image: _localCoverPath != null
                          ? DecorationImage(
                              image: _resolveImage(_localCoverPath!),
                              fit: BoxFit.cover,
                            )
                          : _originalCoverUrl != null
                              ? DecorationImage(
                                  image: _resolveImage(_originalCoverUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                    ),
                    child: _localCoverPath == null && _originalCoverUrl == null
                        ? Center(
                            child: Icon(
                              Icons.photo_camera_outlined,
                              color: AppColors.textSecondary.withValues(alpha: 0.5),
                              size: 28,
                            ),
                          )
                        : null,
                  ),
                ),
                Positioned(
                  left: 0,
                  bottom: -32,
                  child: GestureDetector(
                    onTap: _pickAvatar,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: _localAvatarPath != null
                            ? Image(
                                image: _resolveImage(_localAvatarPath!),
                                width: 72,
                                height: 72,
                                fit: BoxFit.cover,
                              )
                            : _originalAvatarUrl != null
                                ? Image(
                                    image: _resolveImage(_originalAvatarUrl!),
                                    width: 72,
                                    height: 72,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        Icon(Icons.person, color: AppColors.textTertiary, size: 32),
                                  )
                                : Icon(Icons.person, color: AppColors.textTertiary, size: 32),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),

            // ── 昵称 ─────────────────────────────────────────────────────
            Text(
              '昵称',
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            _fieldCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    hintText: '填写昵称',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── 个人简介 ──────────────────────────────────────────────────
            Text(
              '个人简介',
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            _fieldCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: TextField(
                  controller: _bioController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: '介绍一下自己',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── 城市 ─────────────────────────────────────────────────────
            Text(
              '所在城市',
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            _fieldCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: TextField(
                  controller: _cityController,
                  decoration: const InputDecoration(
                    hintText: '填写城市',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── 性别 ─────────────────────────────────────────────────────
            Text(
              '性别',
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _GenderChip(
                  label: '男',
                  value: 'male',
                  selected: _selectedGender == 'male',
                  onTap: () => setState(() => _selectedGender = 'male'),
                ),
                const SizedBox(width: 10),
                _GenderChip(
                  label: '女',
                  value: 'female',
                  selected: _selectedGender == 'female',
                  onTap: () => setState(() => _selectedGender = 'female'),
                ),
                const SizedBox(width: 10),
                _GenderChip(
                  label: '不设置',
                  value: 'not_disclosed',
                  selected: _selectedGender == 'not_disclosed',
                  onTap: () => setState(() => _selectedGender = 'not_disclosed'),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── 生日 ─────────────────────────────────────────────────────
            Text(
              '生日',
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickBirthday,
              child: _fieldCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(Icons.cake_outlined,
                          size: 18, color: AppColors.textSecondary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _selectedBirthday != null
                              ? _formatBirthday(_selectedBirthday)
                              : '点击选择生日',
                          style: AppTypography.bodyMedium.copyWith(
                            color: _selectedBirthday != null
                                ? AppColors.textPrimary
                                : AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),

            // ── 保存按钮 ──────────────────────────────────────────────────
            GestureDetector(
              onTap: _isSaving ? null : _save,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: _isSaving
                      ? AppColors.textTertiary
                      : AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  _isSaving ? '保存中...' : '保存',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
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

class _GenderChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _GenderChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.mint : const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.mintDark : const Color(0xFFEEEEEE),
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.labelMedium.copyWith(
            color: selected ? AppColors.primaryDark : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _HistoryPage extends ConsumerWidget {
  const _HistoryPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(ritualStateProvider).history;
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('我的心绪存档'),
        backgroundColor: AppColors.cream,
      ),
      body: history.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.hourglass_empty_rounded,
                      size: 40, color: AppColors.textTertiary),
                  const SizedBox(height: 12),
                  Text('还没有存档记录',
                      style: AppTypography.bodyMedium
                          .copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text('完成一次体验后会自动保存到这里',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textTertiary)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
              itemCount: history.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                final item = history[history.length - 1 - index];
                final m = item.dateTime.month.toString().padLeft(2, '0');
                final d = item.dateTime.day.toString().padLeft(2, '0');
                return Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                    border: Border.all(color: AppColors.border, width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.mintLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$m-$d',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            item.hexagram.map((e) => e > 0 ? '—' : '— —').join('  '),
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textTertiary,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        item.mood,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _InteractionsPage extends ConsumerWidget {
  const _InteractionsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interactions = ref.watch(profileHubStateProvider).interactions;
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('我的互动'),
        backgroundColor: AppColors.cream,
        actions: [
          if (interactions.isNotEmpty)
            AppTextButton(
              label: '清空',
              onPressed: () =>
                  ref.read(profileHubStateProvider.notifier).clearInteractions(),
            ),
        ],
      ),
      body: interactions.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border_rounded,
                      size: 40, color: AppColors.textTertiary),
                  const SizedBox(height: 12),
                  Text('还没有互动记录',
                      style: AppTypography.bodyMedium
                          .copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text('在宽窄之间点赞后会显示在这里',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textTertiary)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
              itemCount: interactions.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                final item = interactions[index];
                return Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                    border: Border.all(color: AppColors.border, width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: AppTypography.labelLarge.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if ((item.detail ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          item.detail!,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '${item.source} · ${_dateTime(item.createdAt)}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _BrowsePage extends ConsumerWidget {
  const _BrowsePage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(profileHubStateProvider).browseRecords;
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('浏览记录'),
        backgroundColor: AppColors.cream,
        actions: [
          if (records.isNotEmpty)
            AppTextButton(
              label: '清空',
              onPressed: () => ref
                  .read(profileHubStateProvider.notifier)
                  .clearBrowseRecords(),
            ),
        ],
      ),
      body: records.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_rounded,
                      size: 40, color: AppColors.textTertiary),
                  const SizedBox(height: 12),
                  Text('还没有浏览记录',
                      style: AppTypography.bodyMedium
                          .copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text('浏览宽窄之间的内容后会显示在这里',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textTertiary)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
              itemCount: records.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                final item = records[index];
                return Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                    border: Border.all(color: AppColors.border, width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: AppTypography.labelLarge.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if ((item.snippet ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          item.snippet!,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '${item.source} · ${_dateTime(item.createdAt)}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _CheckinCalendarPage extends ConsumerWidget {
  const _CheckinCalendarPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final credit = ref.watch(creditStateProvider);
    final notifier = ref.read(creditStateProvider.notifier);
    final now = DateTime.now();
    final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
    final checkedDays = <int>{2, 4, 5, 7, 10, 12, 15};
    if (credit.hasCheckedInToday) checkedDays.add(now.day);

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('签到日历'),
        backgroundColor: AppColors.cream,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${now.year}年${now.month}月',
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '连续签到 7 天可解锁一张“今日余韵卡”（模拟）',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: daysInMonth,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (context, index) {
                    final day = index + 1;
                    final checked = checkedDays.contains(day);
                    final today = day == now.day;
                    return Container(
                      decoration: BoxDecoration(
                        color: checked ? AppColors.mintLight : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: today ? AppColors.primary : AppColors.border,
                          width: today ? 1.2 : 0.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$day',
                          style: AppTypography.labelSmall.copyWith(
                            color: checked
                                ? AppColors.primaryDark
                                : AppColors.textSecondary,
                            fontWeight: checked ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: credit.hasCheckedInToday || credit.isLoading
                ? null
                : () async {
                    await notifier.checkin();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('签到完成，已增加 1 次追问额度。')),
                    );
                  },
            child: Text(credit.hasCheckedInToday ? '今日已签到' : '立即签到'),
          ),
          const SizedBox(height: 10),
          Text(
            '正式接入后会由后端返回签到明细、连续天数、补签状态与奖励配置。',
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareProfilePage extends StatelessWidget {
  final String name;
  final String bio;
  final String coverUrl;
  final String avatarUrl;
  final String shortId;

  const _ShareProfilePage({
    required this.name,
    required this.bio,
    required this.coverUrl,
    required this.avatarUrl,
    required this.shortId,
  });

  ImageProvider _resolveImage(String url) {
    if (url.startsWith('file://') || url.startsWith('/')) {
      final path = url.startsWith('file://') ? url.substring(7) : url;
      return FileImage(File(path));
    }
    return NetworkImage(url);
  }

  @override
  Widget build(BuildContext context) {
    final shareUrl = 'https://orbit.app/u/$shortId';
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('分享主页'),
        backgroundColor: AppColors.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                SizedBox(
                  height: 160,
                  width: double.infinity,
                  child: Image(
                    image: _resolveImage(coverUrl),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.surfaceVariant,
                    ),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -28),
                  child: CircleAvatar(
                    radius: 36,
                    backgroundColor: Colors.white,
                    child: CircleAvatar(
                      radius: 33,
                      backgroundImage: _resolveImage(avatarUrl),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    children: [
                      Text(
                        name,
                        style: AppTypography.headlineSmall.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Orbit ID · $shortId',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textTertiary,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        bio,
                        textAlign: TextAlign.center,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.7,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '分享链接',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  shareUrl,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已模拟生成主页分享卡片')),
              );
            },
            child: const Text('生成主页分享卡'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已模拟复制链接：$shareUrl')),
              );
            },
            child: const Text('复制主页链接'),
          ),
          const SizedBox(height: 10),
          Text(
            '正式接入后会补充公开主页路由、分享卡截图导出、访客态主页与分享埋点。',
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsPage extends ConsumerWidget {
  const _SettingsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hub = ref.watch(profileHubStateProvider);
    final settings = hub.settings;
    final notifier = ref.read(profileHubStateProvider.notifier);

    Future<void> update(bool? value, String key) async {
      if (value == null) return;
      switch (key) {
        case 'push':
          await notifier
              .updateSettings(settings.copyWith(pushEnabled: value));
          break;
        case 'vibration':
          await notifier
              .updateSettings(settings.copyWith(vibrationEnabled: value));
          break;
        case 'public':
          await notifier
              .updateSettings(settings.copyWith(publicProfile: value));
          break;
        case 'sound':
          final muted = audioService.isMuted;
          if (value && muted) audioService.toggleMute();
          if (!value && !muted) audioService.toggleMute();
          await notifier
              .updateSettings(settings.copyWith(ambientSoundEnabled: value));
          break;
      }
    }

    Widget _card({required Widget child}) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFEEEEEE),
            width: 0.5,
          ),
        ),
        child: child,
      );
    }

    Widget _row({
      required IconData icon,
      required String title,
      String? subtitle,
      Widget? trailing,
      VoidCallback? onTap,
    }) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF6B6B6B)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing,
              if (onTap != null && trailing == null)
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

    Widget _toggleRow({
      required IconData icon,
      required String title,
      required bool value,
      required ValueChanged<bool> onChanged,
    }) {
      return _row(
        icon: icon,
        title: title,
        trailing: Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeTrackColor: const Color(0xFF4CAF82),
          activeThumbColor: Colors.white,
          inactiveTrackColor: const Color(0xFFE8E8E8),
        ),
      );
    }

    Widget _divider({double indent = 48}) {
      return Divider(
        height: 1,
        indent: indent,
        endIndent: 16,
        color: AppColors.border,
        thickness: 0.5,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFCFCF8),
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: const Color(0xFFFCFCF8),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
        children: [
          // 账号与安全
          _card(
            child: Column(
              children: [
                _row(
                  icon: Icons.person_outline_rounded,
                  title: '账号信息',
                  trailing: Text(
                    '未绑定',
                    style:
                        AppTypography.caption.copyWith(color: AppColors.textTertiary),
                  ),
                  onTap: () => _showStubPage(context, '账号信息',
                      '账号绑定与管理功能将在后端接入后启用。\n\n'
                      '接入后会替换为真实账号信息页面，支持邮箱/手机号绑定与解绑。'),
                ),
                _divider(),
                _row(
                  icon: Icons.lock_outline_rounded,
                  title: '修改密码',
                  onTap: () => _showStubPage(context, '修改密码',
                      '密码修改功能将在后端接入后启用。\n\n'
                      '接入后会实现旧密码验证、新密码设置与短信验证码确认流程。'),
                ),
                _divider(),
                _row(
                  icon: Icons.phone_android_outlined,
                  title: '手机号',
                  trailing: Text(
                    '未绑定',
                    style:
                        AppTypography.caption.copyWith(color: AppColors.textTertiary),
                  ),
                  onTap: () => _showStubPage(context, '手机号管理',
                      '手机号绑定与更换功能将在后端接入后启用。\n\n'
                      '接入后会实现手机号绑定、更换（需短信验证）。'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 隐私管理
          _card(
            child: Column(
              children: [
                _toggleRow(
                  icon: Icons.notifications_outlined,
                  title: '通知提醒',
                  value: settings.pushEnabled,
                  onChanged: (v) => update(v, 'push'),
                ),
                _divider(),
                _toggleRow(
                  icon: Icons.vibration_outlined,
                  title: '震动反馈',
                  value: settings.vibrationEnabled,
                  onChanged: (v) => update(v, 'vibration'),
                ),
                _divider(),
                _toggleRow(
                  icon: Icons.public_outlined,
                  title: '公开主页',
                  value: settings.publicProfile,
                  onChanged: (v) => update(v, 'public'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 体验设置
          _card(
            child: Column(
              children: [
                _toggleRow(
                  icon: Icons.music_note_outlined,
                  title: '仪式音效',
                  value: settings.ambientSoundEnabled,
                  onChanged: (v) => update(v, 'sound'),
                ),
                _divider(),
                _toggleRow(
                  icon: Icons.auto_awesome_outlined,
                  title: '仪式触感',
                  value: settings.vibrationEnabled,
                  onChanged: (v) => update(v, 'vibration'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 其他
          _card(
            child: Column(
              children: [
                _row(
                  icon: Icons.help_outline_rounded,
                  title: '帮助与反馈',
                  onTap: () => _showStubPage(context, '帮助与反馈',
                      '如有问题或建议，请联系我们：\n\n'
                      '邮箱：support@orbit-app.com\n'
                      '微信公众号：宽窄Orbit\n\n'
                      '接入后会替换为工单提交与常见问题列表。'),
                ),
                _divider(),
                _row(
                  icon: Icons.info_outline_rounded,
                  title: '关于宽窄',
                  trailing: Text(
                    'v1.0.0',
                    style:
                        AppTypography.caption.copyWith(color: AppColors.textTertiary),
                  ),
                  onTap: () => _showStubPage(context, '关于宽窄·Orbit',
                      '宽窄·Orbit v1.0.0\n\n'
                      '一款以六爻仪式解读为核心的社群APP。\n'
                      '用户通过六爻仪式获得解读，基于解读进行对话。\n'
                      '生成的解读卡可以分享到社群"宽窄之间"。\n\n'
                      '© 2026 宽窄·Orbit Team'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 清空记录
          _card(
            child: Column(
              children: [
                _row(
                  icon: Icons.delete_outline_rounded,
                  title: '清空互动记录',
                  onTap: () async {
                    await notifier.clearInteractions();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已清空互动记录')),
                      );
                    }
                  },
                ),
                _divider(),
                _row(
                  icon: Icons.history_outlined,
                  title: '清空浏览记录',
                  onTap: () async {
                    await notifier.clearBrowseRecords();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已清空浏览记录')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 账号注销
          _card(
            child: _row(
              icon: Icons.person_off_outlined,
              title: '注销账号',
              onTap: () => _showDeleteAccountDialogV2(context, ref),
            ),
          ),

          const SizedBox(height: 32),

          // 退出登录按钮
          GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('确认退出'),
                  content: const Text('确定要退出登录吗？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('取消'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ref.read(authStateProvider.notifier).logout();
                      },
                      child: Text(
                        '退出',
                        style: TextStyle(color: AppColors.accent),
                      ),
                    ),
                  ],
                ),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFEEEEEE),
                  width: 0.5,
                ),
              ),
              child: Center(
                child: Text(
                  '退出登录',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFFF7B6B),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

String _dateTime(DateTime? value) {
  if (value == null) return '--';
  final y = value.year.toString();
  final m = value.month.toString().padLeft(2, '0');
  final d = value.day.toString().padLeft(2, '0');
  final h = value.hour.toString().padLeft(2, '0');
  final mi = value.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $h:$mi';
}

void _showStubPage(BuildContext context, String title, String body) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          title: Text(title),
          backgroundColor: AppColors.surface,
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            body,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.8,
            ),
          ),
        ),
      ),
    ),
  );
}

// ignore: unused_element
void _showDeleteAccountDialog(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    builder: (ctx) {
      int step = 0;
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          if (step == 0) {
            return AlertDialog(
              title: const Text('注销账号'),
              content: const Text(
                '注销后，你的账号数据将被永久删除，包括：\n\n'
                '• 个人资料与设置\n'
                '• 仪式记录与解读\n'
                '• 社区帖子与互动记录\n'
                '• 权益余额\n\n'
                '此操作不可撤销，确定要继续吗？',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () => setDialogState(() => step = 1),
                  child: Text('继续注销',
                      style: TextStyle(color: AppColors.accent)),
                ),
              ],
            );
          }
          return AlertDialog(
            title: const Text('确认注销'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('请输入"注销"以确认：'),
                const SizedBox(height: 12),
                TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: '注销',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (v) {
                    if (v.trim() == '注销') {
                      Navigator.pop(ctx);
                      ref.read(authStateProvider.notifier).logout();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('账号注销请求已提交（模拟）'),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消'),
              ),
            ],
          );
        },
      );
    },
  );
}
