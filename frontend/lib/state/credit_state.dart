import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/credit.dart';
import '../services/credit_service.dart';
import 'auth_state.dart';

class CreditState {
  final CreditAccount? account;
  final bool isLoading;
  final String? error;

  const CreditState({this.account, this.isLoading = false, this.error});

  int get castBalance => account?.castBalance ?? 0;
  int get followupBalance => account?.followupBalance ?? 0;
  bool get hasCheckedInToday => account?.hasCheckedInToday() ?? false;
  bool get canCast => account?.canCast() ?? false;
  bool get canFollowup => account?.canFollowup() ?? false;
  bool get isVip => account?.isVip ?? false;

  CreditState copyWith({
    CreditAccount? account,
    bool? isLoading,
    String? error,
  }) {
    return CreditState(
      account: account ?? this.account,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class CreditStateNotifier extends Notifier<CreditState> {
  @override
  CreditState build() {
    final authState = ref.watch(authStateProvider);
    if (authState.user != null) {
      _loadAccount(authState.user!.id);
    }
    return const CreditState();
  }

  Future<void> _loadAccount(String userId) async {
    var account = await creditServiceProvider.getAccount(userId);
    account ??= await creditServiceProvider.initAccount(userId);
    state = state.copyWith(account: account, error: null);
  }

  Future<bool> consumeCast() async {
    final userId = ref.read(authStateProvider).user?.id;
    if (userId == null) return false;

    state = state.copyWith(isLoading: true, error: null);
    final success = await creditServiceProvider.consumeCast(userId);
    if (success) {
      await _loadAccount(userId);
    } else {
      state = state.copyWith(error: '今日解读额度不足，请开通 VIP 或购买补给。');
    }
    state = state.copyWith(isLoading: false);
    return success;
  }

  Future<bool> consumeFollowup() async {
    final userId = ref.read(authStateProvider).user?.id;
    if (userId == null) return false;

    state = state.copyWith(isLoading: true, error: null);
    final success = await creditServiceProvider.consumeFollowup(userId);
    if (success) {
      await _loadAccount(userId);
    } else {
      state = state.copyWith(error: '今日追问额度不足，请开通 VIP 或购买补给。');
    }
    state = state.copyWith(isLoading: false);
    return success;
  }

  Future<void> checkin() async {
    final userId = ref.read(authStateProvider).user?.id;
    if (userId == null) return;

    state = state.copyWith(isLoading: true, error: null);
    final account = await creditServiceProvider.checkin(userId);
    if (account != null) {
      state = state.copyWith(account: account, isLoading: false, error: null);
    } else {
      state = state.copyWith(isLoading: false, error: '签到失败，请稍后重试。');
    }
  }

  Future<void> rewardPublish() async {
    final userId = ref.read(authStateProvider).user?.id;
    if (userId == null) return;

    final account = await creditServiceProvider.rewardPublish(userId);
    if (account != null) {
      state = state.copyWith(account: account, error: null);
    }
  }

  Future<void> rewardShare() async {
    final userId = ref.read(authStateProvider).user?.id;
    if (userId == null) return;

    final account = await creditServiceProvider.rewardShare(userId);
    if (account != null) {
      state = state.copyWith(account: account, error: null);
    }
  }

  Future<void> purchaseCast(int amount) async {
    if (amount <= 0) return;
    final userId = ref.read(authStateProvider).user?.id;
    if (userId == null) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final account = await creditServiceProvider.purchaseCast(userId, amount);
      if (account != null) {
        state = state.copyWith(account: account, isLoading: false, error: null);
      } else {
        state = state.copyWith(isLoading: false, error: '补充解读额度失败。');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '补充解读额度失败: $e');
    }
  }

  Future<void> purchaseFollowup(int amount) async {
    if (amount <= 0) return;
    final userId = ref.read(authStateProvider).user?.id;
    if (userId == null) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final account = await creditServiceProvider.purchaseFollowup(
        userId,
        amount,
      );
      if (account != null) {
        state = state.copyWith(account: account, isLoading: false, error: null);
      } else {
        state = state.copyWith(isLoading: false, error: '补充追问额度失败。');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '补充追问额度失败: $e');
    }
  }

  Future<void> subscribe(int days) async {
    if (days <= 0) return;
    final userId = ref.read(authStateProvider).user?.id;
    if (userId == null) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final account = await creditServiceProvider.subscribe(userId, days);
      if (account != null) {
        state = state.copyWith(account: account, isLoading: false, error: null);
      } else {
        state = state.copyWith(isLoading: false, error: '开通 VIP 失败。');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '开通 VIP 失败: $e');
    }
  }

  Future<void> refresh() async {
    final userId = ref.read(authStateProvider).user?.id;
    if (userId != null) {
      await _loadAccount(userId);
    }
  }
}

final creditStateProvider = NotifierProvider<CreditStateNotifier, CreditState>(
  CreditStateNotifier.new,
);
