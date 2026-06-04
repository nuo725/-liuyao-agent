import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/credit.dart';

abstract class CreditService {
  Future<CreditAccount?> getAccount(String userId);

  Future<CreditAccount> initAccount(String userId);

  Future<bool> consumeCast(String userId);

  Future<bool> consumeFollowup(String userId);

  Future<CreditAccount?> checkin(String userId);

  Future<CreditAccount?> rewardPublish(String userId);

  Future<CreditAccount?> rewardShare(String userId);

  Future<CreditAccount?> purchaseCast(String userId, int amount);

  Future<CreditAccount?> purchaseFollowup(String userId, int amount);

  Future<CreditAccount?> subscribe(String userId, int days);
}

class CreditException implements Exception {
  final String message;

  const CreditException(this.message);

  @override
  String toString() => message;
}

class CreditConfig {
  static const String backendBaseUrl = String.fromEnvironment(
    'BUSINESS_API_BASE_URL',
    defaultValue:
        'https://polyphonically-plagiocephalic-genesis.ngrok-free.dev/v1',
  );

  static const bool allowDevFallback = bool.fromEnvironment(
    'CREDIT_ALLOW_DEV_FALLBACK',
    defaultValue: true,
  );
}

class CreditApiClient {
  final String baseUrl;
  final http.Client _client;

  CreditApiClient({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  bool get enabled => baseUrl.trim().isNotEmpty;

  Future<CreditAccount?> getAccount(String userId) async {
    final map = await _get('/billing/account', {'userId': userId});
    return _parseAccountFromPayload(map);
  }

  Future<CreditAccount> initAccount(String userId) async {
    final map = await _post('/billing/account/init', {'userId': userId});
    final account = _parseAccountFromPayload(map);
    if (account == null) {
      throw const CreditException('权益初始化失败：服务返回无效。');
    }
    return account;
  }

  Future<bool> consume(String userId, CreditType type) async {
    await _post('/billing/consume', {'userId': userId, 'type': type.value});
    return true;
  }

  Future<CreditAccount?> checkin(String userId) async {
    final map = await _post('/billing/checkin', {'userId': userId});
    return _parseAccountFromPayload(map);
  }

  Future<CreditAccount?> reward({
    required String userId,
    required CreditAction action,
  }) async {
    final map = await _post('/billing/reward', {
      'userId': userId,
      'action': action.value,
    });
    return _parseAccountFromPayload(map);
  }

  Future<CreditAccount?> purchaseCast(String userId, int amount) async {
    final map = await _post('/billing/purchase/cast', {
      'userId': userId,
      'amount': amount,
    });
    return _parseAccountFromPayload(map);
  }

  Future<CreditAccount?> purchaseFollowup(String userId, int amount) async {
    final map = await _post('/billing/purchase/followup', {
      'userId': userId,
      'amount': amount,
    });
    return _parseAccountFromPayload(map);
  }

  Future<CreditAccount?> subscribe(String userId, int days) async {
    final map = await _post('/billing/subscribe', {
      'userId': userId,
      'days': days,
    });
    return _parseAccountFromPayload(map);
  }

  CreditAccount? _parseAccountFromPayload(Map<String, dynamic> payload) {
    final accountMap = payload['account'];
    if (accountMap is Map) {
      return _parseAccountMap(Map<String, dynamic>.from(accountMap));
    }
    return _parseAccountMap(payload);
  }

  CreditAccount? _parseAccountMap(Map<String, dynamic> map) {
    final userId = (map['userId'] ?? map['uid'])?.toString();
    if (userId == null || userId.isEmpty) return null;

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      final s = value.toString().trim();
      if (s.isEmpty) return null;
      return DateTime.tryParse(s);
    }

    final now = DateTime.now();
    return CreditAccount(
      userId: userId,
      castBalance: int.tryParse((map['castBalance'] ?? 0).toString()) ?? 0,
      followupBalance:
          int.tryParse((map['followupBalance'] ?? 0).toString()) ?? 0,
      castExpireDate: parseDate(map['castExpireDate']),
      followupExpireDate: parseDate(map['followupExpireDate']),
      lastCheckinDate: parseDate(map['lastCheckinDate']) ?? now,
      lastResetDate: parseDate(map['lastResetDate']) ?? now,
      isVip: map['isVip'] == true,
      vipExpireDate: parseDate(map['vipExpireDate']),
    );
  }

  Future<Map<String, dynamic>> _get(
    String path,
    Map<String, dynamic> query,
  ) async {
    if (!enabled) {
      throw const CreditException('未配置业务后端地址。');
    }

    final uri = Uri.parse(
      '${baseUrl.trim()}$path',
    ).replace(queryParameters: query.map((k, v) => MapEntry(k, '$v')));
    final resp = await _client.get(uri).timeout(const Duration(seconds: 12));
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw CreditException('权益服务异常(${resp.statusCode})');
    }
    final data = jsonDecode(resp.body);
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const CreditException('权益服务返回格式错误。');
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    if (!enabled) {
      throw const CreditException('未配置业务后端地址。');
    }

    final uri = Uri.parse('${baseUrl.trim()}$path');
    final resp = await _client
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 12));
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw CreditException('权益服务异常(${resp.statusCode})');
    }
    final data = jsonDecode(resp.body);
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const CreditException('权益服务返回格式错误。');
  }
}

class LocalCreditStore {
  static const String _keyPrefix = 'credit_';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  String _accountKey(String userId) => '${_keyPrefix}account_$userId';

  Future<CreditAccount?> getAccount(String userId) async {
    final prefs = await _preferences;
    final raw = prefs.getString(_accountKey(userId));
    if (raw == null || raw.isEmpty) return null;
    try {
      final parsed = jsonDecode(raw);
      if (parsed is Map<String, dynamic>) return CreditAccount.fromJson(parsed);
      if (parsed is Map) {
        return CreditAccount.fromJson(Map<String, dynamic>.from(parsed));
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<void> saveAccount(CreditAccount account) async {
    final prefs = await _preferences;
    await prefs.setString(
      _accountKey(account.userId),
      jsonEncode(account.toJson()),
    );
  }
}

class HybridCreditServiceImpl implements CreditService {
  final CreditApiClient _api;
  final LocalCreditStore _local;

  HybridCreditServiceImpl({CreditApiClient? api, LocalCreditStore? local})
    : _api = api ?? CreditApiClient(baseUrl: CreditConfig.backendBaseUrl),
      _local = local ?? LocalCreditStore();

  bool get _canFallback => CreditConfig.allowDevFallback;

  DateTime _today(DateTime from) => DateTime(from.year, from.month, from.day);

  CreditAccount _applyDailyPolicy(CreditAccount account) {
    final now = DateTime.now();
    final today = _today(now);
    final vipExpired =
        account.vipExpireDate != null && now.isAfter(account.vipExpireDate!);
    final vipActive = account.isVip && !vipExpired;

    if (_today(account.lastResetDate) == today && vipActive == account.isVip) {
      return account;
    }

    // TODO(Backend Integration)[credit_api#daily-reset]: 当前在本地执行每日重置，后续改为服务端结算。
    // TODO(Backend Integration)[credit_api#vip-bonus]: 当前在本地叠加 VIP 加成，后续以服务端权益账本为准。
    return account.copyWith(
      castBalance: vipActive ? 2 : 1,
      followupBalance: vipActive ? 4 : 1,
      lastResetDate: today,
      isVip: vipActive,
      vipExpireDate: vipActive ? account.vipExpireDate : null,
    );
  }

  @override
  Future<CreditAccount?> getAccount(String userId) async {
    if (_api.enabled) {
      try {
        final account = await _api.getAccount(userId);
        if (account != null) {
          final normalized = _applyDailyPolicy(account);
          await _local.saveAccount(normalized);
          return normalized;
        }
      } catch (_) {
        if (!_canFallback) rethrow;
      }
    }

    final local = await _local.getAccount(userId);
    if (local == null) return null;
    final normalized = _applyDailyPolicy(local);
    await _local.saveAccount(normalized);
    return normalized;
  }

  @override
  Future<CreditAccount> initAccount(String userId) async {
    if (_api.enabled) {
      try {
        final account = await _api.initAccount(userId);
        final normalized = _applyDailyPolicy(account);
        await _local.saveAccount(normalized);
        return normalized;
      } catch (_) {
        if (!_canFallback) rethrow;
      }
    }
    final local = _applyDailyPolicy(CreditAccount.newUser(userId));
    await _local.saveAccount(local);
    return local;
  }

  @override
  Future<bool> consumeCast(String userId) {
    return _consume(userId: userId, type: CreditType.cast);
  }

  @override
  Future<bool> consumeFollowup(String userId) {
    return _consume(userId: userId, type: CreditType.followup);
  }

  Future<bool> _consume({
    required String userId,
    required CreditType type,
  }) async {
    if (_api.enabled) {
      try {
        await _api.consume(userId, type);
        final account = await _api.getAccount(userId);
        if (account != null) {
          await _local.saveAccount(_applyDailyPolicy(account));
        }
        return true;
      } catch (_) {
        if (!_canFallback) return false;
      }
    }

    var account = await _local.getAccount(userId);
    if (account == null) return false;
    account = _applyDailyPolicy(account);

    final canUse = type == CreditType.cast
        ? account.canCast()
        : account.canFollowup();
    if (!canUse) return false;

    final next = type == CreditType.cast
        ? account.copyWith(castBalance: account.castBalance - 1)
        : account.copyWith(followupBalance: account.followupBalance - 1);
    await _local.saveAccount(next);
    return true;
  }

  @override
  Future<CreditAccount?> checkin(String userId) async {
    if (_api.enabled) {
      try {
        final account = await _api.checkin(userId);
        if (account != null) {
          final normalized = _applyDailyPolicy(account);
          await _local.saveAccount(normalized);
          return normalized;
        }
      } catch (_) {
        if (!_canFallback) rethrow;
      }
    }

    var account =
        await _local.getAccount(userId) ?? CreditAccount.newUser(userId);
    account = _applyDailyPolicy(account);
    if (account.hasCheckedInToday()) return account;

    final updated = account.copyWith(
      followupBalance: account.followupBalance + 1,
      lastCheckinDate: DateTime.now(),
    );
    await _local.saveAccount(updated);
    return updated;
  }

  @override
  Future<CreditAccount?> rewardPublish(String userId) async {
    return _reward(userId: userId, action: CreditAction.publish);
  }

  @override
  Future<CreditAccount?> rewardShare(String userId) async {
    return _reward(userId: userId, action: CreditAction.share);
  }

  Future<CreditAccount?> _reward({
    required String userId,
    required CreditAction action,
  }) async {
    if (_api.enabled) {
      try {
        final account = await _api.reward(userId: userId, action: action);
        if (account != null) {
          final normalized = _applyDailyPolicy(account);
          await _local.saveAccount(normalized);
          return normalized;
        }
      } catch (_) {
        if (!_canFallback) rethrow;
      }
    }

    var account =
        await _local.getAccount(userId) ?? CreditAccount.newUser(userId);
    account = _applyDailyPolicy(account);
    final updated = account.copyWith(
      followupBalance: account.followupBalance + 1,
    );
    await _local.saveAccount(updated);
    return updated;
  }

  @override
  Future<CreditAccount?> purchaseCast(String userId, int amount) async {
    if (_api.enabled) {
      try {
        final account = await _api.purchaseCast(userId, amount);
        if (account != null) {
          final normalized = _applyDailyPolicy(account);
          await _local.saveAccount(normalized);
          return normalized;
        }
      } catch (_) {
        if (!_canFallback) rethrow;
      }
    }

    var account =
        await _local.getAccount(userId) ?? CreditAccount.newUser(userId);
    account = _applyDailyPolicy(account);
    final updated = account.copyWith(castBalance: account.castBalance + amount);
    await _local.saveAccount(updated);
    return updated;
  }

  @override
  Future<CreditAccount?> purchaseFollowup(String userId, int amount) async {
    if (_api.enabled) {
      try {
        final account = await _api.purchaseFollowup(userId, amount);
        if (account != null) {
          final normalized = _applyDailyPolicy(account);
          await _local.saveAccount(normalized);
          return normalized;
        }
      } catch (_) {
        if (!_canFallback) rethrow;
      }
    }

    var account =
        await _local.getAccount(userId) ?? CreditAccount.newUser(userId);
    account = _applyDailyPolicy(account);
    final updated = account.copyWith(
      followupBalance: account.followupBalance + amount,
    );
    await _local.saveAccount(updated);
    return updated;
  }

  @override
  Future<CreditAccount?> subscribe(String userId, int days) async {
    if (_api.enabled) {
      try {
        final account = await _api.subscribe(userId, days);
        if (account != null) {
          final normalized = _applyDailyPolicy(account);
          await _local.saveAccount(normalized);
          return normalized;
        }
      } catch (_) {
        if (!_canFallback) rethrow;
      }
    }

    var account =
        await _local.getAccount(userId) ?? CreditAccount.newUser(userId);
    final now = DateTime.now();
    final currentExpire = account.vipExpireDate;
    final start = (currentExpire != null && currentExpire.isAfter(now))
        ? currentExpire
        : now;
    final nextExpire = start.add(Duration(days: days));

    // TODO(Backend Integration)[billing_api#purchase-confirm]: 当前为本地模拟开通，后续由服务端订单确认驱动。
    account = account.copyWith(isVip: true, vipExpireDate: nextExpire);
    final normalized = _applyDailyPolicy(account);
    await _local.saveAccount(normalized);
    return normalized;
  }
}

final creditServiceProvider = HybridCreditServiceImpl();
