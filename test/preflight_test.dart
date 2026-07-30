// Rutin — MAĞAZA ÖN KONTROLÜ.
//
// NEDEN VAR: Bu uygulama App Store'dan üç kez reddedildi ve her ret bir
// build + inceleme döngüsü (günler) maliyet çıkardı. Retlerin ortak yanı
// şuydu: hepsi gönderimden ÖNCE, kod okunarak tespit edilebilirdi.
//
//   • Guideline 4 (Design) — ATT izin metni Info.plist'e sabit Türkçe
//     yazılmıştı, yerelleştirme dosyası yoktu. İnceleyicinin cihazı
//     İngilizceydi: uygulama İngilizce açıldı, izin penceresi Türkçe çıktı.
//   • Guideline 2.1(b) — paywall ürünleri yükleyemiyordu.
//   • Guideline 3.1.2 — metadata'da EULA bağlantısı eksikti.
//
// Buradaki testler o hataların TEKRARINI engeller. CI'da her push'ta
// çalışırlar; yani hata Apple'dan değil, iki dakika içinde bilgisayardan
// öğrenilir.
//
// YENİ BİR MAĞAZA REDDİ ALINDIĞINDA: sebebini buraya bir test olarak ekle.
// Bu dosyanın değeri, geçmiş hataların bir daha geçmemesidir.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Info.plist'ten `NS...UsageDescription` anahtarlarını çıkarır.
Set<String> _usageDescriptionKeys(String plist) {
  final re = RegExp(r'<key>(NS\w*UsageDescription)</key>');
  return re.allMatches(plist).map((m) => m.group(1)!).toSet();
}

/// Bir `InfoPlist.strings` dosyasındaki tanımlı anahtarları çıkarır.
Set<String> _stringsKeys(String contents) {
  final re = RegExp(r'"([A-Za-z]\w*)"\s*=');
  return re.allMatches(contents).map((m) => m.group(1)!).toSet();
}

void main() {
  group('iOS izin metinleri — Guideline 4 (Design) reddinin tekrarını önler', () {
    final plistFile = File('ios/Runner/Info.plist');
    final lprojDir = Directory('ios/Runner');

    test('Info.plist okunabiliyor', () {
      expect(plistFile.existsSync(), isTrue,
          reason: 'ios/Runner/Info.plist bulunamadı');
    });

    test('her izin metni İÇİN her dilde çeviri var', () {
      final keys = _usageDescriptionKeys(plistFile.readAsStringSync());

      // İzin metni yoksa kontrol edilecek bir şey de yok — ama bu durumda
      // testin sessizce "geçmesi" yanıltıcı olurdu, o yüzden açıkça belirt.
      if (keys.isEmpty) {
        markTestSkipped('Info.plist içinde NS*UsageDescription yok');
        return;
      }

      final lprojs = lprojDir
          .listSync()
          .whereType<Directory>()
          .where((d) => d.path.endsWith('.lproj'))
          // Base.lproj storyboard'lar içindir, metin barındırmaz.
          .where((d) => !d.path.endsWith('Base.lproj'))
          .toList();

      expect(lprojs, isNotEmpty,
          reason: 'Hiç yerelleştirme klasörü yok. İzin metinleri cihaz '
              'dilini takip etmez ve uygulamanın dilinden farklı görünür — '
              'App Store bunu Guideline 4 altında reddediyor.');

      final missing = <String>[];
      for (final dir in lprojs) {
        final f = File('${dir.path}/InfoPlist.strings');
        if (!f.existsSync()) {
          missing.add('${dir.path}/InfoPlist.strings (dosya yok)');
          continue;
        }
        final defined = _stringsKeys(f.readAsStringSync());
        for (final key in keys) {
          if (!defined.contains(key)) {
            missing.add('$key → ${dir.path}');
          }
        }
      }

      expect(missing, isEmpty,
          reason: 'Şu izin metinlerinin çevirisi eksik:\n'
              '  ${missing.join('\n  ')}\n'
              'Info.plist\'e NS*UsageDescription eklerken TÜM .lproj '
              'klasörlerine de eklenmeli.');
    });

    test('desteklenen diller Xcode projesinde kayıtlı (knownRegions)', () {
      final pbx = File('ios/Runner.xcodeproj/project.pbxproj');
      expect(pbx.existsSync(), isTrue);
      final contents = pbx.readAsStringSync();

      final lprojNames = lprojDir
          .listSync()
          .whereType<Directory>()
          // .lproj FİLTRESİ ŞART: bu klasörde Assets.xcassets gibi başka
          // dizinler de var; filtresiz bırakılırsa onlar "dil" sanılır.
          .where((d) => d.path.endsWith('.lproj'))
          .map((d) => d.path.split('/').last.replaceAll('.lproj', ''))
          .where((n) => n != 'Base')
          .toList();

      expect(lprojNames, isNotEmpty);

      final region = RegExp(r'knownRegions = \(([^)]*)\)').firstMatch(contents);
      expect(region, isNotNull, reason: 'knownRegions bulunamadı');
      final known = region!.group(1)!;

      for (final lang in lprojNames) {
        expect(known.contains(lang), isTrue,
            reason: '$lang.lproj var ama knownRegions içinde kayıtlı değil — '
                'Xcode bu dili paketlemez ve çeviri hiç kullanılmaz.');
      }
    });
  });

  group('Abonelik ürün kimlikleri — Guideline 2.1(b) reddinin tekrarını önler', () {
    // Mağazadaki tek karakterlik bir fark (sondaki nokta) paywall'ı tamamen
    // kilitledi ve ret sebebi oldu. Kimliklerin kodda TEK yerde ve
    // görünür olması, mağazayla karşılaştırmayı mümkün kılar.
    test('ürün kimlikleri kodda tek kaynakta tanımlı', () {
      final iap = File('lib/iap.dart').readAsStringSync();
      expect(iap.contains('_iosMonthlyCandidates'), isTrue,
          reason: 'Aylık kimlik adayları listesi kaldırılmış. Mağazadaki '
              'kimlik değişirse kod sessizce ürün bulamaz.');
      expect(iap.contains("'rutin_pro_yearly'"), isTrue);
      // Ömür boyu ürünü satıştan kaldırıldı; kimlik yalnızca eski
      // alıcıların geri yüklemesi için duruyor (bkz. legacyLifetimeId).
      expect(iap.contains('legacyLifetimeId'), isTrue,
          reason: 'eski alıcıların geri yükleme koruması kaldırılmış');
    });
  });

  group('Yasal bağlantılar — Guideline 3.1.2 reddinin tekrarını önler', () {
    test('paywall gizlilik ve kullanım koşulları bağlantılarını içeriyor', () {
      final paywall = File('lib/ui/paywall_screen.dart').readAsStringSync();
      expect(paywall.contains('_legalLinks'), isTrue,
          reason: 'Abonelik sunulan ekranda yasal bağlantılar ZORUNLU '
              '(App Store 3.1.2).');
    });

    test('yasal bağlantılar ürünler yüklenemediğinde de gösteriliyor', () {
      // Gerçek olay: ürünler yüklenmediğinde erken dönüş yüzünden yasal
      // bağlantılar ve "geri yükle" ekranda hiç görünmüyordu — inceleyicinin
      // gördüğü ekran tam olarak buydu.
      final paywall = File('lib/ui/paywall_screen.dart').readAsStringSync();
      final unavailable = paywall.indexOf('_plansUnavailable');
      expect(unavailable, greaterThan(-1),
          reason: 'Ürünler yüklenemediğinde gösterilen durum kaldırılmış.');
      final body = paywall.substring(paywall.indexOf('Widget _plansUnavailable'));
      expect(body.contains('_legalLinks'), isTrue,
          reason: 'Hata durumunda yasal bağlantılar gösterilmiyor.');
      expect(body.contains('restore'), isTrue,
          reason: 'Hata durumunda "Satın Alımları Geri Yükle" gösterilmiyor — '
              'zaten ödemiş kullanıcı çıkmazda kalır.');
    });
  });
}
