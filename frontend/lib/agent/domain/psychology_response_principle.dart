class PsychologyResponsePrinciple {
  final String principleId;
  final String name;
  final List<String> tags;
  final String guideline;
  final List<String> languageDo;
  final List<String> languageDont;
  final List<String> avoidEscalation;
  final List<String> microPrompts;

  const PsychologyResponsePrinciple({
    required this.principleId,
    required this.name,
    required this.tags,
    required this.guideline,
    required this.languageDo,
    required this.languageDont,
    required this.avoidEscalation,
    required this.microPrompts,
  });
}
