/// 用户模型
class User {
  final String id;
  final String? username;
  final String? avatarUrl;
  final String? coverUrl;
  final String? bio;
  final String? gender; // 'male' | 'female' | 'not_disclosed'
  final DateTime? birthday;
  final String? birthCity;
  final DateTime createdAt;
  final bool isAnonymous;

  const User({
    required this.id,
    this.username,
    this.avatarUrl,
    this.coverUrl,
    this.bio,
    this.gender,
    this.birthday,
    this.birthCity,
    required this.createdAt,
    this.isAnonymous = false,
  });

  bool get isComplete => username != null && !isAnonymous;

  /// 显示用的性别文案
  String get genderDisplay {
    switch (gender) {
      case 'male':
        return '男';
      case 'female':
        return '女';
      default:
        return '未设置';
    }
  }

  User copyWith({
    String? id,
    String? username,
    String? avatarUrl,
    String? coverUrl,
    String? bio,
    String? gender,
    DateTime? birthday,
    String? birthCity,
    DateTime? createdAt,
    bool? isAnonymous,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      bio: bio ?? this.bio,
      gender: gender ?? this.gender,
      birthday: birthday ?? this.birthday,
      birthCity: birthCity ?? this.birthCity,
      createdAt: createdAt ?? this.createdAt,
      isAnonymous: isAnonymous ?? this.isAnonymous,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'avatarUrl': avatarUrl,
    'coverUrl': coverUrl,
    'bio': bio,
    'gender': gender,
    'birthday': birthday?.toIso8601String(),
    'birthCity': birthCity,
    'createdAt': createdAt.toIso8601String(),
    'isAnonymous': isAnonymous,
  };

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as String,
    username: json['username'] as String?,
    avatarUrl: json['avatarUrl'] as String?,
    coverUrl: json['coverUrl'] as String?,
    bio: json['bio'] as String?,
    gender: json['gender'] as String?,
    birthday: json['birthday'] != null
        ? DateTime.parse(json['birthday'] as String)
        : null,
    birthCity: json['birthCity'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    isAnonymous: json['isAnonymous'] as bool? ?? false,
  );

  /// 创建匿名用户
  factory User.anonymous(String id) => User(
    id: id,
    createdAt: DateTime.now(),
    isAnonymous: true,
  );
}
