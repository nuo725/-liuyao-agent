import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/constants/app_spacing.dart';
import '../../models/interpretation_card.dart';
import '../../models/pattern.dart';
import '../../services/feed_service.dart';
import '../../state/auth_state.dart';
import '../../state/profile_hub_state.dart';

/// Minimalist post editor — "写点什么" entry point
///
/// [card] 用户刚刚完成解读获得的卡片（用于发布分享）
/// 如不传，则仅发布纯文本内容（不关联解读卡片）。
class PublishPage extends ConsumerStatefulWidget {
  final InterpretationCard? card;
  final String? presetTag;
  final String? initialText;

  const PublishPage({
    super.key,
    this.card,
    this.presetTag,
    this.initialText,
  });

  @override
  ConsumerState<PublishPage> createState() => _PublishPageState();
}

class _PublishPageState extends ConsumerState<PublishPage> {
  final _controller = TextEditingController();
  bool _isPublishing = false;
  String? _uploadStatus;

  // TODO(Backend Integration)[community_api#publish-upload]: 实现图片上传
  // 本地图片路径，选中后通过 authService.uploadImage() 上传到图床获得 URL
  String? _localImagePath;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _controller.text = (widget.initialText ?? '').trim();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canPublish =>
      _controller.text.trim().isNotEmpty || widget.card != null;

  String _composeShareText() {
    final text = _controller.text.trim();
    final tag = (widget.presetTag ?? '').trim();
    if (tag.isEmpty) return text;
    if (text.isEmpty) return tag;
    if (text.contains(tag)) return text;
    return '$text  $tag';
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 675,
        imageQuality: 85,
      );
      if (image == null) return;
      setState(() {
        _localImagePath = image.path;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('无法选择图片：$e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _publish() async {
    if (!_canPublish || _isPublishing) return;
    setState(() {
      _isPublishing = true;
      _uploadStatus = _localImagePath != null ? '正在模拟上传图片...' : null;
    });

    try {
      final auth = ref.read(authStateProvider);
      final userId = auth.user?.id;
      final username = auth.user?.username;

      // TODO(Backend Integration)[community_api#publish-upload]: 如果有本地图片 _localImagePath，
      // 先调用 authService.uploadImage() 上传到图床，获得 coverImageUrl，
      // 然后传入 feedServiceProvider.publish()
      if (_localImagePath != null) {
        await Future.delayed(const Duration(milliseconds: 900));
        if (mounted) {
          setState(() => _uploadStatus = '已完成本地上传模拟，待接入图床 URL');
        }
      }
      final coverImageUrl = _localImagePath;

      final published = await feedServiceProvider.publish(
        card: widget.card ?? _buildPlaceholderCard(),
        authorId: userId,
        authorUsername: username,
        shareText: _composeShareText().isEmpty ? null : _composeShareText(),
        coverImageUrl: coverImageUrl,
      );

      await ref
          .read(profileHubStateProvider.notifier)
          .recordInteraction(
            source: 'community_publish',
            contentKey: published.id,
            title: '你发布了一条新内容',
            detail: published.displaySummary,
          );

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('发布失败：$e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPublishing = false;
          _uploadStatus = null;
        });
      }
    }
  }

  /// Build a minimal placeholder card for text-only publishing (no ritual card).
  InterpretationCard _buildPlaceholderCard() {
    return InterpretationCard(
      id: 'local-${DateTime.now().millisecondsSinceEpoch}',
      question: '',
      tag: null,
      pattern: Pattern(
        lines: const [1, 0, 1, 0, 1, 0],
        movingLines: const [],
        createdAt: DateTime.now(),
      ),
      riskLevel: RiskLevel.low,
      content: InterpretationContent(
        summary: _controller.text.trim(),
        focusPoints: const [],
        afterglow: '',
        followupDirections: const [],
        body: _controller.text.trim(),
        quoteText: null,
        quoteSource: null,
        visualBlocks: const [],
      ),
      createdAt: DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            '取消',
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ),
        leadingWidth: 64,
        title: Text(
          '记录此刻',
          style: AppTypography.labelLarge.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(
              right: AppSpacing.pageHorizontal - 4,
            ),
            child: GestureDetector(
              onTap: _canPublish ? _publish : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: _canPublish ? AppColors.primary : AppColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '发布',
                  style: AppTypography.labelMedium.copyWith(
                    color: _canPublish ? Colors.white : AppColors.textTertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Text area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageHorizontal,
                  AppSpacing.md,
                  AppSpacing.pageHorizontal,
                  0,
                ),
                child: Column(
                  children: [
                    if ((widget.presetTag ?? '').trim().isNotEmpty) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.mintLight,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            widget.presetTag!.trim(),
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: _localImagePath != null
                                ? AppColors.mintLight
                                : AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: _localImagePath != null
                                  ? AppColors.mintDark
                                  : AppColors.border,
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _localImagePath != null
                                    ? Icons.check_rounded
                                    : Icons.add_photo_alternate_outlined,
                                size: 18,
                                color: _localImagePath != null
                                    ? AppColors.primaryDark
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _localImagePath != null ? '已选图片' : '添加图片',
                                style: AppTypography.labelMedium.copyWith(
                                  color: _localImagePath != null
                                      ? AppColors.primaryDark
                                      : AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                          height: 1.8,
                        ),
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: '这一刻的真实感受...',
                          hintStyle: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textTertiary,
                            height: 1.8,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if ((widget.presetTag ?? '').trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageHorizontal,
                  0,
                  AppSpacing.pageHorizontal,
                  8,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '发布时将自动带上活动标签，便于活动榜单统计。',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ),

            // Divider
            Container(
              margin: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pageHorizontal,
              ),
              height: 0.5,
              color: AppColors.border,
            ),

            // Bottom toolbar
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageHorizontal,
                12,
                AppSpacing.pageHorizontal,
                16,
              ),
              child: Row(
                children: [
                  // Add image button
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _localImagePath != null
                            ? AppColors.mintLight
                            : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _localImagePath != null
                              ? AppColors.mintDark
                              : AppColors.border,
                          width: 0.5,
                        ),
                      ),
                      child: Icon(
                        _localImagePath != null
                            ? Icons.check_rounded
                            : Icons.add_photo_alternate_outlined,
                        size: 18,
                        color: _localImagePath != null
                            ? AppColors.primaryDark
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_localImagePath != null)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _uploadStatus ?? '图片已添加，仅本地预览',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '图片仅用于本地预览，当前不接真实上传。',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (_localImagePath != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageHorizontal,
                  0,
                  AppSpacing.pageHorizontal,
                  16,
                ),
                child: Container(
                  width: double.infinity,
                  height: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border, width: 0.5),
                    image: DecorationImage(
                      image: FileImage(File(_localImagePath!)),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: GestureDetector(
                      onTap: () => setState(() => _localImagePath = null),
                      child: Container(
                        margin: const EdgeInsets.all(10),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.white,
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
