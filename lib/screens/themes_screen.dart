import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'paywall_screen.dart';

class ThemesScreen extends StatelessWidget {
  const ThemesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = RutinColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(t('Temalar', 'Themes'),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (!s.isPro)
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const PaywallScreen())),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 26)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Rutin Pro',
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w800)),
                            Text(t('Tüm temalar + sınırsız streak', 'All themes + unlimited streaks'),
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
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.15,
            children: themes.map((tm) {
              final pal = isDark ? tm.dark : tm.light;
              final selected = s.themeId == tm.id;
              final locked = tm.pro && !s.isPro;
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  if (locked) {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const PaywallScreen()));
                  } else {
                    s.setTheme(tm.id);
                    toast(context, t('${tm.emoji} ${tm.name} teması uygulandı', '${tm.emoji} ${tm.name} theme applied'));
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: pal.bg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected ? pal.accent : c.cardBorder,
                      width: selected ? 2.5 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(tm.emoji, style: const TextStyle(fontSize: 18)),
                          const Spacer(),
                          if (locked)
                            Icon(Icons.lock, size: 16, color: pal.muted)
                          else if (selected)
                            Icon(Icons.check_circle,
                                size: 18, color: pal.accent),
                        ],
                      ),
                      const Spacer(),
                      // Renk önizleme noktaları
                      Row(
                        children: [pal.accent, pal.amber, pal.green, pal.blue]
                            .map((col) => Container(
                                  width: 16,
                                  height: 16,
                                  margin: const EdgeInsets.only(right: 5),
                                  decoration: BoxDecoration(
                                      color: col, shape: BoxShape.circle),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 8),
                      Text(tm.name,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: pal.text)),
                      Text(tm.pro ? 'PRO' : t('Ücretsiz', 'Free'),
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: tm.pro ? pal.accent2 : pal.muted)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
