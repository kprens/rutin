// Rutin — duman testleri: uygulama GERÇEKTEN açılıyor mu?
//
// NEDEN VAR: Bu projede 100'ün üzerinde test vardı ama hepsi saf mantığı
// sınıyordu; uygulamanın kendisi hiçbir otomasyonda BİR KEZ BİLE
// çalıştırılmıyordu. CI yalnızca derliyordu — oysa derlenen bir uygulamanın
// açılmadan çökmesi mümkün ve bu sahada defalarca yaşandı:
//
//   • Bildirim ikonu bulunamadığı için açılışta PlatformException
//     (Sentry RUTIN-1, RUTIN-2)
//   • Açılış zincirinde 8 saniyelik zaman aşımı (RUTIN-3, RUTIN-5)
//   • Paywall'ın tek bir eksik ürün yüzünden tamamen kilitlenmesi —
//     App Store 2.1(b) reddi
//
// Buradaki testler widget ağacını gerçekten kurar ve çizer. Emülatör
// gerektirmedikleri için her PR'da saniyeler içinde koşarlar.
//
// KAPSAMADIKLARI: gerçek platform kanalları (bildirim ikonu, Play Billing,
// AdMob). Onlar ancak gerçek cihazda görülür — bkz. integration_test/.
// İkisi birbirinin yerine geçmez.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rutin/iap.dart';
import 'package:rutin/l10n.dart';
import 'package:rutin/main.dart';
import 'package:rutin/notifications.dart';
import 'package:rutin/repository.dart';
import 'package:rutin/store.dart';
import 'package:rutin/ui/paywall_screen.dart';

/// Mağaza katmanının test ikizi.
///
/// GERÇEK MAĞAZAYI KULLANMAK MÜMKÜN DEĞİL: `InAppPurchase.instance` ilk
/// erişimde platformuna göre kendini kaydediyor ve Android'de Play Billing'e
/// bağlanmaya çalışıyor. Testte o kanal yok, bağlantı ASENKRON olarak
/// başarısız oluyor ve hata "test bittikten sonra" yüzeye çıkıp alakasız bir
/// testi düşürüyordu.
///
/// Çözüm eklentinin kendi genişletme noktası: `InAppPurchasePlatform.instance`
/// dışarıdan atanabiliyor. Hedef platform android/iOS DIŞINDA bir değere
/// çekilince otomatik kayıt hiç çalışmıyor (bkz. in_app_purchase.dart
/// `_getOrCreateInstance`) ve tek gerçek mağaza bağlantısı kurulmuyor.
/// Böylece testler hiçbir platform kanalına dokunmadan, tam deterministik
/// çalışıyor.
class _FakeStore extends InAppPurchasePlatform {
  /// Varsayılan: mağaza yok. Testler gerektiğinde değiştirir.
  Future<bool> Function() onIsAvailable = () async => false;

  Future<ProductDetailsResponse> Function(Set<String>) onQuery =
      (ids) async => ProductDetailsResponse(
            productDetails: const [],
            notFoundIDs: ids.toList(),
          );

  @override
  Future<bool> isAvailable() => onIsAvailable();

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) =>
      onQuery(identifiers);

  @override
  Stream<List<PurchaseDetails>> get purchaseStream =>
      const Stream<List<PurchaseDetails>>.empty();

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {}
}

late _FakeStore _store;

/// Mağazadan gelmiş gibi davranan ürün. Fiyat ASLA koda gömülü değil, her
/// zaman mağazadan gelir (bkz. paywall_screen.dart) — testte de öyle
/// davranıyoruz ki gösterilen metnin kaynağı gerçekle aynı olsun.
ProductDetails _fakeProduct(String id, String price) => ProductDetails(
      id: id,
      title: 'Rutin Pro',
      description: 'Test ürünü',
      price: price,
      rawPrice: 99.99,
      currencyCode: 'TRY',
    );

/// Gerçek uygulamadakiyle AYNI bağımlılıklarla AppState kurar
/// (bkz. main.dart:165).
AppState _appState() => AppState(
      repo: const LocalRepository(),
      notifications: NotificationService(),
    );

Widget _wrapPaywall(AppState state) => ChangeNotifierProvider.value(
      value: state,
      child: const MaterialApp(home: PaywallScreen(source: 'test')),
    );

/// Paywall için geniş ve UZUN bir test yüzeyi.
///
/// UZUN olmalı çünkü paywall bir `ListView` ve ListView TEMBEL: görünüm
/// alanına girmeyen çocuklarını hiç kurmaz. Plan kartları sayfanın altında
/// olduğu için varsayılan 800px'lik yüzeyde ağaca hiç girmiyor, `find`
/// onları bulamıyordu — test yeşil görünürken aslında hiçbir şeyi
/// denetlemiyor olurdu. Kaydırma taklidi yerine yüzeyi uzatmak tercih
/// edildi; kaydırma mesafesi içerik değiştikçe kayan kırılgan bir varsayım.
///
/// GENİŞ olmalı çünkü widget testleri gerçek yazı tipini değil, her karakteri
/// tam kare çizen test yazı tipini kullanır. Aynı metin gerçek cihazdakinden
/// çok daha geniş ölçülür ve gerçekte taşmayan satırlar testte taşar. Bu
/// genişlik bir cihazı temsil etmiyor; yalnızca ölçüm yapaylığını saf dışı
/// bırakıyor. (Gerçek iPad genişlik davranışı ayrı bir testte doğrulanıyor.)
void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(2400, 9000); // 800 x 3000 mantıksal
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Duman testi tanımlar: sahte mağazayı kurar, gövdeyi çalıştırır ve
/// platform override'ını HER DURUMDA geri alır.
///
/// Override neden test gövdesinin İÇİNDE geri alınıyor: `flutter_test` her
/// testin sonunda foundation debug değişkenlerinin sıfırlanmış olmasını
/// doğruluyor ve bu doğrulama `tearDown`'dan ÖNCE çalışıyor. Yani
/// setUp/tearDown çiftiyle yapılırsa tüm testler "debug değişkeni
/// değiştirildi" diyerek düşer.
void smokeTest(String description, Future<void> Function(WidgetTester) body) {
  testWidgets(description, (tester) async {
    // android/iOS DIŞINDA bir hedef: in_app_purchase otomatik platform
    // kaydını yapmaz (bkz. _FakeStore), gerçek mağaza bağlantısı kurulmaz.
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
    try {
      InAppPurchasePlatform.instance = _store;
      SharedPreferences.setMockInitialValues({});
      T.en = false;
      // Iap tekil (singleton): durumu testler arasında sızar, sıfırlanmalı.
      Iap.instance.products = [];
      Iap.instance.productsLoadAttempted = false;
      _store.onIsAvailable = () async => false;

      await body(tester);
    } finally {
      Iap.instance.products = [];
      Iap.instance.productsLoadAttempted = false;
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

void main() {
  _store = _FakeStore();

  group('Uygulama açılışı', () {
    smokeTest('RutinApp istisna fırlatmadan ilk kareyi çizer', (tester) async {
      // Sahadaki en pahalı hata sınıfı: uygulama HİÇ açılmıyor.
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
            value: _appState(), child: const RutinApp()),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: 'açılışta istisna fırlarsa uygulama kullanıcıda açılmaz');
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    smokeTest('onboarding tamamlanmamışken uygulama onboarding\'e düşer',
        (tester) async {
      final state = _appState()..onboarded = false;

      await tester.pumpWidget(
        ChangeNotifierProvider.value(value: state, child: const RutinApp()),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    smokeTest('iPad genişliğinde içerik 560pt ile sınırlanır', (tester) async {
      // Guideline 4 reddinin sebebiydi: telefon için tasarlanmış ekranlar
      // iPad'de 820pt'ye yayılıyordu. Sınır MaterialApp.builder'da tek
      // noktadan uygulanıyor; kaldırılırsa bu test düşer.
      tester.view.physicalSize = const Size(1640, 2360);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
            value: _appState(), child: const RutinApp()),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final constrained =
          tester.widgetList<ConstrainedBox>(find.byType(ConstrainedBox));
      expect(
        constrained.any((c) => c.constraints.maxWidth == 560),
        isTrue,
        reason:
            'iPad genişlik sınırı kaldırılmış — Guideline 4 riski geri geldi',
      );
    });
  });

  group('Paywall — App Store 2.1(b) regresyon koruması', () {
    smokeTest('mağaza hiç ürün döndürmezse HATA durumu gösterilir',
        (tester) async {
      // Apple'ın gördüğü ekran buydu: "an error is shown when trying to
      // access the in-app purchases". Sonsuz spinner DEĞİL, açıklayıcı bir
      // hata ve çıkış yolları görünmeli.
      Iap.instance.products = [];
      Iap.instance.productsLoadAttempted = true;

      _useTallSurface(tester);
      await tester.pumpWidget(_wrapPaywall(_appState()));
      await tester.pumpAndSettle();

      expect(find.text('Planlar şu an yüklenemedi'), findsOneWidget);
      // 3.1.2: abonelik sunulan ekranda geri yükleme ve yasal bağlantılar
      // ZORUNLU. Zaten ödemiş kullanıcı burada kilitli kalmamalı.
      expect(find.text('Satın Alımları Geri Yükle'), findsOneWidget);
      expect(find.text('Gizlilik Politikası'), findsOneWidget);
      expect(find.text('Kullanım Koşulları'), findsOneWidget);
    });

    smokeTest('ürünler henüz gelmediyse YÜKLENİYOR gösterilir — hata değil',
        (tester) async {
      // BEKLEME ile BAŞARISIZLIK ayrı şeyler; eskiden ikisi de aynı sonsuz
      // spinner'a düşüyordu. Mağaza cevabını bilerek askıda tutuyoruz ki
      // "henüz cevap yok" anı ölçülebilsin.
      Iap.instance.products = [];
      Iap.instance.productsLoadAttempted = false;
      _store.onIsAvailable = () => Completer<bool>().future;

      _useTallSurface(tester);
      await tester.pumpWidget(_wrapPaywall(_appState()));
      await tester.pump();

      expect(find.text('Planlar yükleniyor…'), findsOneWidget);
      expect(find.text('Planlar şu an yüklenemedi'), findsNothing);

      // Iap.retryIfNeeded askıdaki cevabı 5sn ile sınırlıyor; o zamanlayıcı
      // boşaltılmazsa test "bekleyen timer" ile düşer.
      await tester.pump(const Duration(seconds: 6));
    });

    smokeTest('YALNIZCA yıllık gelirse paywall yine satış yapabilir',
        (tester) async {
      // 2.1(b) reddinin birebir senaryosu: aylık ürün mağazada ölü
      // (rutin_pro_monthly_v2. — sondaki nokta), yıllık sorunsuz. Eski koşul
      // `yearly != null && monthly != null` idi ve TEK bir ölü ürün tüm
      // ekranı kilitliyordu.
      Iap.instance.products = [_fakeProduct(Iap.yearlyId, '₺349,99')];
      Iap.instance.productsLoadAttempted = true;

      _useTallSurface(tester);
      await tester.pumpWidget(_wrapPaywall(_appState()));
      await tester.pumpAndSettle();

      expect(find.text('Planlar şu an yüklenemedi'), findsNothing,
          reason: 'tek eksik ürün tüm paywall\'ı kilitlememeli');
      // Fiyat mağazadan gelen değerle gösterilmeli — koda gömülü değil.
      expect(find.textContaining('349,99'), findsWidgets);
    });

    smokeTest('YALNIZCA aylık gelirse de satış yapılabilir', (tester) async {
      Iap.instance.products = [_fakeProduct(Iap.monthlyId, '₺49,99')];
      Iap.instance.productsLoadAttempted = true;

      _useTallSurface(tester);
      await tester.pumpWidget(_wrapPaywall(_appState()));
      await tester.pumpAndSettle();

      expect(find.text('Planlar şu an yüklenemedi'), findsNothing);
      expect(find.textContaining('49,99'), findsWidgets);
    });

    smokeTest('ömür boyu ürünü paywall\'da GÖRÜNMEZ', (tester) async {
      // Ürün satıştan tamamen kaldırıldı. Mağaza eski kimliği yine
      // döndürse bile ekranda yer almamalı.
      Iap.instance.products = [
        _fakeProduct(Iap.yearlyId, '₺349,99'),
        _fakeProduct(Iap.legacyLifetimeId, '₺999,99'),
      ];
      Iap.instance.productsLoadAttempted = true;

      _useTallSurface(tester);
      await tester.pumpWidget(_wrapPaywall(_appState()));
      await tester.pumpAndSettle();

      expect(find.textContaining('999,99'), findsNothing,
          reason: 'ömür boyu ürünü satıştan kaldırıldı');
      expect(find.text('Ömür Boyu'), findsNothing);
    });
  });
}
