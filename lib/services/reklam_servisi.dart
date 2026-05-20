import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Reklam Servisi
///
/// Mantık:
/// - VIP kullanıcıya reklam gösterilmez.
/// - Toplam 4 bölüm/deneme tamamlamada 1 geçiş reklamı gösterilmeye çalışılır.
/// - Geçiş reklamı önceden yüklenir; 4. tamamlamada hazırsa anında gösterilir.
/// - Hazır değilse o anda yüklenir ve yüklenince gösterilmeye çalışılır.
/// - Ödüllü reklam enerji sistemi için ayrı çalışır.
class ReklamServisi {
  // Android gerçek AdMob reklam birimi ID'leri.
  static const String _androidGecisId =
      'ca-app-pub-9545517913490977/458449163';
  static const String _androidOdulluId =
      'ca-app-pub-9545517913490977/9412221662';

  // iOS için AdMob panelinden alınan / içeren reklam birimi ID'leri buraya girilmeli.
  // App ID (~ içeren) Info.plist içindedir; burada kullanılmaz.
  static const String _iosGecisId =
      'ca-app-pub-9545517913490977/4766399641';
  static const String _iosOdulluId =
      'ca-app-pub-9545517913490977/9412221662';

  static String get _gecisId => Platform.isIOS ? _iosGecisId : _androidGecisId;
  static String get _odulluId => Platform.isIOS ? _iosOdulluId : _androidOdulluId;

  static int _bolumSayaci = 0;

  static InterstitialAd? _interstitialAd;
  static bool _interstitialLoading = false;
  static bool _showInterstitialAfterLoad = false;

  static bool _rewardedLoading = false;
  static DateTime? _lastRewardClosedAt;

  static bool get _rewardCooldownActive {
    final last = _lastRewardClosedAt;
    if (last == null) return false;
    return DateTime.now().difference(last).inMilliseconds < 900;
  }

  static bool _hasValidAdUnitId(String id) {
    return id.trim().isNotEmpty && id.contains('/');
  }

  static void _preloadInterstitial({
    bool showAfterLoad = false,
    bool isVip = false,
  }) {
    if (isVip) return;

    if (!_hasValidAdUnitId(_gecisId)) {
      debugPrint('Geçiş reklamı ID eksik/geçersiz. Platform: ${Platform.operatingSystem}');
      return;
    }

    if (_interstitialAd != null) {
      if (showAfterLoad) _showReadyInterstitial();
      return;
    }

    if (_interstitialLoading) {
      if (showAfterLoad) _showInterstitialAfterLoad = true;
      return;
    }

    _interstitialLoading = true;
    if (showAfterLoad) _showInterstitialAfterLoad = true;

    InterstitialAd.load(
      adUnitId: _gecisId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          debugPrint('Geçiş reklamı hazırlandı.');
          _interstitialAd = ad;
          _interstitialLoading = false;

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('Geçiş reklamı gösterilemedi: $error');
              ad.dispose();
              _interstitialAd = null;
              _showInterstitialAfterLoad = false;
              _preloadInterstitial();
            },
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null;
              _showInterstitialAfterLoad = false;
              _preloadInterstitial();
            },
          );

          if (_showInterstitialAfterLoad) {
            _showReadyInterstitial();
          }
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('Geçiş reklamı yüklenemedi: $error');
          _interstitialLoading = false;
          _interstitialAd = null;
          _showInterstitialAfterLoad = false;
        },
      ),
    );
  }

  static void _showReadyInterstitial() {
    final ad = _interstitialAd;
    if (ad == null) {
      _preloadInterstitial(showAfterLoad: true);
      return;
    }

    _showInterstitialAfterLoad = false;
    _interstitialAd = null;

    try {
      ad.show();
    } catch (e) {
      debugPrint('Geçiş reklamı show hatası: $e');
      ad.dispose();
      _preloadInterstitial();
    }
  }

  static void gecisReklamiGoster(bool isVip) {
    if (isVip) return;
    if (_interstitialAd != null) {
      _showReadyInterstitial();
      return;
    }
    _preloadInterstitial(showAfterLoad: true);
  }

  static void bolumTamamlandi(bool isVip) {
    if (isVip) return;
    _preloadInterstitial();
    _bolumSayaci++;
    debugPrint('Reklam bölüm sayacı: $_bolumSayaci / 4');
    if (_bolumSayaci >= 4) {
      _bolumSayaci = 0;
      gecisReklamiGoster(isVip);
    }
  }

  static void denemeTamamlandi(bool isVip) => bolumTamamlandi(isVip);

  static void odulluReklamGoster(bool isVip, VoidCallback onReward) {
    if (isVip || _rewardedLoading || _rewardCooldownActive) return;

    if (!_hasValidAdUnitId(_odulluId)) {
      debugPrint('Ödüllü reklam ID eksik/geçersiz. Platform: ${Platform.operatingSystem}');
      return;
    }

    _rewardedLoading = true;

    RewardedAd.load(
      adUnitId: _odulluId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
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
          ad.show(onUserEarnedReward: (_, __) => onReward());
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('Ödüllü reklam yüklenemedi: $error');
          _rewardedLoading = false;
          _lastRewardClosedAt = DateTime.now();
        },
      ),
    );
  }

  static Future<bool> reklamIzletFuture({String? uid}) async {
    if (_rewardedLoading || _rewardCooldownActive) return false;

    if (!_hasValidAdUnitId(_odulluId)) {
      debugPrint('Ödüllü reklam ID eksik/geçersiz. Platform: ${Platform.operatingSystem}');
      return false;
    }

    _rewardedLoading = true;
    final Completer<bool> completer = Completer<bool>();

    RewardedAd.load(
      adUnitId: _odulluId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          bool isRewarded = false;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _rewardedLoading = false;
              _lastRewardClosedAt = DateTime.now();
              if (!completer.isCompleted) completer.complete(isRewarded);
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('Ödüllü reklam gösterilemedi (future): $error');
              ad.dispose();
              _rewardedLoading = false;
              _lastRewardClosedAt = DateTime.now();
              if (!completer.isCompleted) completer.complete(false);
            },
          );
          ad.show(onUserEarnedReward: (_, __) => isRewarded = true);
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('Ödüllü reklam yüklenemedi (future): $error');
          _rewardedLoading = false;
          _lastRewardClosedAt = DateTime.now();
          if (!completer.isCompleted) completer.complete(false);
        },
      ),
    );

    return completer.future;
  }
}
