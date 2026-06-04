/// 仪式记录数据模型
class RitualRecord {
  final String mood;
  final List<int> hexagram;
  final DateTime dateTime;

  RitualRecord({
    required this.mood,
    required this.hexagram,
    required this.dateTime,
  });

  Map<String, dynamic> toJson() => {
    'mood': mood,
    'hexagram': hexagram,
    'dateTime': dateTime.toIso8601String(),
  };

  factory RitualRecord.fromJson(Map<String, dynamic> json) {
    return RitualRecord(
      mood: json['mood'] as String? ?? '',
      hexagram: List<int>.from(json['hexagram'] as List? ?? const <int>[]),
      dateTime:
          DateTime.tryParse(json['dateTime'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  /// 获取节气/农历描述
  String get seasonInfo {
    final month = dateTime.month;
    final day = dateTime.day;

    // 简化节气映射
    if (month == 3) {
      if (day < 6) return '惊蛰前夕';
      if (day < 21) return '惊蛰后数日';
      return '春分前夕';
    } else if (month == 4) {
      if (day < 5) return '春分后数日';
      if (day < 20) return '清明时节';
      return '谷雨前夕';
    } else if (month == 5) {
      if (day < 6) return '谷雨后数日';
      if (day < 21) return '立夏初至';
      return '小满前夕';
    } else if (month == 6) {
      if (day < 6) return '小满后数日';
      if (day < 21) return '芒种时节';
      return '夏至前夕';
    } else if (month == 7) {
      return '夏至后数日';
    } else if (month == 8) {
      if (day < 8) return '立秋前夕';
      return '处暑时节';
    } else if (month == 9) {
      if (day < 8) return '白露前夕';
      return '秋分前夕';
    } else if (month == 10) {
      if (day < 8) return '寒露时节';
      return '霜降前夕';
    } else if (month == 11) {
      if (day < 7) return '立冬前夕';
      return '小雪时节';
    } else if (month == 12) {
      if (day < 7) return '大雪前夕';
      return '冬至前夕';
    } else if (month == 1) {
      if (day < 6) return '冬至后数日';
      return '小寒时节';
    } else if (month == 2) {
      if (day < 4) return '大寒时节';
      return '立春前夕';
    }
    return '寻常时日';
  }

  /// 将卦象数组转换为符号字符串
  String get hexagramSymbols {
    return hexagram.map((v) => v == 1 ? '━━━' : '━　━').join('\n');
  }
}
