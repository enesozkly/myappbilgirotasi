import 'package:flutter/foundation.dart';

/// Reklamlar tamamen kaldırılmıştır.
///
/// Eski çağrılar uygulamayı bozmasın diye metot imzaları korunur. Bu servis
/// hiçbir reklam SDK'sı başlatmaz, yüklemez veya göstermez.
class ReklamServisi {
  static void init({bool isVip = false}) {}

  static void preloadInterstitial({
    bool showAfterLoad = false,
    bool isVip = false,
  }) {}

  static void gecisReklamiGoster(bool isVip) {}

  static void bolumTamamlandi(bool isVip) {}

  static void denemeTamamlandi(bool isVip) {}

  static Future<bool> preloadRewarded() async {
    return true;
  }

  static void odulluReklamGoster(
    bool isVip,
    VoidCallback onReward,
  ) {
    onReward();
  }

  static Future<bool> reklamIzletFuture({String? uid}) async {
    return true;
  }

  static void dispose() {}
}
