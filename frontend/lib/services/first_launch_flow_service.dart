import 'package:shared_preferences/shared_preferences.dart';

abstract class FirstLaunchFlowService {
  Future<bool> isCompleted();
  Future<void> markCompleted();

  /// 首次体验仪式是否已完成（用于判断是否显示简短版解读）
  Future<bool> isFirstRitualDone();
  Future<void> markFirstRitualDone();
}

class SharedPrefsFirstLaunchFlowServiceImpl implements FirstLaunchFlowService {
  static const String _key = 'first_launch_flow_done_v2';
  static const String _firstRitualKey = 'first_ritual_done_v1';
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  @override
  Future<bool> isCompleted() async {
    final prefs = await _preferences;
    return prefs.getBool(_key) ?? false;
  }

  @override
  Future<void> markCompleted() async {
    final prefs = await _preferences;
    await prefs.setBool(_key, true);
  }

  @override
  Future<bool> isFirstRitualDone() async {
    final prefs = await _preferences;
    return prefs.getBool(_firstRitualKey) ?? false;
  }

  @override
  Future<void> markFirstRitualDone() async {
    final prefs = await _preferences;
    await prefs.setBool(_firstRitualKey, true);
  }
}

final firstLaunchFlowServiceProvider = SharedPrefsFirstLaunchFlowServiceImpl();
