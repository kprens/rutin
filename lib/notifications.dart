/// Yerel bildirimler — sunucu gerekmez, uygulama kapalıyken de çalışır.
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'l10n.dart';
import 'models.dart';

class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();

  static const _waterIdBase = 1000; // su hatırlatıcıları 1000-1099
  static const _calIdBase = 2000; // takvim hatırlatıcıları 2000-2199
  static const _eveningIdBase = 3000; // akşam özeti 3000-3009
  static const _weeklyIdBase = 4000; // haftalık rapor 4000-4007
  static const _riskIdBase = 5000; // risk penceresi uyarıları 5000-5013
  static const _wakeStart = 8; // 08:00'den önce bildirim yok
  static const _wakeEnd = 22; // 22:00'den sonra bildirim yok

  Future<void> init() async {
    tzdata.initializeTimeZones();
    // Cihazın yerel saat dilimini ayarla; alınamazsa Europe/Istanbul'a düş.
    // Bu yapılmadan tz.local'a erişince LateInitializationError fırlar.
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
    }
    // ÖNEMLİ: Bildirim küçük ikonu için uygulamanın TAM RENKLİ launcher
    // ikonunu (@mipmap/ic_launcher) DEĞİL, ayrı bir BEYAZ SİLUET kullanmak
    // gerekir — Android, API 21+'da bildirim ikonunun sadece alfa kanalını
    // alıp tek renkli (genelde beyaz) çizer; renkli bir ikon verilirse
    // sonuç bozuk/eski bir logoya benziyormuş gibi görünebilir. Bu yüzden
    // assets/icon/icon_fg.png'den üretilmiş beyaz siluet
    // (android/app/src/main/res/mipmap-*/ic_notification.png) kullanılıyor.
    // KAYNAK YOLU KRİTİK: flutter_local_notifications, Android tarafında
    // bildirim ikonunu DRAWABLE olarak çözer
    // (resources.getIdentifier(name, "drawable", package)). İkon yalnızca
    // mipmap altında dururken `@mipmap/ic_notification` verilmişti ve
    // çalışma anında
    //   PlatformException(invalid_icon, The resource @mipmap/ic_notification
    //   could not be found...)
    // fırlatıyordu — üstelik bu istisna load() → applyNotificationSettings
    // zincirinde uygulamanın AÇILIŞINI engelliyordu (Sentry'de fatal olarak
    // yakalandı). Artık ikon drawable-* altında ve önek olmadan, sade
    // kaynak adıyla veriliyor.
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
      // İzinleri BURADA isteme.
      //
      // DarwinInitializationSettings'in varsayılanları üç izni de `true`
      // yapar; yani `initialize()` çağrısı iOS'ta bildirim iznini AÇILIŞTA
      // sorar. Bu, izni onboarding sonrasına taşıma kararını (bkz.
      // store.dart → _requestNotificationsAfterOnboarding) sessizce boşa
      // çıkarıyordu: kullanıcı uygulamayı görmeden, bağlamsız bir istem
      // alıyordu — iPad'de splash ekranının üstünde doğrulandı.
      //
      // Bağlamsız sorulan izin çok daha sık reddedilir ve iOS aynı istemi
      // BİR DAHA göstermez; reddedilen kullanıcı hatırlatma alamaz.
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings);
  }

  Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          'rutin_main',
          'Hatırlatıcılar',
          channelDescription: 'Su ve görev hatırlatıcıları',
          importance: Importance.high,
          priority: Priority.high,
          // Sade kaynak adı — '@mipmap/...' öneki DEĞİL (bkz. init()'teki not).
          icon: 'ic_notification',
        ),
        iOS: DarwinNotificationDetails(),
      );

  /// Anlık bildirim. Hata durumunda SESSİZCE yutulur: bu, görev tamamlama
  /// ve su hedefi gibi normal kullanıcı akışlarının ortasından çağrılıyor —
  /// bir bildirim hatası kullanıcının görevini işaretlemesini engellememeli.
  Future<void> showNow(String title, String body) async {
    try {
      await _plugin.show(
          DateTime.now().millisecondsSinceEpoch % 100000, title, body, _details);
    } catch (_) {
      // Bildirim gösterilemedi; uygulama akışı etkilenmez.
    }
  }

  /// Tüm zamanlanmış hatırlatıcıları (su + takvim + akşam özeti) iptal eder.
  /// Bildirim ayarları kapatıldığında AppState buradan geçer.
  Future<void> cancelAllReminders() async {
    for (var i = 0; i < 100; i++) {
      await _plugin.cancel(_waterIdBase + i);
    }
    for (var i = 0; i < 200; i++) {
      await _plugin.cancel(_calIdBase + i);
    }
    for (var i = 0; i < 10; i++) {
      await _plugin.cancel(_eveningIdBase + i);
    }
    for (var i = 0; i < 8; i++) {
      await _plugin.cancel(_weeklyIdBase + i);
    }
    for (var i = 0; i < 14; i++) {
      await _plugin.cancel(_riskIdBase + i);
    }
  }

  /// Risk penceresi uyarısı — kullanıcının kişisel deseninden çıkan riskli
  /// saatten 1 SAAT ÖNCE hatırlatır.
  ///
  /// Bu, ürünün en yüksek değerli anıdır: kullanıcı düşmeden ÖNCE müdahale.
  /// Analiz yalnızca ekranda kalırsa değerinin çoğunu kaybeder — insanlar
  /// riskli anlarında uygulamayı açmayı akıl edemez, uygulamanın onlara
  /// gitmesi gerekir.
  ///
  /// [weekday] verilmişse (0 = Pazartesi) yalnızca o gün, verilmemişse her
  /// gün kurulur. Önümüzdeki 14 gün için planlanır; uygulama her açıldığında
  /// zincir tazelenir.
  ///
  /// Ton kritik: uyarı korkutucu değil, hazırlayıcı olmalı. "Düşeceksin"
  /// değil, "planın ne?" der.
  Future<void> scheduleRiskWindow({
    required int hourStart,
    int? weekday,
    required String streakName,
  }) async {
    for (var i = 0; i < 14; i++) {
      await _plugin.cancel(_riskIdBase + i);
    }
    final now = tz.TZDateTime.now(tz.local);
    // Riskli saatten 1 saat önce uyar.
    final alertHour = (hourStart - 1 + 24) % 24;
    var id = 0;

    for (var offset = 0; offset < 14 && id < 14; offset++) {
      final day = now.add(Duration(days: offset));
      if (weekday != null && ((day.weekday - 1) % 7) != weekday) continue;
      final at =
          tz.TZDateTime(tz.local, day.year, day.month, day.day, alertHour, 0);
      if (at.isBefore(now)) continue;
      await _plugin.zonedSchedule(
        _riskIdBase + id,
        t('Yaklaşan bir pencere var', 'A tricky window is coming'),
        t('Genelde bu saatlerde zorlanıyorsun. Planın ne? "$streakName" için hazırlıklı ol.',
            'This is usually a hard stretch for you. What\'s your plan for "$streakName"?'),
        at,
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      id++;
    }
  }

  /// Haftalık rapor bildirimi: her PAZAR 10:00.
  ///
  /// Bu, aboneliğin en güçlü tutundurma mekanizmasıdır — düzenli, beklenen
  /// bir teslimat ("pazar sabahı raporum gelir") iptal kararını en çok
  /// geciktiren şeydir. Önümüzdeki 8 pazar için kurulur; uygulama her
  /// açıldığında zincir tazelendiği için hiç bitmez.
  Future<void> scheduleWeeklyReport() async {
    for (var i = 0; i < 8; i++) {
      await _plugin.cancel(_weeklyIdBase + i);
    }
    final now = tz.TZDateTime.now(tz.local);
    var id = 0;
    for (var offset = 0; offset < 56 && id < 8; offset++) {
      final day = now.add(Duration(days: offset));
      if (day.weekday != DateTime.sunday) continue;
      final at = tz.TZDateTime(tz.local, day.year, day.month, day.day, 10, 0);
      if (at.isBefore(now)) continue;
      await _plugin.zonedSchedule(
        _weeklyIdBase + id,
        t('📊 Haftalık raporun hazır', '📊 Your weekly report is ready'),
        t('Geçen hafta neler başardığına bak.',
            'See what you pulled off last week.'),
        at,
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      id++;
    }
  }

  /// Su hatırlatıcılarını kurar: önümüzdeki 48 saat için, uyanık saatler
  /// (08–22) içinde, [intervalMinutes] aralıklarla bildirim planlar.
  /// Uygulama her açıldığında yeniden kurulduğu için zincir hep taze kalır.
  /// [intervalMinutes] 0 ise tümünü iptal eder.
  Future<void> scheduleWaterReminders(int intervalMinutes) async {
    for (var i = 0; i < 100; i++) {
      await _plugin.cancel(_waterIdBase + i);
    }
    if (intervalMinutes <= 0) return;

    var when = tz.TZDateTime.now(tz.local).add(Duration(minutes: intervalMinutes));
    var id = 0;
    final horizon = tz.TZDateTime.now(tz.local).add(const Duration(hours: 48));

    while (when.isBefore(horizon) && id < 100) {
      if (when.hour >= _wakeStart && when.hour < _wakeEnd) {
        await _plugin.zonedSchedule(
          _waterIdBase + id,
          t('💧 Su zamanı!', '💧 Water time!'),
          t('Bir bardak su içmeyi unutma.', 'Don\'t forget to drink a glass of water.'),
          when,
          _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        id++;
      }
      when = when.add(Duration(minutes: intervalMinutes));
    }
  }

  /// Akşam özeti: her gün 21:00.
  /// Bugünkü bildirim, uygulamanın son bilinen durumunu içerir;
  /// sonraki günler için genel bir hatırlatma kurulur (uygulama her
  /// açıldığında zincir tazelendiği için içerik güncel kalır).
  Future<void> scheduleEveningSummary(String todayBody) async {
    for (var i = 0; i < 10; i++) {
      await _plugin.cancel(_eveningIdBase + i);
    }
    final now = tz.TZDateTime.now(tz.local);
    for (var offset = 0; offset < 7; offset++) {
      final day = now.add(Duration(days: offset));
      final at = tz.TZDateTime(tz.local, day.year, day.month, day.day, 21, 0);
      if (at.isBefore(now)) continue;
      await _plugin.zonedSchedule(
        _eveningIdBase + offset,
        offset == 0
            ? t('🌙 Günün özeti', '🌙 Daily summary')
            : t('🌙 Gün bitmeden', '🌙 Before the day ends'),
        offset == 0
            ? todayBody
            : t('Görevlerini işaretle, su hedefini tamamla — serini koru! 💪',
                'Check off your tasks, hit your water goal — keep the streak! 💪'),
        at,
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  /// Takvim hatırlatıcıları: önümüzdeki 7 gün için, saatli haftalık program
  /// ögelerine ve randevulara başlamadan 30 dk önce bildirim planlar.
  /// Saati olmayan randevular için o gün 09:00'da hatırlatır.
  /// Veri her değiştiğinde ve uygulama her açıldığında yeniden kurulur.
  Future<void> scheduleCalendarReminders(
      List<WeeklyItem> weekly, List<EventItem> events) async {
    for (var i = 0; i < 200; i++) {
      await _plugin.cancel(_calIdBase + i);
    }

    final now = tz.TZDateTime.now(tz.local);
    var id = 0;

    tz.TZDateTime? parseAt(DateTime day, String time) {
      if (time.isEmpty) return null;
      final p = time.split(':');
      if (p.length != 2) return null;
      return tz.TZDateTime(
          tz.local, day.year, day.month, day.day, int.parse(p[0]), int.parse(p[1]));
    }

    Future<void> add(tz.TZDateTime at, String title, String body) async {
      if (at.isBefore(now) || id >= 200) return;
      await _plugin.zonedSchedule(
        _calIdBase + id,
        title,
        body,
        at,
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      id++;
    }

    for (var offset = 0; offset < 7; offset++) {
      final day = DateTime.now().add(Duration(days: offset));
      final dow = (day.weekday - 1) % 7;
      final key =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

      for (final w in weekly.where((w) => w.day == dow && w.time.isNotEmpty)) {
        final at = parseAt(day, w.time);
        if (at != null) {
          // İki ayrı bildirim: 1 saat önce + tam etkinlik saatinde.
          await add(at.subtract(const Duration(hours: 1)), '📅 ${w.name}',
              t('1 saat sonra (${w.time}).', 'In 1 hour (${w.time}).'));
          await add(at, '📅 ${w.name}',
              t('Şimdi (${w.time}).', 'Now (${w.time}).'));
        }
      }
      for (final e in events.where((e) => e.date == key)) {
        if (e.time.isNotEmpty) {
          final at = parseAt(day, e.time);
          if (at != null) {
            await add(at.subtract(const Duration(hours: 1)), '📌 ${e.name}',
                t('1 saat sonra (${e.time}).', 'In 1 hour (${e.time}).'));
            await add(at, '📌 ${e.name}',
                t('Şimdi (${e.time}).', 'Now (${e.time}).'));
          }
        } else {
          await add(
              tz.TZDateTime(tz.local, day.year, day.month, day.day, 9, 0),
              t('📌 Bugün: ${e.name}', '📌 Today: ${e.name}'),
              t('Bugün için planlanmış.', 'Planned for today.'));
        }
      }
    }
  }
}
