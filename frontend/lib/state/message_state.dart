import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/content/message_copy.dart';
import 'profile_hub_state.dart';

enum MessageFilter { all, interaction, browse, system }

class MessageNotice {
  final String id;
  final MessageFilter kind;
  final String title;
  final String subtitle;
  final String timeText;
  final DateTime createdAt;

  const MessageNotice({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.timeText,
    required this.createdAt,
  });
}

class MessageState {
  final MessageFilter filter;
  final Set<String> readIds;
  final Set<String> dismissedIds;
  final bool metaLoading;
  final int refreshAttempt;
  final int actionAttempt;

  const MessageState({
    this.filter = MessageFilter.all,
    this.readIds = const {},
    this.dismissedIds = const {},
    this.metaLoading = true,
    this.refreshAttempt = 0,
    this.actionAttempt = 0,
  });

  MessageState copyWith({
    MessageFilter? filter,
    Set<String>? readIds,
    Set<String>? dismissedIds,
    bool? metaLoading,
    int? refreshAttempt,
    int? actionAttempt,
  }) {
    return MessageState(
      filter: filter ?? this.filter,
      readIds: readIds ?? this.readIds,
      dismissedIds: dismissedIds ?? this.dismissedIds,
      metaLoading: metaLoading ?? this.metaLoading,
      refreshAttempt: refreshAttempt ?? this.refreshAttempt,
      actionAttempt: actionAttempt ?? this.actionAttempt,
    );
  }
}

class MessageNotifier extends Notifier<MessageState> {
  static const String _readKey = 'message_read_ids_v2';
  static const String _dismissedKey = 'message_dismissed_ids_v2';
  SharedPreferences? _prefs;

  @override
  MessageState build() {
    _restoreMeta();
    return const MessageState();
  }

  Future<void> _restoreMeta() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    final readRaw = prefs.getString(_readKey);
    final dismissedRaw = prefs.getString(_dismissedKey);
    state = state.copyWith(
      readIds: _decodeStringSet(readRaw),
      dismissedIds: _decodeStringSet(dismissedRaw),
      metaLoading: false,
    );
  }

  Set<String> _decodeStringSet(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toSet();
      }
      return const {};
    } catch (_) {
      return const {};
    }
  }

  Future<void> _persistMeta() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    // TODO(Backend Integration)[message_api#ui-polish]: 当前仅处理消息列表展示层与交互反馈细节，后端接入后由服务端返回视觉状态字段。
    // TODO(Backend Integration)[message_api#sync-state]: 后端接入后，用服务端状态同步替换本地 read/dismiss 持久化。
    await prefs.setString(_readKey, jsonEncode(state.readIds.toList()));
    await prefs.setString(
      _dismissedKey,
      jsonEncode(state.dismissedIds.toList()),
    );
  }

  void setFilter(MessageFilter filter) {
    state = state.copyWith(filter: filter);
  }

  Future<void> markRead(String id) async {
    state = state.copyWith(readIds: {...state.readIds, id});
    await _persistMeta();
  }

  Future<void> markAllRead(Iterable<String> ids) async {
    state = state.copyWith(readIds: {...state.readIds, ...ids});
    await _persistMeta();
  }

  Future<void> dismiss(String id) async {
    state = state.copyWith(dismissedIds: {...state.dismissedIds, id});
    await _persistMeta();
  }

  Future<void> simulateRefresh() async {
    final attempt = state.refreshAttempt + 1;
    state = state.copyWith(refreshAttempt: attempt);
    await Future.delayed(const Duration(milliseconds: 420));
    if (attempt % 3 == 0) {
      throw Exception('refresh-failed');
    }
    await ref.read(profileHubStateProvider.notifier).refresh();
  }

  Future<bool> simulateAction() async {
    final attempt = state.actionAttempt + 1;
    state = state.copyWith(actionAttempt: attempt);
    await Future.delayed(const Duration(milliseconds: 180));
    return attempt % 7 != 0;
  }

  List<MessageNotice> buildNotices(ProfileHubState hub) {
    final now = DateTime.now();
    final notices = <MessageNotice>[
      MessageNotice(
        id: 'system-optimized-flow',
        kind: MessageFilter.system,
        title: MessageCopy.systemTitle,
        subtitle: MessageCopy.systemSubtitle,
        timeText: MessageCopy.timeToday,
        createdAt: now.subtract(const Duration(hours: 1)),
      ),
      MessageNotice(
        id: 'system-checkin',
        kind: MessageFilter.system,
        title: MessageCopy.checkinTitle,
        subtitle: MessageCopy.checkinSubtitle,
        timeText: MessageCopy.timeToday,
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
      MessageNotice(
        id: 'system-welcome',
        kind: MessageFilter.system,
        title: MessageCopy.welcomeTitle,
        subtitle: MessageCopy.welcomeSubtitle,
        timeText: MessageCopy.timeYesterday,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      MessageNotice(
        id: 'interaction-1',
        kind: MessageFilter.interaction,
        title: MessageCopy.resonanceTitle,
        subtitle: MessageCopy.resonanceSubtitle,
        timeText: '10${MessageCopy.timeMinutesAgoSuffix}',
        createdAt: now.subtract(const Duration(minutes: 10)),
      ),
      MessageNotice(
        id: 'interaction-2',
        kind: MessageFilter.interaction,
        title: MessageCopy.resonanceTitle,
        subtitle: MessageCopy.resonanceBatchSubtitle,
        timeText: '1${MessageCopy.timeHoursAgoSuffix}',
        createdAt: now.subtract(const Duration(hours: 1)),
      ),
      MessageNotice(
        id: 'browse-1',
        kind: MessageFilter.browse,
        title: MessageCopy.browseTitle,
        subtitle: MessageCopy.browseSubtitle,
        timeText: '2${MessageCopy.timeHoursAgoSuffix}',
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      MessageNotice(
        id: 'browse-2',
        kind: MessageFilter.browse,
        title: MessageCopy.browseTitle,
        subtitle: MessageCopy.browseDeepSubtitle,
        timeText: MessageCopy.timeYesterday,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
    ];

    notices.addAll(
      hub.interactions.take(60).map(
            (e) => MessageNotice(
              id: 'interaction-${e.id}',
              kind: MessageFilter.interaction,
              title: MessageCopy.interactionRecordTitle,
              subtitle: e.title,
              timeText: timeAgo(e.createdAt),
              createdAt: e.createdAt,
            ),
          ),
    );

    notices.addAll(
      hub.browseRecords.take(60).map(
            (e) => MessageNotice(
              id: 'browse-${e.id}',
              kind: MessageFilter.browse,
              title: MessageCopy.browseRecordTitle,
              subtitle: e.title,
              timeText: timeAgo(e.createdAt),
              createdAt: e.createdAt,
            ),
          ),
    );

    notices.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return notices;
  }

  String timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return MessageCopy.timeJustNow;
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}${MessageCopy.timeMinutesAgoSuffix}';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}${MessageCopy.timeHoursAgoSuffix}';
    }
    return '${diff.inDays}${MessageCopy.timeDaysAgoSuffix}';
  }
}

final messageStateProvider = NotifierProvider<MessageNotifier, MessageState>(
  MessageNotifier.new,
);
