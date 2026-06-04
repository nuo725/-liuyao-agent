import 'package:shared_preferences/shared_preferences.dart';

abstract class SameFrequencyUnlockService {
  Future<bool> isUnlocked();
  Future<void> markUnlocked();
}

class SharedPrefsSameFrequencyUnlockServiceImpl
    implements SameFrequencyUnlockService {
  static const String _key = 'same_frequency_unlocked_v1';
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  @override
  Future<bool> isUnlocked() async {
    final prefs = await _preferences;
    return prefs.getBool(_key) ?? false;
  }

  @override
  Future<void> markUnlocked() async {
    final prefs = await _preferences;
    await prefs.setBool(_key, true);
  }
}

final sameFrequencyUnlockServiceProvider =
    SharedPrefsSameFrequencyUnlockServiceImpl();
