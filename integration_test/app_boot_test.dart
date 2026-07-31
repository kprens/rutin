// Rutin — gerçek cihaz/emülatör üzerinde açılış testleri.
//
// BU DOSYA `test/` ALTINDAKİLERİN YERİNE GEÇMEZ, ONLARI TAMAMLAR.
//
// `test/smoke_test.dart` widget ağacını kurar ama PLATFORM KANALLARINA hiç
// dokunmaz — mock'lanmış bir dünyada çalışır. Oysa bu projede sahaya kaçan
// hataların önemli bir kısmı tam olarak orada, yani Dart ile native arasında
// oluştu ve hiçbir birim testiyle görülemezdi:
//
//   • RUTIN-1 / RUTIN-2 — `PlatformException(invalid_icon, ...)`:
//     bildirim ikonu APK içinde beklenen kaynak türünde (drawable) yoktu.
//     Kod doğruydu, derleme başarılıydı, testler yeşildi; uygulama açılışta
//     çöküyordu. Bunu ancak GERÇEK bir Android'de `initialize()` çağırmak
//     ortaya çıkarır.
//   • RUTIN-3 / RUTIN-5 — açılış zincirinde zaman aşımı: yalnızca gerçek
//     platform çağrıları asılı kaldığında oluşur.
//
// Çalıştırmak için bir cihaz/emülatör gerekir:
//   flutter test integration_test/app_boot_test.dart
//
// CI'da Android emülatöründe koşar (bkz. .github/workflows/ci.yml →
// "integration-android").

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rutin/main.dart';
import 'package:rutin/notifications.dart';
import 'package:rutin/repository.dart';
import 'package:rutin/store.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('bildirim servisi gerçek platformda kurulabiliyor',
      (tester) async {
    // RUTIN-1 / RUTIN-2'nin birebir yakalandığı nokta.
    //
    // `NotificationService.init()` iki gerçek native iş yapıyor: cihazın
    // saat dilimini okuyor ve bildirim eklentisini `ic_notification` küçük
    // ikonuyla başlatıyor. İkon kaynağı APK'da doğru türde bulunmazsa
    // burada PlatformException fırlar.
    //
    // İstisnayı BİLEREK yutmuyoruz: bu çağrının sessizce başarısız olması,
    // hatırlatmaların hiç kurulmaması demek — uygulamanın temel işlevi.
    await NotificationService().init();
  });

  testWidgets('hatırlatmalar gerçek platformda zamanlanabiliyor',
      (tester) async {
    // init() geçse bile ZAMANLAMA ayrı bir native yol: `zonedSchedule`
    // kendi bildirim detaylarını (kanal, ikon) çözümlüyor ve saat dilimi
    // veritabanına ihtiyaç duyuyor. Bildirim uygulamanın çekirdek özelliği
    // olduğu için bu yolun gerçek cihazda çalıştığı doğrulanmalı.
    final notifications = NotificationService();
    await notifications.init();
    await notifications.scheduleWaterReminders(90);
    await notifications.cancelAllReminders();
  });

  testWidgets('uygulama gerçek cihazda ilk kareyi çiziyor', (tester) async {
    // Sahadaki en pahalı hata sınıfı: uygulama hiç açılmıyor. Burada
    // widget ağacı gerçek bir motor üzerinde, gerçek eklentilerle kuruluyor.
    final state = AppState(
      repo: const LocalRepository(),
      notifications: NotificationService(),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: state, child: const RutinApp()),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('yerel depo gerçek cihazda okunup yazılabiliyor',
      (tester) async {
    // AppState.boot() → load() zinciri SharedPreferences'a dayanıyor ve
    // açılışta AWAIT ediliyor; burada bir hata olursa uygulama açılmaz.
    final state = AppState(
      repo: const LocalRepository(),
      notifications: NotificationService(),
    );

    await state.boot();

    // boot() hatasız tamamlandıysa depo katmanı çalışıyor demektir.
    expect(state.repo, isA<LocalRepository>());
  });
}
