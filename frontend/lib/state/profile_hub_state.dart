import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/profile_hub.dart';
import '../services/profile_hub_service.dart';

class ProfileHubState {
  final bool isLoading;
  final String? error;
  final List<InteractionRecord> interactions;
  final List<BrowseRecord> browseRecords;
  final ProfileSettings settings;

  const ProfileHubState({
    this.isLoading = false,
    this.error,
    this.interactions = const [],
    this.browseRecords = const [],
    this.settings = const ProfileSettings(),
  });

  ProfileHubState copyWith({
    bool? isLoading,
    String? error,
    bool clearError = false,
    List<InteractionRecord>? interactions,
    List<BrowseRecord>? browseRecords,
    ProfileSettings? settings,
  }) {
    return ProfileHubState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      interactions: interactions ?? this.interactions,
      browseRecords: browseRecords ?? this.browseRecords,
      settings: settings ?? this.settings,
    );
  }
}

class ProfileHubNotifier extends Notifier<ProfileHubState> {
  @override
  ProfileHubState build() {
    unawaited(refresh());
    return const ProfileHubState();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final interactions = await profileHubServiceProvider.getInteractions();
      final browse = await profileHubServiceProvider.getBrowseRecords();
      final settings = await profileHubServiceProvider.getSettings();
      state = state.copyWith(
        isLoading: false,
        interactions: interactions,
        browseRecords: browse,
        settings: settings,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '加载个人中心数据失败: $e');
    }
  }

  Future<void> recordLike({
    required String source,
    required String contentKey,
    required String title,
    String? detail,
  }) async {
    await recordInteraction(
      source: source,
      contentKey: contentKey,
      title: title,
      detail: detail,
    );
  }

  Future<void> recordInteraction({
    required String source,
    required String contentKey,
    required String title,
    String? detail,
    bool uniqueBySourceAndKey = true,
  }) async {
    final now = DateTime.now();
    final item = InteractionRecord(
      id: now.microsecondsSinceEpoch.toString(),
      contentKey: contentKey,
      source: source,
      title: title,
      detail: detail,
      createdAt: now,
    );

    final list = [...state.interactions];
    if (uniqueBySourceAndKey) {
      list.removeWhere((e) => e.contentKey == contentKey && e.source == source);
    }
    list.insert(0, item);
    final clipped = list.take(200).toList();
    state = state.copyWith(interactions: clipped, clearError: true);
    await profileHubServiceProvider.saveInteractions(clipped);
  }

  Future<void> removeLike({
    required String source,
    required String contentKey,
  }) async {
    await removeInteraction(source: source, contentKey: contentKey);
  }

  Future<void> removeInteraction({
    required String source,
    required String contentKey,
  }) async {
    final list = [...state.interactions]
      ..removeWhere((e) => e.contentKey == contentKey && e.source == source);
    state = state.copyWith(interactions: list, clearError: true);
    await profileHubServiceProvider.saveInteractions(list);
  }

  Future<void> clearInteractions() async {
    state = state.copyWith(interactions: const [], clearError: true);
    await profileHubServiceProvider.saveInteractions(const []);
  }

  Future<void> recordBrowse({
    required String source,
    required String contentKey,
    required String title,
    String? snippet,
  }) async {
    final now = DateTime.now();
    final item = BrowseRecord(
      id: now.microsecondsSinceEpoch.toString(),
      contentKey: contentKey,
      source: source,
      title: title,
      snippet: snippet,
      createdAt: now,
    );
    final list = [...state.browseRecords];
    list.removeWhere((e) => e.contentKey == contentKey && e.source == source);
    list.insert(0, item);
    final clipped = list.take(300).toList();
    state = state.copyWith(browseRecords: clipped, clearError: true);
    await profileHubServiceProvider.saveBrowseRecords(clipped);
  }

  Future<void> clearBrowseRecords() async {
    state = state.copyWith(browseRecords: const [], clearError: true);
    await profileHubServiceProvider.saveBrowseRecords(const []);
  }

  Future<void> updateSettings(ProfileSettings next) async {
    state = state.copyWith(settings: next, clearError: true);
    await profileHubServiceProvider.saveSettings(next);
  }
}

final profileHubStateProvider =
    NotifierProvider<ProfileHubNotifier, ProfileHubState>(
      ProfileHubNotifier.new,
    );
