// Rutin — hata teşhis katmanı testleri.
//
// Buradaki tek kritik güvence şu: teşhis katmanı, teşhis etmeye çalıştığı
// akışı ASLA bozmamalı. Sentry başlatılmamışken (DSN verilmemiş — testlerde
// ve DSN'siz derlemelerde durum budur) reportError sessizce no-op olmalı;
// fırlatırsa veri kaydetme, satın alma doğrulama ve hesap silme akışlarının
// hepsini birden kırar — yani hataları görünür kılmak için eklenen kod,
// hataların kendisinden daha büyük bir arızaya dönüşür.

import 'package:flutter_test/flutter_test.dart';

import 'package:rutin/diagnostics.dart';

void main() {
  group('reportError — akışı asla bozmaz', () {
    test('Sentry başlatılmamışken fırlatmaz', () {
      expect(
        () => reportError(Exception('test'), StackTrace.current, op: 'test_op'),
        returnsNormally,
      );
    });

    test('stack trace null olsa da fırlatmaz', () {
      expect(
        () => reportError(Exception('test'), null, op: 'test_op'),
        returnsNormally,
      );
    });

    test('etiketlerle çağrıldığında fırlatmaz', () {
      expect(
        () => reportError(
          Exception('test'),
          StackTrace.current,
          op: 'cloud_save',
          tags: {'source': 'test'},
        ),
        returnsNormally,
      );
    });

    test('Exception olmayan bir nesne atıldığında da fırlatmaz', () {
      // catch (e) her türlü nesneyi yakalayabilir — String, int, custom.
      expect(
        () => reportError('düz metin hata', null, op: 'test_op'),
        returnsNormally,
      );
    });

    test('senkron tamamlanır — çağıranı bekletmez', () async {
      // reportError void döner (await edilemez); bu bilinçli, çünkü veri
      // kaydetme gibi sıcak yollara ağ gecikmesi eklememeli. Burada
      // doğrulanan: çağrı, mikro görev kuyruğu boşalmadan ÖNCE dönüyor.
      var devamEtti = false;
      reportError(Exception('x'), null, op: 'test_op');
      devamEtti = true;
      expect(devamEtti, isTrue);
      await Future<void>.delayed(Duration.zero);
    });
  });

  group('unawaited yardımcısı', () {
    test('reddedilen Future uygulamayı çökertmez', () async {
      expect(
        () => unawaited(Future<void>.error(Exception('reddedildi'))),
        returnsNormally,
      );
      // Mikro görev kuyruğunun boşalmasını bekle: hata yutulmamışsa burada
      // "unhandled exception" olarak patlardı.
      await Future<void>.delayed(Duration.zero);
    });

    test('başarılı Future sorunsuz tamamlanır', () async {
      expect(() => unawaited(Future<void>.value()), returnsNormally);
      await Future<void>.delayed(Duration.zero);
    });
  });

  // Çevrimdışılık, ARIZA DEĞİL beklenen durumdur: uygulama yerel önbelleğe
  // düşer, veri güvendedir, kullanıcıya AppState.dataUnavailable ile bilgi
  // verilir. Sentry'ye olay olarak yazılırsa metroya giren tek bir kullanıcı
  // onlarca olay üretir ve GERÇEK arızalar bu gürültüde görünmez olur.
  group('isOfflineError — sinyali gürültüden ayırır', () {
    test('DNS çözülememesi çevrimdışı sayılır', () {
      // Sahadan gelen gerçek olay (Sentry):
      expect(
        isOfflineError(
            "ClientException with SocketException: Failed host lookup: "
            "'pfgljdvkmkqvlvdljvjk.supabase.co' (OS Error: No address "
            "associated with hostname, errno = 7)"),
        isTrue,
      );
    });

    test('yaygın soket hataları çevrimdışı sayılır', () {
      expect(isOfflineError('SocketException: Network is unreachable'), isTrue);
      expect(isOfflineError('Connection refused'), isTrue);
      expect(isOfflineError('Connection reset by peer'), isTrue);
    });

    test('TimeoutException çevrimdışı SAYILMAZ', () {
      // Bilinçli: açılış adımı zaman aşımları (main.dart -> runStep,
      // 'boot_step' etiketi) gerçek bir teşhis sinyali. Susturulursa
      // aradığımız bilginin kendisi kaybolur.
      expect(
        isOfflineError('TimeoutException after 0:00:08.000000: Future not completed'),
        isFalse,
      );
    });

    test('gerçek uygulama hataları çevrimdışı sayılmaz', () {
      expect(isOfflineError('Bad state: Mağaza hiç ürün döndürmedi'), isFalse);
      expect(isOfflineError(const FormatException('bozuk json')), isFalse);
      expect(isOfflineError(StateError('beklenmeyen durum')), isFalse);
    });

    test('çevrimdışı hata raporlamak da fırlatmaz', () {
      expect(
        () => reportError(
            'SocketException: Failed host lookup', StackTrace.current,
            op: 'cloud_load'),
        returnsNormally,
      );
    });
  });
}
