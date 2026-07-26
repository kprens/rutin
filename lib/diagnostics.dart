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
