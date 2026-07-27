// Rutin — veri bütünlüğü ve gelir akışı regresyon testleri.
//
// Buradaki testler, kullanıcının VERİSİNİ ya da PARASINI kaybettiren üç
// gerçek hatayı kalıcı olarak kilitler:
//   1. Geçici bir ağ hatasının bulut verisini silmesi (LoadResult ayrımı).
//   2. Tek bozuk bir alanın, kendisinden sonraki tüm alanları düşürmesi.
//   3. Tek seferlik ("ömür boyu") ürünün abonelik gibi doğrulanmaya
//      çalışılması — ödeme alınıp Pro'nun hiç açılmaması.

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
    test('ömür boyu ürün "lifetime" olarak işaretlenir', () {
      expect(Iap.kindOf(Iap.lifetimeId), 'lifetime');
    });

    test('abonelikler "subscription" olarak işaretlenir', () {
      expect(Iap.kindOf(Iap.yearlyId), 'subscription');
      expect(Iap.kindOf(Iap.monthlyId), 'subscription');
    });

    test('bilinmeyen ürün güvenli tarafa (abonelik) düşer', () {
      expect(Iap.kindOf('beklenmeyen_urun'), 'subscription');
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
}
