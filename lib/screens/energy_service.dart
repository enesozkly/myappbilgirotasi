import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Enerji Kuralları:
/// - Ana enerji: maks 50 (VIP: 100), her 2 saatte +5 yenilenir
/// - VIP: her 1 saatte +5 yenilenir (2x hız) ve her yenilemede +10 (2x miktar)
/// - 1 seviye tamamlama = 5 ana enerji harcama
/// - Günde 3 reklam → her biri +5 bonus enerji (VIP: +10)
/// - Bonus enerji ana limite takılmaz ama cüzdan limiti vardır
/// - Bonus enerji cüzdan limiti: tüm kullanıcılar için 20
/// - Görev ödülleri eklenirken bu limit aşılmaz
/// - Harcama sırası: önce bonus enerji, sonra ana enerji
class EnergyService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Normal kullanıcı sabitleri
  static const int maxMainEnergy              = 50;
  static const int energyPerLevel             = 5;
  static const int regenAmount                = 5;
  static const int regenIntervalHours         = 2;
  static const int maxDailyAdCount            = 3;
  static const int adEnergyReward             = 5;
  static const int maxDailyBonusFromMissions  = 20;
  static const int maxBonusEnergyWallet       = 20;
  static const int defaultMaxMainEnergy       = 50;

  // VIP sabitleri (2x)
  static const int vipMaxMainEnergy              = 100;
  static const int vipRegenAmount                = 10;
  static const int vipRegenIntervalHours         = 1;
  static const int vipAdEnergyReward             = 10;
  static const int vipMaxDailyBonusFromMissions  = 20;
  static const int vipMaxBonusEnergyWallet       = 20;


  int _bonusWalletCap(bool isVip) =>
      isVip ? vipMaxBonusEnergyWallet : maxBonusEnergyWallet;

  /// Eski sürümlerde biriken 55/75 gibi bonusları güvenli limite çeker.
  /// Tüm kullanıcılar için bonus cüzdan limiti 20 bonus enerjidir.
  Future<void> normalizeEnergy(String uid) async {
    try {
      final ref = _db.collection('users').doc(uid);
      final doc = await ref.get();
      if (!doc.exists) return;
      final data = doc.data()!;
      final bool isVip = data['isVip'] == true;
      final int maxMain = (data['maxEnergy'] ?? (isVip ? vipMaxMainEnergy : maxMainEnergy)) as int;
      final int energy = ((data['energy'] ?? 0) as int).clamp(0, maxMain).toInt();
      final int bonusCap = _bonusWalletCap(isVip);
      final int bonus = ((data['bonusEnergy'] ?? 0) as int).clamp(0, bonusCap).toInt();
      final int dailyCap = isVip ? vipMaxDailyBonusFromMissions : maxDailyBonusFromMissions;
      final int dailyBonus = ((data['dailyBonusEarned'] ?? 0) as int).clamp(0, dailyCap).toInt();

      final updates = <String, dynamic>{};
      if (energy != (data['energy'] ?? 0)) updates['energy'] = energy;
      if (bonus != (data['bonusEnergy'] ?? 0)) updates['bonusEnergy'] = bonus;
      if (dailyBonus != (data['dailyBonusEarned'] ?? 0)) {
        updates['dailyBonusEarned'] = dailyBonus;
      }
      if (updates.isNotEmpty) await ref.update(updates);
    } catch (e) {
      debugPrint('Enerji normalize hatası: $e');
    }
  }

  // ── Sessiz Analiz Takip ────────────────────────────────────────────────────
  Future<void> _logAnalytics(String uid, String eventName) async {
    try {
      await _db.collection('analytics_logs').add({
        'uid':       uid,
        'event':     eventName,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Analytics log hatası (Önemsiz): $e');
    }
  }

  // ── Enerji Harca ──────────────────────────────────────────────────────────
  /// Test/deneme başlarken çağrılır. Önce bonus enerji, sonra ana enerji tükenir.
  /// Yeterli enerji yoksa false döner.
  Future<bool> spendEnergy(String uid, {int amount = energyPerLevel}) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return false;

      final data        = doc.data()!;
      int mainEnergy    = data['energy']      ?? 0;
      int bonusEnergy   = data['bonusEnergy'] ?? 0;

      if (mainEnergy + bonusEnergy < amount) {
        await _logAnalytics(uid, 'energy_depleted');
        return false;
      }

      // Kullanıcının kazandığı bonus enerji ekranda net azalsın diye
      // harcamada önce bonus enerji kullanılır. Bonus yetmezse kalan tutar
      // ana enerjiden düşer.
      if (bonusEnergy >= amount) {
        bonusEnergy -= amount;
      } else {
        final int remainder = amount - bonusEnergy;
        bonusEnergy = 0;
        mainEnergy -= remainder;
      }

      if (mainEnergy + bonusEnergy < energyPerLevel) {
        await _logAnalytics(uid, 'energy_depleted');
      }

      await _db.collection('users').doc(uid).update({
        'energy':      mainEnergy,
        'bonusEnergy': bonusEnergy,
      });

      return true;
    } catch (e) {
      debugPrint('Enerji harcanırken hata: $e');
      return false;
    }
  }

  // ── Bonus Enerji Ekleme (Görevlerden) — VIP'e x2 limit ─────────────────
  Future<void> addBonusEnergy(String uid, int amount) async {
    if (amount <= 0) return;
    try {
      final ref = _db.collection('users').doc(uid);
      final doc = await ref.get();
      if (!doc.exists) return;

      final data       = doc.data()!;
      final bool isVip = data['isVip'] == true;
      final int dailyLimit = isVip ? vipMaxDailyBonusFromMissions : maxDailyBonusFromMissions;
      final int dailyBonusEarned = (data['dailyBonusEarned'] ?? 0) as int;
      final int currentBonus = (data['bonusEnergy'] ?? 0) as int;
      final int walletCap = _bonusWalletCap(isVip);

      if (dailyBonusEarned >= dailyLimit || currentBonus >= walletCap) {
        await normalizeEnergy(uid);
        return;
      }

      final int byDailyLimit = dailyLimit - dailyBonusEarned;
      final int byWalletLimit = walletCap - currentBonus;
      final int actualAdd = amount.clamp(0, byDailyLimit).clamp(0, byWalletLimit).toInt();
      if (actualAdd <= 0) return;

      await ref.update({
        'bonusEnergy':      currentBonus + actualAdd,
        'dailyBonusEarned': FieldValue.increment(actualAdd),
      });
    } catch (e) {
      debugPrint('Bonus enerji eklenirken hata: $e');
    }
  }

  // ── Sınırsız Bonus Enerji (Başarım / Tek Seferlik Ödüller) ───────────────
  Future<void> addBonusEnergyUnlimited(String uid, int amount) async {
    if (amount <= 0) return;
    try {
      final ref = _db.collection('users').doc(uid);
      final doc = await ref.get();
      if (!doc.exists) return;
      final data = doc.data()!;
      final bool isVip = data['isVip'] == true;
      final int currentBonus = (data['bonusEnergy'] ?? 0) as int;
      final int cap = _bonusWalletCap(isVip);
      final int actualAdd = amount.clamp(0, cap - currentBonus).toInt();
      if (actualAdd <= 0) {
        await normalizeEnergy(uid);
        return;
      }
      await ref.update({'bonusEnergy': currentBonus + actualAdd});
      debugPrint('Bonus enerji: +$actualAdd eklendi (limit: $cap).');
    } catch (e) {
      debugPrint('Bonus enerji eklenirken hata: $e');
    }
  }

  // ── Bir Sonraki Yenilenmeye Kaç Dakika ────────────────────────────────────
  Future<int> minutesUntilNextRegen(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return regenIntervalHours * 60;
      final data       = doc.data()!;
      final bool isVip = data['isVip'] == true;
      final int interval = isVip ? vipRegenIntervalHours : regenIntervalHours;

      final lastRegenRaw = data['lastEnergyRegen'];
      if (lastRegenRaw == null) return 0;

      final lastRegen  = (lastRegenRaw as Timestamp).toDate();
      final next       = lastRegen.add(Duration(hours: interval));
      final remaining  = next.difference(DateTime.now()).inMinutes;
      return remaining.clamp(0, interval * 60);
    } catch (e) {
      return regenIntervalHours * 60;
    }
  }

  // ── Reklam Ödülü Olarak Enerji — VIP'e x2 ─────────────────────────────────
  Future<void> addAdEnergy(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return;

      final data       = doc.data()!;
      final bool isVip = data['isVip'] == true;
      final int dailyAds = (data['dailyAds'] ?? 0) as int;
      final int reward   = isVip ? vipAdEnergyReward : adEnergyReward;

      if (dailyAds < maxDailyAdCount) {
        final int currentBonus = (data['bonusEnergy'] ?? 0) as int;
        final int cap = _bonusWalletCap(isVip);
        final int actualReward = reward.clamp(0, cap - currentBonus).toInt();
        await _db.collection('users').doc(uid).update({
          'bonusEnergy': currentBonus + actualReward,
          'dailyAds':    FieldValue.increment(1),
          'weeklyAds':   FieldValue.increment(1),
        });
      }
    } catch (e) {
      debugPrint('Reklam enerjisi eklenirken hata: $e');
    }
  }

  // ── Enerji Yenileme (Zamana Bağlı) — VIP'e x2 hız ve x2 miktar ──────────
  Future<void> regenEnergy(String uid) => checkAndRegenEnergy(uid);

  Future<void> checkAndRegenEnergy(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return;

      final data       = doc.data()!;
      final bool isVip = data['isVip'] == true;

      final int currentEnergy   = (data['energy']    ?? 0) as int;
      final int maxEnergy       = (data['maxEnergy'] ?? (isVip ? vipMaxMainEnergy : defaultMaxMainEnergy)) as int;
      final int intervalHours   = isVip ? vipRegenIntervalHours : regenIntervalHours;
      final int amount          = isVip ? vipRegenAmount        : regenAmount;

      if (currentEnergy >= maxEnergy) return;

      final Timestamp? lastRegenTs = data['lastEnergyRegen'] as Timestamp?;
      if (lastRegenTs == null) {
        await _db.collection('users').doc(uid).update({
          'lastEnergyRegen': FieldValue.serverTimestamp(),
        });
        return;
      }

      final lastRegen = lastRegenTs.toDate();
      final now       = DateTime.now();
      final diffHours = now.difference(lastRegen).inHours;

      if (diffHours >= intervalHours) {
        final int regenCycles  = diffHours ~/ intervalHours;
        final int addedEnergy  = regenCycles * amount;
        final int newEnergy    = (currentEnergy + addedEnergy).clamp(0, maxEnergy).toInt();
        final newRegenTime     = lastRegen.add(Duration(hours: regenCycles * intervalHours));

        await _db.collection('users').doc(uid).update({
          'energy':          newEnergy,
          'lastEnergyRegen': Timestamp.fromDate(newRegenTime),
        });
        debugPrint('Enerji yenilendi: +${regenCycles * amount} → $newEnergy (VIP: $isVip)');
      }
    } catch (e) {
      debugPrint('Enerji yenilenirken hata: $e');
    }
  }
}