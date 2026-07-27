// Rutin — temel uygulama testleri.
//
// Platform eklentilerine (shared_preferences, bildirimler, IAP, AdMob,
// Supabase) bağımlı olmayan; modelleri, saf iş mantığını, yerelleştirmeyi
// ve temel UI bileşenlerini doğrudan test eden hafif testler. Bu sayede
// `flutter test` bir emulator/cihaz veya platform kanalı mock'lama
// gerektirmeden çalışır.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rutin/l10n.dart';
import 'package:rutin/models.dart';
import 'package:rutin/ui/home_logic.dart';
import 'package:rutin/ui/rutin_ui.dart';

void main() {
  group('Streak modeli', () {
    test('toJson/fromJson round-trip verideki alanları korur', () {
      final start = DateTime(2026, 1, 1);
      final streak = Streak(
        id: 1,
        name: 'Sigara',
        start: start,
        bestDays: 30,
        dailyCost: 45.5,
        dailyHours: 0.5,
        emoji: '🚬',
        relapses: 2,
      );

      final restored = Streak.fromJson(streak.toJson());

      expect(restored.id, streak.id);
      expect(restored.name, streak.name);
      expect(restored.start, start);
      expect(restored.bestDays, 30);
      expect(restored.dailyCost, 45.5);
      expect(restored.dailyHours, 0.5);
      expect(restored.emoji, '🚬');
      expect(restored.relapses, 2);
    });

    test('daysOrBest aktif seri ile en iyi seriden büyük olanı döner', () {
      final oldStreak = Streak(
        id: 2,
        name: 'Test',
        start: DateTime.now().subtract(const Duration(days: 5)),
        bestDays: 100,
      );
      expect(oldStreak.daysOrBest, 100);
    });
  });

  group('TaskItem modeli', () {
    test('boş days listesi her gün aktif demektir', () {
      final task = TaskItem(id: 1, name: 'Su iç');
      for (var day = 0; day < 7; day++) {
        expect(task.activeOn(day), isTrue);
      }
    });

    test('belirli günler seçiliyse yalnızca o günlerde aktif', () {
      final task = TaskItem(id: 2, name: 'Spor', days: [0, 2, 4]);
      expect(task.activeOn(0), isTrue);
      expect(task.activeOn(1), isFalse);
      expect(task.activeOn(4), isTrue);
      expect(task.activeOn(6), isFalse);
    });
  });

  group('WaterState modeli', () {
    test('toJson/fromJson round-trip verideki alanları korur', () {
      final state = WaterState(
        date: '2026-07-15',
        count: 5,
        goal: 10,
        intervalMinutes: 90,
      );

      final restored = WaterState.fromJson(state.toJson());

      expect(restored.date, '2026-07-15');
      expect(restored.count, 5);
      expect(restored.goal, 10);
      expect(restored.intervalMinutes, 90);
    });

    test('eksik alanlar makul varsayılanlara düşer', () {
      final restored = WaterState.fromJson({'date': '2026-07-15'});
      expect(restored.count, 0);
      expect(restored.goal, 8);
      expect(restored.intervalMinutes, 0);
    });
  });

  group('Yerelleştirme (t)', () {
    test('T.en false iken Türkçe metni döner', () {
      T.en = false;
      expect(t('Merhaba', 'Hello'), 'Merhaba');
    });

    test('T.en true iken İngilizce metni döner', () {
      T.en = true;
      expect(t('Merhaba', 'Hello'), 'Hello');
      T.en = false; // diğer testleri etkilememesi için sıfırla
    });
  });

  group('Home ekranı iş mantığı (home_logic)', () {
    test('greetingFor saat dilimine göre doğru selamlamayı döner', () {
      T.en = false;
      expect(greetingFor(6), 'Günaydın,');
      expect(greetingFor(11), 'Günaydın,');
      expect(greetingFor(12), 'İyi günler,');
      expect(greetingFor(17), 'İyi günler,');
      expect(greetingFor(18), 'İyi akşamlar,');
      expect(greetingFor(23), 'İyi akşamlar,');
    });

    test('progressRatio toplam sıfırken bölme hatası vermez', () {
      expect(progressRatio(0, 0), 0.0);
    });

    test('progressRatio tamamlanan/toplam oranını döner', () {
      expect(progressRatio(2, 4), 0.5);
      expect(progressRatio(4, 4), 1.0);
    });

    test('habitsRemaining negatif dönmez', () {
      expect(habitsRemaining(4, 4), 0);
      expect(habitsRemaining(1, 4), 3);
      expect(habitsRemaining(5, 4), 0);
    });

    test('longestCleanStreak listedeki en uzun aktif seriyi döner', () {
      // longestCleanStreak, Streak.days (o anki aktif seri) üzerinden
      // hesaplar — bestDays'i değil (bkz. lib/ui/home_logic.dart).
      final streaks = [
        Streak(id: 1, name: 'A', start: DateTime.now().subtract(const Duration(days: 3))),
        Streak(id: 2, name: 'B', start: DateTime.now().subtract(const Duration(days: 10))),
        Streak(id: 3, name: 'C', start: DateTime.now().subtract(const Duration(days: 1))),
      ];
      expect(longestCleanStreak(streaks), 10);
    });

    test('longestCleanStreak boş listede 0 döner', () {
      expect(longestCleanStreak(const []), 0);
    });
  });

  group('UI bileşenleri (smoke test)', () {
    testWidgets('RCard ve RButton hatasız render edilir', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const RCard(child: Text('İçerik')),
                RButton('Devam Et', onTap: () => tapped = true),
              ],
            ),
          ),
        ),
      );

      expect(find.text('İçerik'), findsOneWidget);
      expect(find.text('Devam Et'), findsOneWidget);

      await tester.tap(find.text('Devam Et'));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });
}
