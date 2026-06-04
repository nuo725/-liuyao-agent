import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

/// 认证状态
class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
  });

  bool get isLoggedIn => user != null && !user!.isAnonymous;
  bool get isAnonymous => user == null || user!.isAnonymous;

  AuthState copyWith({
    User? user,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 认证状态管理器
class AuthStateNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    _init();
    return const AuthState();
  }

  Future<void> _init() async {
    final user = await authServiceProvider.getCurrentUser();
    state = state.copyWith(user: user);
  }

  Future<void> loginWithPhone(String phone, String code) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await authServiceProvider.loginWithPhone(phone, code);
      state = state.copyWith(user: user, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> sendPhoneCode(String phone) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await authServiceProvider.sendPhoneCode(phone);
      state = state.copyWith(isLoading: false, error: null);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loginWithWechat(String code) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await authServiceProvider.loginWithWechat(code);
      state = state.copyWith(user: user, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loginWithQQ(String code) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await authServiceProvider.loginWithQQ(code);
      state = state.copyWith(user: user, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loginWithDouyin(String code) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await authServiceProvider.loginWithDouyin(code);
      state = state.copyWith(user: user, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> updateProfile({
    String? username,
    String? avatarUrl,
    String? coverUrl,
    String? bio,
  }) async {
    try {
      final user = await authServiceProvider.updateProfile(
        username: username,
        avatarUrl: avatarUrl,
        coverUrl: coverUrl,
        bio: bio,
      );
      state = state.copyWith(user: user);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> setBirthInfo({
    required DateTime birthday,
    String? birthCity,
  }) async {
    try {
      final user = await authServiceProvider.setBirthInfo(
        birthday: birthday,
        birthCity: birthCity,
      );
      state = state.copyWith(user: user);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> updateGender(String gender) async {
    try {
      final user = await authServiceProvider.updateGender(gender);
      state = state.copyWith(user: user);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> logout() async {
    await authServiceProvider.logout();
    state = const AuthState();
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Provider
final authStateProvider =
    NotifierProvider<AuthStateNotifier, AuthState>(AuthStateNotifier.new);
