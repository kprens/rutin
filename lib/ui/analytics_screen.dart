import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../store.dart';
import 'rutin_ui.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  /// Belirli bir günde aktif olan görevlerden tamamlananların sayısı.
  int _doneOn(AppState s, DateTime day) {
    final ids = s.doneByDate[todayKey(day)] ?? const <int>[];
    return s.tasks
        .where((task) => task.activeOn(mondayIndex(day)) && ids.contains(task.id))
        .length;
  }

  int _activeOn(AppState s, DateTime day) =>
      s.tasks.where((task) => task.activeOn(mondayIndex(day))).length;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final now = DateTime.now();

    // Son 7 gün: tamamlama oranı + toplam.
    var possible = 0, doneWeek = 0;
    for (var i = 0; i < 7; i++) {
      final day = now.subtract(Duration(days: i));
      possible += _activeOn(s, day);
      doneWeek += _doneOn(s, day);
    }
    final completionRate =
        possible == 0 ? 0 : (doneWeek / possible * 100).round();

    // En iyi gün (son 28 gün, haftagünü bazında toplam).
    final byWeekday = List<int>.filled(7, 0);
    for (var i = 0; i < 28; i++) {
      final day = now.subtract(Duration(days: i));
      byWeekday[mondayIndex(day)] += _doneOn(s, day);
    }
    var bestWd = 0;
    for (var w = 1; w < 7; w++) {
      if (byWeekday[w] > byWeekday[bestWd]) bestWd = w;
    }
    // 2024-01-01 Pazartesi → haftagünü etiketleri.
    final bestDayLabel = byWeekday[bestWd] == 0
        ? '—'
        : DateFormat('E', T.locale)
            .format(DateTime(2024, 1, 1).add(Duration(days: bestWd)));

    final activeStreaks =
        s.tasks.where((task) => s.taskStreak(task) > 0).length;

    // Haftalık barlar: son 7 gün (eskiden yeniye).
    final bars = List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      final goal = _activeOn(s, day);
      return (
        done: _doneOn(s, day),
        goal: goal == 0 ? 1 : goal,
        label: DateFormat('E', T.locale).format(day),
      );
    });

    // Aylık ısı haritası: son 30 gün.
    final heat = List.generate(30, (i) {
      final day = now.subtract(Duration(days: 29 - i));
      final d = _doneOn(s, day);
      return d == 0
          ? 0
          : d <= 1
              ? 1
              : d <= 3
                  ? 2
                  : d <= 5
                      ? 3
                      : 4;
    });

    return RScreen(
      children: [
        const SizedBox(height: 8),
        Text(t('İstatistik', 'Analytics'), style: RText.h1),
        const SizedBox(height: 6),
        Text(t('Zaman içindeki ilerlemen', 'Your progress over time'),
            style: RText.muted),
        const SizedBox(height: 20),

        Row(
          children: [
            _metric(t('Tamamlama Oranı', 'Completion Rate'), '$completionRate%',
                t('bu hafta', 'this week'), RC.purpleBright, RC.tintPurple),
            const SizedBox(width: 12),
            _metric(t('En İyi Gün', 'Best Day'), bestDayLabel,
                t('${byWeekday[bestWd]} alışkanlık', '${byWeekday[bestWd]} habits'),
                RC.amber, RC.tintAmber),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _metric(t('Toplam Tamamlanan', 'Total Habits Done'), '$doneWeek',
                t('bu hafta', 'this week'), RC.green, RC.tintGreen),
            const SizedBox(width: 12),
            _metric(t('Aktif Seriler', 'Active Streaks'), '$activeStreaks',
                t('yolunda', 'on track'), RC.pink, RC.tintPink),
          ],
        ),
        const SizedBox(height: 22),

        // ---- Haftalık bar chart ----
        RCard(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t('Haftalık Alışkanlıklar', 'Weekly Habits'),
                  style: RText.title),
              const SizedBox(height: 2),
              Text(t('Tamamlanan vs Hedef', 'Completed vs Goal'),
                  style: RText.muted),
              const SizedBox(height: 22),
              SizedBox(
                height: 150,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final b in bars)
                      Expanded(child: _bar(b.done, b.goal, b.label)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ---- Aylık heatmap ----
        RCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t('Aylık Etkinlik', 'Monthly Activity'), style: RText.title),
              const SizedBox(height: 2),
              Text(t('Son 30 gün', 'Last 30 days'), style: RText.muted),
              const SizedBox(height: 18),
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: [
                  for (final v in heat)
                    AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _heatColor(v),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: RC.strokeSoft),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(t('Az', 'Less'),
                      style: TextStyle(color: RC.muted, fontSize: 12)),
                  const SizedBox(width: 8),
                  for (var v = 0; v <= 4; v++) ...[
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: _heatColor(v),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    const SizedBox(width: 5),
                  ],
                  const SizedBox(width: 3),
                  Text(t('Çok', 'More'),
                      style: TextStyle(color: RC.muted, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metric(String label, String value, String sub, Color color, Color tint) {
    return Expanded(
      child: RCard(
        color: tint,
        border: RC.strokeSoft,
        radius: 18,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: RC.muted, fontSize: 13)),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 30, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 4),
            Text(sub, style: TextStyle(color: RC.muted, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _bar(int done, int goal, String label) {
    final ratio = (done / goal).clamp(0.0, 1.0);
    return Column(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              FractionallySizedBox(
                alignment: Alignment.bottomCenter,
                heightFactor: 1,
                child: Container(
                  width: 18,
                  decoration: BoxDecoration(
                    color: RC.purple.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ),
              FractionallySizedBox(
                alignment: Alignment.bottomCenter,
                heightFactor: ratio == 0 ? 0.02 : ratio,
                child: Container(
                  width: 18,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [RC.purpleBright, RC.purple],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: RC.muted, fontSize: 12)),
      ],
    );
  }

  /// Isı haritası kademesi (0 = hiç aktivite yok, 4 = en yoğun).
  ///
  /// 0 kademesi eskiden sabit `0xFF14161F` idi — koyu tema kalıntısı. Açık
  /// temada (varsayılan) simsiyah bir kare olarak çıkıyordu: hem ızgarada
  /// boş günler kömür lekesi gibi görünüyordu hem de "Az → Çok" göstergesi
  /// HER ZAMAN 0'ı çizdiği için siyah kare, hiç boş gün olmayan kullanıcıda
  /// bile ekranda duruyordu. Artık zeminden türetiliyor: 20 tema/mod
  /// kombinasyonunun hepsinde "boş" doğru okunuyor.
  Color _heatColor(int v) {
    switch (v) {
      case 0:
        return Color.alphaBlend(RC.purple.withValues(alpha: 0.06), RC.card);
      case 1:
        return RC.purple.withValues(alpha: 0.25);
      case 2:
        return RC.purple.withValues(alpha: 0.45);
      case 3:
        return RC.purple.withValues(alpha: 0.7);
      default:
        return RC.purpleBright;
    }
  }
}