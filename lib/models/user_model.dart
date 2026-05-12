class UserModel {
  final String uid;
  final String name;
  final String email;

  // ── Rol ve VIP ───────────────────────────────────────────────────────
  final String role;
  final bool   isVip;

  // ── XP ve Lig ────────────────────────────────────────────────────────
  final int    totalXp;
  final int    weeklyXp;
  final String league;
  final int    leagueLevel; // user_service ve mission_service yazıyor

  // ── Enerji ───────────────────────────────────────────────────────────
  final int energy;
  final int maxEnergy;
  final int bonusEnergy;

  // ── Günlük Sayaçlar ──────────────────────────────────────────────────
  final int dailyQuestions;
  final int dailyCorrect;
  final int dailySections;
  final int dailyAds;
  final int dailyBonusEarned;
  final int dailyLogin;

  // ── Haftalık Sayaçlar ────────────────────────────────────────────────
  final int weeklyCorrect;
  final int weeklySections;
  final int weeklyAds;

  // ── Toplam Sayaçlar ──────────────────────────────────────────────────
  final int totalBioQuestions;
  final int totalCorrect;
  final int totalSections;

  // ── Streak ───────────────────────────────────────────────────────────
  final int loginStreak;

  // ── Profil & Başarım ─────────────────────────────────────────────────
  /// Avatar çerçeve index'i (int) — kVipAvatarFrames listesine karşılık gelir.
  /// leaderboard_page, home_page, profile_page bu değeri okur.
  final int          avatarFrame;

  /// Kazanılan rozet ID listesi — achievement sistemi yazar.
  final List<String> badges;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.isVip,
    required this.totalXp,
    required this.weeklyXp,
    required this.league,
    required this.leagueLevel,
    required this.energy,
    required this.maxEnergy,
    required this.bonusEnergy,
    required this.dailyQuestions,
    required this.dailyCorrect,
    required this.dailySections,
    required this.dailyAds,
    required this.dailyBonusEarned,
    required this.dailyLogin,
    required this.weeklyCorrect,
    required this.weeklySections,
    required this.weeklyAds,
    required this.totalBioQuestions,
    required this.totalCorrect,
    required this.totalSections,
    required this.loginStreak,
    required this.avatarFrame,
    required this.badges,
  });

  // ── Firestore → Model ─────────────────────────────────────────────────
  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    // avatarFrame: Firestore'da int olarak saklanır.
    // Tip güvenliği: String veya başka tip gelirse 0 kullan.
    int parseAvatarFrame(dynamic raw) {
      if (raw is int) return raw;
      if (raw is double) return raw.toInt();
      return 0;
    }

    // badges: String listesi olarak saklanır.
    List<String> parseBadges(dynamic raw) {
      if (raw is List) {
        return raw
            .whereType<String>()
            .toList();
      }
      return [];
    }

    return UserModel(
      uid:   uid,
      name:  map['name']  ?? 'İsimsiz',
      email: map['email'] ?? '',

      // Rol ve VIP
      role:  map['role']  ?? 'student',
      isVip: map['isVip'] == true,

      // XP ve Lig
      totalXp:    (map['totalXp']    ?? 0).toInt(),
      weeklyXp:   (map['weeklyXp']   ?? 0).toInt(),
      league:     map['league']      ?? 'Bronz',
      leagueLevel:(map['leagueLevel'] ?? 1).toInt(),

      // Enerji
      energy:      (map['energy']      ?? 50).toInt(),
      maxEnergy:   (map['maxEnergy']   ?? 50).toInt(),
      bonusEnergy: (map['bonusEnergy'] ?? 0).toInt(),

      // Günlük
      dailyQuestions:  (map['dailyQuestions']  ?? 0).toInt(),
      dailyCorrect:    (map['dailyCorrect']    ?? 0).toInt(),
      dailySections:   (map['dailySections']   ?? 0).toInt(),
      dailyAds:        (map['dailyAds']        ?? 0).toInt(),
      dailyBonusEarned:(map['dailyBonusEarned'] ?? 0).toInt(),
      dailyLogin:      (map['dailyLogin']      ?? 0).toInt(),

      // Haftalık
      weeklyCorrect:  (map['weeklyCorrect']  ?? 0).toInt(),
      weeklySections: (map['weeklySections'] ?? 0).toInt(),
      weeklyAds:      (map['weeklyAds']      ?? 0).toInt(),

      // Toplam
      totalBioQuestions: (map['totalBioQuestions'] ?? 0).toInt(),
      totalCorrect:      (map['totalCorrect']      ?? 0).toInt(),
      totalSections:     (map['totalSections']     ?? 0).toInt(),

      // Streak
      loginStreak: (map['loginStreak'] ?? 0).toInt(),

      // Profil & Başarım
      avatarFrame: parseAvatarFrame(map['avatarFrame']),
      badges:      parseBadges(map['badges']),
    );
  }

  // ── Model → Firestore ─────────────────────────────────────────────────
  /// fromMap ile tam simetrik — hangi alan yazılıyorsa okunuyor.
  Map<String, dynamic> toMap() {
    return {
      'uid':   uid,
      'name':  name,
      'email': email,

      // Rol ve VIP
      'role':  role,
      'isVip': isVip,

      // XP ve Lig
      'totalXp':    totalXp,
      'weeklyXp':   weeklyXp,
      'league':     league,
      'leagueLevel': leagueLevel,

      // Enerji
      'energy':      energy,
      'maxEnergy':   maxEnergy,
      'bonusEnergy': bonusEnergy,

      // Günlük
      'dailyQuestions':   dailyQuestions,
      'dailyCorrect':     dailyCorrect,
      'dailySections':    dailySections,
      'dailyAds':         dailyAds,
      'dailyBonusEarned': dailyBonusEarned,
      'dailyLogin':       dailyLogin,

      // Haftalık
      'weeklyCorrect':  weeklyCorrect,
      'weeklySections': weeklySections,
      'weeklyAds':      weeklyAds,

      // Toplam
      'totalBioQuestions': totalBioQuestions,
      'totalCorrect':      totalCorrect,
      'totalSections':     totalSections,

      // Streak
      'loginStreak': loginStreak,

      // Profil & Başarım
      'avatarFrame': avatarFrame,
      'badges':      badges,
    };
  }

  // ── copyWith — immutable güncellemeler için ───────────────────────────
  UserModel copyWith({
    String?       name,
    String?       email,
    String?       role,
    bool?         isVip,
    int?          totalXp,
    int?          weeklyXp,
    String?       league,
    int?          leagueLevel,
    int?          energy,
    int?          maxEnergy,
    int?          bonusEnergy,
    int?          dailyQuestions,
    int?          dailyCorrect,
    int?          dailySections,
    int?          dailyAds,
    int?          dailyBonusEarned,
    int?          dailyLogin,
    int?          weeklyCorrect,
    int?          weeklySections,
    int?          weeklyAds,
    int?          totalBioQuestions,
    int?          totalCorrect,
    int?          totalSections,
    int?          loginStreak,
    int?          avatarFrame,
    List<String>? badges,
  }) {
    return UserModel(
      uid:              uid,
      name:             name             ?? this.name,
      email:            email            ?? this.email,
      role:             role             ?? this.role,
      isVip:            isVip            ?? this.isVip,
      totalXp:          totalXp          ?? this.totalXp,
      weeklyXp:         weeklyXp         ?? this.weeklyXp,
      league:           league           ?? this.league,
      leagueLevel:      leagueLevel      ?? this.leagueLevel,
      energy:           energy           ?? this.energy,
      maxEnergy:        maxEnergy        ?? this.maxEnergy,
      bonusEnergy:      bonusEnergy      ?? this.bonusEnergy,
      dailyQuestions:   dailyQuestions   ?? this.dailyQuestions,
      dailyCorrect:     dailyCorrect     ?? this.dailyCorrect,
      dailySections:    dailySections    ?? this.dailySections,
      dailyAds:         dailyAds         ?? this.dailyAds,
      dailyBonusEarned: dailyBonusEarned ?? this.dailyBonusEarned,
      dailyLogin:       dailyLogin       ?? this.dailyLogin,
      weeklyCorrect:    weeklyCorrect    ?? this.weeklyCorrect,
      weeklySections:   weeklySections   ?? this.weeklySections,
      weeklyAds:        weeklyAds        ?? this.weeklyAds,
      totalBioQuestions:totalBioQuestions?? this.totalBioQuestions,
      totalCorrect:     totalCorrect     ?? this.totalCorrect,
      totalSections:    totalSections    ?? this.totalSections,
      loginStreak:      loginStreak      ?? this.loginStreak,
      avatarFrame:      avatarFrame      ?? this.avatarFrame,
      badges:           badges           ?? this.badges,
    );
  }
}