import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../store.dart';
import 'rutin_ui.dart';
import 'ui_logic.dart';
import 'water_screen.dart' show rutinAppBar;

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});
  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  // (görünen etiket, kategori anahtarı)
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final all = evaluateBadges(s);
    final earned = all.where((b) => b.earned).length;

    final filters = <(String, String)>[
      (t('Tümü', 'All'), 'All'),
      (t('Seri', 'Streak'), 'Streak'),
      (t('Alışkanlık', 'Habit'), 'Habit'),
      (t('Bırakma', 'Recovery'), 'Recovery'),
      (t('Su', 'Water'), 'Water'),
      (t('Özel', 'Special'), 'Special'),
    ];
    final key = filters[_selected].$2;
    final shown =
        key == 'All' ? all : all.where((b) => b.category == key).toList();

    return Scaffold(
      backgroundColor: RC.bg,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: RG.header),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              rutinAppBar(context, t('Başarımlar', 'Achievements')),
              const SizedBox(height: 20),

              // ---- İlerleme banner ----
              RCard(
                color: RC.tintAmber,
                border: RC.amber.withValues(alpha: 0.3),
                child: Row(
                  children: [
                    const Text('🏆', style: TextStyle(fontSize: 44)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$earned/${all.length}',
                              style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  color: RC.amber)),
                          Text(t('rozet kazanıldı', 'badges earned'),
                              style: const TextStyle(
                                  color: RC.muted, fontSize: 14)),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: all.isEmpty ? 0 : earned / all.length,
                              minHeight: 8,
                              backgroundColor: RC.card2,
                              valueColor:
                                  const AlwaysStoppedAnimation(RC.amber),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ---- Filtre chipleri ----
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: filters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () => setState(() => _selected = i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _selected == i
                            ? RC.purple.withValues(alpha: 0.3)
                            : RC.card,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                            color: _selected == i ? RC.purple : RC.stroke),
                      ),
                      child: Text(filters[i].$1,
                          style: TextStyle(
                              color: _selected == i ? RC.text : RC.muted,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // ---- Badge grid ----
              if (shown.isEmpty)
                RCard(
                  border: RC.strokeSoft,
                  child: Text(
                      t('Bu kategoride rozet yok.',
                          'No badges in this category.'),
                      style: const TextStyle(color: RC.muted)),
                )
              else
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.82,
                  children: shown.map(_badge).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(EarnedBadge b) {
    final rare = b.rarity != 'COMMON';
    final rarityColor = switch (b.rarity) {
      'RARE' => RC.blue,
      'EPIC' => RC.purpleBright,
      _ => RC.muted,
    };
    return RCard(
      radius: 18,
      color: b.earned && rare ? RC.tintBlue : RC.card,
      border: b.earned && rare ? rarityColor.withValues(alpha: 0.4) : RC.stroke,
      padding: const EdgeInsets.all(14),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: b.earned ? rarityColor.withValues(alpha: 0.18) : RC.card2,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(b.rarity,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: b.earned ? rarityColor : RC.faint)),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 14),
              Opacity(
                opacity: b.earned ? 1 : 0.35,
                child: Text(b.earned ? b.emoji : '🔒',
                    style: const TextStyle(fontSize: 40)),
              ),
              const SizedBox(height: 12),
              Text(b.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: b.earned ? RC.text : RC.faint)),
              const SizedBox(height: 4),
              Text(b.desc,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: RC.muted, fontSize: 12, height: 1.3)),
              const SizedBox(height: 8),
              Text(
                  b.earned
                      ? t('✓ Kazanıldı', '✓ Earned')
                      : t('Kilitli', 'Locked'),
                  style: TextStyle(
                      color: b.earned
                          ? (rare ? rarityColor : RC.green)
                          : RC.faint,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}
