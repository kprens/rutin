/// Uygulama içi satın alma (IAP) — App Store (StoreKit) + Google Play Billing.
///
/// Tek kod tabanı iki mağazayı da yönetir. Apple, dijital abonelikleri
/// kendi IAP sistemi üzerinden satmayı zorunlu tuttuğu için paywall
/// bu servisi kullanır.
///
/// NOT (v1): Satın alma sunucu tarafında makbuz doğrulaması yapılmadan,
/// mağazadan gelen "purchased/restored" sinyaliyle Pro açılır. Bu, indie
/// uygulamalar için yaygın ve kabul edilebilir bir başlangıçtır; ileride
/// Supabase Edge Function ile makbuz doğrulaması eklenebilir.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class Iap extends ChangeNotifier {
  Iap._();
  static final Iap instance = Iap._();

  /// Ürün kimlikleri — App Store Connect ve Play Console'da BİREBİR aynı
  /// tanımlanmalı (abonelik ürünleri).
  static const String monthlyId = 'rutin_pro_monthly';
  static const String yearlyId = 'rutin_pro_yearly';
  static const Set<String> _ids = {monthlyId, yearlyId};

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  /// Mağazaya ulaşılabiliyor mu (öykünücüde/masaüstünde false olabilir).
  bool available = false;

  /// Mağazadan yüklenen ürünler (fiyat, başlık vb. yerelleştirilmiş).
  List<ProductDetails> products = [];

  /// Satın alma akışı sürüyor mu (buton kilidi için).
  bool purchasePending = false;

  /// Pro kilidini açan callback — AppState.activatePro'ya bağlanır.
  void Function()? _onPro;

  ProductDetails? productFor(String id) {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Mağazadan gelen yerelleştirilmiş fiyat; yoksa [fallback].
  String priceFor(String id, String fallback) =>
      productFor(id)?.price ?? fallback;

  Future<void> init({void Function()? onPro}) async {
    _onPro = onPro;
    try {
      available = await _iap.isAvailable();
    } catch (_) {
      available = false;
    }
    if (!available) {
      notifyListeners();
      return;
    }
    // Önceki oturumdan kalan / bekleyen işlemleri de yakalamak için erken dinle.
    _sub = _iap.purchaseStream.listen(
      _onPurchases,
      onError: (Object _) {},
    );
    await loadProducts();
    notifyListeners();
  }

  Future<void> loadProducts() async {
    try {
      final resp = await _iap.queryProductDetails(_ids);
      products = resp.productDetails;
    } catch (_) {
      products = [];
    }
    notifyListeners();
  }

  /// Aboneliği satın alma akışını başlatır. Sonuç purchaseStream'e düşer.
  Future<void> buy(String id) async {
    final product = productFor(id);
    if (product == null) return;
    purchasePending = true;
    notifyListeners();
    try {
      await _iap.buyNonConsumable(
          purchaseParam: PurchaseParam(productDetails: product));
    } catch (_) {
      purchasePending = false;
      notifyListeners();
    }
  }

  /// Apple'ın zorunlu tuttuğu "Satın alımları geri yükle".
  Future<void> restore() async {
    try {
      await _iap.restorePurchases();
    } catch (_) {}
  }

  void _onPurchases(List<PurchaseDetails> list) {
    for (final p in list) {
      if (p.status == PurchaseStatus.pending) {
        purchasePending = true;
      } else {
        if (p.status == PurchaseStatus.purchased ||
            p.status == PurchaseStatus.restored) {
          purchasePending = false;
          _onPro?.call();
        } else {
          // error / canceled
          purchasePending = false;
        }
        // Her tamamlanan (başarılı/başarısız) işlem mağazaya bildirilmeli;
        // aksi halde iOS'ta işlem kuyrukta kalır ve tekrar tekrar düşer.
        if (p.pendingCompletePurchase) {
          _iap.completePurchase(p);
        }
      }
    }
    notifyListeners();
  }

  void disposeIap() {
    _sub?.cancel();
    _sub = null;
  }
}
