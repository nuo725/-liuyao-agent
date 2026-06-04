import 'package:shared_preferences/shared_preferences.dart';

abstract class OnboardingPersistenceService {
  Future<int> getCurrentPage();
  Future<void> saveCurrentPage(int page);
  Future<bool> isCompleted();
  Future<void> markCompleted();
}

class SharedPrefsOnboardingPersistenceServiceImpl
    implements OnboardingPersistenceService {
  static const String _pageKey = 'onboarding_page_v1';
  static const String _doneKey = 'onboarding_completed_v1';
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  @override
  Future<int> getCurrentPage() async {
    final prefs = await _preferences;
    return prefs.getInt(_pageKey) ?? 0;
  }

  @override
  Future<void> saveCurrentPage(int page) async {
    final prefs = await _preferences;
    await prefs.setInt(_pageKey, page);
  }

  @override
  Future<bool> isCompleted() async {
    final prefs = await _preferences;
    return prefs.getBool(_doneKey) ?? false;
  }

  @override
  Future<void> markCompleted() async {
    final prefs = await _preferences;
    await prefs.setBool(_doneKey, true);
  }
}

final onboardingPersistenceServiceProvider =
    SharedPrefsOnboardingPersistenceServiceImpl();
