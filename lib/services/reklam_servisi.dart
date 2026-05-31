import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class ReklamServisi {
  static const String androidAppId = 'ca-app-pub-9545517913490977~1278583376';
  static const String iosAppId = 'ca-app-pub-9545517913490977~9579742624';

  static const String _androidGecisId = 'ca-app-pub-9545517913490977/4585449163';
  static const String _androidOdulluId = 'ca-app-pub-9545517913490977/6534779489';

  static const String _iosGecisId = 'ca-app-pub-9545517913490977/4766399641';
  static const String _iosOdulluId = 'ca-app-pub-9545517913490977/9412221662';

  static const int _gecisReklamiKacBolumdeBir = 3;

  static String get _gecisId => Platform.isIOS ? _iosGecisId : _androidGecisId;
  static String get _odulluId => Platform.isIOS ? _iosOdulluId : _androidOdulluId;

  static int _bolumSayaci = 0;

  static InterstitialAd? _interstitialAd;
  static bool _interstitialLoading = false;
  static bool _showInterstitialAfterLoad = false;

  static RewardedAd? _rewardedAd;
  static bool _rewardedLoading = false;
  static Completer<bool>? _rewardedLoadCompleter;
  static DateTime? _lastRewardClosedAt;

  static bool get _rewardCooldownActive {
    final last = _lastRewardClosedAt;
    if (last == null) return false;
    return DateTime.now().difference(last).inMilliseconds < 700;
  }

  static bool _hasValidAdUnitId(String id) {
    final value = id.trim();
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
      debugPrint('Geçiş reklamı ID eksik/geçersiz: $_gecisId');
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
            onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
              debugPrint('Geçiş reklamı gösterilemedi: $error');
              ad.dispose();
              _interstitialAd = null;
              _showInterstitialAfterLoad = false;
              preloadInterstitial();
            },
            onAdDismissedFullScreenContent: (InterstitialAd ad) {
              debugPrint('Geçiş reklamı kapandı.');
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
            'Geçiş reklamı yüklenemedi: $error | id=$_gecisId | platform=${Platform.operatingSystem}',
          );
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

  /// Test/bölüm/deneme bitince çağır.
  /// 3 tamamlamada 1 geçiş reklamı gösterir.
  static void bolumTamamlandi(bool isVip) {
    if (isVip) return;

    preloadInterstitial(isVip: isVip);

    _bolumSayaci++;
    debugPrint('Reklam bölüm sayacı: $_bolumSayaci / $_gecisReklamiKacBolumdeBir | interstitial hazır: ${_interstitialAd != null}');

    if (_bolumSayaci >= _gecisReklamiKacBolumdeBir) {
      _bolumSayaci = 0;
      gecisReklamiGoster(isVip);
    }
  }

  static void denemeTamamlandi(bool isVip) => bolumTamamlandi(isVip);

  static Future<bool> preloadRewarded() async {
    if (_rewardedAd != null) return true;

    if (_rewardedLoading) {
      return _rewardedLoadCompleter?.future ?? Future.value(false);
    }

    if (_rewardCooldownActive) return false;

    if (!_hasValidAdUnitId(_odulluId)) {
      debugPrint('Ödüllü reklam ID eksik/geçersiz: $_odulluId');
      return false;
    }

    _rewardedLoading = true;
    _rewardedLoadCompleter = Completer<bool>();

    RewardedAd.load(
      adUnitId: _odulluId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          debugPrint('Ödüllü reklam hazırlandı: $_odulluId');
          _rewardedAd = ad;
          _rewardedLoading = false;

          if (!(_rewardedLoadCompleter?.isCompleted ?? true)) {
            _rewardedLoadCompleter?.complete(true);
          }

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
              debugPrint('Ödüllü reklam gösterilemedi: $error');
              ad.dispose();
              _rewardedAd = null;
              _lastRewardClosedAt = DateTime.now();
              preloadRewarded();
            },
            onAdDismissedFullScreenContent: (RewardedAd ad) {
              debugPrint('Ödüllü reklam kapandı.');
              ad.dispose();
              _rewardedAd = null;
              _lastRewardClosedAt = DateTime.now();
              preloadRewarded();
            },
          );
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint(
            'Ödüllü reklam yüklenemedi: $error | id=$_odulluId | platform=${Platform.operatingSystem}',
          );
          _rewardedLoading = false;
          _rewardedAd = null;
          _lastRewardClosedAt = DateTime.now();

          if (!(_rewardedLoadCompleter?.isCompleted ?? true)) {
            _rewardedLoadCompleter?.complete(false);
          }
        },
      ),
    );

    return _rewardedLoadCompleter!.future;
  }

  static void odulluReklamGoster(bool isVip, VoidCallback onReward) {
    reklamIzletFuture().then((rewarded) {
      if (rewarded) onReward();
    });
  }

  /// Kullanıcı ödülü gerçekten kazanırsa true döner.
  static Future<bool> reklamIzletFuture({String? uid}) async {
    if (_rewardCooldownActive) {
      debugPrint('Ödüllü reklam cooldown aktif, çok hızlı tekrar tıklandı.');
      return false;
    }

    if (!_hasValidAdUnitId(_odulluId)) {
      debugPrint('Ödüllü reklam ID eksik/geçersiz: $_odulluId');
      return false;
    }

    if (_rewardedAd == null) {
      final loaded = await preloadRewarded().timeout(
        const Duration(seconds: 12),
        onTimeout: () {
          debugPrint('Ödüllü reklam yükleme zaman aşımı.');
          return false;
        },
      );

      if (!loaded || _rewardedAd == null) {
        debugPrint('Ödüllü reklam hazır değil.');
        return false;
      }
    }

    final ad = _rewardedAd;
    if (ad == null) return false;

    _rewardedAd = null;

    final completer = Completer<bool>();
    bool rewarded = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        ad.dispose();
        _lastRewardClosedAt = DateTime.now();
        preloadRewarded();
        if (!completer.isCompleted) completer.complete(rewarded);
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        debugPrint('Ödüllü reklam gösterilemedi: $error');
        ad.dispose();
        _lastRewardClosedAt = DateTime.now();
        preloadRewarded();
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    try {
      ad.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          rewarded = true;
          debugPrint('Ödül kazanıldı: ${reward.amount} ${reward.type}');
        },
      );
    } catch (e) {
      debugPrint('Ödüllü reklam show hatası: $e');
      ad.dispose();
      preloadRewarded();
      if (!completer.isCompleted) completer.complete(false);
    }

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
    _rewardedLoadCompleter = null;
  }
}
