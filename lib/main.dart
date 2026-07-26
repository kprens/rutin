import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'ads.dart';
import 'analytics.dart';
import 'auth.dart' as auth;
import 'home_widget_service.dart' as hw;
import 'iap.dart';
import 'l10n.dart';
import 'notifications.dart';
import 'repository.dart';
import 'store.dart';
import 'ui/onboarding_screen.dart';
import 'ui/root_shell.dart';
import 'theme.dart';

/// Supabase proje bilgileri — repoya gömülmez, build-time'da verilir:
///   flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=eyJ...
/// İkisi de boşsa Supabase hiç başlatılmaz; uygulama backend'siz
/// [auth.LocalAuthService] ile çalışmaya devam eder (bkz. auth.dart).
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
const _supabaseAnonKey =
    String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

/// Sentry çökme raporlama — DSN repoya gömülmez, build-time'da verilir:
///   flutter run --dart-define=SENTRY_DSN=https://...@sentry.io/...
/// Boş bırakılırsa (varsayılan) Sentry devre dışı kalır.
const _sentryDsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');

/// Sentry trace örnekleme oranı — üretimde 0.1–0.2 arası önerilir.
///   flutter build apk --dart-define=SENTRY_TRACES_SAMPLE_RATE=0.2
/// Dart'ta `double.fromEnvironment` yoktur; String olarak alınıp parse edilir.
const _sentryTracesSampleRateRaw = String.fromEnvironment(
  'SENTRY_TRACES_SAMPLE_RATE',
  defaultValue: '0.2',
);
final double _sentryTracesSampleRate =
    double.tryParse(_sentryTracesSampleRateRaw) ?? 0.2;

Future<void> main() async {
  if (_sentryDsn.isEmpty) {
    await bootRutin();
    return;
  }
  // SON ÇARE KORUMASI: Sentry başlatma hatası UYGULAMANIN HİÇ AÇILMAMASINA
  // yol açar. Bu gerçekten yaşandı: build_release.sh, doldurulmamış
  // placeholder bir DSN'i (`https://xxxx@oXXXX...`) dart-define ile
  // geçiriyordu; Sentry.init bunu ayrıştıramayıp fırlatınca `bootRutin()`
  // hiç çalışmadı ve release build açılış ekranında sonsuza kadar takıldı
  // (debug'da dart-define verilmediği için sorun görünmüyordu). Script artık
  // placeholder DSN'i hiç geçirmiyor; burası ise ileride bozuk/erişilemez
  // bir DSN girilirse aynı felaketin tekrarlanmaması için ikinci savunma
  // hattı: Sentry başlatılamazsa uygulama Sentry'siz açılır.
  try {
    await SentryFlutter.init(
      (options) {
        options.dsn = _sentryDsn;
        options.tracesSampleRate = _sentryTracesSampleRate;
        // GİZLİLİK — bu uygulama için pazarlık konusu değil.
        //
        // Rutin, kullanıcının neyi bırakmaya çalıştığını bilen bir uygulama.
        // Bir hata raporunun yanına IP adresi, cihaz kimliği veya oturum
        // bilgisi iliştirmek, bu son derece hassas veriyi üçüncü bir tarafa
        // taşımak demektir. `sendDefaultPii` varsayılan olarak zaten false
        // ama burada AÇIKÇA yazılıyor: ileride biri varsayılanı değiştirirse
        // ya da paket sürümü değişirse sessizce açılmasın.
        options.sendDefaultPii = false;
        // Hata mesajlarının kullanıcı içeriğiyle kurulmaması bir KOD
        // kuralıdır (bkz. diagnostics.dart); burada ek bir güvence olarak
        // ekran görüntüsü eki kapalı tutuluyor — kullanıcının alışkanlık
        // adlarını doğrudan taşırdı.
        //
        // `attachViewHierarchy` de aynı riski taşır ama BİLEREK set
        // edilmiyor: API'si deneysel (analyzer uyarısı veriyor) ve
        // varsayılanı zaten false. Deneysel bir API'ye bağlanmak yerine
        // varsayılana güveniliyor; Sentry sürümü yükseltilirken bu
        // varsayılanın hâlâ false olduğu doğrulanmalı.
        options.attachScreenshot = false;
      },
      appRunner: bootRutin,
    );
  } catch (_) {
    await bootRutin();
  }
}

/// Uygulamanın gerçek başlangıcı — yeni koyu arayüzü tüm üretim altyapısıyla
/// (durum, kalıcılık, bildirimler, satın alma) ayağa kaldırır.
/// Hem [main] hem de `lib/main_ui.dart` bu fonksiyonu çağırır.
Future<void> bootRutin() async {
  WidgetsFlutterBinding.ensureInitialized();
  T.init();
  // Ana ekran widget'ı (Android App Widget + iOS WidgetKit) köprüsü —
  // App Group kimliğini ayarlar ve widget'a dokunma callback'ini kaydeder
  // (bkz. home_widget_service.dart).
  await hw.initHomeWidget();
  // Tarih yerelleştirme verisi yüklenemezse (paket verisi eksik/bozuk)
  // uygulama İngilizce varsayılan biçimlerle çalışmaya devam etmeli —
  // açılışta ölmemeli. main() zincirindeki her await bu kurala tabidir.
  try {
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en');
  } catch (_) {
    // Varsayılan biçimlerle devam edilir.
  }

  // Supabase — yapılandırılmışsa (bkz. yukarıdaki dart-define'lar) gerçek
  // Auth'u etkinleştirir. Başarısız olursa (ör. ağ yok) uygulama backend'siz
  // LocalAuthService ile çalışmaya devam eder, çökmez.
  if (_supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty) {
    try {
      // `anonKey` eskitildi; `publishableKey` ile aynı yere gidiyor
      // (paket içinde `publishableKey ?? anonKey`), yani bu yalnızca isim
      // değişikliği — mevcut anahtar aynen çalışmaya devam eder.
      await Supabase.initialize(
          url: _supabaseUrl, publishableKey: _supabaseAnonKey);
      auth.supabaseConfigured = true;
      // IAP makbuz doğrulama Edge Function'ı da aynı Supabase projesinde
      // yaşar; url'i otomatik türet (bkz. iap.dart → verifyReceiptUrl).
      Iap.verifyReceiptUrl = '$_supabaseUrl/functions/v1/verify-receipt';
    } catch (_) {
      auth.supabaseConfigured = false;
    }
  }

  final notifications = NotificationService();
  // Bildirim altyapısı başlatılamazsa (izin reddi, platform kanalı yok,
  // saat dilimi verisi bozuk vb.) uygulama BİLDİRİMSİZ çalışmaya devam
  // etmeli — burada fırlayan bir hata `runApp` satırına hiç gelinmemesine,
  // yani uygulamanın açılışta ölmesine yol açardı (Sentry'nin geçersiz DSN'i
  // yüzünden yaşanan donmanın aynısı).
  //
  // İZİN BURADA İSTENMEZ. Yalnızca altyapı kurulur.
  //
  // Eskiden `requestPermission()` de burada çağrılıyordu: kullanıcı
  // uygulamayı ilk kez açtığı anda, daha tek bir ekran görmeden sistem
  // bildirim izni diyaloğuyla karşılaşıyordu. Bağlamsız sorulan izin en
  // yüksek ret oranına sahip olandır ve iOS'ta reddedilen izin bir daha
  // uygulama içinden sorulamaz — kullanıcı Ayarlar'a gitmek zorunda kalır.
  // Bildirimler bu üründe retention'ın ana kaldıracı (hatırlatıcılar,
  // kilometre taşları, risk penceresi uyarısı) olduğu için burada kaybedilen
  // her izin doğrudan geri dönmeyen kullanıcı demek. İzin artık kullanıcı
  // onboarding'i tamamlayıp ilk alışkanlığını kurduktan SONRA, ne işe
  // yarayacağı belliyken isteniyor (bkz. store.dart → finishOnboarding).
  try {
    await notifications.init();
  } catch (_) {
    // Bildirimler devre dışı; uygulama normal çalışır.
  }

  final state =
      AppState(repo: const LocalRepository(), notifications: notifications);

  // SON SAVUNMA HATTI.
  //
  // Aşağıdaki üç adımın her biri kendi içinde zaten korumalı. Yine de hepsi
  // toplu bir try/catch'e alınmıştır: bu projede ART ARDA İKİ KEZ, açılış
  // zincirindeki korumasız tek bir await yüzünden uygulama HİÇ AÇILMADI
  // (önce Sentry'nin geçersiz DSN'i, sonra bildirim ikonu kaynağı). Ortak
  // ders şu: `runApp` satırına ulaşmak, başlangıçtaki hiçbir yan işlemden
  // daha az önemli değildir.
  //
  // Buradaki bir hata artık en kötü ihtimalle "veri yüklenemedi / mağaza
  // yok / reklam yok" demektir; kullanıcı yine de uygulamayı açar ve
  // kullanmaya devam eder. Hata Sentry'ye düşer, biz görürüz.
  // Her adım BAĞIMSIZ ve ZAMAN AŞIMLI çalışır.
  //
  // KRİTİK: Bir await'in HATA FIRLATMASI değil, HİÇ TAMAMLANMAMASI (askıda
  // kalması) da uygulamayı açılış ekranında sonsuza kadar dondurur — try/catch
  // yalnızca fırlatılan hatayı yakalar, askıda kalmayı yakalayamaz. Bu
  // gerçekten yaşandı: uygulama Play'den (internal test) yüklendiğinde
  // `Iap.instance.init()` GERÇEK Play Billing'e bağlanırken yanıt beklerken
  // asılı kaldı; `runApp` satırına hiç gelinmedi ve splash sonsuza kadar
  // dondu (yandan yüklenen release'de ve debug'da Billing tam bağlanmadığı
  // için sorun görünmüyordu). Bu yüzden her adım bir timeout ile sınırlanır:
  // katman yanıt vermezse boot devam eder, uygulama (o oturumda veri/mağaza/
  // reklam olmadan da olsa) AÇILIR. `runApp`'e ulaşmak her şeyden önemlidir.
  Future<void> runStep(Future<void> Function() step,
      {Duration limit = const Duration(seconds: 8)}) async {
    try {
      await step().timeout(limit);
    } catch (e, st) {
      // Zaman aşımı (TimeoutException) veya başka bir hata — her hâlükârda
      // Sentry'ye raporla ve devam et; bir sonraki adım yine denenir.
      unawaited(Sentry.captureException(e, stackTrace: st));
    }
  }

  // Ürün analitiği — dönüşüm hunisi ve retention ölçümü (bkz. analytics.dart).
  // Supabase yoksa sessizce devre dışı kalır. Kendi try/catch'i var ama
  // yine de runStep ile sınırlandırılıyor: ölçüm katmanı hiçbir koşulda
  // açılışı geciktiremez.
  await runStep(
    () => Analytics.instance.init(backendAvailable: auth.supabaseConfigured),
    limit: const Duration(seconds: 3),
  );
  Analytics.instance.log(Ev.appOpen);

  // boot(): kalıcı bir Supabase oturumu varsa bulut deposunu kullanır
  // (gerekirse cihazdaki veriyi ilk kez buluta taşır); yoksa yereli kullanır.
  await runStep(() => state.boot());

  // Uygulama içi satın alma — App Store / Play Billing. Mağazaya ulaşılamazsa
  // ya da Billing yanıt vermezse sessizce devre dışı kalır (paywall daha sonra
  // ürünleri tekrar yüklemeyi dener).
  await runStep(() => Iap.instance.init(onPro: state.activatePro));

  // AdMob — banner reklamlar yalnızca Pro olmayan kullanıcılara gösterilir
  // (bkz. ui/root_shell.dart).
  await runStep(() => Ads.init());

  runApp(
    ChangeNotifierProvider.value(value: state, child: const RutinApp()),
  );
}

class RutinApp extends StatelessWidget {
  const RutinApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Dil / onboarding değişince yeniden kurulması için dinle.
    final s = context.watch<AppState>();
    return MaterialApp(
      title: 'Rutin',
      debugShowCheckedModeBanner: false,
      theme: rutinLightTheme(),
      darkTheme: rutinDarkTheme(),
      // Sistem ayarına değil, kullanıcının uygulama içi "Karanlık Mod"
      // tercihine (bkz. AppState.darkMode / setDarkMode) bağlı — RC.*
      // (rutin_ui.dart) zaten aynı tercihi useDarkPalette üzerinden okuyor.
      // İkisi ayrı kaynaklardan beslenirse (sistem vs. uygulama) telefonun
      // sistem teması ile uygulama içi seçim çakışır: RC renkleri doğru
      // modda ama varsayılan Material bileşenleri (switch, menü, status
      // bar vb.) hâlâ diğer moddadır — "açık temaya geçince her şey koyu
      // temaymış gibi görünme" hatasının kaynağı buydu.
      themeMode: s.darkMode ? ThemeMode.dark : ThemeMode.light,
      home: s.onboarded ? const RootShell() : const OnboardingScreen(),
    );
  }
}
