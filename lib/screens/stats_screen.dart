import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

List<String> get _dowInitial => T.en
    ? const ['M', 'T', 'W', 'T', 'F', 'S', 'S']
    : const ['P', 'S', 'Ç', 'P', 'C', 'C', 'P'];

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = RutinColors.of(context);

    final taskHist = s.taskHistory(14);
    final waterHist = s.waterHistory(14);
    final maxTasks = taskHist.map((e) => e.done).fold(1, (a, b) => a > b ? a : b);
    final maxWater =
        [s.water.goal, ...waterHist.map((e) => e.count)].reduce((a, b) => a > b ? a : b);

    final totalDone14 = taskHist.fold(0, (sum, e) => sum + e.done);
    final activeDays = waterHist.where((e) => e.count > 0).length;

    Streak? best;
    for (final st in s.streaks) {
      if (best == null || st.daysOrBest > best.daysOrBest) best = st;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        SectionTitle(t('İstatistikler', 'Statistics')),

        // Özet kartları
        Row(
          children: [
            Expanded(
                child: _statCard(c, '✅', '$totalDone14',
                    t('görev tamamlandı\n(son 14 gün)', 'tasks completed\n(last 14 days)'))),
            const SizedBox(width: 10),
            Expanded(
                child: _statCard(c, '💧', t('$activeDays gün', '$activeDays days'),
                    t('su takibi yapıldı\n(son 14 gün)', 'days water tracked\n(last 14 days)'))),
          ],
        ),
        if (s.streaks.isNotEmpty) ...[
          const SizedBox(height: 2),
          SectionTitle(t('Streak Özeti', 'Streak Summary')),
          ...s.streaks.map((st) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Text('🔥', style: TextStyle(fontSize: 22)),
                  title: Text(st.name,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  subtitle: Text(
                      st.bestDays > 0
                          ? t('En iyi seri: ${st.bestDays} gün', 'Best streak: ${st.bestDays} days')
                          : t('İlk seri devam ediyor', 'First streak in progress'),
                      style: TextStyle(fontSize: 12, color: c.muted)),
                  trailing: Text(t('${st.days} gün', '${st.days} days'),
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: c.accent2)),
                ),
              )),
        ],
        const SizedBox(height: 2),
        SectionTitle(t('Görevler — Son 14 Gün', 'Tasks — Last 14 Days')),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _BarChart(
              values: taskHist.map((e) => e.done.toDouble()).toList(),
              labels: taskHist.map((e) => _dowInitial[mondayIndex(e.day)]).toList(),
              max: maxTasks.toDouble(),
              color: c.green,
              emptyColor: c.card2,
              labelColor: c.muted,
              caption: t('Günlük tamamlanan görev sayısı', 'Tasks completed per day'),
            ),
          ),
        ),
        SectionTitle(t('Su — Son 14 Gün', 'Water — Last 14 Days')),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _BarChart(
              values: waterHist.map((e) => e.count.toDouble()).toList(),
              labels: waterHist.map((e) => _dowInitial[mondayIndex(e.day)]).toList(),
              max: maxWater.toDouble(),
              color: c.blue,
              emptyColor: c.card2,
              labelColor: c.muted,
              goal: s.water.goal.toDouble(),
              goalColor: c.amber,
              caption: t('Günlük bardak sayısı — çizgi: hedef (${s.water.goal})', 'Glasses per day — line: goal (${s.water.goal})'),
            ),
          ),
        ),
        if (best != null && best.daysOrBest >= 7)
          Padding(
            padding: const EdgeInsets.all(10),
            child: Text(t('En güçlü alışkanlığın: "${best.name}" 🏆', 'Your strongest habit: "${best.name}" 🏆'),
                textAlign: TextAlign.center,
                style: TextStyle(color: c.amber, fontSize: 13)),
          ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Text('💾', style: TextStyle(fontSize: 20)),
            title: Text(t('Verilerini dışa aktar', 'Export your data'),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            subtitle: Text(t('Tüm verinin JSON yedeğini paylaş/sakla', 'Share/store a JSON backup of all your data'),
                style: TextStyle(fontSize: 12, color: c.muted)),
            trailing: Icon(Icons.chevron_right, color: c.muted),
            onTap: () => Share.share(s.exportJson(), subject: t('Rutin yedek', 'Rutin backup')),
          ),
        ),
      ],
    );
  }

  Widget _statCard(RutinColors c, String emoji, String big, String small) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(big,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(small,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: c.muted, height: 1.3)),
          ],
        ),
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final double max;
  final Color color;
  final Color emptyColor;
  final Color labelColor;
  final double? goal;
  final Color? goalColor;
  final String caption;

  const _BarChart({
    required this.values,
    required this.labels,
    required this.max,
    required this.color,
    required this.emptyColor,
    required this.labelColor,
    this.goal,
    this.goalColor,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    const chartHeight = 90.0;
    final m = max <= 0 ? 1.0 : max;

    return Column(
      children: [
        SizedBox(
          height: chartHeight + 18,
          child: Stack(
            children: [
              if (goal != null && goal! <= m)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 18 + chartHeight * (goal! / m) - 1,
                  child: Container(height: 1.5, color: goalColor ?? labelColor),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(values.length, (i) {
                  final h = (values[i] / m * chartHeight).clamp(3.0, chartHeight);
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            height: h,
                            decoration: BoxDecoration(
                              color: values[i] > 0 ? color : emptyColor,
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4)),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(labels[i],
                              style: TextStyle(fontSize: 9, color: labelColor)),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(caption, style: TextStyle(fontSize: 11, color: labelColor)),
      ],
    );
  }
}
