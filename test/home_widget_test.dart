// Rutin — ana ekran widget'ı arka plan mantığı regresyon testleri.
//
// [toggleWidgetTasks] AYRI bir Flutter izolatında çalışan
// `backgroundCallback` tarafından kullanılır. O izolatın üstünde hiçbir
// yakalayıcı yoktur: burada fırlayan bir istisna yutulmaz, widget dokunuşu
// sessizce işlenmez ve kullanıcı sebebini anlamaz.
//
// Bu yüzden fonksiyonun bozuk veriye karşı ASLA fırlatmaması gerekiyor.

import 'package:flutter_test/flutter_test.dart';

import 'package:rutin/home_widget_service.dart';
import 'package:rutin/models.dart';
import 'package:rutin/notifications.dart';
import 'package:rutin/repository.dart';
import 'package:rutin/store.dart';

void main() {
  group('toggleWidgetTasks — bozuk veriye dayanıklılık', () {
    test('nesne olmayan eleman fırlatmaz, atlanır', () {
      // Regresyon: eskiden `item as Map<String, dynamic>` çıplak cast'tı ve
      // dizideki tek bir sayı/null TypeError fırlatıyordu.
      final result = toggleWidgetTasks(
        [
          {'id': 1, 'name': 'Su iç', 'done': false},
          42, // bozuk
          null, // bozuk
          'metin', // bozuk
        ],
        1,
      );

      expect(result.doneCount, 1);
      expect((result.list.first as Map)['done'], isTrue);
      // Bozuk elemanlar korunur (veri kaybı olmaz), yalnızca atlanır.
      expect(result.list.length, 4);
    });

    test('eşleşen görevin done bayrağını çevirir', () {
      final r1 = toggleWidgetTasks([
        {'id': 7, 'done': false},
      ], 7);
      expect((r1.list.first as Map)['done'], isTrue);
      expect(r1.doneCount, 1);

      final r2 = toggleWidgetTasks(r1.list, 7);
      expect((r2.list.first as Map)['done'], isFalse);
      expect(r2.doneCount, 0);
    });

    test('eşleşmeyen id hiçbir şeyi değiştirmez', () {
      final r = toggleWidgetTasks([
        {'id': 1, 'done': true},
        {'id': 2, 'done': false},
      ], 99);
      expect(r.doneCount, 1);
      expect((r.list[0] as Map)['done'], isTrue);
      expect((r.list[1] as Map)['done'], isFalse);
    });

    // Üretimde veri HER ZAMAN jsonDecode'dan gelir, yani Map<String, dynamic>.
    // Literaller de bu tiple yazılıyor ki test gerçeği yansıtsın.
    test('done alanı eksik ya da yanlış tipteyse false sayılır', () {
      final r = toggleWidgetTasks([
        <String, dynamic>{'id': 1}, // done yok
        <String, dynamic>{'id': 2, 'done': 'evet'}, // yanlış tip
      ], 1);
      expect((r.list[0] as Map)['done'], isTrue); // false kabul edilip çevrildi
      expect(r.doneCount, 1); // 2 numaralı 'evet' bool değil -> sayılmaz
    });

    // Bu test, uygulamayı iki kez değiştirtti ve asıl değerini oradan alıyor.
    //
    // Dart'ta jenerikler kovaryant: `Map<String, int>` de
    // `is Map<String, dynamic>` kontrolünden GEÇER. Yani tip kontrolü,
    // `item['done'] = true` yazarken oluşan TypeError'ı engellemiyordu.
    // Çözüm tipi daraltmak değil, girdiyi yerinde değiştirmemek oldu.
    test('dar değer tipli harita fırlatmaz ve girdiyi bozmaz', () {
      final narrow = <String, int>{'id': 1}; // jsonDecode böyle üretmez
      late final ({List<dynamic> list, int doneCount}) r;

      expect(() => r = toggleWidgetTasks([narrow], 1), returnsNormally);

      // Kopya üzerinde doğru işlendi:
      expect(r.doneCount, 1);
      expect((r.list.first as Map)['done'], isTrue);
      // Çağıranın haritası DEĞİŞMEDİ:
      expect(narrow.containsKey('done'), isFalse);
      expect(identical(r.list.first, narrow), isFalse);
    });

    test('boş liste çökmez', () {
      final r = toggleWidgetTasks([], 1);
      expect(r.doneCount, 0);
      expect(r.list, isEmpty);
    });
  });

  // WIDGET ANLIK GÖRÜNTÜSÜ — sayaç semantiği.
  //
  // Widget en fazla 5 satır gösterir ama ÖZET GÜNÜN TAMAMINI anlatmalı.
  // Eski kod payı günün tüm tamamlananlarından, paydayı ise gösterilen
  // satır sayısından alıyordu: 8 görevden 6'sı bitmişse widget "6/5"
  // gösteriyordu. Bu testler o karışımın geri gelmesini engeller.
  group('AppState.widgetSnapshot — satırlar kırpılır, sayaç kırpılmaz', () {
    AppState stateWith({required int taskCount, required int doneCount}) {
      final s = AppState(
        repo: _NullRepository(),
        notifications: NotificationService(),
      );
      s.tasks = [
        for (var i = 1; i <= taskCount; i++) TaskItem(id: i, name: 'Görev $i'),
      ];
      s.doneByDate[todayKey()] = [for (var i = 1; i <= doneCount; i++) i];
      return s;
    }

    test('5 satırdan fazlası kırpılır', () {
      final snap = stateWith(taskCount: 8, doneCount: 6).widgetSnapshot();
      expect(snap.tasks.length, maxWidgetTasks);
    });

    test('sayaç GÜNÜN tamamını gösterir — kırpılan listeyi değil', () {
      final snap = stateWith(taskCount: 8, doneCount: 6).widgetSnapshot();
      expect(snap.doneToday, 6);
      expect(snap.totalToday, 8,
          reason: 'payda gösterilen 5 satır değil, günün tüm görevleri olmalı');
      // Regresyonun kendisi: pay paydadan büyük çıkamaz.
      expect(snap.doneToday, lessThanOrEqualTo(snap.totalToday),
          reason: 'widget "6/5" gibi anlamsız bir özet göstermemeli');
    });

    test('5 görevden azsa hepsi gösterilir ve sayaç tutar', () {
      final snap = stateWith(taskCount: 3, doneCount: 2).widgetSnapshot();
      expect(snap.tasks.length, 3);
      expect(snap.doneToday, 2);
      expect(snap.totalToday, 3);
    });

    test('tamamlanma bayrağı satır bazında doğru', () {
      final snap = stateWith(taskCount: 4, doneCount: 2).widgetSnapshot();
      expect(snap.tasks.where((t) => t.done).map((t) => t.id), [1, 2]);
      expect(snap.tasks.where((t) => !t.done).map((t) => t.id), [3, 4]);
    });
  });
}

/// Hiçbir şey yapmayan depo — bu testler yalnızca bellek içi durumu okuyor.
class _NullRepository implements Repository {
  @override
  Future<LoadResult> loadAll() async => const LoadResult.missing();

  @override
  Future<void> saveAll(Map<String, dynamic> data) async {}
}
