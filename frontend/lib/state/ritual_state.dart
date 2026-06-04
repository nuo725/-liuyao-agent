import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/content/ritual_copy.dart';
import '../models/interpretation_card.dart';
import '../models/pattern.dart';
import '../models/ritual_record.dart';
import '../models/session.dart';
import '../services/followup_service.dart';
import '../services/conversation_input_guard_service.dart';
import '../services/interpretation_service.dart';
import '../services/first_launch_flow_service.dart';
import '../services/ritual_cache_service.dart';
import 'ritual_trigger_state.dart';
import '../services/safety_service.dart';

enum RitualFlowMode { software, hardware }

enum RitualInputMode { manualThrow, hardwareLink, localAnimation }

enum RitualSimulationMode { success, delayed, timeout, error, retryRecovery }

enum RitualPhase {
  entry,
  hardwareConnect,
  moodInput,
  action,
  hardwareAction,
  hardwareComplete,
  suspension,
  presentation,
  response,
  closure,
}

class RitualState {
  final RitualPhase phase;
  final RitualFlowMode flowMode;
  final Pattern? pattern;
  final String? question;
  final QuestionTag? questionTag;
  final RitualInputMode inputMode;
  final InterpretationCard? card;
  final Session? session;
  final RiskLevel riskLevel;
  final List<RitualRecord> history;
  final List<int>? pendingLines;
  final bool isLoading;
  final String? error;
  final RitualSimulationMode simulationMode;
  final int simulationAttempt;
  final DateTime? lastCompletedAt;

  const RitualState({
    this.phase = RitualPhase.entry,
    this.flowMode = RitualFlowMode.software,
    this.pattern,
    this.question,
    this.questionTag,
    this.inputMode = RitualInputMode.manualThrow,
    this.card,
    this.session,
    this.riskLevel = RiskLevel.low,
    this.history = const [],
    this.pendingLines,
    this.isLoading = false,
    this.error,
    this.simulationMode = RitualSimulationMode.success,
    this.simulationAttempt = 0,
    this.lastCompletedAt,
  });

  bool get completedToday {
    if (lastCompletedAt == null) return false;
    final now = DateTime.now();
    return lastCompletedAt!.year == now.year &&
        lastCompletedAt!.month == now.month &&
        lastCompletedAt!.day == now.day;
  }

  RitualState copyWith({
    RitualPhase? phase,
    RitualFlowMode? flowMode,
    Pattern? pattern,
    String? question,
    QuestionTag? questionTag,
    RitualInputMode? inputMode,
    InterpretationCard? card,
    Session? session,
    RiskLevel? riskLevel,
    List<RitualRecord>? history,
    List<int>? pendingLines,
    bool clearPendingLines = false,
    bool? isLoading,
    String? error,
    bool clearError = false,
    RitualSimulationMode? simulationMode,
    int? simulationAttempt,
    DateTime? lastCompletedAt,
  }) {
    return RitualState(
      phase: phase ?? this.phase,
      flowMode: flowMode ?? this.flowMode,
      pattern: pattern ?? this.pattern,
      question: question ?? this.question,
      questionTag: questionTag ?? this.questionTag,
      inputMode: inputMode ?? this.inputMode,
      card: card ?? this.card,
      session: session ?? this.session,
      riskLevel: riskLevel ?? this.riskLevel,
      history: history ?? this.history,
      pendingLines: clearPendingLines
          ? null
          : (pendingLines ?? this.pendingLines),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      simulationMode: simulationMode ?? this.simulationMode,
      simulationAttempt: simulationAttempt ?? this.simulationAttempt,
      lastCompletedAt: lastCompletedAt ?? this.lastCompletedAt,
    );
  }
}

class RitualStateNotifier extends Notifier<RitualState> {
  @override
  RitualState build() {
    const initial = RitualState();
    unawaited(_restoreFromCache());
    return initial;
  }

  void startSoftwareFlow() {
    ref.read(ritualTriggerProvider.notifier).useTouchMode();
    state = state.copyWith(
      phase: RitualPhase.moodInput,
      flowMode: RitualFlowMode.software,
      clearPendingLines: true,
      clearError: true,
      isLoading: false,
    );
    unawaited(_persistSnapshot());
  }

  void setInputMode(RitualInputMode mode) {
    state = state.copyWith(inputMode: mode);
    unawaited(_persistSnapshot());
  }

  Future<void> startHardwareFlow() async {
    ref.read(ritualTriggerProvider.notifier).useHardwareMode();
    await ref.read(ritualTriggerProvider.notifier).refreshHardwareState();

    state = state.copyWith(
      phase: RitualPhase.hardwareConnect,
      flowMode: RitualFlowMode.hardware,
      clearPendingLines: true,
      clearError: true,
      isLoading: false,
    );
    unawaited(_persistSnapshot());
  }

  void continueFromHardwareConnect() {
    state = state.copyWith(phase: RitualPhase.moodInput, clearError: true);
    unawaited(_persistSnapshot());
  }

  bool setQuestion(String question, {QuestionTag? tag}) {
    final validation = conversationInputGuardServiceProvider
        .validateInitialQuestion(question);
    if (!validation.accepted) {
      state = state.copyWith(error: validation.message, isLoading: false);
      unawaited(_persistSnapshot());
      return false;
    }

    final riskLevel = safetyServiceProvider.detectRiskLevel(
      validation.normalizedText,
    );
    state = state.copyWith(
      question: validation.normalizedText,
      questionTag: tag,
      riskLevel: riskLevel,
      clearError: true,
    );
    unawaited(_persistSnapshot());
    return true;
  }

  void advanceFromQuestion() {
    final target = state.flowMode == RitualFlowMode.hardware
        ? RitualPhase.hardwareAction
        : RitualPhase.action;
    state = state.copyWith(phase: target, clearError: true);
    unawaited(_persistSnapshot());
  }

  void setSimulationMode(RitualSimulationMode mode) {
    state = state.copyWith(
      simulationMode: mode,
      simulationAttempt: 0,
      clearError: true,
    );
    unawaited(_persistSnapshot());
  }

  Future<void> stageHardwareCompletion(List<int> lines) async {
    if (lines.length != 6) {
      state = state.copyWith(
        error: '硬件结果不完整，请重新采集。',
        isLoading: false,
      );
      unawaited(_persistSnapshot());
      return;
    }
    final normalized = lines.map((e) => e > 0 ? 1 : 0).toList();
    state = state.copyWith(
      phase: RitualPhase.hardwareComplete,
      pendingLines: normalized,
      clearError: true,
      isLoading: false,
    );
    unawaited(_persistSnapshot());
  }

  void restartHardwareCollection() {
    state = state.copyWith(
      phase: RitualPhase.hardwareAction,
      clearPendingLines: true,
      clearError: true,
    );
    unawaited(_persistSnapshot());
  }

  void switchHardwareToTouchFallback() {
    ref.read(ritualTriggerProvider.notifier).useTouchMode();
    state = state.copyWith(
      flowMode: RitualFlowMode.software,
      phase: RitualPhase.action,
      clearPendingLines: true,
      clearError: true,
    );
    unawaited(_persistSnapshot());
  }

  Future<void> runHardwareCompletion() async {
    final lines = state.pendingLines;
    if (lines == null || lines.length != 6) {
      state = state.copyWith(
        error: '未检测到完整硬件结果，请重试采集。',
      );
      unawaited(_persistSnapshot());
      return;
    }
    await performRitual(sourceLines: lines);
  }

  Future<void> performRitual({List<int>? sourceLines}) async {
    if (state.question == null || state.question!.trim().isEmpty) return;
    final validation = conversationInputGuardServiceProvider
        .validateInitialQuestion(state.question!);
    if (!validation.accepted) {
      state = state.copyWith(error: validation.message, isLoading: false);
      unawaited(_persistSnapshot());
      return;
    }

    final attempt = state.simulationAttempt + 1;
    state = state.copyWith(
      phase: RitualPhase.suspension,
      isLoading: true,
      clearError: true,
      clearPendingLines: true,
      simulationAttempt: attempt,
      question: validation.normalizedText,
    );
    unawaited(_persistSnapshot());

    final retryPhase = state.flowMode == RitualFlowMode.hardware
        ? RitualPhase.hardwareComplete
        : RitualPhase.action;
    final mode = state.simulationMode;

    final delay = switch (mode) {
      RitualSimulationMode.delayed => const Duration(milliseconds: 2800),
      RitualSimulationMode.timeout => const Duration(milliseconds: 2500),
      _ => const Duration(milliseconds: 1200),
    };
    await Future.delayed(delay);

    final shouldTimeout = mode == RitualSimulationMode.timeout;
    final shouldError = mode == RitualSimulationMode.error;
    final shouldFailFirstOnly =
        mode == RitualSimulationMode.retryRecovery && attempt == 1;
    if (shouldTimeout || shouldError || shouldFailFirstOnly) {
      final error = shouldTimeout
          ? '模拟超时，请重试。'
          : shouldFailFirstOnly
              ? '按模拟设定本次首次失败，请再次重试。'
              : '模拟错误，请重试。';
      state = state.copyWith(phase: retryPhase, isLoading: false, error: error);
      unawaited(_persistSnapshot());
      return;
    }

    final pattern = _buildPattern(sourceLines);
    final body = _buildMockBody(validation.normalizedText, attempt);
    final card = InterpretationCard(
      id: 'sim-${DateTime.now().millisecondsSinceEpoch}',
      question: validation.normalizedText,
      tag: state.questionTag,
      pattern: pattern,
      content: const InterpretationContent(
        summary: '',
        focusPoints: [],
        afterglow: '',
        followupDirections: [
          RitualCopy.followupA,
          RitualCopy.followupB,
          RitualCopy.followupC,
        ],
        body: '',
        visualBlocks: [],
      ),
      riskLevel: state.riskLevel,
      createdAt: DateTime.now(),
      needsClarification: false,
    );

    final hydratedCard = InterpretationCard(
      id: card.id,
      question: card.question,
      tag: card.tag,
      pattern: card.pattern,
      riskLevel: card.riskLevel,
      createdAt: card.createdAt,
      content: InterpretationContent(
        summary: body,
        focusPoints: const [],
        afterglow: '',
        followupDirections: const [
          RitualCopy.followupA,
          RitualCopy.followupB,
          RitualCopy.followupC,
        ],
        body: body,
        quoteText: null,
        quoteSource: null,
        visualBlocks: const [],
      ),
      needsClarification: false,
    );

    final session = Session(
      id: hydratedCard.id,
      question: validation.normalizedText,
      tag: state.questionTag,
      pattern: pattern,
      initialCard: hydratedCard,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final record = RitualRecord(
      mood: validation.normalizedText,
      hexagram: pattern.lines,
      dateTime: DateTime.now(),
    );

    // TODO(Backend Integration)[ritual_api#perform]:
    // 后端接入后，替换本地模拟为服务端 pattern + interpretation。
    state = state.copyWith(
      phase: RitualPhase.response,
      pattern: pattern,
      card: hydratedCard,
      session: session,
      history: [...state.history, record],
      isLoading: false,
      clearError: true,
      lastCompletedAt: DateTime.now(),
    );

    unawaited(firstLaunchFlowServiceProvider.markCompleted());
    unawaited(_persistSnapshot());
  }

  Future<void> followup(String direction) async {
    if (state.session == null || !state.session!.canFollowup) return;

    final cleanedDirection = direction.trim();
    if (cleanedDirection.isEmpty) return;
    final validation = conversationInputGuardServiceProvider
        .validateFollowupQuestion(cleanedDirection);
    final normalizedDirection = validation.accepted
        ? validation.normalizedText
        : cleanedDirection;

    final questionMessage = FollowupMessage(
      id: 'q-${DateTime.now().millisecondsSinceEpoch}',
      content: cleanedDirection,
      type: FollowupMessageType.question,
      createdAt: DateTime.now(),
    );

    final sessionWithQuestion = state.session!.copyWith(
      messages: [...state.session!.messages, questionMessage],
      updatedAt: DateTime.now(),
    );

    state = state.copyWith(isLoading: true, clearError: true);
    state = state.copyWith(session: sessionWithQuestion);
    unawaited(_persistSnapshot());

    try {
      final response = await _simulateFollowupResponse(
        session: sessionWithQuestion,
        prompt: normalizedDirection,
      );

      final updatedSession = sessionWithQuestion.copyWith(
        messages: [...sessionWithQuestion.messages, response],
        followupCount: sessionWithQuestion.followupCount + 1,
        updatedAt: DateTime.now(),
      );

      state = state.copyWith(
        session: updatedSession,
        isLoading: false,
        clearError: true,
      );
    } catch (_) {
      state = state.copyWith(
        session: sessionWithQuestion,
        isLoading: false,
        error: '追问模拟失败，请重试。',
      );
    }

    unawaited(_persistSnapshot());
  }

  Future<void> freeFollowup(String question) async {
    if (state.session == null || !state.session!.canFollowup) return;

    final cleanedQuestion = question.trim();
    if (cleanedQuestion.isEmpty) return;
    final validation = conversationInputGuardServiceProvider
        .validateFollowupQuestion(cleanedQuestion);
    final normalizedQuestion = validation.accepted
        ? validation.normalizedText
        : cleanedQuestion;

    final questionMessage = FollowupMessage(
      id: 'q-${DateTime.now().millisecondsSinceEpoch}',
      content: cleanedQuestion,
      type: FollowupMessageType.question,
      createdAt: DateTime.now(),
    );

    final sessionWithQuestion = state.session!.copyWith(
      messages: [...state.session!.messages, questionMessage],
      updatedAt: DateTime.now(),
    );

    state = state.copyWith(isLoading: true, clearError: true);
    state = state.copyWith(session: sessionWithQuestion);
    unawaited(_persistSnapshot());

    try {
      final response = await _simulateFollowupResponse(
        session: sessionWithQuestion,
        prompt: normalizedQuestion,
      );

      final updatedSession = sessionWithQuestion.copyWith(
        messages: [...sessionWithQuestion.messages, response],
        followupCount: sessionWithQuestion.followupCount + 1,
        updatedAt: DateTime.now(),
      );

      state = state.copyWith(
        session: updatedSession,
        isLoading: false,
        clearError: true,
      );
    } catch (_) {
      state = state.copyWith(
        session: sessionWithQuestion,
        isLoading: false,
        error: '追问模拟失败，请重试。',
      );
    }

    unawaited(_persistSnapshot());
  }

  Pattern _buildPattern(List<int>? sourceLines) {
    final lines = (sourceLines != null && sourceLines.length == 6)
        ? sourceLines.map((e) => e > 0 ? 1 : 0).toList()
        : List<int>.generate(
            6,
            (index) =>
                ((DateTime.now().millisecondsSinceEpoch + index) % 2 == 0)
                ? 1
                : 0,
          );
    return Pattern(
      lines: lines,
      movingLines: const [],
      createdAt: DateTime.now(),
    );
  }

  String _buildMockBody(String question, int attempt) {
    final pool = <String>[
      RitualCopy.mockAnswerA,
      RitualCopy.mockAnswerB,
      RitualCopy.mockAnswerC,
      RitualCopy.mockAnswerD,
    ];
    final seed = question.hashCode.abs() + attempt;
    return pool[seed % pool.length];
  }

  Future<FollowupMessage> _simulateFollowupResponse({
    required Session session,
    required String prompt,
  }) async {
    final mode = state.simulationMode;

    final wait = switch (mode) {
      RitualSimulationMode.delayed => const Duration(milliseconds: 1400),
      RitualSimulationMode.timeout => const Duration(milliseconds: 2000),
      _ => const Duration(milliseconds: 500),
    };
    await Future.delayed(wait);

    if (mode == RitualSimulationMode.timeout) {
      throw TimeoutException('追问模拟超时。');
    }
    if (mode == RitualSimulationMode.error) {
      throw Exception('追问模拟错误。');
    }

    final answer = '你问的是：“$prompt”。先从一个可立即执行的小动作开始，做完后再回看你的内在感受。';

    // TODO(Backend Integration)[ritual_api#continue]:
    // 后端接入后，将模拟追问替换为真实会话回复。
    return FollowupMessage(
      id: 'a-${DateTime.now().millisecondsSinceEpoch}',
      content: answer,
      type: FollowupMessageType.answer,
      createdAt: DateTime.now(),
      suggestedDirections: const [
        RitualCopy.followupA,
        RitualCopy.followupB,
        RitualCopy.followupC,
      ],
    );
  }

  bool shouldShowCooldown() {
    if (state.session == null) return false;
    return followupServiceProvider.shouldShowCooldown(state.session!);
  }

  String getCooldownMessage() {
    if (state.session == null) return '';
    return followupServiceProvider.getCooldownMessage(state.session!);
  }

  bool get canFollowup => state.session?.canFollowup ?? false;

  void clearError() {
    state = state.copyWith(clearError: true);
    unawaited(_persistSnapshot());
  }

  void saveCurrentRecord() {
    if (state.question == null || state.pattern == null) return;
    final record = RitualRecord(
      mood: state.question!,
      hexagram: state.pattern!.lines,
      dateTime: DateTime.now(),
    );
    state = state.copyWith(
      history: [...state.history, record],
      clearError: true,
    );
    unawaited(_persistSnapshot());
  }

  void completeAndExitFlow() {
    state = state.copyWith(phase: RitualPhase.closure, clearError: true);
    unawaited(_persistSnapshot());
  }

  /// 直接写入会话（用于 OneTapCeremonyPage 在兜底路径下跳过 suspension）。
  void forceSetSession({
    required Pattern pattern,
    required InterpretationCard card,
    required Session session,
    required RitualRecord record,
  }) {
    state = state.copyWith(
      phase: RitualPhase.response,
      pattern: pattern,
      card: card,
      session: session,
      history: [...state.history, record],
      isLoading: false,
      clearError: true,
    );
    unawaited(_persistSnapshot());
  }

  void reset() {
    ref.read(ritualTriggerProvider.notifier).useTouchMode();
    state = RitualState(
      phase: RitualPhase.entry,
      flowMode: RitualFlowMode.software,
      inputMode: RitualInputMode.manualThrow,
      history: state.history,
      simulationMode: state.simulationMode,
      simulationAttempt: 0,
      lastCompletedAt: state.lastCompletedAt,
    );
    unawaited(_persistSnapshot());
  }

  void clearHistory() {
    state = RitualState(
      phase: RitualPhase.entry,
      inputMode: RitualInputMode.manualThrow,
      simulationMode: state.simulationMode,
      simulationAttempt: 0,
    );
    unawaited(_persistSnapshot());
  }

  void nextPhase() {
    switch (state.phase) {
      case RitualPhase.entry:
        startSoftwareFlow();
        return;
      case RitualPhase.hardwareConnect:
        continueFromHardwareConnect();
        return;
      case RitualPhase.moodInput:
        advanceFromQuestion();
        return;
      case RitualPhase.action:
      case RitualPhase.hardwareAction:
      case RitualPhase.hardwareComplete:
        state = state.copyWith(phase: RitualPhase.suspension, clearError: true);
        unawaited(_persistSnapshot());
        return;
      case RitualPhase.suspension:
        state = state.copyWith(phase: RitualPhase.response, clearError: true);
        unawaited(_persistSnapshot());
        return;
      case RitualPhase.presentation:
        state = state.copyWith(phase: RitualPhase.response, clearError: true);
        unawaited(_persistSnapshot());
        return;
      case RitualPhase.response:
        state = state.copyWith(phase: RitualPhase.closure, clearError: true);
        unawaited(_persistSnapshot());
        return;
      case RitualPhase.closure:
        return;
    }
  }

  Future<void> _restoreFromCache() async {
    final snapshot = await ritualCacheServiceProvider.loadSnapshot();
    if (snapshot == null) return;

    final restored = _decodeSnapshot(snapshot);
    if (restored == null) return;
    state = restored;
  }

  Future<void> _persistSnapshot() async {
    await ritualCacheServiceProvider.saveSnapshot(_encodeSnapshot(state));
  }

  Map<String, dynamic> _encodeSnapshot(RitualState value) {
    return {
      'phase': value.phase.name,
      'flowMode': value.flowMode.name,
      'inputMode': value.inputMode.name,
      'question': value.question,
      'questionTag': value.questionTag?.value,
      'riskLevel': value.riskLevel.value,
      'pattern': value.pattern?.toJson(),
      'card': value.card?.toJson(),
      'session': value.session?.toJson(),
      'history': value.history.map((e) => e.toJson()).toList(),
      'pendingLines': value.pendingLines,
      'simulationMode': value.simulationMode.name,
      'simulationAttempt': value.simulationAttempt,
      'lastCompletedAt': value.lastCompletedAt?.toIso8601String(),
      'savedAt': DateTime.now().toIso8601String(),
    };
  }

  RitualState? _decodeSnapshot(Map<String, dynamic> json) {
    try {
      final question = (json['question'] as String?)?.trim();
      final phase = _phaseFromName(json['phase'] as String?);
      final flowMode = _flowModeFromName(json['flowMode'] as String?);
      final inputMode = _inputModeFromName(json['inputMode'] as String?);
      final questionTag = _questionTagFromValue(json['questionTag'] as String?);
      final risk = _riskFromValue(json['riskLevel'] as String?);
      final simulationMode = _simulationModeFromName(
        json['simulationMode'] as String?,
      );
      final simulationAttempt = json['simulationAttempt'] as int? ?? 0;
      final lastCompletedAt = json['lastCompletedAt'] != null
          ? DateTime.tryParse(json['lastCompletedAt'] as String)
          : null;

      final patternJson = json['pattern'];
      final cardJson = json['card'];
      final sessionJson = json['session'];
      final historyJson = json['history'];

      final pattern = patternJson is Map
          ? Pattern.fromJson(Map<String, dynamic>.from(patternJson))
          : null;
      final card = cardJson is Map
          ? InterpretationCard.fromJson(Map<String, dynamic>.from(cardJson))
          : null;
      final session = sessionJson is Map
          ? Session.fromJson(Map<String, dynamic>.from(sessionJson))
          : null;
      final history = historyJson is List
          ? historyJson
                .whereType<Map>()
                .map((e) => RitualRecord.fromJson(Map<String, dynamic>.from(e)))
                .toList()
          : const <RitualRecord>[];
      final pendingLines = json['pendingLines'] is List
          ? List<int>.from(json['pendingLines'] as List)
          : null;

      var normalizedPhase = phase;
      if (normalizedPhase == RitualPhase.closure) {
        normalizedPhase = RitualPhase.entry;
      }
      if (question == null || question.isEmpty) {
        normalizedPhase = RitualPhase.entry;
      } else if (normalizedPhase == RitualPhase.presentation) {
        normalizedPhase = RitualPhase.response;
      } else if (session == null &&
          (normalizedPhase == RitualPhase.presentation ||
              normalizedPhase == RitualPhase.response ||
              normalizedPhase == RitualPhase.suspension)) {
        normalizedPhase = RitualPhase.moodInput;
      }

      return RitualState(
        phase: normalizedPhase,
        flowMode: flowMode,
        inputMode: inputMode,
        question: question,
        questionTag: questionTag,
        riskLevel: risk,
        pattern: pattern,
        card: card,
        session: session,
        history: history,
        pendingLines: pendingLines,
        simulationMode: simulationMode,
        simulationAttempt: simulationAttempt,
        lastCompletedAt: lastCompletedAt,
      );
    } catch (_) {
      return null;
    }
  }

  RitualPhase _phaseFromName(String? value) {
    return RitualPhase.values.firstWhere(
      (e) => e.name == value,
      orElse: () => RitualPhase.entry,
    );
  }

  RitualFlowMode _flowModeFromName(String? value) {
    return RitualFlowMode.values.firstWhere(
      (e) => e.name == value,
      orElse: () => RitualFlowMode.software,
    );
  }

  RitualInputMode _inputModeFromName(String? value) {
    return RitualInputMode.values.firstWhere(
      (e) => e.name == value,
      orElse: () => RitualInputMode.manualThrow,
    );
  }

  QuestionTag? _questionTagFromValue(String? value) {
    if (value == null) return null;
    return QuestionTag.values.firstWhere(
      (e) => e.value == value,
      orElse: () => QuestionTag.other,
    );
  }

  RiskLevel _riskFromValue(String? value) {
    return RiskLevel.values.firstWhere(
      (e) => e.value == value,
      orElse: () => RiskLevel.low,
    );
  }

  RitualSimulationMode _simulationModeFromName(String? value) {
    return RitualSimulationMode.values.firstWhere(
      (e) => e.name == value,
      orElse: () => RitualSimulationMode.success,
    );
  }
}

final ritualStateProvider = NotifierProvider<RitualStateNotifier, RitualState>(
  RitualStateNotifier.new,
);

final responseStreamProvider = StreamProvider<String>((ref) {
  final state = ref.watch(ritualStateProvider);
  if (state.pattern == null) return const Stream.empty();

  return interpretationServiceProvider.streamInterpretation(
    question: state.question ?? '',
    tag: state.questionTag,
    pattern: state.pattern!,
    riskLevel: state.riskLevel,
  );
});
