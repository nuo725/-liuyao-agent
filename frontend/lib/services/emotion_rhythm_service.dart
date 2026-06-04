import 'dart:math';

import '../models/emotion_rhythm.dart';
import 'first_launch_flow_service.dart';

/// 情绪节律服务接口（预留后端接入，当前为本地 mock 状态）
abstract class EmotionRhythmService {
  Future<DailyGreeting> fetchDailyGreeting();
  Future<bool> submitCalibration(String feedback, {String? customText});
  Future<PeriodicReport> fetchPeriodicReview(String period);
}

/// Mock implementation for development.
class MockEmotionRhythmServiceImpl implements EmotionRhythmService {
  static final _random = Random();

  /// Last ritual question keyword - set by callers for dynamic context.
  String? lastRitualQuestion;

  static const _greetings = [
    ('早安', 'morning'),
    ('午后安', 'morning'),
    ('晚安', 'evening'),
  ];

  static const _fallbackContexts = [
    '昨天你提到了关于【工作选择】的困惑，过了一夜，现在感觉好些了吗？',
    '前阵子你提到的【人际关系】话题，似乎还在心里延续着。',
    '上周的某次体验中，你提到了想要【改变现状】的念头。',
    '最近几次探索里，“焦虑”这个词出现得比较多，想聊聊吗？',
  ];

  static const _tagSets = [
    ['工作选择', '迷茫'],
    ['人际关系', '困惑'],
    ['自我探索', '期待'],
    ['焦虑', '平静'],
    ['决定', '行动'],
  ];

  static const _calibrationChoices = [
    '好多了',
    '还是有些焦虑',
    '有了新想法',
  ];

  @override
  Future<DailyGreeting> fetchDailyGreeting() async {
    await Future.delayed(const Duration(milliseconds: 600));

    final now = DateTime.now();
    final hour = now.hour;
    final timeOfDay = hour < 12 ? 'morning' : 'evening';
    final greet = hour < 12 ? _greetings[0].$1 : _greetings[2].$1;
    final isFirstRitualDone =
        await firstLaunchFlowServiceProvider.isFirstRitualDone();

    String contextText;
    List<String> tags;

    if (!isFirstRitualDone) {
      contextText = '这是你第一次进入仪式。先输入一个问题，我们会先把感受放稳，再慢慢展开。';
      tags = const [];
    } else {
      final q = lastRitualQuestion?.trim();
      if (q != null && q.isNotEmpty) {
        final keyword = q.length > 10 ? q.substring(0, 10) : q;
        contextText = '上次你提到了关于【$keyword】的困惑，过了一阵子，现在感觉怎么样？';
        tags = [keyword, '回看'];
      } else {
        final idx = _random.nextInt(_fallbackContexts.length);
        contextText = _fallbackContexts[idx];
        tags = _tagSets[idx];
      }
    }

    return DailyGreeting(
      greeting: '$greet，Roy。',
      timeOfDay: timeOfDay,
      contextText: contextText,
      emotionTags: tags,
      relatedQuestion:
          isFirstRitualDone && tags.isNotEmpty && _random.nextBool()
              ? '关于【${tags.first}】的后续思考'
              : null,
    );
  }

  @override
  Future<bool> submitCalibration(String feedback, {String? customText}) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return true;
  }

  @override
  Future<PeriodicReport> fetchPeriodicReview(String period) async {
    await Future.delayed(const Duration(milliseconds: 700));

    final now = DateTime.now();
    final days = period == 'weekly' ? 7 : 30;
    final start = now.subtract(Duration(days: days));

    final cloud = <String, int>{
      '迷茫': 45 + _random.nextInt(30),
      '期待': 30 + _random.nextInt(40),
      '平静': 50 + _random.nextInt(20),
      '焦虑': 20 + _random.nextInt(35),
      '释然': 35 + _random.nextInt(25),
      '好奇': 40 + _random.nextInt(30),
    };

    return PeriodicReport(
      period: period,
      startDate: start,
      endDate: now,
      resonanceCount: 3 + _random.nextInt(days),
      topEmotions: const ['迷茫', '期待', '平静'],
      emotionCloud: cloud,
      activeWeekdays: List.generate(days, (_) => _random.nextInt(7)).toSet().toList()
        ..sort(),
    );
  }

  List<String> get calibrationOptions => _calibrationChoices;
}

/// Singleton instance.
final emotionRhythmService = MockEmotionRhythmServiceImpl();
