class AgentRitualSession {
  final String sessionId;
  final String directionId;
  final String stateName;
  final List<int> ritualResults;
  final String question;
  final String mode;
  final int turnCount;
  final List<Map<String, String>> history;
  final List<String> principleIds;
  final String quoteId;

  const AgentRitualSession({
    required this.sessionId,
    required this.directionId,
    required this.stateName,
    required this.ritualResults,
    required this.question,
    required this.mode,
    required this.turnCount,
    required this.history,
    required this.principleIds,
    required this.quoteId,
  });
}
