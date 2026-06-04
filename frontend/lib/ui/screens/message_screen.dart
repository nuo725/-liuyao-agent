import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/content/message_copy.dart';
import '../../state/message_state.dart';
import '../../state/profile_hub_state.dart';

class MessageScreen extends ConsumerWidget {
  const MessageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final msgState = ref.watch(messageStateProvider);
    final hub = ref.watch(profileHubStateProvider);
    final notifier = ref.read(messageStateProvider.notifier);
    final notices = notifier.buildNotices(hub);
    final visible =
        notices.where((e) => !msgState.dismissedIds.contains(e.id)).toList();
    final filtered = visible.where((n) {
      if (msgState.filter == MessageFilter.all) return true;
      return n.kind == msgState.filter;
    }).toList();
    final unreadCount =
        visible.where((e) => !msgState.readIds.contains(e.id)).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    MessageCopy.title,
                    style: AppTypography.headlineLarge.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.lavender,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$unreadCount ${MessageCopy.unreadSuffix}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: visible.isEmpty
                        ? null
                        : () => notifier.markAllRead(visible.map((e) => e.id)),
                    child: Text(
                      MessageCopy.markAllRead,
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                MessageCopy.subtitle,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  _chip(context, ref, MessageCopy.filterAll, MessageFilter.all,
                      msgState.filter),
                  _chip(context, ref, MessageCopy.filterInteraction,
                      MessageFilter.interaction, msgState.filter),
                  _chip(context, ref, MessageCopy.filterBrowse,
                      MessageFilter.browse, msgState.filter),
                  _chip(context, ref, MessageCopy.filterSystem,
                      MessageFilter.system, msgState.filter),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: msgState.metaLoading
                    ? const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : filtered.isEmpty
                        ? _EmptyState(filter: msgState.filter)
                        : RefreshIndicator(
                            onRefresh: () async {
                              try {
                                await notifier.simulateRefresh();
                              } catch (_) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content:
                                          Text(MessageCopy.refreshFailed),
                                    ),
                                  );
                                }
                              }
                            },
                            child: ListView.separated(
                              physics:
                                  const AlwaysScrollableScrollPhysics(),
                              itemCount: filtered.length,
                              padding: const EdgeInsets.only(bottom: 18),
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final item = filtered[index];
                                return _NoticeCard(item: item);
                              },
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, WidgetRef ref, String label,
      MessageFilter filter, MessageFilter current) {
    final active = current == filter;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      onSelected: (_) =>
          ref.read(messageStateProvider.notifier).setFilter(filter),
      selectedColor: AppColors.lavender,
      labelStyle: AppTypography.caption.copyWith(
        color: active ? AppColors.textPrimary : AppColors.textSecondary,
      ),
      side: BorderSide(
        color: active ? AppColors.lavenderDark : AppColors.border,
      ),
      backgroundColor: AppColors.surface,
    );
  }
}

class _NoticeCard extends ConsumerWidget {
  final MessageNotice item;

  const _NoticeCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final msgState = ref.watch(messageStateProvider);
    final notifier = ref.read(messageStateProvider.notifier);

    return Slidable(
      key: ValueKey(item.id),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: 0.45,
        children: [
          SlidableAction(
            onPressed: (_) async {
              final ok = await notifier.simulateAction();
              if (!ok) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(MessageCopy.actionFailed)),
                  );
                }
                return;
              }
              await notifier.markRead(item.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(MessageCopy.actionSuccessRead)),
                );
              }
            },
            backgroundColor: const Color(0xFFAAAAAA),
            foregroundColor: Colors.white,
            label: MessageCopy.actionRead,
          ),
          SlidableAction(
            onPressed: (_) async {
              final ok = await notifier.simulateAction();
              if (!ok) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(MessageCopy.actionFailed)),
                  );
                }
                return;
              }
              await notifier.dismiss(item.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(MessageCopy.actionSuccessDelete)),
                );
              }
            },
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
            label: MessageCopy.actionDelete,
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await notifier.markRead(item.id);
          if (!context.mounted) return;
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _NoticeDetailPage(item: item),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _icon(item.kind),
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: AppTypography.labelLarge,
                          ),
                        ),
                        if (!msgState.readIds.contains(item.id))
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.timeText,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textTertiary,
                      ),
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

  IconData _icon(MessageFilter kind) {
    return switch (kind) {
      MessageFilter.interaction => Icons.favorite_border_rounded,
      MessageFilter.browse => Icons.remove_red_eye_outlined,
      MessageFilter.system => Icons.notifications_none_rounded,
      MessageFilter.all => Icons.notifications_none_rounded,
    };
  }
}

class _EmptyState extends StatelessWidget {
  final MessageFilter filter;

  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final isAll = filter == MessageFilter.all;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_none_rounded,
                size: 28,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isAll ? MessageCopy.emptyTitle : '当前筛选下暂无消息',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isAll ? MessageCopy.emptySubtitle : '试试切换筛选或下拉刷新。',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoticeDetailPage extends StatelessWidget {
  final MessageNotice item;

  const _NoticeDetailPage({required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(MessageCopy.detailTitle),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title, style: AppTypography.headlineSmall),
              const SizedBox(height: 10),
              Text(
                item.subtitle,
                style: AppTypography.bodyMedium.copyWith(height: 1.75),
              ),
              const SizedBox(height: 10),
              Text(
                item.timeText,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
