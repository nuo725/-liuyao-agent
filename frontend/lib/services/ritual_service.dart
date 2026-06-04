import 'dart:math';

/// 仪式服务抽象接口
abstract class RitualService {
  /// 执行仪式，返回六爻阴阳状态（6个整数，6或8为阴，7或9为阳）
  Future<List<int>> performRitual();
}

/// 模拟仪式服务实现
class MockRitualServiceImpl implements RitualService {
  final Random _random = Random();

  @override
  Future<List<int>> performRitual() async {
    // 强制悬置等待期 3-5 秒，底层锁死，无法被上层绕过
    final delaySeconds = 3 + _random.nextInt(3); // 3, 4, 或 5 秒
    await Future.delayed(Duration(seconds: delaySeconds));

    // 模拟抛掷 3 枚铜币 6 次
    final result = <int>[];
    for (int i = 0; i < 6; i++) {
      // 每枚铜币：正面(1)或背面(0)，3枚相加得到 0-3
      // 传统：3 个正面(3)为阳，2 正 1 反为阴动，其他为静
      // 简化为：0,1,2 → 阴(6/8)，3 → 阳(7/9)
      // 这里直接返回投掷结果之和：0-3
      final coinSum = _random.nextInt(4); // 0, 1, 2, 或 3
      result.add(coinSum);
    }

    return result;
  }
}

/// 全局服务实例
final ritualServiceProvider = MockRitualServiceImpl();
