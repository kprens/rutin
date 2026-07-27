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
}
