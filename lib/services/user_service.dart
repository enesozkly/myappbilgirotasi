import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Merkezi Lig Hesaplama (static — mission_service de kullanır) ──────────
  static Map<String, dynamic> getLeagueInfo(int totalXp) {
    if (totalXp >= 20000) {
      return {'league': 'Efsane', 'leagueLevel': 7};
    } else if (totalXp >= 12000) {
      return {'league': 'Şampiyon', 'leagueLevel': 6};
    } else if (totalXp >= 7000) {
      return {'league': 'Elmas', 'leagueLevel': 5};
    } else if (totalXp >= 3500) {
      return {'league': 'Platin', 'leagueLevel': 4};
    } else if (totalXp >= 1500) {
      return {'league': 'Altın', 'leagueLevel': 3};
    } else if (totalXp >= 500) {
      return {'league': 'Gümüş', 'leagueLevel': 2};
    } else {
      return {'league': 'Bronz', 'leagueLevel': 1};
    }
  }

  // ── 1. Yeni Kullanıcı Oluştur ─────────────────────────────────────────────
  Future<void> createUserProfile(String uid, String name, String email) async {
    try {
      final userRef = _db.collection('users').doc(uid);
      final doc     = await userRef.get();

      if (!doc.exists) {
        await userRef.set({
          'uid':   uid,
          'name':  name,
          'email': email,
          'role':  'student',
          'isVip': false,
          'totalXp':    0,
          'weeklyXp':   0,
          'league':     'Bronz',
          'leagueLevel': 1,
          // Enerji
          'energy':      50,
          'maxEnergy':   50,
          'bonusEnergy': 0,
          // Günlük
          'dailyQuestions':   0,
          'dailyCorrect':     0,
          'dailySections':    0,
          'dailyAds':         0,
          'dailyBonusEarned': 0,
          'dailyLogin':       0,
          // Haftalık
          'weeklyCorrect':  0,
          'weeklySections': 0,
          'weeklyAds':      0,
          // Toplam
          'totalBioQuestions': 0,
          'totalCorrect':      0,
          'totalSections':     0,
          // Streak
          'loginStreak': 0,
          'createdAt':   FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Profil oluşturma hatası: $e');
    }
  }

  // ── 2. VIP Yap ────────────────────────────────────────────────────────────
  /// VIP Paketi — "Sınav Kazandıran Paket":
  /// • 2 Kat Enerji kapasitesi (100)
  /// • 2 Kat Enerji Yenileme Hızı (energy_service'de yönetilir — 1 saatte bir)
  /// • 2 Kat Enerji Yenileme Miktarı (energy_service'de — +10 per cycle)
  /// • Görevlerden bonus enerji kazanımı (bonus cüzdan limiti 20)
  /// • Yanlış Kutusu Limit Artışı 50 soru (mistake_box_page'de _isVip ile)
  /// • Reklamsız Uygulama (reklam_servisi VIP kontrolü)
  /// • Sıralamada VIP Rozet (leaderboard_page, profile_page)
  /// • Haftalık Zayıf Konu Analizi — 4 hak/ay (Firestore vipWeakTopicRights)
  /// • Kişisel Test Talebi — 1 hak/ay (vipTestRights)
  /// • 1 Konu Anlatım PDF — 24 saat içinde mail (vipPdfRights)
  Future<void> makeUserVip(String uid) async {
    try {
      await _db.collection('users').doc(uid).update({
        'isVip':    true,
        'maxEnergy': 100,
        'energy':    100,
        // VIP aylık haklar
        'vipWeakTopicRights': 4,  // Haftalık Zayıf Konu Analizi (aylık 4)
        'vipTestRights':      1,  // Kişisel Test Talebi (aylık 1)
        'vipPdfRights':       1,  // Konu Anlatım PDF (aylık 1)
        'vipRightsMonth':     '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}',
        'vipActivatedAt':     FieldValue.serverTimestamp(),
        'vipExpiresAt':       Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
      });
    } catch (e) {
      debugPrint('VIP yapma hatası: $e');
    }
  }

  // ── 3. VIP İptal ──────────────────────────────────────────────────────────
  Future<void> removeUserVip(String uid) async {
    try {
      await _db.collection('users').doc(uid).update({
        'isVip':    false,
        'maxEnergy': 50,
        'energy':    50,
        // Hakları sıfırla
        'vipWeakTopicRights': 0,
        'vipTestRights':      0,
        'vipPdfRights':       0,
        'vipExpiresAt':       null,
      });
    } catch (e) {
      debugPrint('VIP iptal hatası: $e');
    }
  }

  // ── 4. Ana enerji kazan (maxEnergy sınırını aşmaz) ───────────────────────
  Future<void> gainEnergy(String uid, int amount) async {
    try {
      final doc  = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return;
      final data = doc.data() as Map<String, dynamic>;

      final int currentEnergy = (data['energy']    ?? 0).toInt();
      final int maxEnergy     = (data['maxEnergy'] ?? 50).toInt();
      final int newEnergy     = (currentEnergy + amount).clamp(0, maxEnergy).toInt();

      await _db.collection('users').doc(uid).update({'energy': newEnergy});
    } catch (e) {
      debugPrint('Enerji kazanılırken hata: $e');
    }
  }

  // ── 5. Bölüm İlerlemesini Kaydet ─────────────────────────────────────────
  Future<void> saveSectionProgress({
    required String uid,
    required String subjectName,
    required String topicName,
    required int sectionNumber,
    required int stars,
  }) async {
    try {
      final String sectionId =
          '${subjectName}_${topicName}_$sectionNumber'.replaceAll(' ', '_');

      await _db
          .collection('users')
          .doc(uid)
          .collection('progress')
          .doc(sectionId)
          .set({
        'subject':     subjectName,
        'topic':       topicName,
        'section':     sectionNumber,
        'stars':       stars,
        'completedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final String topicDocId =
          '${subjectName}_$topicName'.replaceAll(' ', '_');
      final topicDoc = await _db
          .collection('users')
          .doc(uid)
          .collection('progress')
          .doc(topicDocId)
          .get();

      final int storedCurrent =
          topicDoc.exists
              ? (topicDoc.data()?['currentSection'] ?? 1).toInt()
              : 1;

      if (sectionNumber >= storedCurrent) {
        await _db
            .collection('users')
            .doc(uid)
            .collection('progress')
            .doc(topicDocId)
            .set({
          'currentSection': sectionNumber + 1,
          'subject':       subjectName,
          'topic':         topicName,
          'lastUpdated':   FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await _db.collection('users').doc(uid).update({
        'totalSections':  FieldValue.increment(1),
        'dailySections':  FieldValue.increment(1),
        'weeklySections': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('Bölüm kaydedilirken hata: $e');
    }
  }

  // ── 6. Konu bazlı doğru/yanlış istatistiği ───────────────────────────────
  Future<void> saveSubjectStats(
    String uid,
    String dersAdi,
    String konuAdi, {
    int dogru  = 0,
    int yanlis = 0,
  }) async {
    if (dogru == 0 && yanlis == 0) return;
    try {
      final docId = '${dersAdi}_$konuAdi'
          .replaceAll(' ', '_')
          .replaceAll('/', '-');
      await _db
          .collection('users')
          .doc(uid)
          .collection('konu_istatistik')
          .doc(docId)
          .set({
        'ders':          dersAdi,
        'konu':          konuAdi,
        'dogru':         FieldValue.increment(dogru),
        'yanlis':        FieldValue.increment(yanlis),
        'sonGuncelleme': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Konu istatistik hatası: $e');
    }
  }

  // ── 7. Yıldıza göre XP ve istatistik güncelle ────────────────────────────
  Future<void> updateStats(
    String uid,
    bool hasCorrect, {
    int correctCount = 0,
    int earnedStars  = 0,
  }) async {
    try {
      final int xpAmount = earnedStars == 3
          ? 50
          : earnedStars == 2
              ? 30
              : earnedStars == 1
                  ? 10
                  : 5;

      final userRef = _db.collection('users').doc(uid);
      final doc     = await userRef.get();
      final data    = doc.data() ?? <String, dynamic>{};
      final int currentTotalXp = (data['totalXp'] ?? 0).toInt();
      final int newTotalXp     = currentTotalXp + xpAmount;

      final leagueInfo = UserService.getLeagueInfo(newTotalXp);

      final Map<String, dynamic> updates = {
        'totalXp':    newTotalXp,
        'weeklyXp':   FieldValue.increment(xpAmount),
        'league':     leagueInfo['league'],
        'leagueLevel': leagueInfo['leagueLevel'],
      };

      if (correctCount > 0) {
        updates['totalCorrect']  = FieldValue.increment(correctCount);
        updates['dailyCorrect']  = FieldValue.increment(correctCount);
        updates['weeklyCorrect'] = FieldValue.increment(correctCount);
      }

      await userRef.update(updates);
    } catch (e) {
      debugPrint('XP güncellenirken hata: $e');
    }
  }

  // ── 8. Görev ilerleme sayaçlarını güncelle ────────────────────────────────
  Future<void> updateTaskProgress(
    String uid,
    int questionCount,
    String subject,
  ) async {
    try {
      final Map<String, dynamic> updates = {
        'dailyQuestions': FieldValue.increment(questionCount),
        'weeklyQuestions': FieldValue.increment(questionCount),
      };
      if (subject == 'Biyoloji' || subject.contains('Biyoloji')) {
        updates['totalBioQuestions'] = FieldValue.increment(questionCount);
      }
      await _db.collection('users').doc(uid).update(updates);
    } catch (e) {
      debugPrint('Görev güncellenirken hata: $e');
    }
  }

  // ── 9. XP Ödülü Al (geriye dönük uyumluluk) ──────────────────────────────
  Future<void> claimXpReward(String uid, int xpAmount, String taskField) async {
    try {
      final userRef = _db.collection('users').doc(uid);
      final doc     = await userRef.get();
      final data    = doc.data() ?? <String, dynamic>{};
      final int currentTotalXp = (data['totalXp'] ?? 0).toInt();
      final int newTotalXp     = currentTotalXp + xpAmount;

      final leagueInfo = UserService.getLeagueInfo(newTotalXp);

      await userRef.update({
        'totalXp':    newTotalXp,
        'weeklyXp':   FieldValue.increment(xpAmount),
        'league':     leagueInfo['league'],
        'leagueLevel': leagueInfo['leagueLevel'],
        taskField:    0,
      });
    } catch (e) {
      debugPrint('Ödül alınırken hata: $e');
    }
  }
}