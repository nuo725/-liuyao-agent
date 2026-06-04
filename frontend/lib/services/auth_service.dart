import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/user.dart';

abstract class AuthService {
  Future<User?> getCurrentUser();

  Future<void> sendPhoneCode(String phone);

  Future<User> loginWithPhone(String phone, String code);

  Future<User> loginWithWechat(String code);

  Future<User> loginWithQQ(String code);

  Future<User> loginWithDouyin(String code);

  Future<User> updateProfile({
    String? username,
    String? avatarUrl,
    String? coverUrl,
    String? bio,
  });

  Future<String?> uploadAvatar(String filePath);

  Future<String?> uploadCover(String filePath);

  Future<User> updateGender(String gender);

  Future<User> setBirthInfo({required DateTime birthday, String? birthCity});

  Future<void> logout();

  bool get isLoggedIn;

  String? get currentUserId;
}

enum SocialProvider { wechat, qq, douyin }

class AuthException implements Exception {
  final String message;

  const AuthException(this.message);

  @override
  String toString() => message;
}

class AuthConfig {
  // 开发环境默认指向本地后端
  // 生产环境通过 --dart-define BUSINESS_API_BASE_URL=xxx 设置
  // ⚠️ TESTING: ngrok 穿透后端
  static const String backendBaseUrl = String.fromEnvironment(
    'BUSINESS_API_BASE_URL',
    defaultValue:
        'https://polyphonically-plagiocephalic-genesis.ngrok-free.dev/v1',
  );
  static const bool allowDevFallback = bool.fromEnvironment(
    'AUTH_ALLOW_DEV_FALLBACK',
    defaultValue: true, // UI 阶段开启，方便测试
  );
}

abstract class ThirdPartyAuthBridge {
  Future<String> requestAuthCode(SocialProvider provider);
}

class MethodChannelThirdPartyAuthBridge implements ThirdPartyAuthBridge {
  static const MethodChannel _channel = MethodChannel('zhouyi/social_auth');

  @override
  Future<String> requestAuthCode(SocialProvider provider) async {
    final method = switch (provider) {
      SocialProvider.wechat => 'loginWithWechat',
      SocialProvider.qq => 'loginWithQQ',
      SocialProvider.douyin => 'loginWithDouyin',
    };

    try {
      final result = await _channel.invokeMethod<String>(method);
      final code = (result ?? '').trim();
      if (code.isEmpty) {
        throw const AuthException('未获取到第三方授权码，请重试。');
      }
      return code;
    } on PlatformException catch (e) {
      throw AuthException(e.message ?? '第三方登录调用失败。');
    } catch (_) {
      throw const AuthException('第三方登录暂不可用，请稍后重试。');
    }
  }
}

class AuthApiClient {
  final String baseUrl;
  final http.Client _client;

  AuthApiClient({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  bool get enabled => baseUrl.trim().isNotEmpty;

  Future<Map<String, dynamic>> loginWithPhone({
    required String phone,
    required String code,
  }) {
    return _post('/auth/phone/login', {'phone': phone, 'code': code});
  }

  Future<void> sendPhoneCode(String phone) async {
    await _post('/auth/phone/send-code', {'phone': phone});
  }

  Future<Map<String, dynamic>> loginWithSocial({
    required SocialProvider provider,
    required String authCode,
  }) {
    return _post('/auth/social/login', {
      'provider': provider.name,
      'authCode': authCode,
    });
  }

  Future<Map<String, dynamic>> updateProfile({
    required String userId,
    required String? username,
    required String? avatarUrl,
    required String? coverUrl,
    required String? bio,
  }) {
    // TODO(Backend Integration)[profile_api#update]: 与后端字段对齐后替换当前兼容映射
    return _post('/auth/profile/update', {
      'userId': userId,
      'username': username,
      'avatarUrl': avatarUrl,
      'coverUrl': coverUrl,
      'bio': bio,
    });
  }

  Future<Map<String, dynamic>> setBirthInfo({
    required String userId,
    required DateTime birthday,
    required String? birthCity,
  }) {
    // TODO(Backend Integration)[profile_api#update]: 合并到统一资料更新接口后移除该专用调用
    return _post('/auth/profile/birth', {
      'userId': userId,
      'birthday': birthday.toIso8601String(),
      'birthCity': birthCity,
    });
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    if (!enabled) {
      throw const AuthException('未配置业务后端地址。');
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
      throw AuthException('登录服务异常(${resp.statusCode})');
    }

    final data = jsonDecode(resp.body);
    if (data is! Map<String, dynamic>) {
      throw const AuthException('登录服务返回格式错误。');
    }
    return data;
  }

  /// 上传图片并返回 URL
  /// [filePath] 本地文件路径
  /// [type] 图片类型：avatar 或 cover
  Future<String?> uploadImage({
    required String filePath,
    required String type,
  }) async {
    // TODO(Backend Integration)[profile_api#media-upload]: 替换为正式媒体上传签名/直传链路
    if (!enabled) {
      return null;
    }

    try {
      final uri = Uri.parse('${baseUrl.trim()}/upload/image');
      final request = http.MultipartRequest('POST', uri);

      request.fields['type'] = type;
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      final streamedResp = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final resp = await http.Response.fromStream(streamedResp);

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        return null;
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return data['url'] as String?;
    } catch (e) {
      return null;
    }
  }
}

class HybridAuthServiceImpl implements AuthService {
  static const String _keyUserId = 'auth_user_id';
  static const String _keyUserJson = 'auth_user_json';
  static const String _keyAnonymousId = 'anonymous_id';

  final ThirdPartyAuthBridge _bridge;
  final AuthApiClient _api;

  SharedPreferences? _prefs;
  User? _currentUser;

  HybridAuthServiceImpl({ThirdPartyAuthBridge? bridge, AuthApiClient? api})
    : _bridge = bridge ?? MethodChannelThirdPartyAuthBridge(),
      _api = api ?? AuthApiClient(baseUrl: AuthConfig.backendBaseUrl);

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  @override
  Future<User?> getCurrentUser() async {
    if (_currentUser != null) return _currentUser;

    final prefs = await _preferences;
    final userJson = prefs.getString(_keyUserJson);
    if (userJson != null && userJson.isNotEmpty) {
      try {
        final parsed = jsonDecode(userJson);
        if (parsed is Map<String, dynamic>) {
          _currentUser = User.fromJson(parsed);
          return _currentUser;
        }
        if (parsed is Map) {
          _currentUser = User.fromJson(Map<String, dynamic>.from(parsed));
          return _currentUser;
        }
      } catch (_) {}
    }

    final userId = prefs.getString(_keyUserId);
    if (userId != null) {
      _currentUser = User(
        id: userId,
        createdAt: DateTime.now(),
        isAnonymous: false,
      );
      await _saveUser(_currentUser!);
      return _currentUser;
    }

    final anonymousId = prefs.getString(_keyAnonymousId) ?? const Uuid().v4();
    await prefs.setString(_keyAnonymousId, anonymousId);
    _currentUser = User.anonymous(anonymousId);
    return _currentUser;
  }

  @override
  Future<void> sendPhoneCode(String phone) async {
    if (_api.enabled) {
      try {
        await _api.sendPhoneCode(phone);
        return;
      } catch (_) {
        // 后端不可用时，开发模式直接跳过（模拟发送成功）
        if (!AuthConfig.allowDevFallback) {
          throw const AuthException('未配置业务后端，无法发送验证码。');
        }
        return;
      }
    }

    if (!AuthConfig.allowDevFallback) {
      throw const AuthException('未配置业务后端，无法发送验证码。');
    }
  }

  @override
  Future<User> loginWithPhone(String phone, String code) async {
    if (_api.enabled) {
      try {
        final payload = await _api.loginWithPhone(phone: phone, code: code);
        final user = _parseUserPayload(
          payload,
          fallbackName: _maskedPhone(phone),
        );
        await _saveUser(user);
        _currentUser = user;
        return user;
      } catch (_) {
        // 后端不可用时，开发模式 fallback 到本地 mock 账号
        if (!AuthConfig.allowDevFallback) {
          throw const AuthException('未配置业务后端，无法完成手机号登录。');
        }
      }
    }

    return _saveDevUser('用户${_maskedPhone(phone)}');
  }

  @override
  Future<User> loginWithWechat(String code) {
    return _loginWithSocial(SocialProvider.wechat, code);
  }

  @override
  Future<User> loginWithQQ(String code) {
    return _loginWithSocial(SocialProvider.qq, code);
  }

  @override
  Future<User> loginWithDouyin(String code) {
    return _loginWithSocial(SocialProvider.douyin, code);
  }

  Future<User> _loginWithSocial(SocialProvider provider, String code) async {
    if (!_api.enabled && AuthConfig.allowDevFallback) {
      return _saveDevUser('${provider.name}_dev');
    }

    final authCode = code.trim().isNotEmpty
        ? code.trim()
        : await _bridge.requestAuthCode(provider);

    if (_api.enabled) {
      final payload = await _api.loginWithSocial(
        provider: provider,
        authCode: authCode,
      );
      final user = _parseUserPayload(payload, fallbackName: provider.name);
      await _saveUser(user);
      _currentUser = user;
      return user;
    }

    if (!AuthConfig.allowDevFallback) {
      throw const AuthException('未配置业务后端，无法完成第三方登录。');
    }

    return _saveDevUser('${provider.name}_dev');
  }

  @override
  Future<User> updateProfile({
    String? username,
    String? avatarUrl,
    String? coverUrl,
    String? bio,
  }) async {
    final current = _currentUser ?? await getCurrentUser();
    if (current == null) {
      throw const AuthException('未找到当前账号。');
    }

    if (_api.enabled) {
      try {
        final payload = await _api.updateProfile(
          userId: current.id,
          username: username,
          avatarUrl: avatarUrl,
          coverUrl: coverUrl,
          bio: bio,
        );
        final user = _parseUserPayload(
          payload,
          fallbackName: username ?? current.username ?? '用户',
        ).copyWith(createdAt: current.createdAt);
        await _saveUser(user);
        _currentUser = user;
        return user;
      } catch (_) {
        // API 不可用时 Fallback 到本地存储
      }
    }

    final updated = current.copyWith(
      username: username ?? current.username,
      avatarUrl: avatarUrl ?? current.avatarUrl,
      coverUrl: coverUrl ?? current.coverUrl,
      bio: bio ?? current.bio,
      isAnonymous: false,
    );

    await _saveUser(updated);
    _currentUser = updated;
    return updated;
  }

  @override
  Future<User> updateGender(String gender) async {
    final current = _currentUser ?? await getCurrentUser();
    if (current == null) {
      throw const AuthException('未找到当前账号。');
    }

    final updated = current.copyWith(gender: gender);
    await _saveUser(updated);
    _currentUser = updated;
    return updated;
  }

  @override
  Future<User> setBirthInfo({
    required DateTime birthday,
    String? birthCity,
  }) async {
    final current = _currentUser ?? await getCurrentUser();
    if (current == null) {
      throw const AuthException('未找到当前账号。');
    }

    if (_api.enabled) {
      final payload = await _api.setBirthInfo(
        userId: current.id,
        birthday: birthday,
        birthCity: birthCity,
      );
      final user = _parseUserPayload(
        payload,
        fallbackName: current.username ?? '用户',
      ).copyWith(createdAt: current.createdAt);
      await _saveUser(user);
      _currentUser = user;
      return user;
    }

    final updated = current.copyWith(
      birthday: birthday,
      birthCity: birthCity ?? current.birthCity,
      isAnonymous: false,
    );
    await _saveUser(updated);
    _currentUser = updated;
    return updated;
  }

  @override
  Future<String?> uploadAvatar(String filePath) async {
    return _api.uploadImage(filePath: filePath, type: 'avatar');
  }

  @override
  Future<String?> uploadCover(String filePath) async {
    return _api.uploadImage(filePath: filePath, type: 'cover');
  }

  @override
  Future<void> logout() async {
    final prefs = await _preferences;
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserJson);
    _currentUser = null;
  }

  @override
  bool get isLoggedIn => _currentUser != null && !_currentUser!.isAnonymous;

  @override
  String? get currentUserId => _currentUser?.id;

  User _parseUserPayload(
    Map<String, dynamic> payload, {
    required String fallbackName,
  }) {
    final userMap = payload['user'];
    if (userMap is Map<String, dynamic>) {
      return User(
        id: (userMap['id'] ?? const Uuid().v4()).toString(),
        username: (userMap['username'] ?? userMap['nickname'] ?? fallbackName)
            .toString(),
        avatarUrl:
            userMap['avatarUrl']?.toString() ?? userMap['avatar']?.toString(),
        coverUrl: userMap['coverUrl']?.toString(),
        bio: userMap['bio']?.toString(),
        createdAt:
            DateTime.tryParse((userMap['createdAt'] ?? '').toString()) ??
            DateTime.now(),
        isAnonymous: false,
      );
    }

    return User(
      id: (payload['userId'] ?? const Uuid().v4()).toString(),
      username: (payload['username'] ?? fallbackName).toString(),
      avatarUrl: payload['avatarUrl']?.toString(),
      coverUrl: payload['coverUrl']?.toString(),
      bio: payload['bio']?.toString(),
      createdAt: DateTime.now(),
      isAnonymous: false,
    );
  }

  Future<User> _saveDevUser(String name) async {
    final user = User(
      id: const Uuid().v4(),
      username: name,
      createdAt: DateTime.now(),
      isAnonymous: false,
    );
    await _saveUser(user);
    _currentUser = user;
    return user;
  }

  Future<void> _saveUser(User user) async {
    final prefs = await _preferences;
    await prefs.setString(_keyUserId, user.id);
    await prefs.setString(_keyUserJson, jsonEncode(user.toJson()));
  }

  String _maskedPhone(String phone) {
    if (phone.length < 4) return phone;
    return phone.substring(phone.length - 4);
  }
}

final authServiceProvider = HybridAuthServiceImpl();
