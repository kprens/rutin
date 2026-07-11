/// Tema sistemi — 8 tema (2 ücretsiz, 6 Pro), her biri açık + koyu paletli.
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

/// Açık palet üretici — nötr sıcak tonlar sabit, kimlik renkleri temaya göre.
RutinColors _l(Color accent, Color accent2, Color amber, Color blue,
        Color bg, Color card, Color card2) =>
    RutinColors(
      bg: bg,
      card: card,
      card2: card2,
      text: const Color(0xFF33302A),
      muted: const Color(0xFF989083),
      accent: accent,
      accent2: accent2,
      green: const Color(0xFF5A9E6F),
      red: const Color(0xFFD95550),
      blue: blue,
      amber: amber,
      cardBorder: const Color(0x1F8A7660),
    );

/// Koyu palet üretici.
RutinColors _d(Color accent, Color accent2, Color amber, Color blue,
        Color bg, Color card, Color card2) =>
    RutinColors(
      bg: bg,
      card: card,
      card2: card2,
      text: const Color(0xFFF0EAE2),
      muted: const Color(0xFFA79C8E),
      accent: accent,
      accent2: accent2,
      green: const Color(0xFF6FB585),
      red: const Color(0xFFE06B66),
      blue: blue,
      amber: amber,
      cardBorder: const Color(0x26E0D4C0),
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
  ThemeSpec(
    id: 'alev',
    name: 'Turuncu Alev',
    emoji: '🔥',
    pro: false,
    light: _l(const Color(0xFFE07A4F), const Color(0xFFC96442), const Color(0xFFD99A3D),
        const Color(0xFF4F9BC4), const Color(0xFFFAF3EA), const Color(0xFFFFFDF9), const Color(0xFFF3E7D8)),
    dark: _d(const Color(0xFFE07A4F), const Color(0xFFE8916B), const Color(0xFFE0A855),
        const Color(0xFF6FB0D4), const Color(0xFF1E1713), const Color(0xFF2A211B), const Color(0xFF3A2E25)),
  ),
  ThemeSpec(
    id: 'okyanus',
    name: 'Okyanus',
    emoji: '🌊',
    pro: false,
    light: _l(const Color(0xFF3E8FB8), const Color(0xFF2F7093), const Color(0xFF52B8A8),
        const Color(0xFF3E8FB8), const Color(0xFFEDF4F6), const Color(0xFFFBFDFE), const Color(0xFFDEEBEF)),
    dark: _d(const Color(0xFF54A5CC), const Color(0xFF7BBCDB), const Color(0xFF63C7B7),
        const Color(0xFF54A5CC), const Color(0xFF121A1F), const Color(0xFF1C272E), const Color(0xFF28363F)),
  ),
  ThemeSpec(
    id: 'orman',
    name: 'Orman',
    emoji: '🌿',
    pro: true,
    light: _l(const Color(0xFF4E9459), const Color(0xFF3B7A46), const Color(0xFFA8B84D),
        const Color(0xFF4F9BC4), const Color(0xFFEFF4EC), const Color(0xFFFCFEFB), const Color(0xFFE0EAD9)),
    dark: _d(const Color(0xFF66AB70), const Color(0xFF8AC292), const Color(0xFFB9C86A),
        const Color(0xFF6FB0D4), const Color(0xFF141A14), const Color(0xFF1F281F), const Color(0xFF2B382B)),
  ),
  ThemeSpec(
    id: 'gul',
    name: 'Gül Kurusu',
    emoji: '🌸',
    pro: true,
    light: _l(const Color(0xFFC96A7E), const Color(0xFFAD4E63), const Color(0xFFD9985D),
        const Color(0xFF4F9BC4), const Color(0xFFF9F0F1), const Color(0xFFFFFBFC), const Color(0xFFF0DEE1)),
    dark: _d(const Color(0xFFD8879A), const Color(0xFFE5A5B4), const Color(0xFFE0A855),
        const Color(0xFF6FB0D4), const Color(0xFF1E1417), const Color(0xFF2A1E22), const Color(0xFF3A2B30)),
  ),
  ThemeSpec(
    id: 'lavanta',
    name: 'Lavanta',
    emoji: '💜',
    pro: true,
    light: _l(const Color(0xFF8A6FC0), const Color(0xFF6F54A6), const Color(0xFFC08ABB),
        const Color(0xFF4F9BC4), const Color(0xFFF2F0F8), const Color(0xFFFCFBFE), const Color(0xFFE5E0F0)),
    dark: _d(const Color(0xFFA089D1), const Color(0xFFBBA9E0), const Color(0xFFD0A0CB),
        const Color(0xFF6FB0D4), const Color(0xFF171420), const Color(0xFF221E2E), const Color(0xFF2F2A3E)),
  ),
  ThemeSpec(
    id: 'gece',
    name: 'Gece Yarısı',
    emoji: '🌌',
    pro: true,
    light: _l(const Color(0xFF4A5FA8), const Color(0xFF39498A), const Color(0xFF7A8FD0),
        const Color(0xFF4F9BC4), const Color(0xFFEEF0F6), const Color(0xFFFBFCFE), const Color(0xFFDFE3EF)),
    dark: _d(const Color(0xFF6B82D0), const Color(0xFF8FA2E0), const Color(0xFF9BAEE8),
        const Color(0xFF6FB0D4), const Color(0xFF0F1220), const Color(0xFF181C30), const Color(0xFF232946)),
  ),
  ThemeSpec(
    id: 'retro',
    name: 'Retro',
    emoji: '📼',
    pro: true,
    light: _l(const Color(0xFFC2842B), const Color(0xFFA36B1B), const Color(0xFF4E9489),
        const Color(0xFF4E9489), const Color(0xFFF7F1E3), const Color(0xFFFEFBF3), const Color(0xFFEBE1C9)),
    dark: _d(const Color(0xFFD49B42), const Color(0xFFE2B56A), const Color(0xFF63AC9F),
        const Color(0xFF63AC9F), const Color(0xFF1B1710), const Color(0xFF272218), const Color(0xFF352E20)),
  ),
  ThemeSpec(
    id: 'kumsal',
    name: 'Kumsal',
    emoji: '🏖️',
    pro: true,
    light: _l(const Color(0xFFD9975B), const Color(0xFFBD7C40), const Color(0xFF56BBB0),
        const Color(0xFF56BBB0), const Color(0xFFFAF5EC), const Color(0xFFFFFDF8), const Color(0xFFF1E7D5)),
    dark: _d(const Color(0xFFE3A96C), const Color(0xFFEFC08D), const Color(0xFF68CCC0),
        const Color(0xFF68CCC0), const Color(0xFF1C1812), const Color(0xFF28231A), const Color(0xFF373023)),
  ),
];

ThemeSpec currentTheme = themes.first;

ThemeSpec themeById(String id) =>
    themes.firstWhere((t) => t.id == id, orElse: () => themes.first);

ThemeData _rutinTheme(RutinColors c, Brightness b) {
  final base = ThemeData(
    useMaterial3: true,
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
