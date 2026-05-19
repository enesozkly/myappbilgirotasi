import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class PdfProductOption {
  final String productId;
  final String price;
  final double rawPrice;
  final ProductDetails productDetails;

  const PdfProductOption({
    required this.productId,
    required this.price,
    required this.rawPrice,
    required this.productDetails,
  });
}

class PdfPurchaseService {
  PdfPurchaseService._();

  static final PdfPurchaseService instance = PdfPurchaseService._();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  static const Set<String> pdfProductIds = {
    'pdf_ayt_biyoloji',
    'pdf_ayt_edebiyat',
    'pdf_kpss_cografya',
    'pdf_kpss_tarih',
    'pdf_tyt_biyoloji',
    'pdf_felsefe',
  };

  Future<Map<String, PdfProductOption>> loadPdfProducts() async {
    final bool available = await _inAppPurchase.isAvailable();

    if (!available) {
      throw Exception('Satin alma servisi su an kullanilamiyor.');
    }

    final ProductDetailsResponse response =
        await _inAppPurchase.queryProductDetails(pdfProductIds);

    if (response.error != null) {
      throw Exception('PDF urunleri cekilemedi: ${response.error!.message}');
    }

    if (response.notFoundIDs.isNotEmpty) {
      debugPrint(
        'Magaza panelinde bulunamayan PDF urunleri: ${response.notFoundIDs.join(', ')}',
      );
    }

    final Map<String, PdfProductOption> products = {};

    for (final ProductDetails product in response.productDetails) {
      if (!pdfProductIds.contains(product.id)) continue;

      products[product.id] = PdfProductOption(
        productId: product.id,
        price: product.price,
        rawPrice: product.rawPrice,
        productDetails: product,
      );
    }

    return products;
  }

  Future<void> buyPdf(PdfProductOption option) async {
    final PurchaseParam purchaseParam = PurchaseParam(
      productDetails: option.productDetails,
    );

    await _inAppPurchase.buyNonConsumable(
      purchaseParam: purchaseParam,
    );
  }

  Future<void> restorePdfPurchases() async {
    await _inAppPurchase.restorePurchases();
  }

  void startListening({
    required Future<void> Function(PurchaseDetails purchase) onPurchased,
    required void Function(PurchaseDetails purchase) onPending,
    required void Function(String message) onError,
  }) {
    _purchaseSubscription?.cancel();

    _purchaseSubscription = _inAppPurchase.purchaseStream.listen(
      (List<PurchaseDetails> purchases) async {
        for (final PurchaseDetails purchase in purchases) {
          if (!pdfProductIds.contains(purchase.productID)) {
            continue;
          }

          switch (purchase.status) {
            case PurchaseStatus.pending:
              onPending(purchase);
              break;

            case PurchaseStatus.purchased:
            case PurchaseStatus.restored:
              try {
                await onPurchased(purchase);

                if (purchase.pendingCompletePurchase) {
                  await _inAppPurchase.completePurchase(purchase);
                }
              } catch (e) {
                onError('PDF satin alma kaydi yapilamadi: $e');
              }
              break;

            case PurchaseStatus.error:
              onError(
                purchase.error?.message ?? 'PDF satin alma hatasi olustu.',
              );
              break;

            case PurchaseStatus.canceled:
              onError('PDF satin alma iptal edildi.');
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
}
