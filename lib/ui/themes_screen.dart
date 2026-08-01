import 'package:flutter/material.dart';

import 'rutin_ui.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../store.dart';
import '../theme.dart';
import 'paywall_screen.dart';

const Map<String, String> _themeDescTr = {
  'alev': 'Enerjik başlangıçlar için',
  'okyanus': 'Sakin ve dengeli',
  'orman': 'Doğayla iç içe',
  'gul': 'Zarif ve sıcak',
  'lavanta': 'Huzurlu anlar için',
  'gece': 'Derin odaklanma',
  'retro': 'Nostaljik bir dokunuş',
  'kumsal': 'Tatil modu',
  'grafit': 'Sade, dikkat dağıtmaz',
};

const Map<String, String> _themeDescEn = {
  'alev': 'For energetic starters',
  'okyanus': 'Calm and balanced',
  'orman': 'Rooted in nature',
  'gul': 'Elegant and warm',
  'lavanta': 'For peaceful moments',
  'gece': 'Deep focus',
  'retro': 'A nostalgic touch',
  'kumsal': 'Vacation mode',
  'grafit': 'Minimal, distraction-free',
};

/// Üstte yatay şerit olarak öne çıkarılan temalar.
const List<String> _featuredIds = ['gece', 'alev', 'lavanta'];

/// Yakın zamanda eklenmiş, "YENİ" rozeti gösterilecek temalar.
const Set<String> _newThemeIds = {'grafit'};

class ThemesScreen extends StatefulWidget {
  const ThemesScreen({super.key});

  @override
  State<ThemesScreen> createState() => _ThemesScreenState();
}

class _ThemesScreenState extends State<ThemesScreen> {
  // Kullanıcının paywall'a gitmeden hemen önce baktığı kilitli tema.
  // Geri döndüğünde hangi temayı incelediğini hatırlatmak için tutuluyor.
  String? _lastViewedLockedId;

  void _openPaywall(BuildContext context, String themeId) {
    setState(() => _lastViewedLockedId = themeId);
    Navigator.push(context,
            MaterialPageRoute(
                builder: (_) => const PaywallScreen(source: 'theme_locked')))
        .then((_) {
      if (mounted) setState(() {});
    });
  }

  void _applyTheme(BuildContext context, AppState s, ThemeSpec tm) {
    final previousId = s.themeId;
    if (previousId == tm.id) return;
    s.setTheme(tm.id);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(t('${tm.emoji} ${tm.name} teması uygulandı',
            '${tm.emoji} ${tm.name} theme applied')),
        duration: const Duration(seconds: 10),
        action: SnackBarAction(
          label: t('Geri al', 'Undo'),
          onPressed: () => s.setTheme(previousId),
        ),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = RutinColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final featured = _featuredIds.map((id) => themeById(id)).toList();
    final rest = themes.where((tm) => !_featuredIds.contains(tm.id)).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(t('Temalar', 'Themes'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: rContentPadding(context, const EdgeInsets.fromLTRB(16, 8, 16, 24)),
        children: [
          Text(
            t('Rutin\'i sana en çok yakışan renklerle kullan.',
                'Make Rutin feel like yours with a palette that fits you.'),
            style: TextStyle(fontSize: 13, color: c.muted, height: 1.4),
          ),
          const SizedBox(height: 16),
          // Tanıtım kartı yalnızca kullanıcı ilk haftasını tamamladıktan
          // sonra (bkz. AppState.showPremiumPromos). Henüz hiçbir kazanım
          // yaşamamış 1. gün kullanıcısına satış yapmak hem dönüşümü düşürür
          // hem güveni zedeler. Ödeme ekranının kendisi her zaman açık.
          if (s.showPremiumPromos)
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) =>
                            const PaywallScreen(source: 'themes_banner'))),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.local_fire_department_rounded, size: 26, color: c.amber),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Rutin Pro',
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w800)),
                            Text(
                                t('Tüm temalar + reklamsız kullanım',
                                    'All themes + no ads'),
                                style:
                                    TextStyle(fontSize: 12, color: c.muted)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: c.muted),
                    ],
                  ),
                ),
              ),
            ),
          if (s.showPremiumPromos) const SizedBox(height: 20),

          // ---- Öne Çıkanlar ----
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 16, color: c.text),
              const SizedBox(width: 6),
              Text(t('Öne Çıkanlar', 'Featured'),
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800, color: c.text)),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 208,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: featured.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final tm = featured[i];
                final pal = isDark ? tm.dark : tm.light;
                final selected = s.themeId == tm.id;
                final locked = tm.pro && !s.hasPro;
                final desc =
                    T.en ? (_themeDescEn[tm.id] ?? '') : (_themeDescTr[tm.id] ?? '');
                return SizedBox(
                  width: 158,
                  child: _ThemeCard(
                    theme: tm,
                    pal: pal,
                    selected: selected,
                    locked: locked,
                    isLastViewed: !selected && _lastViewedLockedId == tm.id,
                    description: desc,
                    onTap: () => locked
                        ? _openPaywall(context, tm.id)
                        : _applyTheme(context, s, tm),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // ---- Tüm Temalar ----
          Text(t('Tüm Temalar', 'All Themes'),
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: c.text)),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            // Yükseklik genişlikten bağımsız, yazı ölçeğine bağlı —
            // iPad'de kart uzamaz, büyük yazıda taşmaz (bkz. paywall_screen).
            mainAxisExtent: 210 * MediaQuery.textScalerOf(context).scale(1),
            children: rest.map((tm) {
              final pal = isDark ? tm.dark : tm.light;
              final selected = s.themeId == tm.id;
              final locked = tm.pro && !s.hasPro;
              final desc =
                  T.en ? (_themeDescEn[tm.id] ?? '') : (_themeDescTr[tm.id] ?? '');

              return _ThemeCard(
                theme: tm,
                pal: pal,
                selected: selected,
                locked: locked,
                isLastViewed: !selected && _lastViewedLockedId == tm.id,
                description: desc,
                onTap: () => locked
                    ? _openPaywall(context, tm.id)
                    : _applyTheme(context, s, tm),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  final ThemeSpec theme;
  final RutinColors pal;
  final bool selected;
  final bool locked;
  final bool isLastViewed;
  final String description;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.theme,
    required this.pal,
    required this.selected,
    required this.locked,
    required this.isLastViewed,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isNew = _newThemeIds.contains(theme.id);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: pal.bg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? pal.accent
                    : (isLastViewed ? pal.accent2 : pal.cardBorder),
                width: selected ? 2.5 : (isLastViewed ? 1.6 : 1),
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: pal.accent.withValues(alpha: 0.35),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(theme.emoji, style: const TextStyle(fontSize: 20)),
                    const Spacer(),
                    if (locked)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                            color: pal.card2, shape: BoxShape.circle),
                        child: Icon(Icons.lock, size: 13, color: pal.muted),
                      )
                    else if (selected)
                      AnimatedScale(
                        scale: 1,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutBack,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                              color: pal.accent, shape: BoxShape.circle),
                          child: const Icon(Icons.check,
                              size: 12, color: Colors.white),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                _MiniPreview(pal: pal),
                const SizedBox(height: 10),
                Text(theme.name,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: pal.text)),
                const SizedBox(height: 2),
                Text(description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: pal.muted, height: 1.25)),
                const Spacer(),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isNew) ...[
                          _newBadge(),
                          const SizedBox(width: 4),
                        ],
                        theme.pro ? _proBadge() : _freeLabel(),
                      ],
                    ),
                    _dualModeHint(),
                  ],
                ),
              ],
            ),
          ),
          if (isLastViewed)
            Positioned(
              top: -8,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: pal.accent2,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  t('Baktığın', 'Viewing'),
                  style: const TextStyle(
                      fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _newBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: pal.blue,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          t('YENİ', 'NEW'),
          style: const TextStyle(
              fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white),
        ),
      );

  Widget _proBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [pal.amber, pal.accent2]),
          borderRadius: BorderRadius.circular(99),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star, size: 10, color: Colors.white),
            SizedBox(width: 3),
            Text('PRO',
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.3)),
          ],
        ),
      );

  Widget _freeLabel() => Text(
        t('Ücretsiz', 'Free'),
        style:
            TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: pal.muted),
      );

  // Bu temanın hem açık hem koyu modu desteklediğine dair küçük bir ipucu.
  Widget _dualModeHint() => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wb_sunny_outlined, size: 10, color: pal.muted),
          const SizedBox(width: 2),
          Icon(Icons.nightlight_outlined, size: 10, color: pal.muted),
        ],
      );
}

class _MiniPreview extends StatelessWidget {
  final RutinColors pal;
  const _MiniPreview({required this.pal});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pal.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                    color: pal.accent, borderRadius: BorderRadius.circular(6)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 5,
                      width: double.infinity,
                      decoration: BoxDecoration(
                          color: pal.text.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(3)),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 4,
                      width: 30,
                      decoration: BoxDecoration(
                          color: pal.muted, borderRadius: BorderRadius.circular(3)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            children: [pal.amber, pal.green, pal.blue, pal.red]
                .map((col) => Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(color: col, shape: BoxShape.circle),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}