// Rutin — erişilebilirlik testleri.
//
// Bu testler "güzel görünüyor mu" sorusunu değil, ölçülebilir erişilebilirlik
// garantilerini kontrol eder:
//   • Ekran okuyucu bileşenleri doğru tanıyor mu (buton mu, anahtar mı, açık
//     mı kapalı mı)
//   • Dokunma hedefleri platform minimumlarını karşılıyor mu (48dp)
//   • Dinamik yazı boyutu büyütüldüğünde düzen taşıyor mu
//
// Erişilebilirlik regresyonları gözle fark edilmez — kimse her değişiklikten
// sonra TalkBack açıp tüm ekranları gezmez. Bu yüzden testle kilitleniyor.

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rutin/ui/rutin_ui.dart';

/// Bileşeni gerçek bir MaterialApp içinde, istenen yazı ölçeğiyle kurar.
Widget _host(Widget child, {double textScale = 1.0}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  group('RButton — ekran okuyucu', () {
    testWidgets('buton olarak duyurulur ve etiketi taşır', (tester) async {
      await tester.pumpWidget(_host(RButton('Hesap Oluştur', onTap: () {})));

      final node = tester.getSemantics(find.byType(RButton));
      expect(node.flagsCollection.isButton, isTrue,
          reason: 'ekran okuyucu "düğme" demeli');
      expect(node.label, 'Hesap Oluştur');
    });

    testWidgets('onTap null iken devre dışı olarak duyurulur', (tester) async {
      await tester.pumpWidget(_host(const RButton('Devre dışı')));

      final node = tester.getSemantics(find.byType(RButton));
      expect(node.flagsCollection.isEnabled, Tristate.isFalse);
    });
  });

  group('RSwitch — ekran okuyucu ve dokunma hedefi', () {
    testWidgets('açık/kapalı durumu duyurulur', (tester) async {
      await tester.pumpWidget(
          _host(RSwitch(value: true, onChanged: (_) {})));
      expect(
        tester
            .getSemantics(find.byType(RSwitch))
            .flagsCollection.isToggled,
        Tristate.isTrue,
      );

      await tester.pumpWidget(
          _host(RSwitch(value: false, onChanged: (_) {})));
      expect(
        tester
            .getSemantics(find.byType(RSwitch))
            .flagsCollection.isToggled,
        Tristate.isFalse,
        reason: 'durum yalnızca renkle değil, semantikle de anlatılmalı',
      );
    });

    testWidgets('dokunma hedefi en az 48dp yüksekliğinde', (tester) async {
      await tester.pumpWidget(_host(RSwitch(value: false, onChanged: (_) {})));

      final size = tester.getSize(find.byType(RSwitch));
      expect(size.height, greaterThanOrEqualTo(48.0),
          reason: 'Android 48dp / iOS 44pt minimumu');
    });

    testWidgets('dokunma 48dp alanın herhangi bir yerinden çalışır',
        (tester) async {
      var toggled = false;
      await tester.pumpWidget(
          _host(RSwitch(value: false, onChanged: (_) => toggled = true)));

      // Görsel anahtar 30dp; en üst kenara (görselin DIŞINA) dokun.
      final rect = tester.getRect(find.byType(RSwitch));
      await tester.tapAt(Offset(rect.center.dx, rect.top + 2));
      await tester.pump();

      expect(toggled, isTrue,
          reason: 'genişletilmiş dokunma alanı gerçekten dokunmayı yakalamalı');
    });
  });

  group('Dinamik yazı boyutu', () {
    testWidgets('RButton büyük yazı ölçeğinde taşmaz', (tester) async {
      // iOS ve Android'de kullanıcı yazıyı 2x'e kadar büyütebilir; sabit
      // yükseklikli butonlarda bu, sarı-siyah "overflow" şeridine yol açar.
      await tester.pumpWidget(_host(
        SizedBox(
          width: 200,
          child: RButton('Satın Almaları Geri Yükle', onTap: () {}),
        ),
        textScale: 2.0,
      ));

      expect(tester.takeException(), isNull,
          reason: '2x yazı ölçeğinde düzen taşmamalı');
    });

    testWidgets('RButton 3x ölçekte bile çökmez', (tester) async {
      await tester.pumpWidget(_host(
        SizedBox(width: 160, child: RButton('Uzun bir buton metni', onTap: () {})),
        textScale: 3.0,
      ));
      expect(tester.takeException(), isNull);
    });
  });

  group('Dekoratif ikonlar', () {
    testWidgets('IconTile ekran okuyucudan gizlenir', (tester) async {
      await tester.pumpWidget(_host(const IconTile(Icons.settings)));

      // İkonun kendisi bir ExcludeSemantics'in İÇİNDE olmalı — aksi halde
      // ekran okuyucu her satırda anlamsız bir ikon düğümü okur ve listede
      // gezinmek iki kat uzun sürer.
      //
      // (findsWidgets, findsOneWidget değil: MaterialApp/Scaffold kendi
      // içinde de ExcludeSemantics kullanıyor, sayıya değil kapsamaya
      // bakıyoruz.)
      expect(
        find.ancestor(
          of: find.byIcon(Icons.settings),
          matching: find.byType(ExcludeSemantics),
        ),
        findsWidgets,
      );
    });
  });
}
