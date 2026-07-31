// Rutin — başarım (rozet) değerlendirme testleri.
//
// NEDEN VAR: `evaluateBadges` rozetlerin kazanılıp kazanılmadığına gerçek
// kullanıcı verisine bakarak karar veriyor ve bu mantık HİÇ test edilmiyordu
// (ui_logic.dart kapsamı %0'dı). Buradaki bir hata sessizdir: kullanıcı hak
// ettiği rozeti görmez ya da hak etmediğini görür — ikisi de ürünün ödül
// döngüsünü bozar ve fark edilmesi zordur.
//
// Testler eşik değerlerinin İKİ YANINI da kontrol ediyor: eşiğin altında
// kazanılmamalı, eşikte kazanılmalı. Tek yönlü test, "her zaman true dönen"
// bir hatayı yakalayamaz.

import 'package:flutter_test/flutter_test.dart';

import 'package:rutin/models.dart';
import 'package:rutin/notifications.dart';
import 'package:rutin/repository.dart';
import 'package:rutin/store.dart';
import 'package:rutin/ui/ui_logic.dart';

class _NullRepository implements Repository {
  @override
  Future<LoadResult> loadAll() async => const LoadResult.missing();

  @override
  Future<void> saveAll(Map<String, dynamic> data) async {}
}

AppState _state() => AppState(
      repo: _NullRepository(),
      notifications: NotificationService(),
    );

/// Rozeti adıyla bulur — sıraya bağlı test kırılgan olurdu.
EarnedBadge _badge(List<EarnedBadge> all, String name) =>
    all.firstWhere((b) => b.name == name);

bool _earned(AppState s, String name) => _badge(evaluateBadges(s), name).earned;

void main() {
  group('evaluateBadges — boş durum', () {
    test('hiçbir veri yokken hiçbir rozet kazanılmış görünmez', () {
      final badges = evaluateBadges(_state());
      expect(badges.where((b) => b.earned), isEmpty,
          reason: 'yeni kullanıcı hiçbir rozeti hak etmiş olamaz');
    });

    test('rozetlerin tamamı her zaman listelenir, kazanılmayanlar dahil', () {
      // Kazanılmayanlar da gösteriliyor (hedef göstermek için); listeden
      // düşerlerse kullanıcı neyi hedefleyeceğini göremez.
      //
      // Sayı sabitlenmiyor — rozet eklemek meşru bir ürün değişikliği ve
      // testin buna takılması gereksiz gürültü olur. Kilitlenen şey
      // listenin BOŞ OLMAMASI ve adların benzersizliği.
      final badges = evaluateBadges(_state());
      expect(badges, isNotEmpty);
      expect(badges.map((b) => b.name).toSet().length, badges.length,
          reason: 'aynı adlı iki rozet arayüzde ayırt edilemez');
    });
  });

  group('İlk Adım — herhangi bir görev tamamlanınca', () {
    test('hiç tamamlanan yoksa kazanılmaz', () {
      final s = _state()..doneByDate = {'2026-07-30': []};
      expect(_earned(s, 'İlk Adım'), isFalse);
    });

    test('boş olmayan tek bir gün yeter', () {
      final s = _state()..doneByDate = {'2026-07-30': [1]};
      expect(_earned(s, 'İlk Adım'), isTrue);
    });
  });

  group('Su Deposu — 10 gün hedefi tutturma', () {
    AppState withWaterDays(int daysAtGoal, {int goal = 8}) {
      final s = _state();
      s.water = WaterState(date: todayKey(), goal: goal);
      s.waterByDate = {
        for (var i = 0; i < daysAtGoal; i++) '2026-07-${i + 1}': goal,
      };
      return s;
    }

    test('9 gün yetmez', () {
      expect(_earned(withWaterDays(9), 'Su Deposu'), isFalse);
    });

    test('10 gün kazandırır', () {
      expect(_earned(withWaterDays(10), 'Su Deposu'), isTrue);
    });

    test('hedefin ALTINDA kalan günler sayılmaz', () {
      final s = _state();
      s.water = WaterState(date: todayKey(), goal: 8);
      s.waterByDate = {for (var i = 0; i < 20; i++) '2026-07-${i + 1}': 7};
      expect(_earned(s, 'Su Deposu'), isFalse,
          reason: 'hedefin altındaki gün "hedef tutturuldu" sayılamaz');
    });
  });

  group('Dumansız — ada göre eşleşme + 30 gün', () {
    AppState withStreak(String name, int daysAgo) {
      final s = _state();
      s.streaks = [
        Streak(
            id: 1,
            name: name,
            start: DateTime.now().subtract(Duration(days: daysAgo))),
      ];
      return s;
    }

    test('sigara serisi 30 günü doldurunca kazanılır', () {
      expect(_earned(withStreak('Sigara', 30), 'Dumansız'), isTrue);
    });

    test('İngilizce ad da eşleşir', () {
      expect(_earned(withStreak('Smoking', 30), 'Dumansız'), isTrue);
    });

    test('29 gün yetmez', () {
      expect(_earned(withStreak('Sigara', 29), 'Dumansız'), isFalse);
    });

    test('ilgisiz adlı seri 30 gün olsa bile kazandırmaz', () {
      expect(_earned(withStreak('Kahve', 300), 'Dumansız'), isFalse,
          reason: 'rozet ada göre eşleşiyor; her seri onu kazandıramaz');
    });
  });

  group('Geri Dönüş — nüksetme sonrası', () {
    test('nüksetme yoksa kazanılmaz', () {
      final s = _state()
        ..streaks = [Streak(id: 1, name: 'Sigara', start: DateTime.now())];
      expect(_earned(s, 'Geri Dönüş'), isFalse);
    });

    test('nüksetme sayısı > 0 ise kazanılır', () {
      final s = _state()
        ..streaks = [
          Streak(id: 1, name: 'Sigara', start: DateTime.now(), relapses: 1),
        ];
      expect(_earned(s, 'Geri Dönüş'), isTrue);
    });

    test('en iyi serinin altına düşmek de geri dönüş sayılır', () {
      // relapses alanı işaretlenmemiş olsa bile, aktif seri en iyiden
      // küçükse bir kopma yaşanmış demektir.
      final s = _state()
        ..streaks = [
          Streak(
              id: 1,
              name: 'Sigara',
              start: DateTime.now().subtract(const Duration(days: 2)),
              bestDays: 40),
        ];
      expect(_earned(s, 'Geri Dönüş'), isTrue);
    });
  });

  group('Kumbara — 500 birikim', () {
    AppState withSaved(double perDay, int days) {
      final s = _state();
      s.streaks = [
        Streak(
            id: 1,
            name: 'Sigara',
            start: DateTime.now().subtract(Duration(days: days)),
            dailyCost: perDay),
      ];
      return s;
    }

    test('500 altında kazanılmaz', () {
      expect(_earned(withSaved(10, 49), 'Kumbara'), isFalse);
    });

    test('500 ve üstünde kazanılır', () {
      expect(_earned(withSaved(10, 50), 'Kumbara'), isTrue);
    });

    test('birden fazla seri toplanır', () {
      final s = _state();
      s.streaks = [
        Streak(
            id: 1,
            name: 'Sigara',
            start: DateTime.now().subtract(const Duration(days: 30)),
            dailyCost: 10),
        Streak(
            id: 2,
            name: 'Alkol',
            start: DateTime.now().subtract(const Duration(days: 30)),
            dailyCost: 10),
      ];
      expect(_earned(s, 'Kumbara'), isTrue,
          reason: 'birikim tek seriden değil, hepsinin toplamından');
    });
  });

  // ÜRÜN BULGUSU — bu test bir hatayı KİLİTLEMİYOR, belgeliyor.
  //
  // "Erkenci" rozeti `evaluateBadges` içinde sabit `false` ile veriliyor.
  // Yani hiçbir kullanıcı, ne yaparsa yapsın onu kazanamaz. Sebep veri
  // eksikliği: tamamlama kayıtları yalnızca GÜN bazında tutuluyor
  // (`doneByDate`: tarih -> [görev id]), saat bilgisi hiç yok — dolayısıyla
  // "sabah 7'den önce" koşulu mevcut şemayla hesaplanamıyor.
  //
  // Bu test, davranış değiştiğinde (rozet ya kaldırıldığında ya da
  // gerçekten hesaplanır hale geldiğinde) DÜŞER ve kararın bilinçli
  // verilmesini sağlar.
  group('Erkenci rozeti şu an kazanılamıyor (bilinen ürün eksiği)', () {
    test('en yoğun veriyle bile kazanılmıyor', () {
      final s = _state()
        ..doneByDate = {
          for (var i = 1; i <= 60; i++) '2026-06-${i.toString().padLeft(2, '0')}': [1, 2, 3],
        }
        ..tasks = [
          TaskItem(id: 1, name: 'Sabah sporu'),
          TaskItem(id: 2, name: 'Meditasyon'),
          TaskItem(id: 3, name: 'Kitap oku'),
        ];
      expect(_earned(s, 'Erkenci'), isFalse,
          reason: 'sabit false — tamamlama saati hiç kaydedilmiyor');
    });
  });
}
