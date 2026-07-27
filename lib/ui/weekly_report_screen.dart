/// Haftalık Hayat Raporu ekranı.
///
/// Ürün mantığı (bkz. ABONELIK-STRATEJISI.md):
///  • İLK RAPOR HERKESE ÜCRETSİZ. Değeri anlatmak yerine yaşatmak, en güçlü
///    dönüşüm aracıdır — kullanıcı raporu bir kez gördükten sonra "haftaya
///    ne yazacak?" merakı oluşur.
///  • Sonraki raporlar Pro'da. Ancak manşet ve temel rakamlar HER ZAMAN
///    görünür kalır; kilitlenen kısım derin analiz (en iyi/en zor gün,
///    odak önerisi, kilometre taşları). Kullanıcı neyi kaçırdığını görür
///    ama tamamen dışarıda bırakılmaz.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../store.dart';
import '../weekly_report.dart';
import 'paywall_screen.dart';
import 'rutin_ui.dart';
import 'water_screen.dart' show rutinAppBar;

class WeeklyReportScreen extends StatefulWidget {
  const WeeklyReportScreen({super.key});

  @override
  State<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends State<WeeklyReportScreen> {
  @override
  void initState() {
    super.initState();
    // Ücretsiz kullanıcı ilk raporunu açtı — bir kereye mahsus hakkı
    // burada tüketilir (bkz. AppState.markWeeklyReportSeen).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppState>().markWeeklyReportSeen();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final r = buildWeeklyReport(s);
    // İlk rapor ücretsiz; sonrakiler Pro.
    //
    // `> 1` DEĞİL `>= 1`: sayaç, ekran çizildikten SONRA (postFrameCallback)
    // artıyor. İlk açılışta build 0 değeriyle çalışır (kilitsiz, doğru),
    // sonra 1 olur. `> 1` olsaydı ikinci açılış da 1 değeriyle çizilip
    // kilitsiz kalır, yani kullanıcı bir değil İKİ ücretsiz rapor görürdü.
    final locked = !s.hasPro && s.weeklyReportsSeen >= 1;

    final df = DateFormat('d MMM', T.locale);

    return Scaffold(
      backgroundColor: RC.bg,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: RG.header),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              rutinAppBar(context, t('Haftalık Rapor', 'Weekly Report')),
              const SizedBox(height: 6),
              Text('${df.format(r.from)} – ${df.format(r.to)}',
                  style: TextStyle(color: RC.muted, fontSize: 13)),
              const SizedBox(height: 18),

              if (!r.hasData)
                REmpty(
                  icon: Icons.insights_outlined,
                  title: t('Bu hafta için yeterli veri yok',
                      'Not enough data this week'),
                  message: t('Birkaç gün kullandıktan sonra raporun anlam kazanacak.',
                      'Your report gets meaningful after a few days of use.'),
                )
              else ...[
                // ---- Manşet (her zaman görünür) ----
                RCard(
                  color: RC.tintPurple,
                  border: RC.purple.withValues(alpha: 0.3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.headline,
                          style: TextStyle(
                              color: RC.text,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              height: 1.3)),
                      const SizedBox(height: 10),
                      Text(
                          t('Alışkanlıklarının %${r.completionRate}\'ini tamamladın.',
                              'You completed ${r.completionRate}% of your habits.'),
                          style: TextStyle(
                              color: RC.muted, fontSize: 14, height: 1.4)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ---- Rakamlar (her zaman görünür) ----
                Row(
                  children: [
                    _stat(Icons.check_circle_rounded, '${r.doneCount}',
                        t('tamamlanan', 'completed'), RC.green, RC.tintGreen),
                    const SizedBox(width: 12),
                    _stat(Icons.local_fire_department_rounded, '${r.cleanDays}',
                        t('temiz gün', 'clean days'), RC.amber, RC.tintAmber),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (r.moneySaved > 0) ...[
                      _stat(
                          Icons.savings_rounded,
                          '₺${r.moneySaved.toStringAsFixed(0)}',
                          t('bu hafta', 'this week'),
                          RC.teal,
                          RC.tintTeal),
                      const SizedBox(width: 12),
                    ],
                    _stat(
                        Icons.water_drop_rounded,
                        r.avgWaterCups.toStringAsFixed(1),
                        t('ort. bardak/gün', 'avg cups/day'),
                        RC.blue,
                        RC.tintBlue),
                  ],
                ),
                // Geri kazanılan süre yalnızca kullanıcı bu veriyi girdiyse
                // anlamlı (dailyHours > 0). Hesaplanıp hiç gösterilmemesi
                // ölü koddu — burada gösteriliyor.
                if (r.hoursSaved > 0) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _stat(
                          Icons.access_time_rounded,
                          t('${r.hoursSaved.toStringAsFixed(1)} sa',
                              '${r.hoursSaved.toStringAsFixed(1)} h'),
                          t('geri kazanılan süre', 'time reclaimed'),
                          RC.purpleBright,
                          RC.tintPurple),
                    ],
                  ),
                ],
                const SizedBox(height: 18),

                // ---- Derin analiz (ilk rapordan sonra Pro) ----
                if (locked)
                  _lockedCard(context)
                else ...[
                  if (r.milestones.isNotEmpty) ...[
                    Text(t('Bu hafta geçtiğin eşikler',
                        'Milestones you crossed'), style: RText.title),
                    const SizedBox(height: 10),
                    ...r.milestones.map((m) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: RCard(
                            color: RC.tintAmber,
                            border: RC.amber.withValues(alpha: 0.25),
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Icon(Icons.emoji_events_rounded,
                                    size: 20, color: RC.amber),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                      t('${m.name}: ${m.days} gün',
                                          '${m.name}: ${m.days} days'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: RC.text,
                                          fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                          ),
                        )),
                    const SizedBox(height: 14),
                  ],
                  if (r.bestDay != null || r.hardestDay != null) ...[
                    Text(t('Haftanın deseni', 'Your week\'s pattern'),
                        style: RText.title),
                    const SizedBox(height: 10),
                    RCard(
                      border: RC.strokeSoft,
                      child: Column(
                        children: [
                          if (r.bestDay != null)
                            _patternRow(
                                Icons.trending_up_rounded,
                                t('En güçlü günün', 'Your strongest day'),
                                DateFormat('EEEE', T.locale)
                                    .format(r.bestDay!),
                                RC.green),
                          if (r.bestDay != null && r.hardestDay != null)
                            const SizedBox(height: 12),
                          if (r.hardestDay != null)
                            _patternRow(
                                Icons.trending_down_rounded,
                                t('En zorlandığın gün', 'Your hardest day'),
                                DateFormat('EEEE', T.locale)
                                    .format(r.hardestDay!),
                                RC.red),
                          if (r.perfectDays > 0) ...[
                            const SizedBox(height: 12),
                            _patternRow(
                                Icons.star_rounded,
                                t('Kusursuz gün', 'Perfect days'),
                                '${r.perfectDays}',
                                RC.amber),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (r.focusSuggestion != null) ...[
                    Text(t('Gelecek hafta', 'Next week'), style: RText.title),
                    const SizedBox(height: 10),
                    RCard(
                      color: RC.tintBlue,
                      border: RC.blue.withValues(alpha: 0.25),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.lightbulb_outline_rounded,
                              size: 22, color: RC.blue),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(r.focusSuggestion!,
                                style: TextStyle(
                                    color: RC.text,
                                    fontSize: 14,
                                    height: 1.45)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _lockedCard(BuildContext context) => RCard(
        color: RC.tintPurple,
        border: RC.purple.withValues(alpha: 0.4),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const PaywallScreen(source: 'weekly_report'))),
        child: Row(
          children: [
            Icon(Icons.insights_rounded, size: 26, color: RC.purpleBright),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      t('Haftanın deseni ve odak önerin hazır',
                          'Your weekly pattern and focus are ready'),
                      style: TextStyle(
                          color: RC.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(
                      t('En güçlü ve en zor günün, geçtiğin eşikler ve gelecek hafta için öneri — Pro ile her hafta.',
                          'Your strongest and hardest day, milestones crossed, and next week\'s focus — every week with Pro.'),
                      style: TextStyle(
                          color: RC.muted, fontSize: 12, height: 1.4)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: RC.purpleBright, size: 20),
          ],
        ),
      );

  Widget _patternRow(
          IconData icon, String label, String value, Color color) =>
      Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: RC.muted, fontSize: 14)),
          ),
          const SizedBox(width: 8),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: RC.text, fontSize: 15, fontWeight: FontWeight.w700)),
        ],
      );

  Widget _stat(IconData icon, String big, String sub, Color color, Color tint) =>
      Expanded(
        child: RCard(
          color: tint,
          border: RC.strokeSoft,
          radius: 18,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 8),
              Text(big,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: color)),
              const SizedBox(height: 2),
              Text(sub,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: RC.muted, fontSize: 12, height: 1.15)),
            ],
          ),
        ),
      );
}
