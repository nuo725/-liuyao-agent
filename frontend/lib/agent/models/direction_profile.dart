class AgentDirectionProfile {
  final String directionId;
  final String code;
  final String theme;
  final String stateName;
  final String coreTension;
  final String stateSummary;
  final String responseMode;
  final List<String> bestForInnerTensions;
  final List<String> avoidEmphasis;
  final List<String> culturalThemeRange;
  final List<String> psychTags;
  final List<String> followupCandidates;
  final List<String> hardAvoid;

  const AgentDirectionProfile({
    required this.directionId,
    required this.code,
    required this.theme,
    required this.stateName,
    required this.coreTension,
    required this.stateSummary,
    required this.responseMode,
    required this.bestForInnerTensions,
    required this.avoidEmphasis,
    required this.culturalThemeRange,
    required this.psychTags,
    required this.followupCandidates,
    required this.hardAvoid,
  });
}
