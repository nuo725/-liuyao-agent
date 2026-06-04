import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/profile_hub.dart';

abstract class ProfileHubService {
  Future<List<InteractionRecord>> getInteractions();

  Future<void> saveInteractions(List<InteractionRecord> value);

  Future<List<BrowseRecord>> getBrowseRecords();

  Future<void> saveBrowseRecords(List<BrowseRecord> value);

  Future<ProfileSettings> getSettings();

  Future<void> saveSettings(ProfileSettings value);
}

class SharedPrefsProfileHubService implements ProfileHubService {
  static const String _interactionsKey = 'profile_hub_interactions_v1';
  static const String _browseKey = 'profile_hub_browse_v1';
  static const String _settingsKey = 'profile_hub_settings_v1';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  @override
  Future<List<InteractionRecord>> getInteractions() async {
    // TODO(Backend Integration)[profile_api#interactions]: 用后端记录替换本地缓存读取
    final prefs = await _preferences;
    final raw = prefs.getString(_interactionsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final parsed = jsonDecode(raw);
      if (parsed is! List) return const [];
      return parsed
          .whereType<Map>()
          .map((e) => InteractionRecord.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> saveInteractions(List<InteractionRecord> value) async {
    // TODO(Backend Integration)[profile_api#interactions]: 切到后端后改为增量上报
    final prefs = await _preferences;
    final raw = jsonEncode(value.map((e) => e.toJson()).toList());
    await prefs.setString(_interactionsKey, raw);
  }

  @override
  Future<List<BrowseRecord>> getBrowseRecords() async {
    // TODO(Backend Integration)[profile_api#browse]: 用后端记录替换本地缓存读取
    final prefs = await _preferences;
    final raw = prefs.getString(_browseKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final parsed = jsonDecode(raw);
      if (parsed is! List) return const [];
      return parsed
          .whereType<Map>()
          .map((e) => BrowseRecord.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> saveBrowseRecords(List<BrowseRecord> value) async {
    // TODO(Backend Integration)[profile_api#browse]: 切到后端后改为增量上报
    final prefs = await _preferences;
    final raw = jsonEncode(value.map((e) => e.toJson()).toList());
    await prefs.setString(_browseKey, raw);
  }

  @override
  Future<ProfileSettings> getSettings() async {
    // TODO(Backend Integration)[profile_api#settings]: 接入远端用户设置读取
    final prefs = await _preferences;
    final raw = prefs.getString(_settingsKey);
    if (raw == null || raw.isEmpty) return const ProfileSettings();
    try {
      final parsed = jsonDecode(raw);
      if (parsed is Map<String, dynamic>) {
        return ProfileSettings.fromJson(parsed);
      }
      if (parsed is Map) {
        return ProfileSettings.fromJson(Map<String, dynamic>.from(parsed));
      }
      return const ProfileSettings();
    } catch (_) {
      return const ProfileSettings();
    }
  }

  @override
  Future<void> saveSettings(ProfileSettings value) async {
    // TODO(Backend Integration)[profile_api#settings]: 接入远端用户设置更新
    final prefs = await _preferences;
    await prefs.setString(_settingsKey, jsonEncode(value.toJson()));
  }
}

final profileHubServiceProvider = SharedPrefsProfileHubService();
