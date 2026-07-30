// Rutin — SERİ (streak) hesabı testleri.
//
// NEDEN BU DOSYA: Seri sayısı bu uygulamanın çekirdek ürün değeri. Kullanıcı
// 200 günlük serisine bakarak devam ediyor. Hesap yanlış olsa kimse hata
// mesajı görmez — sadece sayı yanlış çıkar ve kullanıcı güvenini kaybeder.
// Bu mantığın hiç testi yoktu.
//
// Özellikle iki davranış sessizce bozulmaya çok müsait:
//   1. Bugün henüz işaretlenmemişse seri DÜNDEN sayılır (gün bitmedi
//      toleransı). Bu olmadan kullanıcı her sabah serisinin sıfırlandığını
//      görürdü.
//   2. Görevin aktif OLMADIĞI günler seriyi KIRMAZ. Hafta içi alışkanlığı
//      hafta sonu "kaçırılmış" sayılmamalı.

import 'package:flutter_test/flutter_test.dart';

import 'package:rutin/models.dart';
import 'package:rutin/notifications.dart';
import 'package:rutin/repository.dart';
import 'package:rutin/store.dart';

class _FakeRepository implements Repository {
  @override
  Future<LoadResult> loadAll() async => const LoadResult.missing();
  @override
  Future<void> saveAll(Map<String, dynamic> data) async {}
}

AppState _state() =>
    AppState(repo: _FakeRepository(), notifications: NotificationService());

/// [daysAgo] gün önceki tarihin `doneByDate` anahtarı.
String _key(int daysAgo) {
  final d = DateTime.now().subtract(Duration(days: daysAgo));
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

void main() {
  group('taskStreak — her gün aktif görev', () {
    test('hiç kayıt yoksa seri 0', () {
      final s = _state();
      final task = TaskItem(id: 1, name: 'Su iç');
      expect(s.taskStreak(task), 0);
    });

    test('bugün işaretliyse bugün de sayılır', () {
      final s = _state();
      final task = TaskItem(id: 1, name: 'Su iç');
      s.doneByDate[_key(0)] = [1];
      expect(s.taskStreak(task), 1);
    });

    test('bugün İŞARETLENMEMİŞSE dünden sayılır — gün bitmedi toleransı', () {
      // Bu tolerans olmadan kullanıcı her sabah serisinin sıfırlandığını
      // görür ve uygulamayı bırakır.
      final s = _state();
      final task = TaskItem(id: 1, name: 'Su iç');
      s.doneByDate[_key(1)] = [1];
      s.doneByDate[_key(2)] = [1];
      s.doneByDate[_key(3)] = [1];
      expect(s.taskStreak(task), 3,
          reason: 'bugün boş olsa da dünden geriye 3 gün kesintisiz');
    });

    test('zincir kırıldığı yerde durur', () {
      final s = _state();
      final task = TaskItem(id: 1, name: 'Su iç');
      s.doneByDate[_key(0)] = [1];
      s.doneByDate[_key(1)] = [1];
      // 2 gün önce YOK -> seri burada kesilmeli
      s.doneByDate[_key(3)] = [1];
      s.doneByDate[_key(4)] = [1];
      expect(s.taskStreak(task), 2);
    });

    test('başka görevin işareti bu görevin serisini saymaz', () {
      final s = _state();
      final task = TaskItem(id: 1, name: 'Su iç');
      s.doneByDate[_key(0)] = [99]; // farklı görev
      expect(s.taskStreak(task), 0);
    });
  });

  group('taskStreak — güne özel görev (aktif olmayan gün seriyi KIRMAZ)', () {
    test('aktif olmayan günler atlanır, seri korunur', () {
      final s = _state();
      // Görev YALNIZCA bugünün hafta gününde aktif -> yani haftada bir.
      final today = DateTime.now();
      final onlyToday = mondayIndex(today);
      final task = TaskItem(id: 5, name: 'Haftalık', days: [onlyToday]);

      // Bugün ve tam 7/14 gün önce işaretli; aradaki 6 gün görev aktif
      // olmadığı için seriyi kırmamalı.
      s.doneByDate[_key(0)] = [5];
      s.doneByDate[_key(7)] = [5];
      s.doneByDate[_key(14)] = [5];

      expect(s.taskStreak(task), 3,
          reason: 'aktif olmayan günler atlanmalı, seri 3 hafta');
    });

    test('aktif gün kaçırıldıysa seri kırılır', () {
      final s = _state();
      final today = DateTime.now();
      final task = TaskItem(id: 5, name: 'Haftalık', days: [mondayIndex(today)]);

      s.doneByDate[_key(0)] = [5];
      // 7 gün önce (aktif gün) İŞARETLENMEMİŞ
      s.doneByDate[_key(14)] = [5];

      expect(s.taskStreak(task), 1);
    });
  });

  group('taskStreak önbelleği — bayat değer döndürmemeli', () {
    // Önbellek performans için var (bkz. store.dart _streakCache) ama veri
    // değiştiğinde temizlenmezse kullanıcı işaretleme yaptığı hâlde eski
    // seriyi görür. Sessiz ve kafa karıştırıcı bir hata sınıfı.
    test('toggleTask sonrası seri güncellenir', () {
      final s = _state();
      final task = TaskItem(id: 1, name: 'Su iç');
      s.tasks.add(task);

      expect(s.taskStreak(task), 0); // önbelleğe 0 yazıldı

      s.toggleTask(task); // bugünü işaretle -> önbellek temizlenmeli

      expect(s.taskStreak(task), 1,
          reason: 'önbellek temizlenmediyse hâlâ 0 döner');
    });

    test('aynı görev iki kez okunduğunda aynı sonucu verir', () {
      final s = _state();
      final task = TaskItem(id: 1, name: 'Su iç');
      s.doneByDate[_key(1)] = [1];
      expect(s.taskStreak(task), s.taskStreak(task));
    });
  });

  group('maxHabitStreak — en uzun aktif seri', () {
    test('görev yoksa 0', () {
      expect(_state().maxHabitStreak, 0);
    });

    test('en uzun seriyi döndürür', () {
      final s = _state();
      final a = TaskItem(id: 1, name: 'A');
      final b = TaskItem(id: 2, name: 'B');
      s.tasks.addAll([a, b]);

      // A: 1 gün, B: 3 gün
      s.doneByDate[_key(1)] = [1, 2];
      s.doneByDate[_key(2)] = [2];
      s.doneByDate[_key(3)] = [2];

      expect(s.taskStreak(a), 1);
      expect(s.taskStreak(b), 3);
      expect(s.maxHabitStreak, 3);
    });
  });
}
