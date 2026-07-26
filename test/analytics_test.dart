// Rutin — ürün analitiği testleri.
//
// En kritik test grubu PII filtresidir: Rutin bir bağımlılık bırakma
// uygulaması ve kullanıcının neyi bıraktığı, ne yazdığı, kim olduğu asla
// ölçüm verisine karışmamalı. Bu, tek tek çağrı yerlerine güvenilerek değil
// merkezî bir filtreyle garanti altına alınıyor — testler o garantiyi kilitler.

import 'package:flutter_test/flutter_test.dart';

import 'package:rutin/analytics.dart';

/// Gönderilenleri yakalayan sahte hedef.
class _CapturingSink implements AnalyticsSink {
  final List<AnalyticsEvent> sent = [];
  bool succeed = true;

  @override
  Future<bool> send(String installId, List<AnalyticsEvent> batch) async {
    if (!succeed) return false;
    sent.addAll(batch);
    return true;
  }
}

void main() {
  late _CapturingSink sink;
  late Analytics a;

  setUp(() async {
    sink = _CapturingSink();
    a = Analytics.instance;
    await a.resetForTest(sink);
  });

  group('PII filtresi — hassas veri asla gönderilmez', () {
    test('serbest metin (boşluk içeren) düşürülür', () {
      // Alışkanlık adı, kullanıcı adı, mektup metni bu kalıba girer.
      a.log('test', {'habit': 'Sigara icmeyi birakmak', 'plan': 'yearly'});
      final p = a.pendingForTest.single.params;
      expect(p.containsKey('habit'), isFalse,
          reason: 'boşluk içeren metin serbest girdi sayılır');
      expect(p['plan'], 'yearly', reason: 'enum benzeri değer geçer');
    });

    test('40 karakterden uzun metin düşürülür', () {
      a.log('test', {'note': 'a' * 41});
      expect(a.pendingForTest.single.params.containsKey('note'), isFalse);
    });

    test('liste ve map tamamen düşürülür', () {
      a.log('test', {
        'items': [1, 2, 3],
        'nested': {'k': 'v'},
        'ok': 1,
      });
      final p = a.pendingForTest.single.params;
      expect(p.containsKey('items'), isFalse);
      expect(p.containsKey('nested'), isFalse);
      expect(p['ok'], 1);
    });

    test('sayı ve bool her zaman geçer', () {
      a.log('test', {'days': 42, 'ratio': 1.5, 'restored': true});
      final p = a.pendingForTest.single.params;
      expect(p['days'], 42);
      expect(p['ratio'], 1.5);
      expect(p['restored'], isTrue);
    });

    test('null değerler atlanır', () {
      a.log('test', {'a': null, 'b': 1});
      final p = a.pendingForTest.single.params;
      expect(p.containsKey('a'), isFalse);
      expect(p['b'], 1);
    });
  });

  group('Kuyruk davranışı', () {
    test('olaylar kuyruğa alınır ve flush ile gönderilir', () async {
      a.log(Ev.paywallView, {'source': 'profile'});
      a.log(Ev.planSelect, {'plan': 'yearly'});
      expect(a.pendingForTest, hasLength(2));

      await a.flush();

      expect(sink.sent, hasLength(2));
      expect(sink.sent.first.name, Ev.paywallView);
      expect(a.pendingForTest, isEmpty);
    });

    test('gönderim başarısızsa olaylar kuyrukta KALIR', () async {
      sink.succeed = false;
      a.log(Ev.purchaseStart, {'plan': 'monthly'});

      await a.flush();

      expect(sink.sent, isEmpty);
      expect(a.pendingForTest, hasLength(1),
          reason: 'çevrimdışıyken olay kaybolmamalı');
    });

    test('kapalıyken hiçbir olay toplanmaz', () async {
      a.enabled = false;
      a.log(Ev.paywallView);
      expect(a.pendingForTest, isEmpty);
    });
  });

  group('Huni olay adları tutarlı', () {
    // Yazım hatası huniyi sessizce koparır; sabitler tek kaynak olmalı.
    test('satın alma hunisinin tüm adımları tanımlı', () {
      expect(
        [
          Ev.appOpen,
          Ev.onboardingStart,
          Ev.onboardingComplete,
          Ev.authSuccess,
          Ev.paywallView,
          Ev.planSelect,
          Ev.purchaseStart,
          Ev.purchaseSuccess,
          Ev.purchaseFail,
        ],
        everyElement(isA<String>().having((s) => s.isNotEmpty, 'boş değil', isTrue)),
      );
    });

    test('olay adları snake_case standardına uyar', () {
      final names = [
        Ev.appOpen,
        Ev.paywallView,
        Ev.paywallDismiss,
        Ev.purchaseSuccess,
        Ev.rewardedGranted,
        Ev.streakRelapse,
        Ev.habitCheck,
      ];
      for (final n in names) {
        expect(RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(n), isTrue,
            reason: '"$n" snake_case değil');
      }
    });
  });

  group('AnalyticsEvent serileştirme', () {
    test('toJson/fromJson round-trip alanları korur', () {
      final at = DateTime(2026, 7, 26, 12, 30);
      final e = AnalyticsEvent(Ev.purchaseSuccess, const {'plan': 'yearly'}, at);
      final back = AnalyticsEvent.fromJson(e.toJson());
      expect(back.name, Ev.purchaseSuccess);
      expect(back.params['plan'], 'yearly');
      expect(back.at, at);
    });
  });
}
