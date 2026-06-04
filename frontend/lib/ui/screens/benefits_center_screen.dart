import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../../models/ui_flow_state.dart';
import '../../state/credit_state.dart';

class BenefitsCenterScreen extends ConsumerStatefulWidget {
  final bool openCheckin;

  const BenefitsCenterScreen({super.key, this.openCheckin = false});

  @override
  ConsumerState<BenefitsCenterScreen> createState() =>
      _BenefitsCenterScreenState();
}

class _BenefitsCenterScreenState extends ConsumerState<BenefitsCenterScreen> {
  int _selectedPlanDays = 30;
  BillingFlowState _billingState = BillingFlowState.idle;

  @override
  Widget build(BuildContext context) {
    final credit = ref.watch(creditStateProvider);
    final account = credit.account;
    final notifier = ref.read(creditStateProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: Text(widget.openCheckin ? '签到打卡' : '权益中心'),
        backgroundColor: AppColors.cream,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
        children: [
          _overviewCard(
            isVip: credit.isVip,
            castBalance: account?.castBalance ?? 0,
            followupBalance: account?.followupBalance ?? 0,
          ),
          const SizedBox(height: AppSpacing.lg),
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
            child: Text(credit.hasCheckedInToday ? '今日已签到' : '签到补给（+1追问）'),
          ),
          if (!widget.openCheckin) ...[
            const SizedBox(height: AppSpacing.lg),
            Text('VIP 套餐', style: AppTypography.labelLarge),
            const SizedBox(height: 8),
            _PlanCard(
              title: '周卡',
              subtitle: '7 天 VIP 权益（模拟）',
              selected: _selectedPlanDays == 7,
              onTap: () => setState(() => _selectedPlanDays = 7),
            ),
            const SizedBox(height: 8),
            _PlanCard(
              title: '月卡',
              subtitle: '30 天 VIP 权益（模拟）',
              selected: _selectedPlanDays == 30,
              onTap: () => setState(() => _selectedPlanDays = 30),
            ),
            const SizedBox(height: 8),
            _PlanCard(
              title: '季卡',
              subtitle: '90 天 VIP 权益（模拟）',
              selected: _selectedPlanDays == 90,
              onTap: () => setState(() => _selectedPlanDays = 90),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed:
                  credit.isLoading ||
                      _billingState == BillingFlowState.confirming
                  ? null
                  : _confirmPurchase,
              child: Text(
                _billingState == BillingFlowState.confirming
                    ? '确认中...'
                    : '确认开通（模拟）',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: credit.isLoading
                  ? null
                  : () async {
                      await notifier.purchaseCast(1);
                      await notifier.purchaseFollowup(1);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已补充 1 解读 + 1 追问额度（模拟）')),
                      );
                    },
              child: const Text('购买补给包（模拟）'),
            ),
          ],
          if ((credit.error ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              credit.error!,
              style: AppTypography.bodySmall.copyWith(color: AppColors.error),
            ),
          ],
        ],
      ),
    );
  }

  Widget _overviewCard({
    required bool isVip,
    required int castBalance,
    required int followupBalance,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isVip ? '当前身份：VIP' : '当前身份：普通用户',
            style: AppTypography.labelLarge.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '今日剩余：解读 $castBalance 次，追问 $followupBalance 次',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '每日规则：普通 1 解读 + 1 追问；VIP 2 解读 + 4 追问',
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmPurchase() async {
    setState(() => _billingState = BillingFlowState.confirming);
    final notifier = ref.read(creditStateProvider.notifier);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('确认购买'),
          content: Text('将开通 $_selectedPlanDays 天 VIP（仅 UI 模拟）。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确认'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      // TODO(Backend Integration)[billing_api#purchase-confirm]:
      // 后续替换为真实订单确认和支付回调。
      await notifier.subscribe(_selectedPlanDays);
      if (!mounted) return;
      setState(() => _billingState = BillingFlowState.success);
      await showDialog<void>(
        context: context,
        builder: (_) {
          return AlertDialog(
            title: const Text('开通成功'),
            content: const Text('VIP 已生效，今日额度已按 VIP 规则刷新。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('知道了'),
              ),
            ],
          );
        },
      );
    }
    if (!mounted) return;
    setState(() => _billingState = BillingFlowState.idle);
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _PlanCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: selected ? AppColors.mintLight : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.2 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              size: 18,
              color: selected ? AppColors.primary : AppColors.textTertiary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.labelLarge),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
