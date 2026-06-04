/// 权益类型
/// cast: 解读次数
/// followup: 追问次数
enum CreditType {
  cast('解读', 'cast'),
  followup('追问', 'followup');

  final String label;
  final String value;
  const CreditType(this.label, this.value);
}

/// 权益变动原因
enum CreditAction {
  reward('奖励', 'reward'),
  checkin('签到', 'checkin'),
  publish('发布', 'publish'),
  share('分享', 'share'),
  purchase('购买', 'purchase'),
  subscription('订阅', 'subscription'),
  consume('消耗', 'consume'),
  expire('过期', 'expire');

  final String label;
  final String value;
  const CreditAction(this.label, this.value);
}

class CreditAccount {
  final String userId;
  final int castBalance;
  final int followupBalance;
  final DateTime? castExpireDate;
  final DateTime? followupExpireDate;
  final DateTime lastCheckinDate;
  final DateTime lastResetDate;
  final bool isVip;
  final DateTime? vipExpireDate;

  const CreditAccount({
    required this.userId,
    this.castBalance = 0,
    this.followupBalance = 0,
    this.castExpireDate,
    this.followupExpireDate,
    required this.lastCheckinDate,
    required this.lastResetDate,
    this.isVip = false,
    this.vipExpireDate,
  });

  bool canCast() => castBalance > 0;

  bool canFollowup() => followupBalance > 0;

  bool hasCheckedInToday() {
    final now = DateTime.now();
    return lastCheckinDate.year == now.year &&
        lastCheckinDate.month == now.month &&
        lastCheckinDate.day == now.day;
  }

  bool isExpired(DateTime? expireDate) {
    if (expireDate == null) return false;
    return DateTime.now().isAfter(expireDate);
  }

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'castBalance': castBalance,
    'followupBalance': followupBalance,
    'castExpireDate': castExpireDate?.toIso8601String(),
    'followupExpireDate': followupExpireDate?.toIso8601String(),
    'lastCheckinDate': lastCheckinDate.toIso8601String(),
    'lastResetDate': lastResetDate.toIso8601String(),
    'isVip': isVip,
    'vipExpireDate': vipExpireDate?.toIso8601String(),
  };

  factory CreditAccount.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return CreditAccount(
      userId: json['userId'] as String,
      castBalance: json['castBalance'] as int? ?? 0,
      followupBalance: json['followupBalance'] as int? ?? 0,
      castExpireDate: json['castExpireDate'] != null
          ? DateTime.tryParse(json['castExpireDate'] as String)
          : null,
      followupExpireDate: json['followupExpireDate'] != null
          ? DateTime.tryParse(json['followupExpireDate'] as String)
          : null,
      lastCheckinDate:
          DateTime.tryParse((json['lastCheckinDate'] ?? '').toString()) ?? now,
      lastResetDate:
          DateTime.tryParse((json['lastResetDate'] ?? '').toString()) ?? now,
      isVip: json['isVip'] as bool? ?? false,
      vipExpireDate: json['vipExpireDate'] != null
          ? DateTime.tryParse(json['vipExpireDate'] as String)
          : null,
    );
  }

  CreditAccount copyWith({
    String? userId,
    int? castBalance,
    int? followupBalance,
    DateTime? castExpireDate,
    DateTime? followupExpireDate,
    DateTime? lastCheckinDate,
    DateTime? lastResetDate,
    bool? isVip,
    DateTime? vipExpireDate,
  }) {
    return CreditAccount(
      userId: userId ?? this.userId,
      castBalance: castBalance ?? this.castBalance,
      followupBalance: followupBalance ?? this.followupBalance,
      castExpireDate: castExpireDate ?? this.castExpireDate,
      followupExpireDate: followupExpireDate ?? this.followupExpireDate,
      lastCheckinDate: lastCheckinDate ?? this.lastCheckinDate,
      lastResetDate: lastResetDate ?? this.lastResetDate,
      isVip: isVip ?? this.isVip,
      vipExpireDate: vipExpireDate ?? this.vipExpireDate,
    );
  }

  factory CreditAccount.newUser(String userId) {
    final now = DateTime.now();
    return CreditAccount(
      userId: userId,
      castBalance: 1,
      followupBalance: 1,
      lastCheckinDate: DateTime.fromMillisecondsSinceEpoch(0),
      lastResetDate: DateTime(now.year, now.month, now.day),
      isVip: false,
    );
  }
}

class CreditTransaction {
  final String id;
  final String userId;
  final CreditType type;
  final CreditAction action;
  final int amount;
  final DateTime createdAt;
  final String? description;

  const CreditTransaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.action,
    required this.amount,
    required this.createdAt,
    this.description,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'type': type.value,
    'action': action.value,
    'amount': amount,
    'createdAt': createdAt.toIso8601String(),
    'description': description,
  };

  factory CreditTransaction.fromJson(Map<String, dynamic> json) {
    return CreditTransaction(
      id: json['id'] as String,
      userId: json['userId'] as String,
      type: CreditType.values.firstWhere(
        (e) => e.value == json['type'],
        orElse: () => CreditType.cast,
      ),
      action: CreditAction.values.firstWhere(
        (e) => e.value == json['action'],
        orElse: () => CreditAction.consume,
      ),
      amount: json['amount'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      description: json['description'] as String?,
    );
  }
}
