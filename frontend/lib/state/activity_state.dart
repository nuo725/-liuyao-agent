import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/activity_service.dart';
import 'auth_state.dart';

class ActivityListState {
  final List<Activity> activities;
  final bool isLoading;
  final String? error;

  const ActivityListState({
    this.activities = const [],
    this.isLoading = true,
    this.error,
  });

  ActivityListState copyWith({
    List<Activity>? activities,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return ActivityListState(
      activities: activities ?? this.activities,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ActivityListNotifier extends Notifier<ActivityListState> {
  @override
  ActivityListState build() {
    Future.microtask(() => fetchActivities());
    return const ActivityListState();
  }

  Future<void> fetchActivities() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final userId = ref.read(authStateProvider).user?.id;
      final activities = await activityServiceProvider.getActivities(
        userId: userId,
      );
      state = state.copyWith(activities: activities, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: '加载失败：$e', isLoading: false);
    }
  }
}

final activityListProvider =
    NotifierProvider<ActivityListNotifier, ActivityListState>(
      ActivityListNotifier.new,
    );
