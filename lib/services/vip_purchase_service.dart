import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

class VipPlanOption {
  final String planKey;
  final String title;
  final String price;
  final double rawPrice;
  final ProductDetails productDetails;

  /// Android/Google Play subscription base plan veya offer token değeri.
  /// iOS tarafında boş kalır.
  final String? offerToken;

  const VipPlanOption({
    required this.planKey,
    required this.title,
    required this.price,
    required this.rawPrice,
    required this.productDetails,
    this.offerToken,
  });
}

class VipPurchaseService {
  VipPurchaseService._();

  static final VipPurchaseService instance = VipPurchaseService._();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  /// Google Play tarafında tek subscription ürünün ve base plan/offer yapın.
  static const Set<String> androidVipProductIds = <String>{
    'vip',
  };

  /// App Store Connect tarafında açılan abonelik product id'leri.
  static const Set<String> iosVipProductIds = <String>{
    'vip_monthly',
    'vip_3_months',
    'vip_yearly',
  };

  static Set<String> get vipProductIds =>
      Platform.isIOS ? iosVipProductIds : androidVipProductIds;

  /// Kullanıcı gerçekten satın alma butonuna bastığında set edilir.
  /// iOS purchaseStream bazen eski/restored transaction döndürebildiği için
  /// bu koruma olmadan hesap dokunmayla VIP'e çevrilebilir.
  final Set<String> _activePurchaseProductIds = <String>{};

  Future<List<VipPlanOption>> loadVipPlans() async {
    final bool available = await _inAppPurchase.isAvailable();
    if (!available) {
      throw Exception('Satın alma servisi şu an kullanılamıyor.');
    }

    final ProductDetailsResponse response =
        await _inAppPurchase.queryProductDetails(vipProductIds);

    if (response.error != null) {
      throw Exception('Ürünler çekilemedi: ${response.error!.message}');
    }

    if (response.notFoundIDs.length == vipProductIds.length) {
      throw Exception(
        'Mağaza panelinde VIP ürünleri bulunamadı: ${response.notFoundIDs.join(', ')}',
      );
    }

    if (response.notFoundIDs.isNotEmpty) {
      debugPrint(
        'Mağaza panelinde bulunamayan VIP ürünleri: ${response.notFoundIDs.join(', ')}',
      );
    }

    final List<VipPlanOption> plans = <VipPlanOption>[];

    for (final ProductDetails product in response.productDetails) {
      if (!vipProductIds.contains(product.id)) continue;

      final List<VipPlanOption> googleOfferPlans =
          _plansFromGooglePlaySubscriptionOffers(product);

      if (googleOfferPlans.isNotEmpty) {
        plans.addAll(googleOfferPlans);
      } else {
        final String planKey = _planKeyFromProductId(product.id, plans.length);
        plans.add(
          VipPlanOption(
            planKey: planKey,
            title: _titleForPlanKey(planKey),
            price: product.price,
            rawPrice: product.rawPrice,
            productDetails: product,
          ),
        );
      }
    }

    plans.sort((VipPlanOption a, VipPlanOption b) {
      final int orderA = _planOrder(a.planKey);
      final int orderB = _planOrder(b.planKey);
      if (orderA != orderB) return orderA.compareTo(orderB);
      return a.rawPrice.compareTo(b.rawPrice);
    });

    debugPrint('VIP plan sayısı: ${plans.length}');
    for (final VipPlanOption plan in plans) {
      debugPrint(
        'VIP Plan: ${plan.planKey} | ${plan.title} | ${plan.price} | ${plan.rawPrice} | product=${plan.productDetails.id} | offer=${plan.offerToken ?? '-'}',
      );
    }

    return plans;
  }

  List<VipPlanOption> _plansFromGooglePlaySubscriptionOffers(
    ProductDetails product,
  ) {
    if (!Platform.isAndroid || product is! GooglePlayProductDetails) {
      return const <VipPlanOption>[];
    }

    try {
      final dynamic wrapped = product.productDetails;
      final List<dynamic>? offers =
          wrapped.subscriptionOfferDetails as List<dynamic>?;
      if (offers == null || offers.isEmpty) return const <VipPlanOption>[];

      final List<VipPlanOption> result = <VipPlanOption>[];
      for (int i = 0; i < offers.length; i++) {
        final dynamic offer = offers[i];
        final String? offerToken = offer.offerToken?.toString();
        if (offerToken == null || offerToken.isEmpty) continue;

        final String planKey = _planKeyFromGoogleOffer(offer, i);
        final _OfferPrice price = _priceFromGoogleOffer(offer, product);

        result.add(
          VipPlanOption(
            planKey: planKey,
            title: _titleForPlanKey(planKey),
            price: price.formattedPrice,
            rawPrice: price.rawPrice,
            productDetails: product,
            offerToken: offerToken,
          ),
        );
      }
      return result;
    } catch (e) {
      debugPrint('Google Play abonelik offer bilgisi okunamadı: $e');
      return const <VipPlanOption>[];
    }
  }

  Future<void> buyVipPlan(VipPlanOption plan) async {
    final String productId = plan.productDetails.id;
    _activePurchaseProductIds.add(productId);

    try {
      final PurchaseParam purchaseParam;
      if (Platform.isAndroid && plan.offerToken != null) {
        purchaseParam = GooglePlayPurchaseParam(
          productDetails: plan.productDetails,
          offerToken: plan.offerToken,
        );
      } else {
        purchaseParam = PurchaseParam(productDetails: plan.productDetails);
      }

      await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (_) {
      _activePurchaseProductIds.remove(productId);
      rethrow;
    }
  }

  Future<void> restoreVipPurchases() async {
    await _inAppPurchase.restorePurchases();
  }

  void startListening({
    required Future<void> Function(PurchaseDetails purchase) onPurchased,
    required void Function(PurchaseDetails purchase) onPending,
    required void Function(String message) onError,
    void Function(PurchaseDetails purchase)? onIgnored,
  }) {
    _purchaseSubscription?.cancel();

    _purchaseSubscription = _inAppPurchase.purchaseStream.listen(
      (List<PurchaseDetails> purchases) async {
        for (final PurchaseDetails purchase in purchases) {
          if (!vipProductIds.contains(purchase.productID)) continue;

          switch (purchase.status) {
            case PurchaseStatus.pending:
              onPending(purchase);
              break;

            case PurchaseStatus.purchased:
              if (!_activePurchaseProductIds.contains(purchase.productID)) {
                debugPrint(
                  'VIP satın alma yok sayıldı. Kullanıcı bu oturumda satın alma başlatmadı: ${purchase.productID}',
                );
                onIgnored?.call(purchase);
                if (purchase.pendingCompletePurchase) {
                  await _inAppPurchase.completePurchase(purchase);
                }
                break;
              }

              try {
                await onPurchased(purchase);
                _activePurchaseProductIds.remove(purchase.productID);
                if (purchase.pendingCompletePurchase) {
                  await _inAppPurchase.completePurchase(purchase);
                }
              } catch (e) {
                onError('VIP satın alma kaydı yapılamadı: $e');
              }
              break;

            case PurchaseStatus.restored:
              // Otomatik VIP açmasın. Restore için ayrı buton/akış kullanılmalı.
              debugPrint('VIP restored transaction otomatik işlenmedi: ${purchase.productID}');
              onIgnored?.call(purchase);
              if (purchase.pendingCompletePurchase) {
                await _inAppPurchase.completePurchase(purchase);
              }
              break;

            case PurchaseStatus.error:
              _activePurchaseProductIds.remove(purchase.productID);
              onError(purchase.error?.message ?? 'Satın alma hatası oluştu.');
              break;

            case PurchaseStatus.canceled:
              _activePurchaseProductIds.remove(purchase.productID);
              onError('Satın alma iptal edildi.');
              break;
          }
        }
      },
      onError: (Object error) => onError(error.toString()),
    );
  }

  Future<void> dispose() async {
    await _purchaseSubscription?.cancel();
    _purchaseSubscription = null;
    _activePurchaseProductIds.clear();
  }

  String _planKeyFromGoogleOffer(dynamic offer, int index) {
    final String text = <dynamic>[offer.basePlanId, offer.offerId, offer.offerTags]
        .where((dynamic e) => e != null)
        .join(' ')
        .toLowerCase();

    if (text.contains('year') ||
        text.contains('annual') ||
        text.contains('yillik') ||
        text.contains('yıllık')) {
      return 'yearly';
    }
    if (text.contains('3') ||
        text.contains('quarter') ||
        text.contains('three') ||
        text.contains('uc') ||
        text.contains('üç')) {
      return 'three_months';
    }
    if (text.contains('month') ||
        text.contains('monthly') ||
        text.contains('aylik') ||
        text.contains('aylık')) {
      return 'monthly';
    }
    return _planKeyByIndex(index);
  }

  _OfferPrice _priceFromGoogleOffer(
    dynamic offer,
    ProductDetails fallbackProduct,
  ) {
    try {
      final List<dynamic>? phases = offer.pricingPhases as List<dynamic>?;
      if (phases == null || phases.isEmpty) {
        return _OfferPrice(fallbackProduct.price, fallbackProduct.rawPrice);
      }

      final dynamic phase = phases.last;
      final String formattedPrice =
          phase.formattedPrice?.toString() ?? fallbackProduct.price;
      final dynamic microsValue = phase.priceAmountMicros;
      final double rawPrice = microsValue is num
          ? microsValue.toDouble() / 1000000.0
          : fallbackProduct.rawPrice;

      return _OfferPrice(formattedPrice, rawPrice);
    } catch (_) {
      return _OfferPrice(fallbackProduct.price, fallbackProduct.rawPrice);
    }
  }

  String _planKeyFromProductId(String productId, int index) {
    switch (productId) {
      case 'vip_monthly':
        return 'monthly';
      case 'vip_3_months':
        return 'three_months';
      case 'vip_yearly':
        return 'yearly';
      case 'vip':
        return Platform.isAndroid ? 'monthly' : _planKeyByIndex(index);
      default:
        return _planKeyByIndex(index);
    }
  }

  String _planKeyByIndex(int index) {
    switch (index) {
      case 0:
        return 'monthly';
      case 1:
        return 'three_months';
      case 2:
        return 'yearly';
      default:
        return 'vip_$index';
    }
  }

  int _planOrder(String planKey) {
    switch (planKey) {
      case 'monthly':
        return 0;
      case 'three_months':
        return 1;
      case 'yearly':
        return 2;
      default:
        return 99;
    }
  }

  String _titleForPlanKey(String planKey) {
    switch (planKey) {
      case 'monthly':
        return 'Aylık VIP';
      case 'three_months':
        return '3 Aylık VIP';
      case 'yearly':
        return 'Yıllık VIP';
      default:
        return 'VIP';
    }
  }
}

class _OfferPrice {
  final String formattedPrice;
  final double rawPrice;

  const _OfferPrice(this.formattedPrice, this.rawPrice);
}
