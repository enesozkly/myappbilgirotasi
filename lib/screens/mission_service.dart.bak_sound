import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'energy_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// MODELS
// ═══════════════════════════════════════════════════════════════════════════

enum MissionType { daily, weekly, achievement, oneTime }

class Mission {
  final String id;
  final String title;
  final String description;
  final String icon;
  final int targetCount;
  final int bonusEnergyReward;
  final int xpReward;
  final String trackField;
  final MissionType type;
  bool isClaimed;

  Mission({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.targetCount,
    required this.bonusEnergyReward,
    this.xpReward = 0,
    required this.trackField,
    required this.type,
    this.isClaimed = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'icon': icon,
        'targetCount': targetCount,
        'bonusEnergyReward': bonusEnergyReward,
        'xpReward': xpReward,
        'trackField': trackField,
        'type': type.name,
        'isClaimed': isClaimed,
      };

  factory Mission.fromMap(Map<String, dynamic> map) => Mission(
        id: map['id'] ?? '',
        title: map['title'] ?? '',
        description: map['description'] ?? '',
        icon: map['icon'] ?? '🎯',
        targetCount: (map['targetCount'] ?? 1).toInt(),
        bonusEnergyReward: (map['bonusEnergyReward'] ?? 0).toInt(),
        xpReward: (map['xpReward'] ?? 0).toInt(),
        trackField: map['trackField'] ?? 'dailyQuestions',
        type: MissionType.values.firstWhere(
          (t) => t.name == map['type'],
          orElse: () => MissionType.daily,
        ),
        isClaimed: map['isClaimed'] ?? false,
      );
}

class AchievementMission extends Mission {
  final String? badge;
  final String? avatarFrame;
  final String? specialIcon;

  AchievementMission({
    required super.id,
    required super.title,
    required super.description,
    required super.icon,
    required super.targetCount,
    required super.bonusEnergyReward,
    super.xpReward = 0,
    required super.trackField,
    required super.type,
    super.isClaimed,
    this.badge,
    this.avatarFrame,
    this.specialIcon,
  });

  factory AchievementMission.fromMap(Map<String, dynamic> map) =>
      AchievementMission(
        id: map['id'] ?? '',
        title: map['title'] ?? '',
        description: map['description'] ?? '',
        icon: map['icon'] ?? '🏅',
        targetCount: (map['targetCount'] ?? 1).toInt(),
        bonusEnergyReward: (map['bonusEnergyReward'] ?? 0).toInt(),
        xpReward: (map['xpReward'] ?? 0).toInt(),
        trackField: map['trackField'] ?? 'totalSections',
        type: MissionType.achievement,
        isClaimed: map['isClaimed'] ?? false,
        badge: map['badge'],
        avatarFrame: map['avatarFrame'],
        specialIcon: map['specialIcon'],
      );
}

class OneTimeMission extends Mission {
  final bool manualClaim;

  OneTimeMission({
    required super.id,
    required super.title,
    required super.description,
    required super.icon,
    required super.targetCount,
    required super.bonusEnergyReward,
    super.xpReward = 0,
    required super.trackField,
    required super.type,
    super.isClaimed,
    this.manualClaim = false,
  });

  factory OneTimeMission.fromMap(Map<String, dynamic> map) => OneTimeMission(
        id: map['id'] ?? '',
        title: map['title'] ?? '',
        description: map['description'] ?? '',
        icon: map['icon'] ?? '🎯',
        targetCount: (map['targetCount'] ?? 1).toInt(),
        bonusEnergyReward: (map['bonusEnergyReward'] ?? 0).toInt(),
        xpReward: (map['xpReward'] ?? 0).toInt(),
        trackField: map['trackField'] ?? 'totalSections',
        type: MissionType.oneTime,
        isClaimed: map['isClaimed'] ?? false,
        manualClaim: map['manualClaim'] ?? false,
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// SERVICE
// ═══════════════════════════════════════════════════════════════════════════

class MissionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final EnergyService _energy = EnergyService();

  String _todayKey() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 3));
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _weekKey() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 3));
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
  }

  // ══════════════════════════════════════════════════════════════════════
  // GÜNLÜK GÖREV HAVUZU
  // Sabit liste: yapay/rasgele görev yok. Reklamla ilgili tek görev 3 reklamdır.
  // Toplam bonus enerji: 15 (2 + 3 + 2 + 3 + 5), cüzdan üst limiti 20'dir.
  // ══════════════════════════════════════════════════════════════════════
  static const List<Map<String, dynamic>> _dailyMissionsPool = [
    {
      'id': 'daily_s_1',
      'title': '1 Bölüm Bitir',
      'description': 'Herhangi bir dersten 1 bölüm tamamla',
      'icon': '🏁',
      'targetCount': 1,
      'bonusEnergyReward': 2,
      'xpReward': 40,
      'trackField': 'dailySections',
      'type': 'daily',
    },
    {
      'id': 'daily_s_2',
      'title': '2 Bölüm Bitir',
      'description': 'Bugün 2 farklı bölüm tamamla',
      'icon': '🚀',
      'targetCount': 2,
      'bonusEnergyReward': 3,
      'xpReward': 80,
      'trackField': 'dailySections',
      'type': 'daily',
    },
    {
      'id': 'daily_c_10',
      'title': '10 Doğru Cevap',
      'description': 'Bugün en az 10 soruyu doğru bil',
      'icon': '✅',
      'targetCount': 10,
      'bonusEnergyReward': 2,
      'xpReward': 50,
      'trackField': 'dailyCorrect',
      'type': 'daily',
    },
    {
      'id': 'daily_c_20',
      'title': '20 Doğru Cevap',
      'description': 'Bugün 20 soruyu doğru bil',
      'icon': '🎯',
      'targetCount': 20,
      'bonusEnergyReward': 3,
      'xpReward': 80,
      'trackField': 'dailyCorrect',
      'type': 'daily',
    },
    {
      'id': 'daily_ads_3',
      'title': '3 Reklam İzle',
      'description': 'Bugün 3 kez ödüllü reklam izle',
      'icon': '📺',
      'targetCount': 3,
      'bonusEnergyReward': 5,
      'xpReward': 50,
      'trackField': 'dailyAds',
      'type': 'daily',
    },
  ];

  List<Map<String, dynamic>> _canonicalDailyMissions(List<dynamic> existing) {
    final Map<String, Map<String, dynamic>> byId = {};
    for (final item in existing) {
      if (item is Map<String, dynamic>) {
        final id = item['id']?.toString();
        if (id != null) byId[id] = item;
      } else if (item is Map) {
        final converted = Map<String, dynamic>.from(item);
        final id = converted['id']?.toString();
        if (id != null) byId[id] = converted;
      }
    }

    return _dailyMissionsPool.map((mission) {
      final old = byId[mission['id']];
      return {
        ...mission,
        'isClaimed': old?['isClaimed'] == true,
      };
    }).toList();
  }

  bool _needsDailyMissionMigration(
    List<dynamic> existing,
    List<Map<String, dynamic>> canonical,
  ) {
    if (existing.length != canonical.length) return true;
    for (var i = 0; i < canonical.length; i++) {
      final raw = existing[i];
      final item = raw is Map<String, dynamic>
          ? raw
          : raw is Map
              ? Map<String, dynamic>.from(raw)
              : <String, dynamic>{};
      final expected = canonical[i];
      for (final key in [
        'id',
        'title',
        'targetCount',
        'bonusEnergyReward',
        'trackField',
        'type',
      ]) {
        if (item[key] != expected[key]) return true;
      }
    }
    return false;
  }

  Future<List<Mission>> getDailyMissions(String uid) async {
    final dateKey = _todayKey();
    final ref = _db
        .collection('users')
        .doc(uid)
        .collection('daily_missions')
        .doc(dateKey);

    try {
      final doc = await ref.get();

      if (!doc.exists) {
        await _resetDailyCounters(uid);

        final missions = _dailyMissionsPool
            .map((m) => {...m, 'isClaimed': false})
            .toList();

        await ref.set({
          'date': dateKey,
          'missions': missions,
          'createdAt': FieldValue.serverTimestamp(),
        });
        return missions.map((m) => Mission.fromMap(m)).toList();
      }

      final raw = (doc.data()!['missions'] as List<dynamic>? ?? []);
      final missions = _canonicalDailyMissions(raw);
      if (_needsDailyMissionMigration(raw, missions)) {
        await ref.update({'missions': missions});
      }
      return missions.map((m) => Mission.fromMap(m)).toList();
    } catch (e) {
      debugPrint('getDailyMissions error: $e');
      return [];
    }
  }

  Future<bool> claimDailyMission(String uid, Mission mission) async {
    return _claimMission(
      uid: uid,
      mission: mission,
      docPath: 'users/$uid/daily_missions/${_todayKey()}',
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // HAFTALIK GÖREVLER
  // Müşteri isteği: 30 / 50 gibi yüksek bonuslar yerine haftalık görevler
  // maksimum 10 bonus enerji verir.
  // Eski Firestore haftalık görevleri varsa otomatik bu listeye migrate edilir.
  // ══════════════════════════════════════════════════════════════════════
  static const List<Map<String, dynamic>> _weeklyMissions = [
    {
      'id': 'weekly_correct_100',
      'title': '100 Doğru Cevap',
      'description': 'Bu hafta toplamda 100 doğru yap ve istikrarını göster',
      'icon': '🎯',
      'targetCount': 100,
      'bonusEnergyReward': 10,
      'xpReward': 220,
      'trackField': 'weeklyCorrect',
      'type': 'weekly',
    },
    {
      'id': 'weekly_sections_10',
      'title': '10 Bölüm Bitir',
      'description': 'Bu hafta 10 bölüm tamamlayarak ciddi ilerleme kaydet',
      'icon': '🏁',
      'targetCount': 10,
      'bonusEnergyReward': 10,
      'xpReward': 240,
      'trackField': 'weeklySections',
      'type': 'weekly',
    },
    {
      'id': 'weekly_streak_5',
      'title': '5 Gün Seri Yap',
      'description': 'Hafta içinde en az 5 gün uygulamaya gir',
      'icon': '🔥',
      'targetCount': 5,
      'bonusEnergyReward': 10,
      'xpReward': 180,
      'trackField': 'loginStreak',
      'type': 'weekly',
    },
    {
      'id': 'weekly_ads_3',
      'title': '3 Reklam İzle',
      'description': 'Hafta içinde 3 ödüllü reklam izleyerek ekstra destek kazan',
      'icon': '📺',
      'targetCount': 3,
      'bonusEnergyReward': 10,
      'xpReward': 150,
      'trackField': 'weeklyAds',
      'type': 'weekly',
    },
  ];

  static const int weeklyAllCompletedBonus = 10;
  static const int weeklyAllCompletedXp = 250;

  List<Map<String, dynamic>> _canonicalWeeklyMissions(List<dynamic> existing) {
    final Map<String, Map<String, dynamic>> byId = {};

    for (final item in existing) {
      if (item is Map<String, dynamic>) {
        final id = item['id']?.toString();
        if (id != null) byId[id] = item;
      } else if (item is Map) {
        final converted = Map<String, dynamic>.from(item);
        final id = converted['id']?.toString();
        if (id != null) byId[id] = converted;
      }
    }

    return _weeklyMissions.map((mission) {
      final old = byId[mission['id']];

      return {
        ...mission,
        'isClaimed': old?['isClaimed'] == true,
      };
    }).toList();
  }

  bool _needsWeeklyMissionMigration(
    List<dynamic> existing,
    List<Map<String, dynamic>> canonical,
  ) {
    if (existing.length != canonical.length) return true;

    for (var i = 0; i < canonical.length; i++) {
      final raw = existing[i];

      final item = raw is Map<String, dynamic>
          ? raw
          : raw is Map
              ? Map<String, dynamic>.from(raw)
              : <String, dynamic>{};

      final expected = canonical[i];

      for (final key in [
        'id',
        'title',
        'targetCount',
        'bonusEnergyReward',
        'trackField',
        'type',
      ]) {
        if (item[key] != expected[key]) return true;
      }
    }

    return false;
  }

  Future<List<Mission>> getWeeklyMissions(String uid) async {
    final weekKey = _weekKey();
    final ref = _db
        .collection('users')
        .doc(uid)
        .collection('weekly_missions')
        .doc(weekKey);

    try {
      final doc = await ref.get();

      if (!doc.exists) {
        await _resetWeeklyCounters(uid);

        final missions = _weeklyMissions
            .map((m) => {...m, 'isClaimed': false})
            .toList();

        await ref.set({
          'weekStart': weekKey,
          'missions': missions,
          'allBonusClaimed': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        return missions.map((m) => Mission.fromMap(m)).toList();
      }

      final raw = (doc.data()!['missions'] as List<dynamic>? ?? []);
      final missions = _canonicalWeeklyMissions(raw);

      if (_needsWeeklyMissionMigration(raw, missions)) {
        await ref.update({'missions': missions});
      }

      return missions.map((m) => Mission.fromMap(m)).toList();
    } catch (e) {
      debugPrint('getWeeklyMissions error: $e');
      return [];
    }
  }

  Future<bool> claimWeeklyMission(String uid, Mission mission) async {
    final success = await _claimMission(
      uid: uid,
      mission: mission,
      docPath: 'users/$uid/weekly_missions/${_weekKey()}',
    );
    if (success) await _checkWeeklyAllBonus(uid);
    return success;
  }

  Future<void> _checkWeeklyAllBonus(String uid) async {
    final weekKey = _weekKey();
    final ref = _db
        .collection('users')
        .doc(uid)
        .collection('weekly_missions')
        .doc(weekKey);

    try {
      final doc = await ref.get();
      if (!doc.exists) return;
      final data = doc.data()!;
      if (data['allBonusClaimed'] == true) return;

      final missions = (data['missions'] as List<dynamic>? ?? []);
      final allClaimed = missions.every((m) => m['isClaimed'] == true);

      if (allClaimed) {
        await _energy.addBonusEnergy(uid, weeklyAllCompletedBonus);
        await _db.collection('users').doc(uid).update({
          'totalXp': FieldValue.increment(weeklyAllCompletedXp),
          'weeklyXp': FieldValue.increment(weeklyAllCompletedXp),
        });
        await ref.update({'allBonusClaimed': true});
      }
    } catch (e) {
      debugPrint('_checkWeeklyAllBonus error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // BAŞARIMLAR
  // ══════════════════════════════════════════════════════════════════════
  static const List<Map<String, dynamic>> _achievements = [
    {
      'id': 'achievement_level_50',
      'title': '50 Seviye',
      'description': 'Toplamda 50 bölüm tamamla',
      'icon': '⭐',
      'targetCount': 50,
      'bonusEnergyReward': 20,
      'xpReward': 1000,
      'trackField': 'totalSections',
      'type': 'achievement',
      'badge': 'level50',
    },
    {
      'id': 'achievement_level_100',
      'title': '100 Seviye',
      'description': 'Toplamda 100 bölüm tamamla',
      'icon': '🌟',
      'targetCount': 100,
      'bonusEnergyReward': 50,
      'xpReward': 2500,
      'trackField': 'totalSections',
      'type': 'achievement',
      'badge': 'level100',
      'avatarFrame': 'gold_aura',
    },
    {
      'id': 'achievement_correct_500',
      'title': '500 Doğru',
      'description': 'Toplamda 500 doğru cevap ver',
      'icon': '🎖️',
      'targetCount': 500,
      'bonusEnergyReward': 30,
      'xpReward': 1500,
      'trackField': 'totalCorrect',
      'type': 'achievement',
      'badge': 'correct500',
    },
    {
      'id': 'achievement_correct_1000',
      'title': '1000 Doğru',
      'description': 'Toplamda 1000 doğru cevap ver',
      'icon': '💎',
      'targetCount': 1000,
      'bonusEnergyReward': 60,
      'xpReward': 3000,
      'trackField': 'totalCorrect',
      'type': 'achievement',
      'badge': 'correct1000',
      'avatarFrame': 'diamond_frame',
    },
    {
      'id': 'achievement_streak_30',
      'title': '30 Gün Seri',
      'description': '30 gün üst üste giriş yap',
      'icon': '🔥',
      'targetCount': 30,
      'bonusEnergyReward': 40,
      'xpReward': 2000,
      'trackField': 'loginStreak',
      'type': 'achievement',
      'badge': 'streak30',
    },
    {
      'id': 'achievement_streak_60',
      'title': '60 Gün Seri',
      'description': '60 gün üst üste giriş yap',
      'icon': '🌋',
      'targetCount': 60,
      'bonusEnergyReward': 100,
      'xpReward': 5000,
      'trackField': 'loginStreak',
      'type': 'achievement',
      'badge': 'streak60',
      'avatarFrame': 'inferno',
    },
  ];

  Future<List<AchievementMission>> getAchievements(String uid) async {
    final ref = _db.collection('users').doc(uid).collection('achievements');

    try {
      final snapshot = await ref.get();
      final claimedIds = <String>{};
      for (final doc in snapshot.docs) {
        if (doc.data()['isClaimed'] == true) claimedIds.add(doc.id);
      }

      return _achievements.map((a) {
        final raw = Map<String, dynamic>.from(a);
        raw['isClaimed'] = claimedIds.contains(a['id']);
        return AchievementMission.fromMap(raw);
      }).toList();
    } catch (e) {
      debugPrint('getAchievements error: $e');
      return [];
    }
  }

  Future<bool> claimAchievement(
    String uid,
    AchievementMission achievement,
  ) async {
    try {
      final ref = _db
          .collection('users')
          .doc(uid)
          .collection('achievements')
          .doc(achievement.id);

      final doc = await ref.get();
      if (doc.exists && doc.data()?['isClaimed'] == true) return false;

      await ref.set({
        'isClaimed': true,
        'claimedAt': FieldValue.serverTimestamp(),
        'badge': achievement.badge,
        'avatarFrame': achievement.avatarFrame,
      });

      await _energy.addBonusEnergyUnlimited(
        uid,
        achievement.bonusEnergyReward,
      );

      if (achievement.xpReward > 0) {
        await _applyXpReward(uid, achievement.xpReward);
      }

      if (achievement.badge != null) {
        await _db.collection('users').doc(uid).update({
          'badges': FieldValue.arrayUnion([achievement.badge!]),
        });
      }
      if (achievement.avatarFrame != null) {
        await _db.collection('users').doc(uid).update({
          'avatarFrame': achievement.avatarFrame,
        });
      }

      return true;
    } catch (e) {
      debugPrint('claimAchievement error: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // TEK SEFERLİK GÖREVLER
  // ══════════════════════════════════════════════════════════════════════
  static const List<Map<String, dynamic>> _oneTimeMissions = [
    {
      'id': 'onetime_instagram_bilgirotasi',
      'title': 'Instagram: bilgirotasi.app',
      'description':
          'Instagram’da @bilgirotasi.app hesabımızı takip et ve topluluğa katıl',
      'icon': '📱',
      'targetCount': 1,
      'bonusEnergyReward': 10,
      'xpReward': 150,
      'trackField': 'instagramBilgiRotasi',
      'type': 'oneTime',
      'manualClaim': true,
    },
    {
      'id': 'onetime_instagram_sonerler',
      'title': 'Instagram: sonerlerbilisim',
      'description': 'Instagram’da @sonerlerbilisim hesabımızı takip et',
      'icon': '📱',
      'targetCount': 1,
      'bonusEnergyReward': 10,
      'xpReward': 150,
      'trackField': 'instagramSonerler',
      'type': 'oneTime',
      'manualClaim': true,
    },
    {
      'id': 'onetime_rate_app',
      'title': 'Uygulamamızı Değerlendir',
      'description': 'Uygulamamızı değerlendir ve yorumlarını bizlere bildir',
      'icon': '⭐',
      'targetCount': 1,
      'bonusEnergyReward': 10,
      'xpReward': 200,
      'trackField': 'ratedApp',
      'type': 'oneTime',
      'manualClaim': true,
    },
  ];

  Future<List<OneTimeMission>> getOneTimeMissions(String uid) async {
    final ref =
        _db.collection('users').doc(uid).collection('onetime_missions');

    try {
      final snapshot = await ref.get();
      final claimedIds = <String>{};
      for (final doc in snapshot.docs) {
        if (doc.data()['isClaimed'] == true) claimedIds.add(doc.id);
      }

      return _oneTimeMissions.map((m) {
        final raw = Map<String, dynamic>.from(m);
        raw['isClaimed'] = claimedIds.contains(m['id']);
        return OneTimeMission.fromMap(raw);
      }).toList();
    } catch (e) {
      debugPrint('getOneTimeMissions error: $e');
      return [];
    }
  }

  Future<bool> claimOneTimeMission(
    String uid,
    OneTimeMission mission,
  ) async {
    try {
      final ref = _db
          .collection('users')
          .doc(uid)
          .collection('onetime_missions')
          .doc(mission.id);

      final doc = await ref.get();
      if (doc.exists && doc.data()?['isClaimed'] == true) return false;

      await ref.set({
        'isClaimed': true,
        'claimedAt': FieldValue.serverTimestamp(),
      });

      await _energy.addBonusEnergyUnlimited(uid, mission.bonusEnergyReward);

      if (mission.xpReward > 0) {
        await _applyXpReward(uid, mission.xpReward);
      }

      return true;
    } catch (e) {
      debugPrint('claimOneTimeMission error: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // ORTAK CLAIM MANTIĞI
  // ══════════════════════════════════════════════════════════════════════
  Future<bool> _claimMission({
    required String uid,
    required Mission mission,
    required String docPath,
  }) async {
    try {
      final ref = _db.doc(docPath);
      final doc = await ref.get();
      if (!doc.exists) return false;

      final data = doc.data()!;
      final List<dynamic> missions = List.from(data['missions'] ?? []);
      final idx = missions.indexWhere((m) => m['id'] == mission.id);
      if (idx == -1) return false;
      if (missions[idx]['isClaimed'] == true) return false;

      missions[idx] = {...missions[idx], 'isClaimed': true};
      await ref.update({'missions': missions});

      final int energyReward = mission.bonusEnergyReward;
      if (mission.type == MissionType.daily ||
          mission.type == MissionType.weekly) {
        await _energy.addBonusEnergy(uid, energyReward);
      } else {
        await _energy.addBonusEnergyUnlimited(uid, energyReward);
      }

      final xpReward = (missions[idx]['xpReward'] ?? 0).toInt();
      if (xpReward > 0) await _applyXpReward(uid, xpReward);

      return true;
    } catch (e) {
      debugPrint('_claimMission error: $e');
      return false;
    }
  }

  Future<void> _applyXpReward(String uid, int xpReward) async {
    final userRef = _db.collection('users').doc(uid);
    final userDoc = await userRef.get();

    final currentXp = (userDoc.data()?['totalXp'] ?? 0).toInt();
    final newXp = currentXp + xpReward;

    String league = 'Bronz';
    int leagueLevel = 1;
    if (newXp >= 20000) {
      league = 'Efsane';
      leagueLevel = 7;
    } else if (newXp >= 12000) {
      league = 'Şampiyon';
      leagueLevel = 6;
    } else if (newXp >= 7000) {
      league = 'Elmas';
      leagueLevel = 5;
    } else if (newXp >= 3500) {
      league = 'Platin';
      leagueLevel = 4;
    } else if (newXp >= 1500) {
      league = 'Altın';
      leagueLevel = 3;
    } else if (newXp >= 500) {
      league = 'Gümüş';
      leagueLevel = 2;
    }

    await userRef.update({
      'totalXp': newXp,
      'weeklyXp': FieldValue.increment(xpReward),
      'league': league,
      'leagueLevel': leagueLevel,
    });
  }

  Future<void> _resetDailyCounters(String uid) async {
    try {
      await _db.collection('users').doc(uid).set({
        'dailyQuestions': 0,
        'dailyCorrect': 0,
        'dailySections': 0,
        'dailyAds': 0,
        'dailyBonusEarned': 0,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('_resetDailyCounters error: $e');
    }
  }

  Future<void> _resetWeeklyCounters(String uid) async {
    try {
      await _db.collection('users').doc(uid).set({
        'weeklyCorrect': 0,
        'weeklySections': 0,
        'weeklyAds': 0,
        'weeklyQuestions': 0,
        'weeklyXp': 0,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('_resetWeeklyCounters error: $e');
    }
  }

  Future<void> recordDailyLogin(String uid) async {
    final dateKey = _todayKey();
    final loginRef =
        _db.collection('users').doc(uid).collection('daily_logins').doc(dateKey);

    try {
      final doc = await loginRef.get();
      if (doc.exists) return;

      await loginRef.set({'date': dateKey, 'loggedIn': true});

      final yesterday = DateTime.now()
          .toUtc()
          .add(const Duration(hours: 3))
          .subtract(const Duration(days: 1));
      final yKey =
          '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
      final yDoc = await _db
          .collection('users')
          .doc(uid)
          .collection('daily_logins')
          .doc(yKey)
          .get();

      final userDoc = await _db.collection('users').doc(uid).get();
      int currentStreak = (userDoc.data()?['loginStreak'] ?? 0).toInt();
      int newStreak = yDoc.exists ? currentStreak + 1 : 1;

      await _db.collection('users').doc(uid).set({
        'dailyLogin': 1,
        'loginStreak': newStreak,
        'lastLoginDate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('recordDailyLogin error: $e');
    }
  }
}