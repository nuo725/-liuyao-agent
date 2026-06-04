import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum ActivityJoinStatus {
  none('未报名', 'none'),
  pending('待确认', 'pending'),
  approved('已通过', 'approved'),
  waitlist('候补中', 'waitlist');

  final String label;
  final String value;
  const ActivityJoinStatus(this.label, this.value);

  static ActivityJoinStatus fromValue(String? value) {
    for (final item in values) {
      if (item.value == value) return item;
    }
    return ActivityJoinStatus.none;
  }
}

class Activity {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String dateText;
  final String status;
  final int participantCount;
  final int? joinLimit;
  final List<String> tags;
  final String? content;
  final Map<String, dynamic>? organizer;
  final bool joined;
  final ActivityJoinStatus joinStatus;

  const Activity({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.dateText,
    required this.status,
    required this.participantCount,
    this.joinLimit,
    this.tags = const [],
    this.content,
    this.organizer,
    this.joined = false,
    this.joinStatus = ActivityJoinStatus.none,
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    final joinStatus = ActivityJoinStatus.fromValue(
      json['joinStatus']?.toString() ?? json['join_status']?.toString(),
    );
    final joined =
        json['joined'] as bool? ?? joinStatus != ActivityJoinStatus.none;
    return Activity(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      imageUrl: (json['imageUrl'] ?? json['image_url'] ?? '').toString(),
      dateText: (json['dateText'] ?? json['date_text'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      participantCount:
          (json['participantCount'] ?? json['participant_count'] ?? 0) as int,
      joinLimit: json['joinLimit'] as int?,
      tags: (json['tags'] as List?)?.cast<String>() ?? const [],
      content: json['content']?.toString(),
      organizer: json['organizer'] as Map<String, dynamic>?,
      joined: joined,
      joinStatus: joinStatus,
    );
  }

  Activity copyWith({
    String? id,
    String? title,
    String? description,
    String? imageUrl,
    String? dateText,
    String? status,
    int? participantCount,
    int? joinLimit,
    List<String>? tags,
    String? content,
    Map<String, dynamic>? organizer,
    bool? joined,
    ActivityJoinStatus? joinStatus,
  }) {
    return Activity(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      dateText: dateText ?? this.dateText,
      status: status ?? this.status,
      participantCount: participantCount ?? this.participantCount,
      joinLimit: joinLimit ?? this.joinLimit,
      tags: tags ?? this.tags,
      content: content ?? this.content,
      organizer: organizer ?? this.organizer,
      joined: joined ?? this.joined,
      joinStatus: joinStatus ?? this.joinStatus,
    );
  }
}

abstract class ActivityService {
  Future<List<Activity>> getActivities({String? userId});

  Future<Activity> getActivityDetail(String activityId, {String? userId});

  Future<Activity> joinActivity(String activityId, String userId);
}

class ActivityApiClient {
  static const String _baseUrl = String.fromEnvironment(
    'BUSINESS_API_BASE_URL',
    defaultValue:
        'https://polyphonically-plagiocephalic-genesis.ngrok-free.dev/v1',
  );
  static const bool _allowDevFallback = bool.fromEnvironment(
    'ACTIVITY_ALLOW_DEV_FALLBACK',
    defaultValue: false,
  );

  final http.Client _client;

  ActivityApiClient({http.Client? client}) : _client = client ?? http.Client();

  bool get enabled => _baseUrl.trim().isNotEmpty;

  Future<List<Activity>> getActivities({String? userId}) async {
    _ensureEnabled();
    final uri = Uri.parse('$_baseUrl/activities');
    final resp = await _client.get(uri).timeout(const Duration(seconds: 12));
    _checkStatus(resp);
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final list = data['data']['activities'] as List? ?? [];
    return list
        .whereType<Map>()
        .map((e) => Activity.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Activity> getActivityDetail(
    String activityId, {
    String? userId,
  }) async {
    _ensureEnabled();
    final uri = Uri.parse('$_baseUrl/activities/$activityId');
    final resp = await _client.get(uri).timeout(const Duration(seconds: 12));
    _checkStatus(resp);
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return Activity.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<Activity> joinActivity(String activityId, String userId) async {
    _ensureEnabled();
    final uri = Uri.parse('$_baseUrl/activities/$activityId/join');
    final resp = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'userId': userId}),
        )
        .timeout(const Duration(seconds: 10));
    _checkStatus(resp);
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return Activity.fromJson(data['data'] as Map<String, dynamic>);
  }

  void _ensureEnabled() {
    if (!enabled && !_allowDevFallback) {
      throw const ActivityException('未配置 Activity 后端地址（BUSINESS_API_BASE_URL）');
    }
  }

  void _checkStatus(http.Response resp) {
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ActivityException('Activity 服务异常(${resp.statusCode})');
    }
  }
}

class ActivityException implements Exception {
  final String message;
  const ActivityException(this.message);
  @override
  String toString() => message;
}

class LocalActivityService implements ActivityService {
  static const String _joinStateKey = 'activity_join_state_v2';
  SharedPreferences? _prefs;
  bool _joinStateLoaded = false;
  final Map<String, String> _joinStateByUserAndActivity = <String, String>{};

  static const List<Activity> _mockActivities = <Activity>[
    Activity(
      id: 'act_cold_joke_001',
      title: '冷笑话大赛',
      description: '参与后在“宽窄之间”发布冷笑话并带 #冷笑话大赛，角逐点赞王与点踩王。',
      imageUrl:
          'https://images.unsplash.com/photo-1520229406068-f5fd8adb08c5?w=1200',
      dateText: '4月17日 - 4月24日',
      status: '火热进行中',
      participantCount: 86,
      tags: ['冷笑话', '活动挑战', '#冷笑话大赛'],
      content:
          '参与方式：\n1) 点击“参加活动”。\n2) 到宽窄之间发布冷笑话，正文带 #冷笑话大赛。\n3) 活动页会按帖子点赞数和模拟点踩数生成榜单。\n\n评选说明：\n- 点赞王：活动帖点赞总数最高。\n- 点踩王：活动帖模拟点踩数最高（用于趣味展示）。',
    ),
    Activity(
      id: 'act_002',
      title: '宽窄夜话 Vol.3：情绪的河流',
      description: '把那些难以命名的情绪说出来，和同频的人一起整理。',
      imageUrl:
          'https://images.unsplash.com/photo-1516245834210-c4d1426b33a9?w=600',
      dateText: '4月20日 20:00',
      status: '报名中',
      participantCount: 156,
      joinLimit: 200,
      tags: ['情绪', '深谈'],
    ),
    Activity(
      id: 'act_003',
      title: '七日静心挑战',
      description: '连续七天，每天十分钟，建立可持续的内在节律。',
      imageUrl:
          'https://images.unsplash.com/photo-1506126613408-eca07ce68773?w=600',
      dateText: '长期有效',
      status: '进行中',
      participantCount: 1024,
      tags: ['静心', '习惯'],
    ),
    Activity(
      id: 'act_004',
      title: '周末茶叙：关系里的边界练习',
      description: '在轻松讨论中练习表达边界、听见彼此。',
      imageUrl:
          'https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=600',
      dateText: '每周六 15:00',
      status: '进行中',
      participantCount: 45,
      tags: ['关系', '表达'],
    ),
  ];

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  String _key(String userId, String activityId) => '$userId::$activityId';

  Future<void> _ensureJoinStateLoaded() async {
    if (_joinStateLoaded) return;
    final prefs = await _preferences;
    final raw = prefs.getString(_joinStateKey);
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final parsed = jsonDecode(raw);
        if (parsed is Map) {
          _joinStateByUserAndActivity
            ..clear()
            ..addAll(
              parsed.map(
                (key, value) => MapEntry(key.toString(), value.toString()),
              ),
            );
        }
      } catch (_) {
        _joinStateByUserAndActivity.clear();
      }
    }
    _joinStateLoaded = true;
  }

  Future<void> _persistJoinState() async {
    final prefs = await _preferences;
    await prefs.setString(
      _joinStateKey,
      jsonEncode(_joinStateByUserAndActivity),
    );
  }

  ActivityJoinStatus _statusFor({
    required String? userId,
    required Activity activity,
  }) {
    if (userId == null || userId.trim().isEmpty) return ActivityJoinStatus.none;
    return ActivityJoinStatus.fromValue(
      _joinStateByUserAndActivity[_key(userId, activity.id)],
    );
  }

  Activity _applyUserStatus(Activity activity, {required String? userId}) {
    final status = _statusFor(userId: userId, activity: activity);
    final joined = status != ActivityJoinStatus.none;
    final countDelta = status == ActivityJoinStatus.approved ? 1 : 0;
    return activity.copyWith(
      joined: joined,
      joinStatus: status,
      participantCount: activity.participantCount + countDelta,
    );
  }

  @override
  Future<List<Activity>> getActivities({String? userId}) async {
    // TODO(Backend Integration)[activity_api#list]:
    // 接后端后替换为活动列表接口，joinStatus 由后端直接返回。
    await _ensureJoinStateLoaded();
    await Future.delayed(const Duration(milliseconds: 300));
    return _mockActivities
        .map((item) => _applyUserStatus(item, userId: userId))
        .toList();
  }

  @override
  Future<Activity> getActivityDetail(
    String activityId, {
    String? userId,
  }) async {
    // TODO(Backend Integration)[activity_api#detail]:
    // 替换为活动详情接口，并携带当前用户上下文返回报名状态。
    await _ensureJoinStateLoaded();
    await Future.delayed(const Duration(milliseconds: 200));
    final activity = _mockActivities.firstWhere(
      (a) => a.id == activityId,
      orElse: () => throw const ActivityException('活动不存在'),
    );
    return _applyUserStatus(activity, userId: userId);
  }

  @override
  Future<Activity> joinActivity(String activityId, String userId) async {
    // TODO(Backend Integration)[activity_api#join]:
    // 接后端后改为真实报名接口，服务端返回报名状态与排队位次。
    // TODO(Backend Integration)[activity_api#join-status]:
    // 当前为本地规则模拟：待确认/已通过/候补中。
    await _ensureJoinStateLoaded();
    await Future.delayed(const Duration(milliseconds: 400));
    final activity = _mockActivities.firstWhere(
      (a) => a.id == activityId,
      orElse: () => throw const ActivityException('活动不存在'),
    );

    final current = _statusFor(userId: userId, activity: activity);
    if (current != ActivityJoinStatus.none) {
      return _applyUserStatus(activity, userId: userId);
    }

    ActivityJoinStatus next;
    if (activity.joinLimit != null &&
        activity.participantCount >= activity.joinLimit!) {
      next = ActivityJoinStatus.waitlist;
    } else if (activity.participantCount % 3 == 0) {
      next = ActivityJoinStatus.pending;
    } else {
      next = ActivityJoinStatus.approved;
    }

    _joinStateByUserAndActivity[_key(userId, activityId)] = next.value;
    await _persistJoinState();
    return _applyUserStatus(activity, userId: userId);
  }
}

/// 全局服务实例
/// TODO(Backend Integration)[activity_api#switch]: 替换为 HybridActivityServiceImpl
final activityServiceProvider = LocalActivityService();

class HybridActivityServiceImpl implements ActivityService {
  final ActivityApiClient _api;
  final LocalActivityService _local;

  HybridActivityServiceImpl({
    ActivityApiClient? api,
    LocalActivityService? local,
  }) : _api = api ?? ActivityApiClient(),
       _local = local ?? LocalActivityService();

  bool get _apiEnabled => _api.enabled;

  @override
  Future<List<Activity>> getActivities({String? userId}) async {
    if (_apiEnabled) {
      try {
        return await _api.getActivities(userId: userId);
      } catch (_) {}
    }
    return _local.getActivities(userId: userId);
  }

  @override
  Future<Activity> getActivityDetail(
    String activityId, {
    String? userId,
  }) async {
    if (_apiEnabled) {
      try {
        return await _api.getActivityDetail(activityId, userId: userId);
      } catch (_) {}
    }
    return _local.getActivityDetail(activityId, userId: userId);
  }

  @override
  Future<Activity> joinActivity(String activityId, String userId) async {
    if (_apiEnabled) {
      try {
        return await _api.joinActivity(activityId, userId);
      } catch (_) {}
    }
    return _local.joinActivity(activityId, userId);
  }
}
