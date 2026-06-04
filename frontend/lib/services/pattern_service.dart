import 'dart:math';

import '../models/pattern.dart';

/// 纹理生成服务：六次输入仅作为随机种子，不做前端符号直译。
abstract class PatternService {
  Future<Pattern> generatePattern({String? seed, List<int>? sourceLines});

  Pattern? restorePattern(String seed);

  bool validatePattern(Pattern pattern);
}

/// 基于硬币投掷的六爻生成
/// 3枚硬币，每爻掷一次，共6爻
/// 规则：
/// - 正面=3，反面=2
/// - 和=6: 老阴(0)，动爻
/// - 和=7: 少阳(1)
/// - 和=8: 少阴(0)
/// - 和=9: 老阳(1)，动爻
class MockPatternServiceImpl implements PatternService {
  final Random _random = Random();

  @override
  Future<Pattern> generatePattern({
    String? seed,
    List<int>? sourceLines,
  }) async {
    // 保留短暂留白，给"光影消散 -> 结果浮现"转场时间。
    await Future.delayed(const Duration(milliseconds: 1400));

    final lines = <int>[];
    final movingLines = <int>[];

    for (int i = 0; i < 6; i++) {
      // 掷3枚硬币
      int sum = 0;
      for (int j = 0; j < 3; j++) {
        sum += _random.nextBool() ? 3 : 2; // 正面=3，反面=2
      }

      // 根据点数计算爻值
      int line;
      switch (sum) {
        case 6: // 老阴，动爻
          line = 0;
          movingLines.add(i + 1); // 1-6 索引
          break;
        case 7: // 少阳
          line = 1;
          break;
        case 8: // 少阴
          line = 0;
          break;
        case 9: // 老阳，动爻
          line = 1;
          movingLines.add(i + 1);
          break;
        default:
          line = _random.nextBool() ? 1 : 0;
      }
      lines.add(line);
    }

    // 动爻升序排列
    movingLines.sort();

    final seedText = seed ?? '${DateTime.now().millisecondsSinceEpoch}-${lines.join()}';

    return Pattern(
      lines: lines,
      movingLines: movingLines,
      seed: seedText,
      createdAt: DateTime.now(),
    );
  }

  @override
  Pattern? restorePattern(String seed) {
    try {
      final hash = seed.hashCode;
      final lines = List<int>.generate(6, (i) => ((hash >> i) & 1));
      return Pattern(
        lines: lines,
        movingLines: const [],
        seed: seed,
        createdAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  bool validatePattern(Pattern pattern) {
    return pattern.lines.length == 6 &&
        pattern.lines.every((line) => line == 0 || line == 1) &&
        pattern.movingLines.every((ml) => ml >= 1 && ml <= 6);
  }
}

final patternServiceProvider = MockPatternServiceImpl();