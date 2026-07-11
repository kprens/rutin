/// Yerel bildirimler — sunucu gerekmez, uygulama kapalıyken de çalışır.
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'l10n.dart';
import 'models.dart';

class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();

  static const _waterIdBase = 1000; // su hatırlatıcıları 1000-1099
  static const _calIdBase = 2000; // takvim hatırlatıcıları 2000-2199
  static const _eveningIdBase = 3000; // akşam özeti 3000-3009
  static const _wakeStart = 8; // 08:00'den önce bildirim yok
  static const _wakeEnd = 22; // 22:00'den sonra bildirim yok

  Future<void> init() async {
    tzdata.initializeTimeZones();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
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
        ),
        iOS: DarwinNotificationDetails(),
      );

  Future<void> showNow(String title, String body) async {
    await _plugin.show(DateTime.now().millisecondsSinceEpoch % 100000, title, body, _details);
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
          await add(at.subtract(const Duration(minutes: 30)), '📅 ${w.name}',
              t('30 dakika sonra (${w.time}).', 'In 30 minutes (${w.time}).'));
        }
      }
      for (final e in events.where((e) => e.date == key)) {
        if (e.time.isNotEmpty) {
          final at = parseAt(day, e.time);
          if (at != null) {
            await add(at.subtract(const Duration(minutes: 30)), '📌 ${e.name}',
                t('30 dakika sonra (${e.time}).', 'In 30 minutes (${e.time}).'));
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
