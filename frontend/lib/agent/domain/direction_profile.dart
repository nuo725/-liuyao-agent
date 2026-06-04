class DirectionProfile {
  final String directionId;
  final String code;

  // Internal topic for matching (not preferred for direct user display).
  final String theme;

  // User-facing state naming.
  final String stateName;

  final String coreTension;
  final String stateSummary;
  final String responseMode;

  final String hexagramName;
  final String upperTrigram;
  final String lowerTrigram;
  final String guaCi;
  final String xiangCi;
  final String lineRule;

  final List<String> avoid;
  final List<String> culturalTags;
  final List<String> psychTags;

  // Renamed per requirement.
  final List<String> bestForInnerTensions;

  final List<String> avoidEmphasis;
  final List<String> culturalThemeRange;
  final List<String> followupCandidates;

  const DirectionProfile({
    required this.directionId,
    required this.code,
    required this.theme,
    required this.stateName,
    required this.coreTension,
    required this.stateSummary,
    required this.responseMode,
    required this.hexagramName,
    required this.upperTrigram,
    required this.lowerTrigram,
    required this.guaCi,
    required this.xiangCi,
    required this.lineRule,
    required this.avoid,
    required this.culturalTags,
    required this.psychTags,
    required this.bestForInnerTensions,
    required this.avoidEmphasis,
    required this.culturalThemeRange,
    required this.followupCandidates,
  });
}
