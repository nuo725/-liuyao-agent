import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../models/interpretation_card.dart';
import '../../../services/feed_service.dart';
import '../../../services/share_card_draft_service.dart';
import '../../../state/auth_state.dart';
import '../../../state/community_state.dart';
import '../../../state/profile_hub_state.dart';
import '../../widgets/share_card_canvas.dart';

class ShareCardWorkflowScreen extends ConsumerStatefulWidget {
  final InterpretationCard card;

  const ShareCardWorkflowScreen({super.key, required this.card});

  @override
  ConsumerState<ShareCardWorkflowScreen> createState() =>
      _ShareCardWorkflowScreenState();
}

class _ShareCardWorkflowScreenState
    extends ConsumerState<ShareCardWorkflowScreen> {
  final _repaintKey = GlobalKey();
  final _picker = ImagePicker();

  late final TextEditingController _textController;
  ShareCardTheme _theme = ShareCardTheme.warm;
  String? _backgroundImagePath;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(
      text: shareCardDraftServiceProvider.buildFallbackDraft(
        card: widget.card,
        style: ShareCardDraftStyle.concise,
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  List<int> get _lines => widget.card.pattern.lines;

  String get _coordinateName {
    if (_lines.length != 6) return '';
    final seed = int.parse(_lines.join(), radix: 2);
    const labels = [
      '林隙', '晨汐', '远岚', '山脊', '微澜', '夜航', '天镜', '归岸'
    ];
    final a = labels[seed % labels.length];
    final b = labels[(seed ~/ 3 + 2) % labels.length];
    return '$a · $b';
  }

  Future<void> _pickBackground() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 86,
      );
      if (image == null) return;
      setState(() => _backgroundImagePath = image.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法选择图片：$e')),
        );
      }
    }
  }

  Future<void> _saveToGallery() async {
    // TODO(Backend Integration)[share_api#save-image]:
    // Use image_gallery_saver or similar plugin to persist PNG to device.
    if (_loading) return;
    setState(() => _loading = true);
    final image = await ShareCardCanvas.capture(_repaintKey);
    await Future.delayed(const Duration(milliseconds: 600));
    if (image == null || !mounted) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已模拟保存到相册（已生成 ${image.width}×${image.height} 图片，待接入 image_gallery_saver）'),
      ),
    );
    setState(() => _loading = false);
  }

  Future<void> _shareExternal() async {
    // TODO(Backend Integration)[share_api#external-share]:
    // Use share_plus to share PNG bytes externally.
    if (_loading) return;
    setState(() => _loading = true);
    final image = await ShareCardCanvas.capture(_repaintKey);
    await Future.delayed(const Duration(milliseconds: 500));
    if (image == null || !mounted) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已模拟分享到外部（已生成 ${image.width}×${image.height} 图片，待接入 share_plus）'),
      ),
    );
    setState(() => _loading = false);
  }

  Future<void> _publishToCommunity() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final auth = ref.read(authStateProvider);
      final user = auth.user;
      final text = _textController.text.trim();
      final content = widget.card.content;
      final editedContent = InterpretationContent(
        summary: content.summary,
        focusPoints: content.focusPoints,
        afterglow: content.afterglow,
        followupDirections: content.followupDirections,
        rawResponse: content.rawResponse,
        microActions: content.microActions,
        body: text.isEmpty ? content.body : text,
        quoteText: content.quoteText,
        quoteSource: content.quoteSource,
        visualBlocks: content.visualBlocks,
      );
      final editedCard = InterpretationCard(
        id: widget.card.id,
        question: widget.card.question,
        tag: widget.card.tag,
        pattern: widget.card.pattern,
        content: editedContent,
        riskLevel: widget.card.riskLevel,
        createdAt: widget.card.createdAt,
        authorId: user?.id ?? widget.card.authorId,
        needsClarification: widget.card.needsClarification,
      );

      final published = await feedServiceProvider.publish(
        card: editedCard,
        authorId: user?.id,
        authorUsername: user?.username ?? '匿名用户',
        shareText: text.isEmpty ? null : text,
        coverImageUrl: _backgroundImagePath,
      );

      await ref.read(profileHubStateProvider.notifier).recordInteraction(
        source: 'share_publish',
        contentKey: 'share-${editedCard.id}',
        title: '你发布了一张解读卡',
        detail: published.displaySummary,
      );
      await ref
          .read(communityStateProvider.notifier)
          .loadFeeds(showLoading: false);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已发布到宽窄之间')),
      );
      Navigator.of(context).pop(published.id);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summaryText = _textController.text.trim().isEmpty
        ? widget.card.content.summary
        : _textController.text.trim();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          '生成解读卡',
          style: AppTypography.labelLarge.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          color: AppColors.textSecondary,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          // Step 1: Live preview
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: ShareCardCanvas(
                repaintKey: _repaintKey,
                coordinateName: _coordinateName,
                summary: summaryText,
                hexagramLines: _lines,
                theme: _theme,
                backgroundImagePath: _backgroundImagePath,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Step 2: Theme + edit
          Text(
            '配色方案',
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: ShareCardTheme.values.map((t) {
              final selected = t == _theme;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () => setState(() => _theme = t),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: _themePreviewGradient(t),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : AppColors.border,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: selected
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickBackground,
                  icon: Icon(
                    _backgroundImagePath != null
                        ? Icons.check_rounded
                        : Icons.add_photo_alternate_outlined,
                    size: 16,
                  ),
                  label: Text(
                    _backgroundImagePath != null ? '已选背景图' : '自定义背景',
                  ),
                ),
              ),
              if (_backgroundImagePath != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () =>
                      setState(() => _backgroundImagePath = null),
                  icon: const Icon(Icons.close, size: 18),
                  color: AppColors.textTertiary,
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),

          Text(
            '编辑文案',
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _textController,
            minLines: 3,
            maxLines: 8,
            onChanged: (_) => setState(() {}),
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              height: 1.7,
            ),
            decoration: InputDecoration(
              hintText: '编辑解读卡文案…',
              hintStyle: AppTypography.bodyMedium.copyWith(
                color: AppColors.textTertiary,
              ),
              filled: true,
              fillColor: AppColors.surfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Step 3: Export
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _loading ? null : _publishToCommunity,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: Text(_loading ? '发布中…' : '发布到宽窄之间'),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _loading ? null : _saveToGallery,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: const Text('保存到相册'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: _loading ? null : _shareExternal,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: const Text('分享外部'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '当前导出为 UI 模拟：已完成卡片截图生成，正式接入时需补充系统相册写入、外部分享面板、权限申请与失败重试。',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  LinearGradient _themePreviewGradient(ShareCardTheme t) {
    return switch (t) {
      ShareCardTheme.warm => const LinearGradient(
          colors: [AppColors.canvasWarm, AppColors.mintLight],
        ),
      ShareCardTheme.cool => const LinearGradient(
          colors: [AppColors.sky, AppColors.lavender],
        ),
      ShareCardTheme.dark => const LinearGradient(
          colors: [Color(0xFF2A2A2E), Color(0xFF1A1A20)],
        ),
    };
  }
}
