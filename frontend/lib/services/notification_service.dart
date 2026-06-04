import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================================
// 通知服务
// ============================================================================
//
// 待接入后端 API（推送服务）：
//   POST /notifications/token   注册设备 Token
//   GET  /notifications        获取消息列表
//   POST /notifications/:id/read   标记已读
//   POST /notifications/:id/dismiss  删除消息
//   GET  /notifications/unread-count 获取未读数
//
// 消息类型（type）：
//   interaction - 他人的点赞/评论/关注等互动
//   browse      - 有人浏览了你的内容
//   system      - 系统通知（版本更新、活动提醒等）
//
// POST /notifications/token 请求结构：
//   { "token": "fcm_device_token_string", "platform": "android" }
//
// GET /notifications 响应结构：
//   {
//     "success": true,
//     "data": {
//       "messages": [
//         {
//           "id": "notif_001",
//           "type": "interaction",
//           "title": "鹿野赞了你的分享",
//           "body": "「在宽窄之间找到内心的平静」",
//           "data": { "targetId": "feed_xxx", "targetType": "feed" },
//           "createdAt": "2026-04-10T14:30:00Z",
//           "read": false
//         }
//       ],
//       "unreadCount": 3
//     }
//   }
//
// 后端实现注意事项：
//   - interaction/browse 类消息合并展示（如"等3人赞了你的分享"）
//   - 已删除消息不计入未读数
//   - 消息保留 30 天后自动清理
// ============================================================================

/// 通知消息数据模型
class NotificationMessage {
  final String id;
  final String type; // interaction | browse | system
  final String title;
  final String? body;
  final Map<String, dynamic>? data;
  final DateTime createdAt;
  final bool read;

  const NotificationMessage({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    this.data,
    required this.createdAt,
    this.read = false,
  });

  NotificationMessage copyWith({
    String? id,
    String? type,
    String? title,
    String? body,
    Map<String, dynamic>? data,
    DateTime? createdAt,
    bool? read,
  }) {
    return NotificationMessage(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      read: read ?? this.read,
    );
  }

  factory NotificationMessage.fromJson(Map<String, dynamic> json) {
    return NotificationMessage(
      id: json['id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      body: json['body'] as String?,
      data: json['data'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      read: json['read'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'title': title,
    'body': body,
    'data': data,
    'createdAt': createdAt.toIso8601String(),
    'read': read,
  };
}

/// 通知服务接口
abstract class NotificationService {
  /// 注册设备推送 Token 到后端
  Future<void> registerDeviceToken(String token, {String platform = 'android'});

  /// 获取消息列表
  Future<List<NotificationMessage>> getMessages({
    int page = 0,
    int pageSize = 20,
  });

  /// 获取未读消息数量
  Future<int> getUnreadCount();

  /// 标记单条消息为已读
  Future<void> markAsRead(String id);

  /// 标记所有消息为已读
  Future<void> markAllAsRead();

  /// 删除（Dismiss）单条消息
  Future<void> dismiss(String id);

  /// 清除所有消息
  Future<void> clearAll();

  /// 删除设备 Token（退出登录时调用）
  Future<void> unregisterDeviceToken();
}

/// 本地 Mock 实现（开发调试用）
/// TODO(Backend Integration)[message_api#switch]: 替换为 HybridNotificationServiceImpl
class LocalNotificationServiceImpl implements NotificationService {
  static const String _tokenKey = 'notification_device_token';
  static const String _messagesKey = 'notification_messages_v1';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  @override
  Future<void> registerDeviceToken(
    String token, {
    String platform = 'android',
  }) async {
    final prefs = await _preferences;
    await prefs.setString(_tokenKey, token);
    // TODO(Backend Integration)[message_api#register-token]: 调用 POST /notifications/token
  }

  @override
  Future<List<NotificationMessage>> getMessages({
    int page = 0,
    int pageSize = 20,
  }) async {
    final prefs = await _preferences;
    final raw = prefs.getString(_messagesKey);
    if (raw == null || raw.isEmpty) return _mockMessages();

    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => NotificationMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return _mockMessages();
    }
  }

  @override
  Future<int> getUnreadCount() async {
    final prefs = await _preferences;
    final raw = prefs.getString(_messagesKey);
    if (raw == null || raw.isEmpty) {
      return _mockMessages().where((m) => !m.read).length;
    }

    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => NotificationMessage.fromJson(e as Map<String, dynamic>))
          .where((m) => !m.read)
          .length;
    } catch (_) {
      return _mockMessages().where((m) => !m.read).length;
    }
  }

  @override
  Future<void> markAsRead(String id) async {
    final messages = await getMessages();
    final updated = messages
        .map((m) => m.id == id ? m.copyWith(read: true) : m)
        .toList();
    await _saveMessages(updated);
  }

  @override
  Future<void> markAllAsRead() async {
    final messages = await getMessages();
    final updated = messages.map((m) => m.copyWith(read: true)).toList();
    await _saveMessages(updated);
  }

  @override
  Future<void> dismiss(String id) async {
    final messages = await getMessages();
    final updated = messages.where((m) => m.id != id).toList();
    await _saveMessages(updated);
  }

  @override
  Future<void> clearAll() async {
    final prefs = await _preferences;
    await prefs.remove(_messagesKey);
  }

  @override
  Future<void> unregisterDeviceToken() async {
    final prefs = await _preferences;
    await prefs.remove(_tokenKey);
    // TODO(Backend Integration)[message_api#unregister-token]: 调用 DELETE /notifications/token
  }

  Future<void> _saveMessages(List<NotificationMessage> messages) async {
    final prefs = await _preferences;
    final raw = jsonEncode(messages.map((m) => m.toJson()).toList());
    await prefs.setString(_messagesKey, raw);
  }

  /// 生成 Mock 消息（用于开发调试）
  List<NotificationMessage> _mockMessages() {
    final now = DateTime.now();
    return [
      NotificationMessage(
        id: 'notif_001',
        type: 'interaction',
        title: '鹿野赞了你的分享',
        body: '「在宽窄之间找到内心的平静」',
        data: {'targetId': 'feed_xxx', 'targetType': 'feed'},
        createdAt: now.subtract(const Duration(minutes: 5)),
        read: false,
      ),
      NotificationMessage(
        id: 'notif_002',
        type: 'system',
        title: '清明茶叙已开始报名',
        body: '4月5日 14:00，与同伴进行一场无评判的正念对话练习',
        data: {'activityId': 'act_001'},
        createdAt: now.subtract(const Duration(hours: 2)),
        read: false,
      ),
      NotificationMessage(
        id: 'notif_003',
        type: 'browse',
        title: '有12人浏览了你的记录',
        body: null,
        data: {'targetId': 'card_xxx', 'targetType': 'card'},
        createdAt: now.subtract(const Duration(hours: 6)),
        read: true,
      ),
      NotificationMessage(
        id: 'notif_004',
        type: 'interaction',
        title: '周墨评论了你的分享',
        body: '「很共鸣，我也经常这样感受」',
        data: {'targetId': 'feed_yyy', 'targetType': 'feed'},
        createdAt: now.subtract(const Duration(days: 1)),
        read: true,
      ),
    ];
  }
}

/// 生产环境混合实现（API + 本地缓存）
/// TODO(Backend Integration)[message_api#hybrid]: 完成 API 调用实现
class HybridNotificationServiceImpl implements NotificationService {
  static const String _baseUrl = String.fromEnvironment(
    'BUSINESS_API_BASE_URL',
    defaultValue:
        'https://polyphonically-plagiocephalic-genesis.ngrok-free.dev/v1',
  );

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  bool get _enabled => _baseUrl.isNotEmpty;

  @override
  Future<void> registerDeviceToken(
    String token, {
    String platform = 'android',
  }) async {
    final prefs = await _preferences;
    await prefs.setString('notification_device_token', token);

    if (!_enabled) return;

    try {
      final uri = Uri.parse('$_baseUrl/notifications/token');
      await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'token': token, 'platform': platform}),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // 后端对接前忽略错误
    }
  }

  @override
  Future<List<NotificationMessage>> getMessages({
    int page = 0,
    int pageSize = 20,
  }) async {
    if (!_enabled) {
      return LocalNotificationServiceImpl().getMessages();
    }

    try {
      final uri = Uri.parse(
        '$_baseUrl/notifications?page=$page&pageSize=$pageSize',
      );
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        return [];
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final list = (data['data']['messages'] as List?) ?? [];
      return list
          .map((e) => NotificationMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<int> getUnreadCount() async {
    if (!_enabled) {
      return LocalNotificationServiceImpl().getUnreadCount();
    }

    try {
      final uri = Uri.parse('$_baseUrl/notifications/unread-count');
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        return 0;
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return data['data']['count'] as int? ?? 0;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<void> markAsRead(String id) async {
    if (!_enabled) return;

    try {
      final uri = Uri.parse('$_baseUrl/notifications/$id/read');
      await http.post(uri).timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  @override
  Future<void> markAllAsRead() async {
    if (!_enabled) return;

    try {
      final uri = Uri.parse('$_baseUrl/notifications/read-all');
      await http.post(uri).timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  @override
  Future<void> dismiss(String id) async {
    if (!_enabled) return;

    try {
      final uri = Uri.parse('$_baseUrl/notifications/$id/dismiss');
      await http.post(uri).timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  @override
  Future<void> clearAll() async {
    if (!_enabled) return;

    try {
      final uri = Uri.parse('$_baseUrl/notifications/clear');
      await http.delete(uri).timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  @override
  Future<void> unregisterDeviceToken() async {
    final prefs = await _preferences;
    final token = prefs.getString('notification_device_token');
    if (token == null || !_enabled) return;

    try {
      final uri = Uri.parse('$_baseUrl/notifications/token');
      await http
          .delete(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'token': token}),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {}

    await prefs.remove('notification_device_token');
  }
}

/// 全局通知服务实例（开发阶段使用 LocalNotificationServiceImpl）
/// TODO(Backend Integration)[message_api#switch]: 替换为 HybridNotificationServiceImpl
final notificationServiceProvider = LocalNotificationServiceImpl();
