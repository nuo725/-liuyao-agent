import '../models/interpretation_card.dart';

/// 安全策略服务 - 风险识别与内容过滤
abstract class SafetyService {
  /// 检测问题风险等级
  RiskLevel detectRiskLevel(String question);

  /// 检测内容是否命中禁用模式
  SafetyResult checkContent(String content);

  /// 对内容进行脱敏处理
  String desensitize(String content);

  /// 判断是否为高风险主题
  bool isHighRiskTopic(String question);
}

/// 安全检测结果
class SafetyResult {
  final bool isSafe;
  final RiskLevel riskLevel;
  final List<SafetyViolation> violations;
  final String? rewrittenContent;

  const SafetyResult({
    required this.isSafe,
    required this.riskLevel,
    this.violations = const [],
    this.rewrittenContent,
  });

  factory SafetyResult.safe() => const SafetyResult(
    isSafe: true,
    riskLevel: RiskLevel.low,
  );

  factory SafetyResult.degraded(String content) => SafetyResult(
    isSafe: true,
    riskLevel: RiskLevel.medium,
    rewrittenContent: content,
  );

  factory SafetyResult.blocked(List<SafetyViolation> violations) =>
    SafetyResult(
      isSafe: false,
      riskLevel: RiskLevel.high,
      violations: violations,
    );
}

/// 安全违规项
class SafetyViolation {
  final String type;      // 违规类型
  final String keyword;   // 触发关键词
  final String message;   // 违规描述

  const SafetyViolation({
    required this.type,
    required this.keyword,
    required this.message,
  });
}

/// Mock实现
class MockSafetyServiceImpl implements SafetyService {
  // 高风险关键词
  static const _highRiskKeywords = [
    '健康', '疾病', '生病', '死亡', '自杀',
    '法律', '犯罪', '坐牢', '判刑',
    '投资', '股票', '彩票', '赌博', '钱', '财运',
    '分手', '离婚', '复合',
  ];

  // 禁用模式关键词
  static const _forbiddenPatterns = [
    '未来会发生', '明年', '后天', '下个月',
    '一定', '肯定', '绝对',
    '不好', '凶', '大凶', '灾难', '祸',
    '必须这样做', '你一定要', '听我的',
  ];

  @override
  RiskLevel detectRiskLevel(String question) {
    final lowerQuestion = question.toLowerCase();

    // 高风险检测
    for (final keyword in _highRiskKeywords) {
      if (lowerQuestion.contains(keyword)) {
        return RiskLevel.high;
      }
    }

    // 中风险检测（验证倾向）
    if (lowerQuestion.contains('准不准') ||
        lowerQuestion.contains('灵不灵') ||
        lowerQuestion.contains('是真的吗')) {
      return RiskLevel.medium;
    }

    return RiskLevel.low;
  }

  @override
  SafetyResult checkContent(String content) {
    final violations = <SafetyViolation>[];

    for (final pattern in _forbiddenPatterns) {
      if (content.contains(pattern)) {
        violations.add(SafetyViolation(
          type: 'forbidden',
          keyword: pattern,
          message: '内容包含禁用表达',
        ));
      }
    }

    if (violations.isNotEmpty) {
      return SafetyResult.blocked(violations);
    }

    return SafetyResult.safe();
  }

  @override
  String desensitize(String content) {
    // 简单的脱敏处理
    return content
        .replaceAll(RegExp(r'\d{11,}'), '***') // 手机号
        .replaceAll(RegExp(r'\d{3,4}-\d{7,8}'), '***-****') // 电话
        .replaceAll(RegExp(r'[\u4e00-\u9fa5]{2,4}'), '**'); // 姓名
  }

  @override
  bool isHighRiskTopic(String question) {
    return detectRiskLevel(question) == RiskLevel.high;
  }
}

/// 全局服务实例
final safetyServiceProvider = MockSafetyServiceImpl();
