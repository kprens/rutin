// Rutin — veri bütünlüğü ve gelir akışı regresyon testleri.
//
// Buradaki testler, kullanıcının VERİSİNİ ya da PARASINI kaybettiren üç
// gerçek hatayı kalıcı olarak kilitler:
//   1. Geçici bir ağ hatasının bulut verisini silmesi (LoadResult ayrımı).
//   2. Tek bozuk bir alanın, kendisinden sonraki tüm alanları düşürmesi.
//   3. Ürün tipinin yanlış belirlenmesi — ödeme alınıp Pro'nun hiç açılmaması.

import 'package:flutter_test/flutter_test.dart';

import 'package:rutin/iap.dart';
import 'package:rutin/models.dart';
import 'package:rutin/notifications.dart';
import 'package:rutin/repository.dart';
import 'package:rutin/store.dart';

/// Testlerde kullanılan, platform kanalına hiç dokunmayan sahte depo.
class _FakeRepository implements Repository {
  _FakeRepository(this.result);

  LoadResult result;
  Map<String, dynamic>? lastSaved;
  int saveCount = 0;

  @override
  Future<LoadResult> loadAll() async => result;

  @override
  Future<void> saveAll(Map<String, dynamic> data) async {
    lastSaved = data;
    saveCount++;
  }
}

AppState _stateWith(LoadResult result) => AppState(
      repo: _FakeRepository(result),
      notifications: NotificationService(),
    );

void main() {
  group('LoadResult — "veri yok" ile "okunamadı" ayrımı', () {
    test('missing: kayıt gerçekten yok, hata değil', () {
      const r = LoadResult.missing();
      expect(r.failed, isFalse);
      expect(r.data, isNull);
    });

    test('failure: okuma başarısız — veri VAR olabilir', () {
      const r = LoadResult.failure();
      expect(r.failed, isTrue);
      expect(r.data, isNull);
    });

    test('found: veri geldi', () {
      const r = LoadResult.found({'onboarded': true});
      expect(r.failed, isFalse);
      expect(r.data, isNotNull);
    });

    // Bu ayrım olmadan boot(), ağ hatasını "yeni hesap" sanıp cihazdaki boş
    // veriyi buluta yazıyor ve kullanıcının verisini kalıcı olarak siliyordu.
    test('failure ile missing birbirinden ayırt edilebilir', () {
      const failure = LoadResult.failure();
      const missing = LoadResult.missing();
      expect(failure.failed == missing.failed, isFalse);
    });
  });

  group('AppState.load — bozuk alan dayanıklılığı', () {
    test('tek bozuk alan sonraki alanları DÜŞÜRMEZ', () async {
      // `proTrialUntilMs` bilerek bozuk (String). Eski kodda bu, kendisinden
      // sonra okunan `onboarded` / `userName` / `themeId` alanlarının hiç
      // yüklenmemesine yol açıyordu: kullanıcı verisini kaybetmiş gibi
      // onboarding'e geri düşüyordu.
      final s = _stateWith(const LoadResult.found({
        'proTrialUntilMs': 'bozuk-veri',
        'onboarded': true,
        'userName': 'Alperen',
        'themeId': 'gece',
      }));

      await s.load();

      expect(s.proTrialUntilMs, isNull, reason: 'bozuk alan varsayılana düşer');
      expect(s.onboarded, isTrue, reason: 'sonraki alanlar yüklenmeye devam eder');
      expect(s.userName, 'Alperen');
      expect(s.themeId, 'gece');
    });

    test('bozuk liste alanı yalnızca kendini boşaltır', () async {
      final s = _stateWith(const LoadResult.found({
        'streaks': 'liste-değil',
        'userName': 'Deniz',
        'onboarded': true,
      }));

      await s.load();

      expect(s.streaks, isEmpty);
      expect(s.userName, 'Deniz');
      expect(s.onboarded, isTrue);
    });

    test('JSON round-trip sonrası double olan sayılar okunabilir', () async {
      // Buluta yazılıp geri okunan sayılar double'a dönüşebilir; `as int`
      // bunda fırlıyordu.
      final s = _stateWith(const LoadResult.found({
        'createdAtMs': 1700000000000.0,
        'weeklyReportsSeen': 3.0,
        'onboarded': true,
      }));

      await s.load();

      expect(s.createdAtMs, 1700000000000);
      expect(s.weeklyReportsSeen, 3);
      expect(s.onboarded, isTrue);
    });

    test('veri hiç yoksa varsayılanlar korunur', () async {
      final s = _stateWith(const LoadResult.missing());
      await s.load();
      expect(s.onboarded, isFalse);
      expect(s.streaks, isEmpty);
      expect(s.isPro, isFalse);
    });

    test('sağlam veri eksiksiz yüklenir', () async {
      final s = _stateWith(LoadResult.found({
        'onboarded': true,
        'userName': 'Ece',
        'isPro': true,
        'streaks': [
          Streak(id: 7, name: 'Sigara', start: DateTime(2026, 1, 1)).toJson(),
        ],
      }));

      await s.load();

      expect(s.onboarded, isTrue);
      expect(s.userName, 'Ece');
      expect(s.isPro, isTrue);
      expect(s.streaks.single.name, 'Sigara');
    });
  });

  group('Iap.kindOf — ürün tipi doğrulama yolunu belirler', () {
    // Ömür boyu ürün abonelik gibi doğrulanınca (Play'de subscriptions uç
    // noktası, Apple'da expires_date_ms) doğrulama HER ZAMAN başarısız
    // oluyordu: kullanıcı ödüyor, Pro açılmıyordu.
    test('abonelikler "subscription" olarak işaretlenir', () {
      expect(Iap.kindOf(Iap.yearlyId), 'subscription');
      expect(Iap.kindOf(Iap.monthlyId), 'subscription');
    });

    test('bilinmeyen ürün güvenli tarafa (abonelik) düşer', () {
      expect(Iap.kindOf('beklenmeyen_urun'), 'subscription');
    });

    // iOS'ta aylık abonelik App Store Connect'te SONUNDA NOKTA olan bir
    // kimlikle oluşturulmuş ve Apple Product ID değiştirmeye izin vermiyor.
    // Her iki varyant da abonelik olarak doğrulanmalı; 'lifetime' yoluna
    // düşerse makbuz yanlış uç noktaya sorulur ve satın alma açılmaz.
    test('noktalı ve noktasız aylık kimlik de abonelik sayılır', () {
      expect(Iap.kindOf('rutin_pro_monthly_v3'), 'subscription');
      expect(Iap.kindOf('rutin_pro_monthly_v2.'), 'subscription');
      expect(Iap.kindOf('rutin_pro_monthly'), 'subscription');
    });
  });

  // Makbuz doğrulama adresi yapılandırılmadıysa bu, AĞ hatası gibi
  // görünmemeli: kullanıcı ödemiş ve Pro açılmamış olur.
  group('Makbuz doğrulama adresi yapılandırması', () {
    tearDown(() => Iap.verifyReceiptUrl = Iap.unconfiguredVerifyUrl);

    test('atanmamış varsayılan adres "yapılandırılmadı" sayılır', () {
      Iap.verifyReceiptUrl = Iap.unconfiguredVerifyUrl;
      expect(Iap.verifyUrlConfigured, isFalse);
    });

    test('gerçek adres atanınca yapılandırılmış sayılır', () {
      Iap.verifyReceiptUrl =
          'https://pfgljdvkmkqvlvdljvjk.supabase.co/functions/v1/verify-receipt';
      expect(Iap.verifyUrlConfigured, isTrue);
    });
  });

  // Okuma amaçlı getter'lar kalıcı state'i DEĞİŞTİRMEMELİ.
  //
  // `todaysDone` ve `todaysWaterLog` eskiden `putIfAbsent` ile bugünün
  // anahtarını oluşturuyordu. Bu getter'lar `build()` içinden de okunduğu
  // için çizim sırasında kalıcı veri yazılıyordu ve hiçbir şey yapılmayan
  // günler için boş kayıtlar birikiyordu. Bu kayıtlar `dailyRollover`
  // içindeki 400 anahtarlık budama kotasını tüketip GERÇEK geçmişin erken
  // silinmesine yol açıyordu.
  group('Getter yan etkisi — okumak kalıcı state yazmamalı', () {
    test('todaysDone okumak doneByDate\'e boş kayıt EKLEMEZ', () {
      final s = _stateWith(const LoadResult.missing());
      expect(s.doneByDate, isEmpty);
      s.todaysDone; // yalnızca okuma
      expect(s.doneByDate, isEmpty,
          reason: 'okuma, budama kotasını tüketen boş kayıt yaratmamalı');
    });

    test('todaysWaterLog okumak waterLog\'a boş kayıt EKLEMEZ', () {
      final s = _stateWith(const LoadResult.missing());
      expect(s.waterLog, isEmpty);
      s.todaysWaterLog; // yalnızca okuma
      expect(s.waterLog, isEmpty);
    });

    test('kayıt yokken okuma boş liste döner (null değil)', () {
      final s = _stateWith(const LoadResult.missing());
      expect(s.todaysDone, isEmpty);
      expect(s.todaysWaterLog, isEmpty);
      expect(s.todaysWaterMl, 0);
    });

    test('removeWaterLog hiç kayıt yokken çökmez ve harita boş kalır', () {
      final s = _stateWith(const LoadResult.missing());
      // Okuma getter'ı artık değiştirilemez sabit liste döndürebiliyor;
      // silme yolu bu yüzden doğrudan haritadan geçmeli, aksi halde
      // burada UnsupportedError fırlardı.
      s.removeWaterLog(WaterLogEntry(ml: 250, time: '10:00'));
      expect(s.waterLog, isEmpty);
    });
  });

  // 400 GÜNLÜK BUDAMA — veri saklama sınırı.
  //
  // dailyRollover, doneByDate/waterByDate/waterLog haritalarında en yeni 400
  // anahtarı tutup gerisini siler. Bu, kullanıcının GEÇMİŞİNİ silen bir
  // işlem: yanlış çalışırsa (ör. sıralama ters olursa) en yeni veri silinir,
  // en eskisi kalır. Böyle bir hata sessizdir ve kullanıcı ancak aylar sonra
  // fark eder. Bu davranışın testi yoktu.
  group('dailyRollover — 400 günlük budama', () {
    String key(int daysAgo) {
      final d = DateTime.now().subtract(Duration(days: daysAgo));
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
    }

    test('400 anahtarın altındaysa hiçbir şey silinmez', () {
      final s = _stateWith(const LoadResult.missing());
      for (var i = 0; i < 100; i++) {
        s.doneByDate[key(i)] = [1];
      }
      s.dailyRollover();
      expect(s.doneByDate.length, 100);
    });

    test('400 anahtar aşılırsa EN ESKİler silinir, en yeniler kalır', () {
      final s = _stateWith(const LoadResult.missing());
      // 450 gün: en eski 50 tanesi budanmalı.
      for (var i = 0; i < 450; i++) {
        s.doneByDate[key(i)] = [i];
      }
      s.dailyRollover();

      expect(s.doneByDate.length, 400, reason: '400 anahtara indirilmeli');
      // En yeni gün KORUNMALI:
      expect(s.doneByDate.containsKey(key(0)), isTrue,
          reason: 'bugünün kaydı asla silinmemeli');
      expect(s.doneByDate.containsKey(key(399)), isTrue);
      // En eskiler GİTMELİ:
      expect(s.doneByDate.containsKey(key(449)), isFalse);
      expect(s.doneByDate.containsKey(key(400)), isFalse);
    });

    test('waterByDate de aynı sınıra tabi', () {
      final s = _stateWith(const LoadResult.missing());
      for (var i = 0; i < 430; i++) {
        s.waterByDate[key(i)] = i;
      }
      s.dailyRollover();
      expect(s.waterByDate.length, 400);
      expect(s.waterByDate.containsKey(key(0)), isTrue);
      expect(s.waterByDate.containsKey(key(429)), isFalse);
    });

    test('waterLog da aynı sınıra tabi', () {
      final s = _stateWith(const LoadResult.missing());
      for (var i = 0; i < 420; i++) {
        s.waterLog[key(i)] = [WaterLogEntry(ml: 250, time: '10:00')];
      }
      s.dailyRollover();
      expect(s.waterLog.length, 400);
      expect(s.waterLog.containsKey(key(0)), isTrue);
      expect(s.waterLog.containsKey(key(419)), isFalse);
    });
  });

  // AYLIK ÜRÜN KİMLİĞİ ÇÖZÜMLEME.
  //
  // Gerçek olay: App Store Connect'te aylık aboneliğin Product ID'si
  // SONUNDA NOKTA ile oluşturulmuştu (`rutin_pro_monthly_v2.`). Kod
  // noktasız kimliği arıyordu, mağaza ürünü tanımıyordu ve paywall'ın
  // `ready` koşulu ikisini birden şart koştuğu için (yearly && monthly)
  // ekran TAMAMEN kilitleniyordu — yıllık gelse bile. Günlerce hiç kimse
  // abonelik satın alamadı.
  //
  // Apple oluşturulmuş bir Product ID'yi DEĞİŞTİRMEYE izin vermiyor; çözüm
  // ürünü temiz bir kimlikle YENİDEN OLUŞTURMAK oldu: `rutin_pro_monthly_v3`
  // (v2 ile birebir aynı ayarlar, sondaki nokta yok). Noktalı kimliğin
  // App Store Connect'teki durumu "Developer Rejected" — artık aday değil.
  //
  // Aday listesi mekanizması yine de duruyor: kimlik değişimini yeni sürüm
  // çıkmadan yapabilmeyi sağlayan şey o.
  group('Iap.resolveMonthly — mağaza hangi kimliği tanıyorsa o', () {
    const v3 = 'rutin_pro_monthly_v3';
    const dotted = 'rutin_pro_monthly_v2.';

    test('mağaza v3 kimliğini döndürürse o seçilir', () {
      expect(
        Iap.resolveMonthly([v3, 'rutin_pro_yearly'],
            isIos: true, fallback: dotted),
        v3,
      );
    });

    test('noktalı eski kimlik ARTIK aday değil', () {
      // App Store Connect'te durumu "Developer Rejected" — hiçbir koşulda
      // servis edilmez. Bir süre "v3 onaylanana kadar sigorta" diye listede
      // tutuldu; işe yaramayacağı görülünce çıkarıldı. Mağaza onu döndürse
      // bile kod ona geçmemeli.
      expect(
        Iap.resolveMonthly([dotted, 'rutin_pro_yearly'],
            isIos: true, fallback: v3),
        v3,
        reason: 'satılamayan bir kimliğe geçmek aylık planı ölü gösterir',
      );
    });

    test('mağaza hiçbir adayı tanımıyorsa fallback korunur', () {
      // Yanlış bir kimliğe geçmektense mevcut değerde kalmak güvenli.
      expect(
        Iap.resolveMonthly(['rutin_pro_yearly'], isIos: true, fallback: dotted),
        dotted,
      );
      expect(Iap.resolveMonthly([], isIos: true, fallback: v3), v3);
    });

    test('Android her zaman kendi kimliğini kullanır', () {
      // Android'de "yanma" yaşanmadı; orijinal kimlik sağlam.
      expect(
        Iap.resolveMonthly([v3, dotted], isIos: false, fallback: dotted),
        'rutin_pro_monthly',
      );
    });

    test('ikisi birden dönse bile v3 seçilir', () {
      expect(
        Iap.resolveMonthly([dotted, v3], isIos: true, fallback: dotted),
        v3,
      );
    });
  });
}
