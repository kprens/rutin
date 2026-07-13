/// Basit yerelleştirme: cihaz dili Türkçe ise Türkçe, değilse İngilizce.
///
/// Kullanım: `t('Merhaba', 'Hello')`
library;

import 'dart:ui';

class T {
  /// true = İngilizce göster
  static bool en = false;

  static void init() {
    en = PlatformDispatcher.instance.locale.languageCode.toLowerCase() != 'tr';
  }

  /// intl DateFormat için yerel ayar kodu.
  static String get locale => en ? 'en' : 'tr_TR';
}

/// Cihaz diline göre metin seçer.
String t(String tr, String en) => T.en ? en : tr;

/// En popüler 20 bağımlılık / bırakılmak istenen alışkanlık — (emoji, ad).
/// Hem onboarding hem de streak ekranı hazır seçenek olarak kullanır.
List<(String, String)> addictionPresets() => T.en
    ? const [
        ('🚬', 'Smoking'),
        ('🍺', 'Alcohol'),
        ('💨', 'Vaping'),
        ('🍬', 'Sugar'),
        ('📱', 'Social media'),
        ('🎮', 'Video games'),
        ('☕', 'Caffeine'),
        ('🔞', 'Pornography'),
        ('🍔', 'Fast food'),
        ('🛍️', 'Shopping'),
        ('🎰', 'Gambling'),
        ('📺', 'Binge-watching'),
        ('🤳', 'Phone'),
        ('💤', 'Late nights'),
        ('⏰', 'Procrastination'),
        ('🥤', 'Energy drinks'),
        ('🍫', 'Chocolate'),
        ('💅', 'Nail biting'),
        ('🤬', 'Swearing'),
        ('💊', 'Drugs'),
      ]
    : const [
        ('🚬', 'Sigara'),
        ('🍺', 'Alkol'),
        ('💨', 'Elektronik sigara'),
        ('🍬', 'Şeker'),
        ('📱', 'Sosyal medya'),
        ('🎮', 'Video oyunları'),
        ('☕', 'Kafein'),
        ('🔞', 'Porno'),
        ('🍔', 'Fast food'),
        ('🛍️', 'Alışveriş'),
        ('🎰', 'Kumar'),
        ('📺', 'Dizi & film'),
        ('🤳', 'Telefon'),
        ('💤', 'Geç yatma'),
        ('⏰', 'Erteleme'),
        ('🥤', 'Enerji içeceği'),
        ('🍫', 'Çikolata'),
        ('💅', 'Tırnak yeme'),
        ('🤬', 'Küfür'),
        ('💊', 'Uyuşturucu'),
      ];
