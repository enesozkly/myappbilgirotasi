import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Reklam Servisi
///
/// - VIP kullanıcıya geçiş reklamı gösterilmez.
/// - Ödüllü reklam enerji sistemi için ayrı çalışır.
/// - Test ID yoktur; aşağıdaki ID'ler gerçek AdMob reklam birimi ID'leridir.
class ReklamServisi {
  static const String _androidGecisId =
      'ca-app-pub-9545517913490977/4585449163';
  static const String _androidOdulluId =
      'ca-app-pub-9545517913490977/6534779489';

  /// iOS AdMob panelindeki iOS uygulamasına ait reklam birimi ID'leri.
  /// Dikkat: iOS Rewarded reklam birimi Android Rewarded ID ile aynı olmamalı.
  /// AdMob > Apps > Bilgi Rotası iOS > Ad units bölümündeki Rewarded ID buraya yazılmalı.
  static const String _iosGecisId = 'ca-app-pub-9545517913490977/4766399641';
  static const String _iosOdulluId = 'ca-app-pub-9545517913490977/9412221662';

  static String get _gecisId => Platform.isIOS ? _iosGecisId : _androidGecisId;
  static String get _odulluId =>
      Platform.isIOS ? _iosOdulluId : _androidOdulluId;

  static int _bolumSayaci = 0;

  static InterstitialAd? _interstitialAd;
  static bool _interstitialLoading = false;
  static bool _showInterstitialAfterLoad = false;

  static RewardedAd? _rewardedAd;
  static bool _rewardedLoading = false;
  static DateTime? _lastRewardClosedAt;

  static bool get _rewardCooldownActive {
    final DateTime? last = _lastRewardClosedAt;
    if (last == null) return false;
    return DateTime.now().difference(last).inMilliseconds < 900;
  }

  static bool _hasValidAdUnitId(String id) {
    final String value = id.trim();
    return value.startsWith('ca-app-pub-') && value.contains('/');
  }

  static void init({bool isVip = false}) {
    if (!isVip) {
      preloadInterstitial(isVip: isVip);
    }
    preloadRewarded();
  }

  static void preloadInterstitial({
    bool showAfterLoad = false,
    bool isVip = false,
  }) {
    if (isVip) return;

    if (!_hasValidAdUnitId(_gecisId)) {
      debugPrint(
          'Geçiş reklamı ID eksik/geçersiz. Platform: ${Platform.operatingSystem}');
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
          debugPrint('Geçiş reklamı hazırlandı: $_gecisId');
          _interstitialAd = ad;
          _interstitialLoading = false;

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdFailedToShowFullScreenContent:
                (InterstitialAd ad, AdError error) {
              debugPrint('Geçiş reklamı gösterilemedi: $error');
              ad.dispose();
              _interstitialAd = null;
              _showInterstitialAfterLoad = false;
              preloadInterstitial();
            },
            onAdDismissedFullScreenContent: (InterstitialAd ad) {
              ad.dispose();
              _interstitialAd = null;
              _showInterstitialAfterLoad = false;
              preloadInterstitial();
            },
          );

          if (_showInterstitialAfterLoad) {
            _showReadyInterstitial();
          }
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint(
              'Geçiş reklamı yüklenemedi: $error | id=$_gecisId | platform=${Platform.operatingSystem}');
          _interstitialLoading = false;
          _interstitialAd = null;
          _showInterstitialAfterLoad = false;
        },
      ),
    );
  }

  static void _showReadyInterstitial() {
    final InterstitialAd? ad = _interstitialAd;
    if (ad == null) {
      preloadInterstitial(showAfterLoad: true);
      return;
    }

    _showInterstitialAfterLoad = false;
    _interstitialAd = null;

    try {
      ad.show();
    } catch (e) {
      debugPrint('Geçiş reklamı show hatası: $e');
      ad.dispose();
      preloadInterstitial();
    }
  }

  static void gecisReklamiGoster(bool isVip) {
    if (isVip) return;
    if (_interstitialAd != null) {
      _showReadyInterstitial();
      return;
    }
    preloadInterstitial(showAfterLoad: true);
  }

  static void bolumTamamlandi(bool isVip) {
    if (isVip) return;
    preloadInterstitial(isVip: isVip);
    _bolumSayaci++;
    debugPrint('Reklam bölüm sayacı: $_bolumSayaci / 4');
    if (_bolumSayaci >= 4) {
      _bolumSayaci = 0;
      gecisReklamiGoster(isVip);
    }
  }

  static void denemeTamamlandi(bool isVip) => bolumTamamlandi(isVip);

  static void preloadRewarded() {
    if (_rewardedAd != null || _rewardedLoading || _rewardCooldownActive)
      return;

    if (!_hasValidAdUnitId(_odulluId)) {
      debugPrint(
          'Ödüllü reklam ID eksik/geçersiz. Platform: ${Platform.operatingSystem}');
      return;
    }

    _rewardedLoading = true;

    RewardedAd.load(
      adUnitId: _odulluId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          debugPrint('Ödüllü reklam hazırlandı: $_odulluId');
          _rewardedAd = ad;
          _rewardedLoading = false;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
              debugPrint('Ödüllü reklam gösterilemedi: $error');
              ad.dispose();
              _rewardedAd = null;
              _lastRewardClosedAt = DateTime.now();
              preloadRewarded();
            },
            onAdDismissedFullScreenContent: (RewardedAd ad) {
              ad.dispose();
              _rewardedAd = null;
              _lastRewardClosedAt = DateTime.now();
              preloadRewarded();
            },
          );
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint(
              'Ödüllü reklam yüklenemedi: $error | id=$_odulluId | platform=${Platform.operatingSystem}');
          _rewardedLoading = false;
          _rewardedAd = null;
          _lastRewardClosedAt = DateTime.now();
        },
      ),
    );
  }

  static void odulluReklamGoster(bool isVip, VoidCallback onReward) {
    // VIP kullanıcı geçiş reklamı görmez; isterse ödüllü reklam izleyebilir.
    if (_rewardedLoading || _rewardCooldownActive) return;

    final RewardedAd? ad = _rewardedAd;
    if (ad == null) {
      reklamIzletFuture().then((bool rewarded) {
        if (rewarded) onReward();
      });
      return;
    }

    _rewardedAd = null;
    ad.show(onUserEarnedReward: (_, __) => onReward());
  }

  static Future<bool> reklamIzletFuture({String? uid}) async {
    if (_rewardedLoading || _rewardCooldownActive) return false;

    if (!_hasValidAdUnitId(_odulluId)) {
      debugPrint(
          'Ödüllü reklam ID eksik/geçersiz. Platform: ${Platform.operatingSystem}');
      return false;
    }

    final RewardedAd? readyAd = _rewardedAd;
    if (readyAd != null) {
      _rewardedAd = null;
      final Completer<bool> readyCompleter = Completer<bool>();
      bool rewarded = false;
      readyAd.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (RewardedAd ad) {
          ad.dispose();
          _lastRewardClosedAt = DateTime.now();
          preloadRewarded();
          if (!readyCompleter.isCompleted) readyCompleter.complete(rewarded);
        },
        onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
          debugPrint('Ödüllü reklam gösterilemedi (hazır): $error');
          ad.dispose();
          _lastRewardClosedAt = DateTime.now();
          preloadRewarded();
          if (!readyCompleter.isCompleted) readyCompleter.complete(false);
        },
      );
      readyAd.show(onUserEarnedReward: (_, __) => rewarded = true);
      return readyCompleter.future;
    }

    _rewardedLoading = true;
    final Completer<bool> completer = Completer<bool>();

    RewardedAd.load(
      adUnitId: _odulluId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          bool rewarded = false;
          _rewardedLoading = false;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (RewardedAd ad) {
              ad.dispose();
              _lastRewardClosedAt = DateTime.now();
              preloadRewarded();
              if (!completer.isCompleted) completer.complete(rewarded);
            },
            onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
              debugPrint('Ödüllü reklam gösterilemedi (future): $error');
              ad.dispose();
              _lastRewardClosedAt = DateTime.now();
              preloadRewarded();
              if (!completer.isCompleted) completer.complete(false);
            },
          );
          ad.show(onUserEarnedReward: (_, __) => rewarded = true);
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint(
              'Ödüllü reklam yüklenemedi (future): $error | id=$_odulluId');
          _rewardedLoading = false;
          _lastRewardClosedAt = DateTime.now();
          if (!completer.isCompleted) completer.complete(false);
        },
      ),
    );

    return completer.future;
  }

  static void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _interstitialLoading = false;
    _rewardedLoading = false;
    _showInterstitialAfterLoad = false;
  }
}
