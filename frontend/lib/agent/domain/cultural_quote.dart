class CulturalQuote {
  final String quoteId;
  final String text;
  final String source;
  final List<String> tags;
  final String tone;
  final List<String> suitableFor;
  final List<String> avoidFor;
  final bool verified;
  final String sourceType; // local | web

  const CulturalQuote({
    required this.quoteId,
    required this.text,
    required this.source,
    required this.tags,
    required this.tone,
    required this.suitableFor,
    required this.avoidFor,
    this.verified = true,
    this.sourceType = 'local',
  });
}
