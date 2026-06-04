import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

abstract class RitualCacheService {
  Future<void> saveSnapshot(Map<String, dynamic> snapshot);

  Future<Map<String, dynamic>?> loadSnapshot();

  Future<void> clearSnapshot();
}

class SharedPrefsRitualCacheService implements RitualCacheService {
  static const String _snapshotKey = 'ritual_snapshot_v1';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  @override
  Future<void> saveSnapshot(Map<String, dynamic> snapshot) async {
    final prefs = await _preferences;
    await prefs.setString(_snapshotKey, jsonEncode(snapshot));
  }

  @override
  Future<Map<String, dynamic>?> loadSnapshot() async {
    final prefs = await _preferences;
    final raw = prefs.getString(_snapshotKey);
    if (raw == null || raw.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> clearSnapshot() async {
    final prefs = await _preferences;
    await prefs.remove(_snapshotKey);
  }
}

final ritualCacheServiceProvider = SharedPrefsRitualCacheService();
