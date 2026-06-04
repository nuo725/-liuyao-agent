import '../models/session.dart';
import 'liuyao_agent_service.dart';

// ============================================================================
// 追问服务接口
// ============================================================================
//
// 已接入后端：Liuyao APP API（/liuyao/app/chat/continue）
// 当前实现：LiuyaoFollowupServiceImpl
//
// 待接入后端 API（如果未来切换到业务后端）：
//   POST /agent/followup
//   Body: { "sessionId": "xxx", "direction": "xxx" | "question": "xxx" }
//   Response: { "success": true, "data": { FollowupMessage 结构 } }
//
//   GET  /agent/session/:sessionId
//   获取会话详情（用于断线重连后恢复）
//   Response: { "success": true, "data": { Session 结构 } }
//
// 注意事项：
//   - continueChat 超时设置为 120s（后端 LLM 生成较慢）
//   - SESSION_NOT_FOUND 错误码：会话过期，需要用户重新起卦
//   - 需要前端配合：追问上限 Session.maxFollowups = 5
// ============================================================================

/// 追问服务接口
/// 接入独立 Agent 时实现此接口
abstract class FollowupService {
  /// 基于推荐方向追问
  ///
  /// [session] 当前会话（含 id）
  /// [direction] 推荐方向文本（来自上一条回复的 followupDirections）
  Future<FollowupMessage> generateResponse({
    required Session session,
    required String direction,
  });

  /// 自由追问（用户直接输入）
  ///
  /// [session] 当前会话（含 id）
  /// [question] 用户自由输入的追问文本
  Future<FollowupMessage> generateFreeResponse({
    required Session session,
    required String question,
  });

  /// 流式追问（打字机效果）
  Stream<String> streamResponse({
    required Session session,
    required String content,
  });

  /// 是否应显示冷却提示（每 2 次追问后提示一次）
  bool shouldShowCooldown(Session session);

  /// 获取冷却提示文案
  String getCooldownMessage(Session session);
}

/// Liuyao Agent 追问服务实现
class LiuyaoFollowupServiceImpl implements FollowupService {
  final LiuyaoAgentApiService _api;

  LiuyaoFollowupServiceImpl({LiuyaoAgentApiService? api})
    : _api = api ?? LiuyaoAgentApiService();

  @override
  Future<FollowupMessage> generateResponse({
    required Session session,
    required String direction,
  }) async {
    if (session.id.isEmpty) {
      throw const LiuyaoAgentException('INVALID_SESSION', '会话 ID 为空');
    }

    // TODO(Backend Integration)[ritual_api#continue]: 替换为业务追问接口并补充分流策略
    final response = await _api.continueChat(
      sessionId: session.id,
      message: direction,
    );

    return FollowupMessage(
      id: 'f-${DateTime.now().millisecondsSinceEpoch}',
      content: response.reply.text,
      type: FollowupMessageType.answer,
      createdAt: DateTime.now(),
      suggestedDirections: null,
    );
  }

  @override
  Future<FollowupMessage> generateFreeResponse({
    required Session session,
    required String question,
  }) async {
    if (session.id.isEmpty) {
      throw const LiuyaoAgentException('INVALID_SESSION', '会话 ID 为空');
    }

    // TODO(Backend Integration)[ritual_api#continue]: 替换为业务追问接口并补充分流策略
    final response = await _api.continueChat(
      sessionId: session.id,
      message: question,
    );

    return FollowupMessage(
      id: 'f-${DateTime.now().millisecondsSinceEpoch}',
      content: response.reply.text,
      type: FollowupMessageType.answer,
      createdAt: DateTime.now(),
      suggestedDirections: null,
    );
  }

  @override
  Stream<String> streamResponse({
    required Session session,
    required String content,
  }) async* {
    for (final rune in content.runes) {
      await Future.delayed(const Duration(milliseconds: 30));
      yield String.fromCharCode(rune);
    }
  }

  @override
  bool shouldShowCooldown(Session session) {
    return session.followupCount > 0 &&
        session.followupCount % 2 == 0 &&
        session.followupCount < Session.maxFollowups;
  }

  @override
  String getCooldownMessage(Session session) {
    final remaining = Session.maxFollowups - session.followupCount;
    if (remaining <= 0) {
      return '本轮追问次数已用完，可稍后重新开启一次完整流程。';
    }
    return '先停一下，给自己十秒钟呼吸，再继续追问。';
  }
}

final followupServiceProvider = LiuyaoFollowupServiceImpl();
