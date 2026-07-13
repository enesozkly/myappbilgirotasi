/// Enerji sistemi kaldırılmıştır.
///
/// Bu sınıf eski ekran ve servis çağrılarının derlenmeye devam etmesi için
/// uyumluluk katmanı olarak tutulur. Hiçbir kullanıcıdan enerji düşmez.
class EnergyService {
  static const int maxMainEnergy = 0;
  static const int energyPerLevel = 0;
  static const int regenAmount = 0;
  static const int regenIntervalHours = 0;
  static const int maxDailyAdCount = 0;
  static const int adEnergyReward = 0;
  static const int maxDailyBonusFromMissions = 0;
  static const int maxBonusEnergyWallet = 0;
  static const int defaultMaxMainEnergy = 0;

  static const int vipMaxMainEnergy = 0;
  static const int vipRegenAmount = 0;
  static const int vipRegenIntervalHours = 0;
  static const int vipAdEnergyReward = 0;
  static const int vipMaxDailyBonusFromMissions = 0;
  static const int vipMaxBonusEnergyWallet = 0;

  Future<void> normalizeEnergy(String uid) async {}

  Future<bool> spendEnergy(
    String uid, {
    int amount = energyPerLevel,
  }) async {
    return true;
  }

  Future<void> addBonusEnergy(String uid, int amount) async {}

  Future<void> addBonusEnergyUnlimited(String uid, int amount) async {}

  Future<int> minutesUntilNextRegen(String uid) async {
    return 0;
  }

  Future<int> addAdEnergy(String uid) async {
    return 0;
  }

  Future<void> regenEnergy(String uid) async {}

  Future<void> checkAndRegenEnergy(String uid) async {}
}
