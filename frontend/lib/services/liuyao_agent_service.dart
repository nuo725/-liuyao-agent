import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

void _dlog(String message) {
  if (kDebugMode) debugPrint(message);
}

/// Liuyao APP API 配置
class LiuyaoAgentConfig {
  /// Base URL 路径：/api/v1
  /// 本地开发示例：
  /// - Web: http://localhost:3000/api/v1
  /// - Android Emulator: http://10.0.2.2:3000/api/v1
  static String get baseUrl {
    return _runtimeUrl.isNotEmpty
        ? _runtimeUrl
        : const String.fromEnvironment(
            'LIUYAO_API_BASE_URL',
            defaultValue: 'http://10.0.2.2:3000/api/v1',
          );
  }

  static String _runtimeUrl = '';

  /// 运行时配置 URL
  static void setRuntimeUrl(String url) {
    _runtimeUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  static void clearRuntimeUrl() {
    _runtimeUrl = '';
  }

  /// 默认模型
  static const String defaultModel = 'Qwen/Qwen3-32B';

  /// 默认温度
  static const double defaultTemperature = 0.8;

  /// 超时时间（秒）- 后端 LLM 生成可能需要较长时间
  static const int timeoutSeconds = 120;
}

/// API 统一响应结构
class ApiResponse<T> {
  final bool success;
  final T? data;
  final ApiError? error;

  const ApiResponse({required this.success, this.data, this.error});

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    return ApiResponse(
      success: json['success'] as bool? ?? false,
      data: json['data'] != null ? fromJson(json['data'] as Map<String, dynamic>) : null,
      error: json['error'] != null ? ApiError.fromJson(json['error'] as Map<String, dynamic>) : null,
    );
  }
}

class ApiError {
  final String code;
  final String message;

  const ApiError({required this.code, required this.message});

  factory ApiError.fromJson(Map<String, dynamic> json) {
    return ApiError(
      code: json['code']?.toString() ?? 'UNKNOWN',
      message: json['message']?.toString() ?? '未知错误',
    );
  }
}

/// 会话信息
class SessionInfo {
  final String sessionId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? historyLength;

  const SessionInfo({
    required this.sessionId,
    this.createdAt,
    this.updatedAt,
    this.historyLength,
  });

  factory SessionInfo.fromJson(Map<String, dynamic> json) {
    return SessionInfo(
      sessionId: json['sessionId']?.toString() ?? '',
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
      historyLength: json['historyLength'] as int?,
    );
  }
}

/// 卦象摘要
class HexagramSummary {
  final HexagramInfo? originalHexagram;
  final HexagramInfo? changedHexagram;
  final List<int> movingLines;

  const HexagramSummary({
    this.originalHexagram,
    this.changedHexagram,
    this.movingLines = const [],
  });

  factory HexagramSummary.fromJson(Map<String, dynamic> json) {
    return HexagramSummary(
      originalHexagram: json['originalHexagram'] != null
          ? HexagramInfo.fromJson(json['originalHexagram'] as Map<String, dynamic>)
          : null,
      changedHexagram: json['changedHexagram'] != null
          ? HexagramInfo.fromJson(json['changedHexagram'] as Map<String, dynamic>)
          : null,
      movingLines: (json['movingLines'] as List?)?.cast<int>() ?? [],
    );
  }
}

class HexagramInfo {
  final String id;
  final String name;
  final String symbol;

  const HexagramInfo({
    required this.id,
    required this.name,
    required this.symbol,
  });

  factory HexagramInfo.fromJson(Map<String, dynamic> json) {
    return HexagramInfo(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      symbol: json['symbol']?.toString() ?? '',
    );
  }
}

/// 回复内容
class ReplyContent {
  final String text;
  final String? model;
  final TokenUsage? usage;

  const ReplyContent({
    required this.text,
    this.model,
    this.usage,
  });

  factory ReplyContent.fromJson(Map<String, dynamic> json) {
    return ReplyContent(
      text: json['text']?.toString() ?? '',
      model: json['model']?.toString(),
      usage: json['usage'] != null ? TokenUsage.fromJson(json['usage'] as Map<String, dynamic>) : null,
    );
  }
}

class TokenUsage {
  final int inputTokens;
  final int outputTokens;
  final int totalTokens;

  const TokenUsage({
    required this.inputTokens,
    required this.outputTokens,
    required this.totalTokens,
  });

  factory TokenUsage.fromJson(Map<String, dynamic> json) {
    return TokenUsage(
      inputTokens: json['inputTokens'] as int? ?? 0,
      outputTokens: json['outputTokens'] as int? ?? 0,
      totalTokens: json['totalTokens'] as int? ?? 0,
    );
  }
}

/// 评估信息
class EvaluationInfo {
  final String? confidence;
  final String? suggestedQuestionType;
  final List<String> reasons;
  final List<String> warnings;

  const EvaluationInfo({
    this.confidence,
    this.suggestedQuestionType,
    this.reasons = const [],
    this.warnings = const [],
  });

  factory EvaluationInfo.fromJson(Map<String, dynamic> json) {
    return EvaluationInfo(
      confidence: json['confidence']?.toString(),
      suggestedQuestionType: json['suggestedQuestionType']?.toString(),
      reasons: (json['reasons'] as List?)?.cast<String>() ?? [],
      warnings: (json['warnings'] as List?)?.cast<String>() ?? [],
    );
  }
}

/// 开始聊天响应
class StartChatResponse {
  final String mode;
  final bool needsClarification;
  final SessionInfo? session;
  final HexagramSummary? summary;
  final ReplyContent reply;
  final EvaluationInfo? evaluation;

  const StartChatResponse({
    required this.mode,
    required this.needsClarification,
    this.session,
    this.summary,
    required this.reply,
    this.evaluation,
  });

  factory StartChatResponse.fromJson(Map<String, dynamic> json) {
    return StartChatResponse(
      mode: json['mode']?.toString() ?? 'normal_reading',
      needsClarification: json['needsClarification'] as bool? ?? false,
      session: json['session'] != null
          ? SessionInfo.fromJson(json['session'] as Map<String, dynamic>)
          : null,
      summary: json['summary'] != null
          ? HexagramSummary.fromJson(json['summary'] as Map<String, dynamic>)
          : null,
      reply: ReplyContent.fromJson(json['reply'] as Map<String, dynamic>? ?? {}),
      evaluation: json['evaluation'] != null
          ? EvaluationInfo.fromJson(json['evaluation'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// 继续聊天响应
class ContinueChatResponse {
  final SessionInfo session;
  final ReplyContent reply;

  const ContinueChatResponse({
    required this.session,
    required this.reply,
  });

  factory ContinueChatResponse.fromJson(Map<String, dynamic> json) {
    return ContinueChatResponse(
      session: SessionInfo.fromJson(json['session'] as Map<String, dynamic>),
      reply: ReplyContent.fromJson(json['reply'] as Map<String, dynamic>),
    );
  }
}

/// Liuyao Agent API 服务
class LiuyaoAgentApiService {
  final String? userId;

  LiuyaoAgentApiService({this.userId});

  String get _baseUrl => LiuyaoAgentConfig.baseUrl;

  /// 健康检查
  Future<bool> health() async {
    try {
      final uri = Uri.parse('$_baseUrl/liuyao/app/health');
      final response = await http.get(uri).timeout(
            const Duration(seconds: 5),
          );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return json['success'] == true;
      }
      return false;
    } catch (e) {
      _dlog('[LiuyaoAgent] health check failed: $e');
      return false;
    }
  }

  /// 开始会话（首轮开聊）
  Future<StartChatResponse> startChat({
    required String question,
    required List<int> lines,
    List<int> movingLines = const [],
    String? model,
    double? temperature,
  }) async {
    final uri = Uri.parse('$_baseUrl/liuyao/app/chat/start');

    final body = {
      'question': question,
      'lines': lines,
      'movingLines': movingLines,
      'datetime': DateTime.now().toUtc().toIso8601String(),
      'model': model ?? LiuyaoAgentConfig.defaultModel,
      'temperature': temperature ?? LiuyaoAgentConfig.defaultTemperature,
      'includeDebug': false,
    };

    _dlog('[LiuyaoAgent] POST $_baseUrl/liuyao/app/chat/start');
    _dlog('[LiuyaoAgent] body: $body');

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: LiuyaoAgentConfig.timeoutSeconds));

      _dlog('[LiuyaoAgent] start response status: ${response.statusCode}');
      final bodyStr = response.body;
      _dlog(
        '[LiuyaoAgent] start response body: ${bodyStr.length > 200 ? '${bodyStr.substring(0, 200)}...' : bodyStr}',
      );

      if (response.statusCode != 200) {
        // 尝试解析后端返回的错误信息
        String errorMsg = '请求失败: ${response.statusCode}';
        try {
          final errorJson = jsonDecode(response.body) as Map<String, dynamic>;
          if (errorJson['error'] != null) {
            errorMsg = errorJson['error']['message']?.toString() ??
                      errorJson['error'].toString();
          }
        } catch (_) {}
        throw LiuyaoAgentException(
          'start_chat_failed',
          errorMsg,
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (json['success'] != true) {
        final error = json['error'] != null
            ? ApiError.fromJson(json['error'] as Map<String, dynamic>)
            : const ApiError(code: 'UNKNOWN', message: '未知错误');
        throw LiuyaoAgentException(error.code, error.message);
      }

      // 解析响应数据，捕获可能的解析错误
      try {
        final data = json['data'];
        if (data == null) {
          throw const LiuyaoAgentException('NULL_DATA', '响应数据为空');
        }
        return StartChatResponse.fromJson(data as Map<String, dynamic>);
      } catch (e) {
        _dlog('[LiuyaoAgent] Response parsing error: $e');
        _dlog('[LiuyaoAgent] Response data: ${json['data']}');
        throw LiuyaoAgentException('PARSE_ERROR', '响应解析失败: $e');
      }
    } on TimeoutException {
      throw const LiuyaoAgentException('TIMEOUT', '请求超时，请检查网络后重试');
    } catch (e, st) {
      if (e is LiuyaoAgentException) rethrow;
      _dlog('[LiuyaoAgent] start error: $e');
      _dlog('[LiuyaoAgent] start stack trace: $st');
      throw LiuyaoAgentException('NETWORK_ERROR', '网络错误: $e');
    }
  }

  /// 继续会话（追问）
  Future<ContinueChatResponse> continueChat({
    required String sessionId,
    required String message,
    String? model,
    double? temperature,
  }) async {
    final uri = Uri.parse('$_baseUrl/liuyao/app/chat/continue');

    final body = {
      'sessionId': sessionId,
      'message': message,
      'model': model ?? LiuyaoAgentConfig.defaultModel,
      'temperature': temperature ?? LiuyaoAgentConfig.defaultTemperature,
    };

    _dlog('[LiuyaoAgent] POST $_baseUrl/liuyao/app/chat/continue');
    _dlog('[LiuyaoAgent] body: $body');

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: LiuyaoAgentConfig.timeoutSeconds));

      _dlog('[LiuyaoAgent] continue response status: ${response.statusCode}');

      if (response.statusCode != 200) {
        throw LiuyaoAgentException(
          'continue_chat_failed',
          '请求失败: ${response.statusCode}',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (json['success'] != true) {
        final error = json['error'] != null
            ? ApiError.fromJson(json['error'] as Map<String, dynamic>)
            : const ApiError(code: 'UNKNOWN', message: '未知错误');
        throw LiuyaoAgentException(error.code, error.message);
      }

      return ContinueChatResponse.fromJson(json['data'] as Map<String, dynamic>);
    } on TimeoutException {
      throw const LiuyaoAgentException('TIMEOUT', '请求超时，请检查网络后重试');
    } catch (e) {
      if (e is LiuyaoAgentException) rethrow;
      _dlog('[LiuyaoAgent] continue error: $e');
      throw LiuyaoAgentException('NETWORK_ERROR', '网络错误: $e');
    }
  }

  /// 获取会话历史
  Future<SessionInfo> getSession(String sessionId) async {
    final uri = Uri.parse('$_baseUrl/liuyao/app/chat/session/$sessionId');

    _dlog('[LiuyaoAgent] GET $uri');

    try {
      final response = await http.get(uri).timeout(
            const Duration(seconds: LiuyaoAgentConfig.timeoutSeconds),
          );

      if (response.statusCode != 200) {
        throw LiuyaoAgentException(
          'get_session_failed',
          '获取会话失败: ${response.statusCode}',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (json['success'] != true) {
        final error = json['error'] != null
            ? ApiError.fromJson(json['error'] as Map<String, dynamic>)
            : const ApiError(code: 'UNKNOWN', message: '未知错误');
        throw LiuyaoAgentException(error.code, error.message);
      }

      return SessionInfo.fromJson(json['data'] as Map<String, dynamic>);
    } on TimeoutException {
      throw const LiuyaoAgentException('TIMEOUT', '请求超时，请检查网络后重试');
    } catch (e) {
      if (e is LiuyaoAgentException) rethrow;
      throw LiuyaoAgentException('NETWORK_ERROR', '网络错误: $e');
    }
  }
}

/// Liuyao Agent 异常
class LiuyaoAgentException implements Exception {
  final String code;
  final String message;

  const LiuyaoAgentException(this.code, this.message);

  @override
  String toString() => 'LiuyaoAgentException[$code]: $message';
}