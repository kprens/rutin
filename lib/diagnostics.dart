/// Hata teşhisi — sessizce yutulan hataları görünür kılar.
///
/// NEDEN VAR: Kod tabanında 60'tan fazla `catch (_) {}` bloğu vardı. Bunların
/// bir kısmı doğru ve bilinçliydi (reklam yüklenmezse uygulama çalışmaya devam
/// etmeli), ama bir kısmı GERÇEK arızaları gizliyordu: bulut kaydının
/// başarısız olması, satın alma doğrulamasının patlaması, oturumun
/// yenilenememesi. Bunlar sessiz kaldığında kullanıcı veri kaybediyor ya da
/// ödediği şeyi alamıyor, geliştirici ise hiçbir şey öğrenmiyor.
///
/// Ürün analitiği (analytics.dart) "kullanıcı ne yaptı" sorusunu yanıtlıyor;
/// burası ise "ne bozuldu" sorusunu. İkisi ayrı yollar: analitik olayları
/// kendi Supabase tablomuza, hatalar Sentry'ye gider.
///
/// GİZLİLİK: Rutin bir bağımlılık bırakma uygulaması. Hata raporlarına ASLA
/// kullanıcı içeriği (alışkanlık adı, mektup metni, e-posta) konmaz.
/// [reportError] yalnızca sabit bir işlem adı ve enum benzeri etiketler kabul
/// eder; hata mesajının kendisi de kullanıcı verisiyle kurulmamalıdır.
library;

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Yutulmuş ama önemli bir hatayı raporlar.
///
/// [op] neyin başarısız olduğunu anlatan SABİT bir tanımlayıcıdır
/// ('cloud_save', 'iap_verify' gibi) — asla kullanıcı verisinden türetilmez.
///
/// Bu fonksiyon hiçbir koşulda fırlatmaz ve çağıranı bekletmez: teşhis
/// katmanı, teşhis etmeye çalıştığı akışı bozamaz.
/// Cihazın çevrimdışı olmasından kaynaklanan, BEKLENEN bir hata mı.
///
/// Bunlar arıza değil, uygulamanın zaten öngördüğü durumdur: bulut okunamaz,
/// yerel önbelleğe düşülür, veri güvendedir ve kullanıcıya
/// [AppState.dataUnavailable] üzerinden bilgi verilir.
///
/// Neden filtreleniyor: metroya giren tek bir kullanıcı, her okuma/yazma
/// denemesinde bir Sentry olayı üretiyordu. Bu gürültü GERÇEK arızaları
/// (satın alma doğrulaması patlaması, veri bozulması) görünmez hale getirir.
/// Gözlemlenebilirlikte asıl mesele olay toplamak değil, sinyali korumaktır.
///
/// `dart:io`'ya BAĞLANMAZ (`error is SocketException` yazılamaz): bu proje
/// web'i de hedefliyor ve orada `dart:io` derlenmez. Bu yüzden tip yerine
/// mesaj eşleştirmesi yapılıyor — kırılgan ama taşınabilir.
///
/// [TimeoutException] BİLEREK dışarıda: açılış adımlarının zaman aşımına
/// uğraması (bkz. main.dart → runStep, `boot_step` etiketi) gerçek bir teşhis
/// sinyalidir, çevrimdışılık değil. Onu susturmak asıl aradığımız bilgiyi
/// yok ederdi.
bool isOfflineError(Object error) {
  final s = error.toString();
  return s.contains('SocketException') ||
      s.contains('Failed host lookup') ||
      s.contains('No address associated with hostname') ||
      s.contains('Network is unreachable') ||
      s.contains('Connection refused') ||
      s.contains('Connection reset by peer') ||
      s.contains('Connection closed before full header was received') ||
      _isTransientBackendError(s);
}

/// Sunucunun GEÇİCİ olarak yanıt verememesi.
///
/// Sahadan gelen örnek (Sentry RUTIN-9, build 20):
///   PostgrestException(message: , code: 504, details: Gateway Timeout)
///
/// Bu, çevrimdışılıkla aynı sınıfta: kullanıcının ağı da uygulamanın kodu da
/// sağlam, karşı taraf o an cevap vermiyor. Geliştiricinin yapabileceği bir
/// şey yok, ama olay olarak raporlanınca gerçek hataların arasında gürültü
/// yaratıyor ve "20 kullanıcıda hata var" gibi yanıltıcı bir tablo çiziyor.
///
/// Yok sayılmıyor — çevrimdışılıkta olduğu gibi BREADCRUMB olarak kaydediliyor;
/// sonradan gerçek bir hata düşerse "o sırada arka uç 504 veriyordu" bilgisi
/// izlerde duruyor.
///
/// 5xx'in tamamı değil, yalnızca GEÇİCİ olanlar: 500 (Internal Server Error)
/// ve 501 bilinçli olarak DIŞARIDA — onlar sunucu tarafında gerçek bir hatayı
/// gösterir ve görülmesi gerekir.
bool _isTransientBackendError(String s) {
  if (!s.contains('code: 502') &&
      !s.contains('code: 503') &&
      !s.contains('code: 504')) {
    return false;
  }
  return s.contains('Gateway Timeout') ||
      s.contains('Bad Gateway') ||
      s.contains('Service Unavailable') ||
      s.contains('PostgrestException') ||
      s.contains('StorageException');
}

void reportError(
  Object error,
  StackTrace? stack, {
  required String op,
  Map<String, String>? tags,
}) {
  // Debug'da konsola yaz — geliştirirken Sentry'ye gitmesine gerek yok.
  if (kDebugMode) {
    debugPrint('[$op] $error');
  }
  // Çevrimdışılık olay değil, İZ (breadcrumb) olarak kaydedilir.
  //
  // Tamamen yok saymıyoruz: sonradan gerçek bir hata raporlanırsa, izlerde
  // "o sırada ağ yoktu" bilgisi görünür ve teşhisi kolaylaştırır.
  if (isOfflineError(error)) {
    try {
      unawaited(Sentry.addBreadcrumb(Breadcrumb(
        category: 'network',
        message: 'offline · $op',
        level: SentryLevel.info,
      )));
    } catch (_) {
      // Sentry yoksa sessizce geç.
    }
    return;
  }
  try {
    // DSN verilmemişse Sentry başlatılmamıştır; bu çağrı sessizce no-op olur.
    unawaited(Sentry.captureException(
      error,
      stackTrace: stack,
      withScope: (scope) {
        scope.setTag('op', op);
        tags?.forEach(scope.setTag);
      },
    ));
  } catch (_) {
    // Sentry yoksa/başlatılmadıysa sessizce geç.
  }
}

/// `unawaited` için küçük yardımcı — dart:async'i tüm çağrı yerlerine
/// import ettirmemek için.
void unawaited(Future<void> f) {
  f.catchError((_) {
    // Raporlama başarısız oldu; yapacak bir şey yok.
  });
}
