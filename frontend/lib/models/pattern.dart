/// 纹理数据模型 - 替代传统"卦象"概念
/// 包含六层纹线的结构化数据
class Pattern {
  /// 纹线数据（6个元素，每元素0或1）
  /// 0 = 阴（虚线）
  /// 1 = 阳（实线）
  /// 顺序：自下而上（初爻到上爻）
  final List<int> lines;

  /// 动爻位置（1-6，对应初爻到上爻）
  /// 允许空数组，表示静卦
  /// 示例：[1, 3] 表示初爻和第三爻为动爻
  final List<int> movingLines;

  /// 纹理的唯一标识符（用于追溯）
  final String? seed;

  /// 生成时间
  final DateTime createdAt;

  const Pattern({
    required this.lines,
    this.movingLines = const [],
    this.seed,
    required this.createdAt,
  });

  /// 从掷硬币结果创建
  /// [coinResults] 6个整数值，每个0-3
  factory Pattern.fromCoins(List<int> coinResults) {
    // 简化逻辑：0,1,2 -> 虚线(0)，3 -> 实线(1)
    final lines = coinResults.map((v) => v >= 2 ? 1 : 0).toList();
    return Pattern(
      lines: lines,
      seed: DateTime.now().millisecondsSinceEpoch.toString(),
      createdAt: DateTime.now(),
    );
  }

  /// 获取第n层纹线（0-5，从下往上）
  int getLine(int index) {
    if (index < 0 || index >= 6) return 0;
    return lines[index];
  }

  /// 判断是否为实线
  bool isYang(int lineIndex) => getLine(lineIndex) == 1;

  /// 判断是否为虚线
  bool isYin(int lineIndex) => getLine(lineIndex) == 0;

  /// 获取纹理描述（用于调试/追溯）
  String get description {
    return lines.map((l) => l == 1 ? '━' : '┄').join('\n');
  }

  /// 转换为显示符号（清新抽象风格）
  String get displaySymbol {
    return lines.map((l) => l == 1 ? '●' : '○').join('');
  }

  /// 转换为可分享的字符串
  String toShareString() {
    return lines.join('');
  }

  /// 从分享字符串解析
  factory Pattern.fromShareString(String str) {
    final lines = str.split('').map((s) => int.tryParse(s) ?? 0).toList();
    return Pattern(
      lines: lines.take(6).toList(),
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'lines': lines,
    'movingLines': movingLines,
    'seed': seed,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Pattern.fromJson(Map<String, dynamic> json) => Pattern(
    lines: List<int>.from(json['lines'] as List),
    movingLines: (json['movingLines'] as List?)?.cast<int>() ?? [],
    seed: json['seed'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}