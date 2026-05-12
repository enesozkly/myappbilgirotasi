import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class VipPlanOption {
  final String planKey;
  final String title;
  final String price;
  final double rawPrice;
  final ProductDetails productDetails;

  const VipPlanOption({
    required this.planKey,
    required this.title,
    required this.price,
    required this.rawPrice,
    required this.productDetails,
  });
}

class VipPurchaseService {
  VipPurchaseService._();

  static final VipPurchaseService instance = VipPurchaseService._();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  static const String vipProductId = 'vip';

  Future<List<VipPlanOption>> loadVipPlans() async {
    final bool available = await _inAppPurchase.isAvailable();

    if (!available) {
      throw Exception('Google Play satin alma servisi su an kullanilamiyor.');
    }

    final ProductDetailsResponse response =
        await _inAppPurchase.queryProductDetails({vipProductId});

    if (response.error != null) {
      throw Exception('Urunler cekilemedi: ${response.error!.message}');
    }

    if (response.notFoundIDs.isNotEmpty) {
      throw Exception(
        'Play Console icinde bulunamayan urun ID: ${response.notFoundIDs.join(', ')}',
      );
    }

    final List<ProductDetails> vipProducts = response.productDetails
        .where((ProductDetails product) => product.id == vipProductId)
        .toList();

    vipProducts.sort(
      (ProductDetails a, ProductDetails b) => a.rawPrice.compareTo(b.rawPrice),
    );

    final List<VipPlanOption> plans = [];

    for (int i = 0; i < vipProducts.length; i++) {
      final ProductDetails product = vipProducts[i];
      final String planKey = _planKeyByIndex(i);

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

    debugPrint('VIP plan sayisi: ${plans.length}');

    for (final VipPlanOption plan in plans) {
      debugPrint(
        'VIP Plan: ${plan.planKey} | ${plan.title} | ${plan.price} | ${plan.rawPrice}',
      );
    }

    return plans;
  }

  Future<void> buyVipPlan(VipPlanOption plan) async {
    final PurchaseParam purchaseParam = PurchaseParam(
      productDetails: plan.productDetails,
    );

    await _inAppPurchase.buyNonConsumable(
      purchaseParam: purchaseParam,
    );
  }

  void startListening({
    required void Function(PurchaseDetails purchase) onPurchased,
    required void Function(PurchaseDetails purchase) onPending,
    required void Function(String message) onError,
  }) {
    _purchaseSubscription?.cancel();

    _purchaseSubscription = _inAppPurchase.purchaseStream.listen(
      (List<PurchaseDetails> purchases) async {
        for (final PurchaseDetails purchase in purchases) {
          if (purchase.productID != vipProductId) {
            continue;
          }

          switch (purchase.status) {
            case PurchaseStatus.pending:
              onPending(purchase);
              break;

            case PurchaseStatus.purchased:
            case PurchaseStatus.restored:
              onPurchased(purchase);

              if (purchase.pendingCompletePurchase) {
                await _inAppPurchase.completePurchase(purchase);
              }
              break;

            case PurchaseStatus.error:
              onError(
                purchase.error?.message ?? 'Satin alma hatasi olustu.',
              );
              break;

            case PurchaseStatus.canceled:
              onError('Satin alma iptal edildi.');
              break;
          }
        }
      },
      onError: (Object error) {
        onError(error.toString());
      },
    );
  }

  Future<void> dispose() async {
    await _purchaseSubscription?.cancel();
    _purchaseSubscription = null;
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

  String _titleForPlanKey(String planKey) {
    switch (planKey) {
      case 'monthly':
        return 'Aylik VIP';
      case 'three_months':
        return '3 Aylik VIP';
      case 'yearly':
        return 'Yillik VIP';
      default:
        return 'VIP';
    }
  }
}