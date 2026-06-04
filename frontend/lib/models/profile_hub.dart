class InteractionRecord {
  final String id;
  final String contentKey;
  final String source;
  final String title;
  final String? detail;
  final DateTime createdAt;

  const InteractionRecord({
    required this.id,
    required this.contentKey,
    required this.source,
    required this.title,
    this.detail,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'contentKey': contentKey,
        'source': source,
        'title': title,
        'detail': detail,
        'createdAt': createdAt.toIso8601String(),
      };

  factory InteractionRecord.fromJson(Map<String, dynamic> json) {
    return InteractionRecord(
      id: json['id'] as String? ?? '',
      contentKey: json['contentKey'] as String? ?? '',
      source: json['source'] as String? ?? '',
      title: json['title'] as String? ?? '',
      detail: json['detail'] as String?,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class BrowseRecord {
  final String id;
  final String contentKey;
  final String source;
  final String title;
  final String? snippet;
  final DateTime createdAt;

  const BrowseRecord({
    required this.id,
    required this.contentKey,
    required this.source,
    required this.title,
    this.snippet,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'contentKey': contentKey,
        'source': source,
        'title': title,
        'snippet': snippet,
        'createdAt': createdAt.toIso8601String(),
      };

  factory BrowseRecord.fromJson(Map<String, dynamic> json) {
    return BrowseRecord(
      id: json['id'] as String? ?? '',
      contentKey: json['contentKey'] as String? ?? '',
      source: json['source'] as String? ?? '',
      title: json['title'] as String? ?? '',
      snippet: json['snippet'] as String?,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class ProfileSettings {
  final bool pushEnabled;
  final bool vibrationEnabled;
  final bool publicProfile;
  final bool ambientSoundEnabled;

  const ProfileSettings({
    this.pushEnabled = true,
    this.vibrationEnabled = true,
    this.publicProfile = true,
    this.ambientSoundEnabled = true,
  });

  ProfileSettings copyWith({
    bool? pushEnabled,
    bool? vibrationEnabled,
    bool? publicProfile,
    bool? ambientSoundEnabled,
  }) {
    return ProfileSettings(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      publicProfile: publicProfile ?? this.publicProfile,
      ambientSoundEnabled: ambientSoundEnabled ?? this.ambientSoundEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'pushEnabled': pushEnabled,
        'vibrationEnabled': vibrationEnabled,
        'publicProfile': publicProfile,
        'ambientSoundEnabled': ambientSoundEnabled,
      };

  factory ProfileSettings.fromJson(Map<String, dynamic> json) {
    return ProfileSettings(
      pushEnabled: json['pushEnabled'] as bool? ?? true,
      vibrationEnabled: json['vibrationEnabled'] as bool? ?? true,
      publicProfile: json['publicProfile'] as bool? ?? true,
      ambientSoundEnabled: json['ambientSoundEnabled'] as bool? ?? true,
    );
  }
}
