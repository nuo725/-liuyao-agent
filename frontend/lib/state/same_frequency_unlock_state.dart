import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/same_frequency_unlock_service.dart';

final sameFrequencyUnlockProvider =
    NotifierProvider<SameFrequencyUnlockNotifier, bool>(
  SameFrequencyUnlockNotifier.new,
);

class SameFrequencyUnlockNotifier extends Notifier<bool> {
  @override
  bool build() {
    // Synchronous initial value; real async load happens in initState of widgets
    return false;
  }

  Future<void> initialize() async {
    state = await sameFrequencyUnlockServiceProvider.isUnlocked();
  }

  Future<void> unlock() async {
    await sameFrequencyUnlockServiceProvider.markUnlocked();
    state = true;
  }
}
