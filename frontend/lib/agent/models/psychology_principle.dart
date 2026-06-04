class AgentPsychologyPrinciple {
  final String principleId;
  final String name;
  final List<String> applicableTags;
  final String guideline;
  final List<String> languageDo;
  final List<String> languageDont;
  final List<String> microBridgeExamples;
  final List<String> avoidEscalation;

  const AgentPsychologyPrinciple({
    required this.principleId,
    required this.name,
    required this.applicableTags,
    required this.guideline,
    required this.languageDo,
    required this.languageDont,
    required this.microBridgeExamples,
    required this.avoidEscalation,
  });
}
