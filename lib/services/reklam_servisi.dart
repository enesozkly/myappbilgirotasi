import 'dart:async';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/material.dart';

/// Reklam Servisi
///
/// TEST ID'lerini production'a almak için sadece
/// [_gecisId] ve [_odulluId] sabitlerini değiştir.
/// Diğer hiçbir yere dokunmana gerek yok.
class ReklamServisi {
  // ── Reklam ID'leri — tek yerden yönetilir ────────────────────────────
  /// Google tarafından sağlanan test geçiş reklamı ID'si.
  /// Production'da kendi AdMob birim ID'nle değiştir.
  static const String _gecisId =
      'ca-app-pub-3940256099942544/1033173712';

  /// Google tarafından sağlanan test ödüllü reklam ID'si.
  /// Production'da kendi AdMob birim ID'nle değiştir.
  static const String _odulluId =
      'ca-app-pub-3940256099942544/5224354917';

  // ── Bölüm sayacı — her 4 bölümde bir geçiş reklamı ──────────────────
  static int _bolumSayaci = 0;

  // Aynı dokunuş / reklam kapanışından sonra yeniden yüklemeyi engeller.
  // Özellikle ödüllü reklam kapatma çarpısına basınca alttaki butona
  // yanlışlıkla ikinci kez basılmış gibi davranmasını önler.
  static bool _interstitialLoading = false;
  static bool _rewardedLoading = false;
  static DateTime? _lastRewardClosedAt;

  static bool get _rewardCooldownActive {
    final last = _lastRewardClosedAt;
    if (last == null) return false;
    return DateTime.now().difference(last).inMilliseconds < 900;
  }

  // ── Geçiş Reklamı ─────────────────────────────────────────────────────
  /// VIP kullanıcılara reklam gösterilmez.
  static void gecisReklamiGoster(bool isVip) {
    if (isVip || _interstitialLoading) return;
    _interstitialLoading = true;

    InterstitialAd.load(
      adUnitId: _gecisId,
      request:  const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('Geçiş reklamı gösterilemedi: $error');
              ad.dispose();
              _interstitialLoading = false;
            },
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialLoading = false;
            },
          );
          ad.show();
        },
        onAdFailedToLoad: (error) {
          debugPrint('Geçiş reklamı yüklenemedi: $error');
          _interstitialLoading = false;
        },
      ),
    );
  }

  // ── Bölüm Tamamlandı — her 4 bölümde bir geçiş reklamı ───────────────
  /// quiz_page.dart buradan çağırır.
  /// Sayaç VIP kullanıcılar için de artıyor —
  /// ancak reklam yalnızca VIP olmayanlara gösteriliyor.
  static void bolumTamamlandi(bool isVip) {
    _bolumSayaci++;
    if (_bolumSayaci >= 4) {
      gecisReklamiGoster(isVip);
      _bolumSayaci = 0;
    }
  }

  
  // Deneme Tamamlandi: normal bolum sayaciyla ayni mantik.
  // Mini deneme / tam deneme bitislerinde cagrilir.
  // Toplam 4 tamamlamada 1 gecis reklami gosterilir.
  static void denemeTamamlandi(bool isVip) => bolumTamamlandi(isVip);

  // ── Ödüllü Reklam (callback tabanlı — eski sistem) ────────────────────
  /// Enerji butonu gibi callback tabanlı yerlerde kullanılır.
  /// [onReward]: kullanıcı ödülü kazandığında çağrılır.
  static void odulluReklamGoster(
      bool isVip, VoidCallback onReward) {
    if (isVip || _rewardedLoading || _rewardCooldownActive) {
      return;
    }
    _rewardedLoading = true;

    RewardedAd.load(
      adUnitId: _odulluId,
      request:  const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('Ödüllü reklam gösterilemedi: $error');
              ad.dispose();
              _rewardedLoading = false;
              _lastRewardClosedAt = DateTime.now();
            },
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _rewardedLoading = false;
              _lastRewardClosedAt = DateTime.now();
            },
          );
          ad.show(
            onUserEarnedReward: (_, __) => onReward(),
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('Ödüllü reklam yüklenemedi: $error');
          _rewardedLoading = false;
          _lastRewardClosedAt = DateTime.now();
        },
      ),
    );
  }

  // ── Ödüllü Reklam (Future tabanlı — yeni sistem) ──────────────────────
  /// level_map_page gibi async/await uyumlu yerlerde kullanılır.
  /// Reklamın bitmesini bekler.
  /// [uid]: isteğe bağlı — loglama için kullanılabilir.
  /// Döndürür: kullanıcı ödül kazandıysa `true`, aksi hâlde `false`.
  static Future<bool> reklamIzletFuture({String? uid}) async {
    if (_rewardedLoading || _rewardCooldownActive) return false;
    _rewardedLoading = true;
    final Completer<bool> completer = Completer<bool>();

    RewardedAd.load(
      adUnitId: _odulluId,
      request:  const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          bool isRewarded = false;

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _rewardedLoading = false;
              _lastRewardClosedAt = DateTime.now();
              // Completer zaten tamamlandıysa tekrar complete etme
              if (!completer.isCompleted) {
                completer.complete(isRewarded);
              }
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint(
                  'Ödüllü reklam gösterilemedi (future): $error');
              ad.dispose();
              _rewardedLoading = false;
              _lastRewardClosedAt = DateTime.now();
              if (!completer.isCompleted) {
                completer.complete(false);
              }
            },
          );

          ad.show(
            onUserEarnedReward: (_, __) => isRewarded = true,
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('Ödüllü reklam yüklenemedi (future): $error');
          _rewardedLoading = false;
          _lastRewardClosedAt = DateTime.now();
          if (!completer.isCompleted) {
            completer.complete(false);
          }
        },
      ),
    );

    return completer.future;
  }
}