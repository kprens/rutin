/// Tema sistemi — 9 tema (2 ücretsiz, 7 Pro), her biri açık + koyu paletli.
/// Yeni Rutin tasarım diline göre yeniden renklendirildi: soğuk, derin
/// near-black koyu modlar ve canlı, doygun vurgu renkleri.
/// Sistem temasına (açık/koyu) otomatik uyar.
library;

import 'package:flutter/material.dart';

class RutinColors {
  final Color bg, card, card2, text, muted, accent, accent2, green, red, blue, amber, cardBorder;

  const RutinColors({
    required this.bg,
    required this.card,
    required this.card2,
    required this.text,
    required this.muted,
    required this.accent,
    required this.accent2,
    required this.green,
    required this.red,
    required this.blue,
    required this.amber,
    required this.cardBorder,
  });

  static RutinColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? currentTheme.dark
          : currentTheme.light;
}

/// Açık palet üretici — nötr soğuk tonlar sabit, kimlik renkleri temaya göre.
RutinColors _l(Color accent, Color accent2, Color amber, Color blue,
        Color bg, Color card, Color card2) =>
    RutinColors(
      bg: bg,
      card: card,
      card2: card2,
      text: const Color(0xFF1C1C22),
      // ERİŞİLEBİLİRLİK: eskiden 0xFF8C8B98 idi ve açık temaların HEPSİNDE
      // WCAG AA'nın altında kalıyordu (ölçülen 3.00–3.35:1, gereken 4.5:1).
      // Bu renk uygulamada 120'den fazla yerde metin rengi olarak kullanılıyor,
      // yani sorun kozmetik değil: düşük görme keskinliğinde ya da güneş
      // altında bu metinlerin çoğu okunmuyordu. Ton korunarak koyulaştırıldı;
      // yeni ölçüm 4.56–5.10:1 (beyaz kart dahil en zorlu üç yüzeyde).
      muted: const Color(0xFF6E6D77),
      accent: accent,
      accent2: accent2,
      green: const Color(0xFF29B673),
      red: const Color(0xFFE85A54),
      blue: blue,
      amber: amber,
      cardBorder: const Color(0x14000000),
    );

/// Koyu palet üretici.
RutinColors _d(Color accent, Color accent2, Color amber, Color blue,
        Color bg, Color card, Color card2) =>
    RutinColors(
      bg: bg,
      card: card,
      card2: card2,
      text: const Color(0xFFF2F1F5),
      muted: const Color(0xFF9C9BAA),
      accent: accent,
      accent2: accent2,
      green: const Color(0xFF45C98A),
      red: const Color(0xFFF16B65),
      blue: blue,
      amber: amber,
      cardBorder: const Color(0x22FFFFFF),
    );

class ThemeSpec {
  final String id;
  final String name;
  final String emoji;
  final bool pro;
  final RutinColors light;
  final RutinColors dark;

  const ThemeSpec({
    required this.id,
    required this.name,
    required this.emoji,
    required this.pro,
    required this.light,
    required this.dark,
  });
}

final List<ThemeSpec> themes = [
  // Beyaz önce listelenir — uygulamanın varsayılan (ücretsiz) teması budur.
  // Turuncu Alev hakkında olumsuz kullanıcı yorumları üzerine önce Okyanus'a,
  // sonra kullanıcı isteğiyle temiz/minimal bu beyaz temaya çevrildi (bkz.
  // store.dart themeId varsayılanları). Diğerleri hâlâ ücretsiz/pro seçenek
  // olarak listede duruyor, sadece artık ilk/varsayılan değil.
  ThemeSpec(
    id: 'beyaz',
    name: 'Beyaz',
    emoji: '⚪',
    pro: false,
    light: _l(const Color(0xFF4A6CF7), const Color(0xFF3552C8), const Color(0xFFF5A623),
        const Color(0xFF4A6CF7), const Color(0xFFFAFAFB), const Color(0xFFFFFFFF), const Color(0xFFF1F2F5)),
    dark: _d(const Color(0xFF6C8CFF), const Color(0xFF90A8FF), const Color(0xFFFFC266),
        const Color(0xFF6C8CFF), const Color(0xFF0F1115), const Color(0xFF17191F), const Color(0xFF1E2129)),
  ),
  ThemeSpec(
    id: 'okyanus',
    name: 'Okyanus',
    emoji: '🌊',
    pro: false,
    light: _l(const Color(0xFF2E9CE0), const Color(0xFF2380BE), const Color(0xFF3FB6A6),
        const Color(0xFF2E9CE0), const Color(0xFFF5FAFC), const Color(0xFFFFFFFF), const Color(0xFFE1F0F6)),
    dark: _d(const Color(0xFF4FB4EE), const Color(0xFF7CC8F2), const Color(0xFF5FD0C0),
        const Color(0xFF4FB4EE), const Color(0xFF070E12), const Color(0xFF101B21), const Color(0xFF17262E)),
  ),
  ThemeSpec(
    id: 'alev',
    name: 'Turuncu Alev',
    emoji: '🔥',
    pro: false,
    light: _l(const Color(0xFFFF7A45), const Color(0xFFE85A2A), const Color(0xFFFFB238),
        const Color(0xFF4FA8E8), const Color(0xFFFAF8F6), const Color(0xFFFFFFFF), const Color(0xFFF1E9E2)),
    dark: _d(const Color(0xFFFF8F5E), const Color(0xFFFFAB7A), const Color(0xFFFFC266),
        const Color(0xFF6FBBEF), const Color(0xFF120E0B), const Color(0xFF1C1512), const Color(0xFF29201A)),
  ),
  ThemeSpec(
    id: 'orman',
    name: 'Orman',
    emoji: '🌿',
    pro: true,
    light: _l(const Color(0xFF3FAE55), const Color(0xFF2E8C42), const Color(0xFFB7C24A),
        const Color(0xFF4FA8E8), const Color(0xFFF4F9F2), const Color(0xFFFFFFFF), const Color(0xFFE1EEDC)),
    dark: _d(const Color(0xFF5CC773), const Color(0xFF82D797), const Color(0xFFC7D766),
        const Color(0xFF6FBBEF), const Color(0xFF0A0F0A), const Color(0xFF131C13), const Color(0xFF1C2A1C)),
  ),
  ThemeSpec(
    id: 'gul',
    name: 'Gül Kurusu',
    emoji: '🌸',
    pro: true,
    light: _l(const Color(0xFFE0567A), const Color(0xFFC43E63), const Color(0xFFE0A15D),
        const Color(0xFF4FA8E8), const Color(0xFFFCF3F5), const Color(0xFFFFFFFF), const Color(0xFFF3DFE4)),
    dark: _d(const Color(0xFFEE7A98), const Color(0xFFF6A0B6), const Color(0xFFEFBB80),
        const Color(0xFF6FBBEF), const Color(0xFF130A0D), const Color(0xFF1E1216), const Color(0xFF2C1A20)),
  ),
  ThemeSpec(
    id: 'lavanta',
    name: 'Lavanta',
    emoji: '💜',
    pro: true,
    light: _l(const Color(0xFF8F6BE8), const Color(0xFF7250C8), const Color(0xFFC98FC4),
        const Color(0xFF4FA8E8), const Color(0xFFF6F4FC), const Color(0xFFFFFFFF), const Color(0xFFE7E1F5)),
    dark: _d(const Color(0xFFA98CF0), const Color(0xFFC3ADF5), const Color(0xFFDBA8D6),
        const Color(0xFF6FBBEF), const Color(0xFF0D0A17), const Color(0xFF171224), const Color(0xFF221A33)),
  ),
  ThemeSpec(
    id: 'gece',
    name: 'Gece Yarısı',
    emoji: '🌌',
    pro: true,
    light: _l(const Color(0xFF5A6BF0), const Color(0xFF4353D4), const Color(0xFF8B9AF0),
        const Color(0xFF4FA8E8), const Color(0xFFF3F4FA), const Color(0xFFFFFFFF), const Color(0xFFE2E5F3)),
    dark: _d(const Color(0xFF7C8AF5), const Color(0xFF9CA8F7), const Color(0xFFAAB6F5),
        const Color(0xFF6FBBEF), const Color(0xFF0A0B14), const Color(0xFF131526), const Color(0xFF1C2038)),
  ),
  ThemeSpec(
    id: 'retro',
    name: 'Retro',
    emoji: '📼',
    pro: true,
    light: _l(const Color(0xFFD68C2E), const Color(0xFFB5721E), const Color(0xFF5AA89B),
        const Color(0xFF5AA89B), const Color(0xFFF9F5EC), const Color(0xFFFFFFFF), const Color(0xFFEEE3C9)),
    dark: _d(const Color(0xFFE8A44E), const Color(0xFFF2BE79), const Color(0xFF75C2B4),
        const Color(0xFF75C2B4), const Color(0xFF110D08), const Color(0xFF1C1610), const Color(0xFF2A2216)),
  ),
  ThemeSpec(
    id: 'kumsal',
    name: 'Kumsal',
    emoji: '🏖️',
    pro: true,
    light: _l(const Color(0xFFE0A15D), const Color(0xFFC6853E), const Color(0xFF5FC2B5),
        const Color(0xFF5FC2B5), const Color(0xFFFBF7EF), const Color(0xFFFFFFFF), const Color(0xFFF0E5CF)),
    dark: _d(const Color(0xFFEFBB80), const Color(0xFFF6D1A3), const Color(0xFF7ED8CB),
        const Color(0xFF7ED8CB), const Color(0xFF120E09), const Color(0xFF1D1710), const Color(0xFF2B2216)),
  ),
  ThemeSpec(
    id: 'grafit',
    name: 'Grafit',
    emoji: '⚫',
    pro: true,
    light: _l(const Color(0xFF3A3A42), const Color(0xFF6B6B76), const Color(0xFFFF8A4C),
        const Color(0xFF5C87A8), const Color(0xFFF7F7F8), const Color(0xFFFFFFFF), const Color(0xFFECECEF)),
    dark: _d(const Color(0xFFD4D4DC), const Color(0xFFA8A8B4), const Color(0xFFFF8A4C),
        const Color(0xFF7FA8C9), const Color(0xFF08080A), const Color(0xFF111114), const Color(0xFF1A1A1F)),
  ),
];

ThemeSpec currentTheme = themes.first;

/// Kullanıcının Ayarlar'daki "Koyu Mod" tercihi. AppState.setDarkMode()
/// tarafından güncellenir ve MaterialApp'ın themeMode'u ile senkron tutulur.
/// "Yeni arayüz" (RC, rutin_ui.dart) context'e erişemediği için hangi
/// paleti (currentTheme.dark / currentTheme.light) kullanacağını buradan okur.
bool useDarkPalette = true;

ThemeSpec themeById(String id) =>
    themes.firstWhere((t) => t.id == id, orElse: () => themes.first);

ThemeData _rutinTheme(RutinColors c, Brightness b) {
  final base = ThemeData(
    useMaterial3: true,
    // Poppins — assets/fonts/ altına .ttf dosyaları + pubspec.yaml'daki
    // `fonts:` bloğu eklenince otomatik devreye girer (bkz.
    // assets/fonts/README.md). Şimdilik font kayıtlı değilse Flutter
    // sessizce platform varsayılan fontuna düşer.
    fontFamily: 'Poppins',
    colorScheme: ColorScheme.fromSeed(
      seedColor: c.accent,
      brightness: b,
      surface: c.bg,
    ),
    scaffoldBackgroundColor: c.bg,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: c.text, displayColor: c.text),
    cardTheme: CardThemeData(
      color: c.card,
      elevation: 1,
      shadowColor: const Color(0x14785032),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: c.cardBorder),
      ),
      margin: const EdgeInsets.only(bottom: 12),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.accent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.card2,
      hintStyle: TextStyle(color: c.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.accent),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.card,
      indicatorColor: c.card2,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.text),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.card2,
      contentTextStyle: TextStyle(color: c.text),
      actionTextColor: c.accent2,
    ),
  );
}

ThemeData rutinLightTheme() => _rutinTheme(currentTheme.light, Brightness.light);
ThemeData rutinDarkTheme() => _rutinTheme(currentTheme.dark, Brightness.dark);