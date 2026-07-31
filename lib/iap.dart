/// Uygulama içi satın alma (IAP) — App Store (StoreKit) + Google Play Billing.
///
/// Tek kod tabanı iki mağazayı da yönetir. Apple, dijital abonelikleri
/// kendi IAP sistemi üzerinden satmayı zorunlu tuttuğu için paywall
/// bu servisi kullanır.
///
/// Satın alma, mağazadan gelen "purchased/restored" sinyali TEK BAŞINA
/// yeterli sayılmaz: makbuz, sunucu tarafında (Supabase Edge Function)
/// doğrulanmadan Pro açılmaz. Bkz. [_verifyReceipt] / [verifyReceiptUrl].
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';

import 'analytics.dart';
import 'diagnostics.dart';

/// Sunucu tarafı makbuz doğrulaması yapan fonksiyon tipi.
/// `true` dönerse Pro açılır, `false` dönerse [Iap.lastError] set edilir.
typedef ReceiptVerifier = Future<bool> Function(PurchaseDetails details);

class Iap extends ChangeNotifier {
  Iap._();
  static final Iap instance = Iap._();

  /// Aylık abonelik kimliği — PLATFORMA GÖRE değişir.
  ///
  /// iOS: `rutin_pro_monthly_v2`. Orijinal `rutin_pro_monthly` kimliği App
  /// Store Connect'te yanlışlıkla yanlış tipte (abonelik yerine tek seferlik
  /// Non-Consumable) oluşturulmuştu; App Store bir Product ID'yi silinse bile
  /// bir daha asla yeniden kullanıma açmıyor (kalıcı "yanmış"). Bu yüzden
  /// iOS'ta v2 kimliğiyle yeni abonelik oluşturuldu.
  ///
  /// Android: orijinal `rutin_pro_monthly`. Play Console'da bu kimlik SAĞLAM —
  /// doğru tipte (otomatik yenilenen abonelik) ve etkin bir temel planla zaten
  /// tanımlı. Android'de yanma yaşanmadığı için orijinal kimlik korunur;
  /// böylece Play tarafında yeni bir abonelik oluşturmaya gerek kalmaz.
  /// iOS'ta aylık abonelik App Store Connect'te SONUNDA NOKTA olan bir
  /// kimlikle oluşturulmuş: `rutin_pro_monthly_v2.`
  ///
  /// Apple bir Product ID'yi oluşturduktan sonra değiştirmeye izin vermez,
  /// silinen kimliği de bir daha kullanıma açmaz. Yani noktayı mağaza
  /// tarafında düzeltmek mümkün değil; kodun mağazaya uyması gerekiyor.
  ///
  /// Tek bir değere sabitlemek yerine İKİ varyant da sorgulanıyor ve
  /// mağaza hangisini döndürürse o kullanılıyor: kimlik ileride düzgün
  /// olanla yeniden oluşturulursa kod kendiliğinden ona geçer, iki mağaza
  /// durumunda da çalışır.
  /// SIRA ANLAMLIDIR: mağazanın tanıdığı İLK aday kullanılır
  /// (bkz. [resolveMonthly]).
  ///
  /// `rutin_pro_monthly_v3` App Store Connect'te noktalı kimliğin yerine,
  /// aynı ayarlarla yeniden oluşturuldu ve tercih edilen kimlik odur.
  ///
  /// Noktalı `rutin_pro_monthly_v2.` listede KALIYOR ama ikinci sırada.
  /// Sebebi ucuz sigorta: yeni bir abonelik kimliği üretimde servis
  /// edilmeden önce Apple'ın onayından geçmek zorunda. v3 henüz onaylanmamış
  /// bir anda mağaza onu döndürmezse, noktalı kimlik servis edilebiliyorsa
  /// aylık plan yine satılabilir kalır. Maliyeti yalnızca `notFoundIDs`
  /// içinde fazladan bir satır.
  ///
  /// Noktasız `rutin_pro_monthly_v2` listeden ÇIKARILDI: sahadan gelen
  /// Sentry verisi (build 13/14, `notFound` etiketi) o kimliğin mağazada
  /// hiç var olmadığını gösterdi — sorgulamak boşuna gürültü.
  static const List<String> _iosMonthlyCandidates = [
    'rutin_pro_monthly_v3',
    'rutin_pro_monthly_v2.',
  ];

  static const String _androidMonthlyId = 'rutin_pro_monthly';

  static bool get _isIos =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Mağazadan gerçekten dönen aylık kimlik. Ürünler yüklenene kadar ilk
  /// aday; yükleme sonrası [_resolveMonthlyId] gerçekleşeni yazar.
  static String _monthlyId =
      _isIos ? _iosMonthlyCandidates.first : _androidMonthlyId;

  static String get monthlyId => _monthlyId;

  /// Mağazanın döndürdüğü kimliklere bakıp hangi aylık kimliğin geçerli
  /// olduğunu seçer. SAF fonksiyon — platform ve ağ bağımlılığı yok, bu
  /// yüzden doğrudan test edilebilir.
  ///
  /// Bu mantığın testi olması önemli: mağazadaki tek bir karakter farkı
  /// (sondaki nokta) yüzünden paywall günlerce hiç fiyat gösteremedi ve
  /// hiç kimse abonelik satın alamadı. Kod okumasıyla bulunması zor,
  /// testle kilitlenmesi kolay bir hata sınıfı.
  ///
  /// Mağaza hiçbir adayı tanımıyorsa [fallback] korunur — yanlış bir
  /// kimliğe geçmektense mevcut değerde kalmak daha güvenli.
  @visibleForTesting
  static String resolveMonthly(
    List<String> storeIds, {
    required bool isIos,
    required String fallback,
  }) {
    if (!isIos) return _androidMonthlyId;
    for (final candidate in _iosMonthlyCandidates) {
      if (storeIds.contains(candidate)) return candidate;
    }
    return fallback;
  }

  static void _resolveMonthlyId(List<ProductDetails> loaded) {
    _monthlyId = resolveMonthly(
      loaded.map((p) => p.id).toList(),
      isIos: _isIos,
      fallback: _monthlyId,
    );
  }

  static const String yearlyId = 'rutin_pro_yearly';

  /// ARTIK SATILMAYAN tek seferlik "ömür boyu" ürünü.
  ///
  /// Ürün üründen kaldırıldı: paywall'da gösterilmiyor, [_ids] içinde
  /// sorgulanmıyor, satın alınamıyor.
  ///
  /// Kimlik yine de BURADA DURUYOR ve bu kasıtlı: Play Console'da ürün
  /// tanımlıydı ve satın alma testi yapıldı. Daha önce satın almış biri
  /// "Satın Alımları Geri Yükle" dediğinde işlem `purchaseStream`'e düşer.
  /// [kindOf] bu kimliği tanımazsa makbuz ABONELİK olarak doğrulanır —
  /// tek seferlik üründe karşılığı olmayan bir sorgu olduğu için doğrulama
  /// başarısız olur ve kullanıcı ÖDEDİĞİ Pro'yu kaybeder.
  ///
  /// Yani bu satır bir kalıntı değil, ödemiş kullanıcı için emniyet kemeri.
  static const String legacyLifetimeId = 'rutin_pro_lifetime';

  // monthlyId platforma bağlı olduğu için _ids const olamaz.
  //
  // iOS'ta aylık kimliğin İKİ varyantı da sorgulanır (bkz.
  // _iosMonthlyCandidates); mağaza hangisini tanıyorsa onu döndürür,
  // tanımadığı notFoundIDs'e düşer ve diğer ürünleri etkilemez.
  //
  // Ömür boyu ürünü BİLEREK sorgulanmıyor — satıştan kaldırıldı.
  static Set<String> get _ids => {
        if (_isIos) ..._iosMonthlyCandidates else _androidMonthlyId,
        yearlyId,
      };

  /// Bir ürün kimliğinin doğrulama tipi: `'lifetime'` (tek seferlik,
  /// non-consumable) ya da `'subscription'` (otomatik yenilenen).
  ///
  /// Bu ayrım gelir açısından kritik: sunucu tarafı doğrulama HER ürünü
  /// abonelik sanarsa Play'in `purchases/subscriptions` uç noktasını ve
  /// Apple'ın `expires_date_ms` alanını kullanır. Tek seferlik üründe ikisi
  /// de karşılığı olmayan sorgular olduğu için doğrulama HER ZAMAN
  /// başarısız olur: kullanıcı parasını öder, "Satın alma doğrulanamadı"
  /// hatası alır ve Pro açılmaz.
  ///
  /// Ömür boyu ürünü artık SATILMIYOR ama kimlik burada hâlâ tanınıyor:
  /// daha önce satın almış birinin geri yüklemesi doğru uç noktadan
  /// doğrulansın diye (bkz. [legacyLifetimeId]).
  static String kindOf(String productId) =>
      productId == legacyLifetimeId ? 'lifetime' : 'subscription';

  /// Yapılandırılmamış durumu temsil eden varsayılan (sahte) adres.
  ///
  /// Gerçek değer `main.dart` içinde SUPABASE_URL'den türetilir. Supabase
  /// yapılandırması başarısız olursa (geçersiz URL, initialize hatası) bu
  /// değer OLDUĞU GİBİ kalır — bu yüzden ayrı bir sabit olarak tutuluyor ki
  /// "yapılandırıldı mı" sorusu güvenilir biçimde cevaplanabilsin.
  static const String unconfiguredVerifyUrl =
      'https://YOUR-PROJECT.supabase.co/functions/v1/verify-receipt';

  /// Makbuz doğrulama uç noktası.
  ///
  /// `main.dart` bunu `$SUPABASE_URL/functions/v1/verify-receipt` olarak
  /// atar. Fonksiyon; { source, productId, receipt, kind } alıp App Store /
  /// Play sunucularına karşı doğrulama yapar ve { "valid": true|false } döner.
  static String verifyReceiptUrl = unconfiguredVerifyUrl;

  /// Aboneliğin yönetildiği (iptal/plan değişikliği) mağaza sayfası.
  ///
  /// Abonelik iptali TAMAMEN mağazanın elindedir; uygulama içinden iptal
  /// edilemez. Kullanıcıyı doğru sayfaya götürmemek, "iptal edemiyorum"
  /// şikâyetlerinin ve iade taleplerinin en yaygın sebebi — App Store da
  /// abonelik yönetimine erişimi bekler (3.1.2).
  ///
  /// (`dart:io` Platform DEĞİL — proje web'i de hedefliyor, orada derlenmez.)
  static String get manageSubscriptionsUrl =>
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS)
          ? 'https://apps.apple.com/account/subscriptions'
          // Play'de paket adı verilmezse genel abonelik listesi açılır;
          // vererek doğrudan bu uygulamanın aboneliğine gidiyoruz.
          : 'https://play.google.com/store/account/subscriptions'
              '?package=com.alper.rutin';

  /// Oturum erişim token'ını döndüren sağlayıcı — `main.dart` tarafından
  /// enjekte edilir (bkz. [verifyReceiptUrl] ile aynı desen).
  ///
  /// NEDEN VAR: Makbuz doğrulama uç noktası şu anda kimlik doğrulamasız ve
  /// gelen makbuz hiçbir kullanıcıya BAĞLANMIYOR (denetim bulgusu SEC-001).
  /// Kalıcı çözüm sunucuda entitlement tutmak; bunun ilk adımı istemcinin
  /// kim olduğunu söylemesi.
  ///
  /// Token gönderilmesi MEVCUT fonksiyonu bozmaz: bugünkü sürüm
  /// `Authorization` başlığını yok sayıyor. Sunucu tarafı doğrulamayı
  /// zorunlu kıldığında (ayrı bir deploy) istemci tarafı hazır olacak.
  ///
  /// `iap.dart` bilerek Supabase'e BAĞLANMIYOR: satın alma katmanının
  /// kimlik sağlayıcısını bilmesi gerekmiyor, enjeksiyon bu ayrımı korur.
  static String? Function()? accessTokenProvider;

  /// Doğrulama adresi gerçekten yapılandırıldı mı.
  ///
  /// `false` iken satın alma doğrulanamaz; ağ hatası gibi görünen ama
  /// aslında YAPILANDIRMA hatası olan sessiz bir gelir kaybı doğar.
  static bool get verifyUrlConfigured =>
      verifyReceiptUrl != unconfiguredVerifyUrl;

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  /// Mağazaya ulaşılabiliyor mu (öykünücüde/masaüstünde false olabilir).
  bool available = false;

  /// Mağazadan yüklenen ürünler (fiyat, başlık vb. yerelleştirilmiş).
  List<ProductDetails> products = [];

  /// Ürün yükleme denemesi TAMAMLANDI mı (başarılı ya da başarısız).
  ///
  /// Arayüzün "hâlâ bekliyoruz" ile "denedik, ürün gelmedi" durumlarını
  /// ayırt etmesi için şart. Bu bilgi olmadan paywall, mağaza hiç ürün
  /// döndürmediğinde sonsuza kadar dönen bir yükleniyor göstergesinde
  /// kalıyordu: kullanıcı satın alamıyor, neden olduğunu anlamıyor ve
  /// zaten ödemiş biri "geri yükle"ye bile ulaşamıyordu.
  bool productsLoadAttempted = false;

  /// Mağazanın "böyle bir ürün yok" dediği kimlikler.
  ///
  /// Yapılandırma hatalarının tek teşhis ipucu budur: Product ID yanlış
  /// yazıldıysa, ürün reddedilmiş durumdaysa ya da Paid Apps sözleşmesi
  /// aktif değilse mağaza ürünü bulunamadı olarak döner.
  List<String> notFoundIds = const [];

  /// Satın alma akışı sürüyor mu (buton kilidi için).
  bool purchasePending = false;

  /// Kullanıcıya gösterilecek son hata mesajı (varsa). UI, gösterdikten
  /// sonra [clearError] ile temizlemeli.
  String? lastError;

  /// Pro kilidini açan callback — AppState.activatePro'ya bağlanır.
  void Function()? _onPro;

  /// Makbuz doğrulama fonksiyonu — dışarıdan verilmezse [_defaultVerify]
  /// kullanılır (Supabase Edge Function'a HTTP isteği atar).
  ReceiptVerifier? _verifyReceipt;

  ProductDetails? productFor(String id) {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Mağazadan gelen yerelleştirilmiş fiyat; yoksa [fallback].
  String priceFor(String id, String fallback) =>
      productFor(id)?.price ?? fallback;

  Future<void> init({
    void Function()? onPro,
    ReceiptVerifier? verifyReceipt,
  }) async {
    _onPro = onPro;
    _verifyReceipt = verifyReceipt;
    // isAvailable() bir platform kanalı çağrısıdır ve GERÇEK Play Billing'e
    // bağlanırken (özellikle uygulama Play'den yüklenmişse) YANIT VERMEDEN
    // asılı kalabilir — bu, main() zincirinde await edildiği için uygulamayı
    // açılış ekranında sonsuza kadar dondurur. Bu yüzden zaman aşımıyla
    // sınırlanır: yanıt gelmezse mağaza bu oturumda "yok" sayılır, uygulama
    // açılmaya devam eder.
    try {
      available =
          await _iap.isAvailable().timeout(const Duration(seconds: 5));
    } catch (e, st) {
      available = false;
      // Eskiden `catch (_)` ile sessizce yutuluyordu. Sonuç: mağaza katmanına
      // hiç ulaşılamadığında paywall "planlar yüklenemedi" gösteriyor ama
      // Sentry'ye TEK BİR KAYIT bile düşmüyordu — yani sahada satın alma
      // tamamen çalışmazken elimizde hiçbir kanıt olmuyordu.
      reportError(e, st, op: 'iap_store_unavailable');
    }
    if (!available) {
      // Zaman aşımı/istisna olmadan da false dönebilir (ör. ebeveyn
      // denetimiyle satın alma kısıtlanmış). Bu da raporlanmalı: bu durumda
      // kullanıcı HİÇBİR ŞEY satın alamaz, yani gelir sıfırdır.
      reportError(
        StateError('Mağaza katmanı kullanılamıyor (isAvailable=false)'),
        StackTrace.current,
        op: 'iap_store_unavailable',
      );
      notifyListeners();
      return;
    }
    // Bu blok main() zincirinde AWAIT ediliyor: buradan sızan bir istisna
    // `runApp`'e hiç ulaşılmamasına, yani uygulamanın açılmamasına yol açar
    // (bkz. Sentry DSN ve bildirim ikonu vakaları). Mağaza katmanı
    // çalışmasa bile uygulama çalışmalı — satın alma sonradan denenebilir.
    try {
      // Önceki oturumdan kalan / bekleyen işlemleri de yakalamak için
      // erken dinle.
      _sub = _iap.purchaseStream.listen(
        _onPurchases,
        onError: (Object _) {},
      );
      await loadProducts();
    } catch (_) {
      // Mağaza katmanı bu oturumda kullanılamıyor.
    }
    notifyListeners();
  }

  Future<void> loadProducts() async {
    try {
      // queryProductDetails de Billing'e bağlı olduğu için askıda kalabilir;
      // zaman aşımıyla sınırla (bkz. init'teki isAvailable açıklaması).
      final resp = await _iap
          .queryProductDetails(_ids)
          .timeout(const Duration(seconds: 5));
      products = resp.productDetails;
      notFoundIds = resp.notFoundIDs;
      // Aylık kimliğin hangi varyantının geçerli olduğunu mağazanın
      // cevabından öğren (bkz. _iosMonthlyCandidates).
      _resolveMonthlyId(products);
      // Mağaza cevap verdi ama HİÇ ürün yok: bu neredeyse her zaman bir
      // yapılandırma hatasıdır (Paid Apps sözleşmesi aktif değil, Product
      // ID uyuşmuyor, ürün reddedilmiş durumda). Kullanıcı satın alamaz,
      // yani doğrudan gelir kaybı — sessiz kalmamalı.
      if (products.isEmpty) {
        // Sahadaki ilk 21 olayda `notFound` HER SEFERİNDE sorulan kimliklerin
        // TAMAMINI içeriyordu — `rutin_pro_yearly` dahil, yani satın alma
        // testi yapılmış ve çalıştığı bilinen ürün de "yok" dönüyordu.
        // Buradan çıkan sonuç önemli: sorun tek bir kimliğin yazımında
        // (iOS'taki sondaki nokta) DEĞİL; mağaza sorulan hiçbir ürünü
        // tanımıyor.
        //
        // Bu iki durumu ayırt edebilmek için `allMissing` gerekiyor:
        //   true  → mağaza cevap verdi ve sorulan her kimliği reddetti.
        //           Kimlik yazımı sorunu değil, mağaza tarafında DURUM
        //           sorunu: Play'de base plan aktif değil, uygulama o hesap
        //           için o kanalda yayında değil, Paid Apps sözleşmesi
        //           onaylı değil, ya da derleme mağazadan yüklenmemiş.
        //   false → bazı kimlikler tanındı ama liste yine boş; bambaşka ve
        //           çok daha nadir bir hata sınıfı.
        //
        // `queried` olmadan `notFound` tek başına yorumlanamıyordu: neyin
        // eksik olduğunu görüyorduk ama neyin SORULDUĞUNU görmüyorduk.
        final queried = _ids.toList();
        reportError(
          StateError('Mağaza hiç ürün döndürmedi'),
          StackTrace.current,
          op: 'iap_no_products',
          tags: {
            'notFound': resp.notFoundIDs.join(','),
            'queried': queried.join(','),
            'allMissing': '${resp.notFoundIDs.toSet().containsAll(queried)}',
          },
        );
      }
    } catch (e, st) {
      products = [];
      notFoundIds = const [];
      reportError(e, st, op: 'iap_load_products');
    }
    productsLoadAttempted = true;
    notifyListeners();
  }

  /// Paywall açıldığında çağrılır: boot sırasında mağaza katmanı
  /// yüklenememişse (yanıt vermedi / zaman aşımı) bu oturumda TEKRAR dener.
  /// Ürünler zaten yüklüyse hiçbir şey yapmaz (gereksiz sorgu atmaz).
  Future<void> retryIfNeeded() async {
    if (products.isNotEmpty) return;
    try {
      available =
          await _iap.isAvailable().timeout(const Duration(seconds: 5));
    } catch (e, st) {
      available = false;
      // init()'teki aynı kör nokta: sessiz yutulursa paywall hata gösterir
      // ama hiçbir kayıt düşmez. Buradaki daha da değerli çünkü bu yol
      // KULLANICI paywall'ı açtığında çalışıyor — yani satın almaya
      // niyetlenmiş biri engellenmiş demektir.
      reportError(e, st, op: 'iap_store_unavailable', tags: {'at': 'paywall'});
    }
    if (!available) {
      reportError(
        StateError('Mağaza katmanı kullanılamıyor (isAvailable=false)'),
        StackTrace.current,
        op: 'iap_store_unavailable',
        tags: {'at': 'paywall'},
      );
      // Bu da tamamlanmış bir denemedir — aksi halde arayüz sonsuza kadar
      // "yükleniyor" gösterir.
      productsLoadAttempted = true;
      notifyListeners();
      return;
    }
    _sub ??= _iap.purchaseStream.listen(_onPurchases, onError: (Object _) {});
    await loadProducts();
  }

  /// Kullanıcının "tekrar dene" eylemi: durumu sıfırlayıp yeniden dener.
  ///
  /// [retryIfNeeded] ürünler zaten yüklüyse hiçbir şey yapmaz; burada ise
  /// kullanıcı açıkça yeniden denemek istiyor, o yüzden deneme bayrağı
  /// sıfırlanır ve arayüz tekrar "yükleniyor"a döner.
  Future<void> retryProducts() async {
    productsLoadAttempted = false;
    notifyListeners();
    await retryIfNeeded();
  }

  /// Aboneliği satın alma akışını başlatır. Sonuç purchaseStream'e düşer.
  Future<void> buy(String id) async {
    final product = productFor(id);
    if (product == null) return;
    purchasePending = true;
    lastError = null;
    notifyListeners();
    try {
      await _iap.buyNonConsumable(
          purchaseParam: PurchaseParam(productDetails: product));
    } catch (e) {
      purchasePending = false;
      lastError = 'Satın alma başlatılamadı. Lütfen tekrar deneyin.';
      notifyListeners();
    }
  }

  /// Apple'ın zorunlu tuttuğu "Satın alımları geri yükle".
  Future<void> restore() async {
    lastError = null;
    try {
      await _iap.restorePurchases();
    } catch (e) {
      lastError = 'Satın alımlar geri yüklenemedi. Lütfen tekrar deneyin.';
      notifyListeners();
    }
  }

  /// UI, hata mesajını gösterdikten (ör. SnackBar) sonra bunu çağırmalı.
  void clearError() {
    if (lastError != null) {
      lastError = null;
      notifyListeners();
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      if (p.status == PurchaseStatus.pending) {
        purchasePending = true;
      } else {
        if (p.status == PurchaseStatus.purchased ||
            p.status == PurchaseStatus.restored) {
          purchasePending = false;
          // Mağaza sinyali tek başına yeterli değil: Pro'yu açmadan önce
          // makbuzu sunucu tarafında doğrula.
          final verified = await _verify(p);
          if (verified) {
            lastError = null;
            Analytics.instance.log(Ev.purchaseSuccess, {
              'plan': p.productID,
              'kind': kindOf(p.productID),
              'restored': p.status == PurchaseStatus.restored,
            });
            _onPro?.call();
          } else {
            lastError ??=
                'Satın alma doğrulanamadı. Lütfen tekrar deneyin veya destek ile iletişime geçin.';
            // Kullanıcı ÖDEDİ ama Pro açılmadı. Bu, sessiz kaldığında
            // aylarca fark edilmeyen türden bir gelir kaybıdır (bkz. ömür
            // boyu ürün doğrulama hatası) — mutlaka ölçülmeli.
            Analytics.instance.log(Ev.purchaseFail, {
              'plan': p.productID,
              'kind': kindOf(p.productID),
              'reason': 'verification_failed',
            });
          }
        } else if (p.status == PurchaseStatus.error) {
          purchasePending = false;
          lastError = p.error?.message ??
              'Satın alma sırasında bir hata oluştu. Lütfen tekrar deneyin.';
          Analytics.instance.log(Ev.purchaseFail, {
            'plan': p.productID,
            'kind': kindOf(p.productID),
            // Hata MESAJI gönderilmez (serbest metin, mağazaya göre değişir);
            // yalnızca makine tarafından okunabilir kod.
            'reason': p.error?.code ?? 'store_error',
          });
        } else {
          // canceled
          purchasePending = false;
          Analytics.instance
              .log(Ev.purchaseCancel, {'plan': p.productID});
        }
        // Her tamamlanan (başarılı/başarısız) işlem mağazaya bildirilmeli;
        // aksi halde iOS'ta işlem kuyrukta kalır ve tekrar tekrar düşer.
        if (p.pendingCompletePurchase) {
          try {
            await _iap.completePurchase(p);
          } catch (e, st) {
            // Bildirim başarısız oldu; işlem kuyrukta kalabilir ve
            // purchaseStream'den tekrar düşer, bir sonraki denemede
            // yeniden completePurchase çağrılır. Kullanıcıya ekstra bir
            // hata göstermeye gerek yok.
            //
            // Ama sessiz de kalmamalı: completePurchase KALICI olarak
            // başarısız olursa işlem kuyruktan hiç düşmez ve mağaza aynı
            // satın almayı tekrar tekrar sunar. `debugPrint` release'te
            // hiçbir yere ulaşmadığı için bu, sahada görünmez bir arıza
            // olurdu.
            reportError(e, st, op: 'iap_complete_purchase');
          }
        }
      }
    }
    notifyListeners();
  }

  /// Makbuzu doğrular. Dışarıdan bir [_verifyReceipt] verilmişse onu,
  /// verilmemişse [verifyReceiptUrl] üzerinden varsayılan Supabase Edge
  /// Function doğrulamasını kullanır.
  Future<bool> _verify(PurchaseDetails p) {
    if (_verifyReceipt != null) return _verifyReceipt!(p);
    return _defaultVerify(p);
  }

  Future<bool> _defaultVerify(PurchaseDetails p) async {
    // Yapılandırma hatasını AĞ hatasından ayır.
    //
    // URL atanmamışsa istek sahte bir alan adına gider, DNS hatasıyla
    // düşer ve kullanıcı "sunucuya ulaşılamadı" görür — oysa sorun ağ
    // değil, yapılandırmadır. Kullanıcı ÖDEMİŞ ve Pro açılmamıştır; bu
    // ayrım yapılmazsa hata aylarca ağ sorunu sanılıp gözden kaçar.
    if (!verifyUrlConfigured) {
      lastError = 'Satın alma doğrulaması yapılandırılmadı. '
          'Ödemen alındıysa "Satın Alımları Geri Yükle" ile geri kazanabilirsin.';
      reportError(
        StateError('verifyReceiptUrl yapılandırılmadı (Supabase kurulmamış)'),
        StackTrace.current,
        op: 'iap_verify_unconfigured',
        tags: {'productId': p.productID},
      );
      return false;
    }
    try {
      // Oturum token'ı VARSA gönder. Bugünkü sunucu sürümü bunu yok sayar;
      // sunucu tarafı makbuzu kullanıcıya bağlamaya başladığında (SEC-001)
      // istemci tarafı hazır olacak. Token yoksa (anonim kullanım) istek
      // eskisi gibi başlıksız gider — davranış değişmez.
      final token = accessTokenProvider?.call();
      final res = await http
          .post(
            Uri.parse(verifyReceiptUrl),
            headers: {
              'Content-Type': 'application/json',
              if (token != null && token.isNotEmpty)
                'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'source': p.verificationData.source, // 'app_store' | 'google_play'
              'productId': p.productID,
              'receipt': p.verificationData.serverVerificationData,
              // Ürün TİPİ doğrulama yolunu belirler ve sunucuda tahmin
              // edilemez: abonelik ile tek seferlik satın alma hem Play'de
              // (subscriptions vs. products uç noktası) hem App Store'da
              // (süre kontrolü vs. sahiplik kontrolü) TAMAMEN farklı
              // doğrulanır. Tek kaynak burası olsun diye tipi istemci
              // bildiriyor.
              'kind': kindOf(p.productID),
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) {
        lastError =
            'Makbuz doğrulama sunucusu hata döndürdü (${res.statusCode}).';
        return false;
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['valid'] == true;
    } catch (e, st) {
      lastError = 'Makbuz doğrulanamadı: sunucuya ulaşılamadı.';
      // Kullanıcı ÖDEDİ ama Pro açılamadı. Ağ hatası da olabilir, Edge
      // Function arızası da — ikincisi sessiz kaldığında aylarca fark
      // edilmeyen bir gelir kaybına dönüşür (ömür boyu ürün doğrulama
      // hatasında tam olarak bu yaşandı). `e` zaten yakalanıyordu ama
      // hiçbir yere gitmiyordu.
      reportError(e, st, op: 'iap_verify');
      return false;
    }
  }

  void disposeIap() {
    _sub?.cancel();
    _sub = null;
  }
}