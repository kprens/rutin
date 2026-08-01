/// İçgörüler ekranı — Risk Penceresi + Tetikleyici Haritası.
///
/// Ürün mantığı: Bu ekran Premium'un ASIL gerekçesidir. Kullanıcı kendi
/// verisine tek başına bakıp "cuma akşamları 22:00–01:00 arası risk
/// altındayım" sonucunu çıkaramaz — biz çıkarabiliriz. Satılan şey grafik
/// değil, grafiğin ANLAMI.
///
/// Ücretsiz kullanıcı bu ekranı görebilir ve verisinin biriktiğini,
/// desenin VAR OLDUĞUNU görür — ama desenin ne olduğunu göremez. Bu,
/// merak boşluğu (curiosity gap) yaratır ve dönüşümün en güçlü
/// tetikleyicisidir. Boş bir kilit ekranı göstermek yerine gerçek ilerleme
/// göstermek, hem dürüst hem daha ikna edicidir.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../insights.dart';
import '../l10n.dart';
import '../store.dart';
import 'paywall_screen.dart';
import 'rutin_ui.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final i = computeInsights(s.triggerLog);
    final locked = !s.hasPro;

    return Scaffold(
      backgroundColor: RC.bg,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: RG.header),
        child: SafeArea(
          child: ListView(
            padding: rContentPadding(context, const EdgeInsets.fromLTRB(20, 8, 20, 40)),
            children: [
              rutinAppBar(context, t('İçgörüler', 'Insights')),
              const SizedBox(height: 18),

              if (!i.hasEnoughData)
                _collecting(i.sampleCount)
              else ...[
                // ---- Risk penceresi ----
                Text(t('Risk pencerenin', 'Your risk window'),
                    style: RText.title),
                const SizedBox(height: 10),
                if (locked)
                  _lockedCard(
                    context,
                    icon: Icons.schedule_rounded,
                    title: t('Bir zaman desenin var',
                        'You have a time pattern'),
                    body: t(
                        '${i.sampleCount} kayıttan belirgin bir desen çıktı — hangi gün ve saatlerde risk altında olduğunu Pro ile gör.',
                        'A clear pattern emerged from ${i.sampleCount} records — see exactly when you\'re at risk with Pro.'),
                  )
                else
                  RCard(
                    color: RC.tintAmber,
                    border: RC.amber.withValues(alpha: 0.3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.schedule_rounded,
                            size: 26, color: RC.amber),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(riskSentence(i.riskWindow!),
                              style: TextStyle(
                                  color: RC.text,
                                  fontSize: 15,
                                  height: 1.45)),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),

                // ---- Tetikleyici haritası ----
                Text(t('Tetikleyici haritan', 'Your trigger map'),
                    style: RText.title),
                const SizedBox(height: 10),
                if (locked)
                  _lockedCard(
                    context,
                    icon: Icons.psychology_rounded,
                    title: t('${i.triggers.length} farklı tetikleyici kaydedildi',
                        '${i.triggers.length} distinct triggers recorded'),
                    body: t(
                        'Hangisinin baskın olduğunu, hangisinde dayandığını ve hangisinde kırıldığını Pro ile gör.',
                        'See which one dominates, where you hold firm, and where you break — with Pro.'),
                  )
                else ...[
                  for (final tr in i.triggers)
                    _triggerRow(tr, i.triggers.first.count),
                  const SizedBox(height: 14),
                  if (i.strongest != null)
                    _verdictCard(
                      icon: Icons.shield_rounded,
                      color: RC.green,
                      tint: RC.tintGreen,
                      text: t(
                          '${triggerLabel(i.strongest!.key)} anlarında güçlüsün — bu tetikleyicide %${i.strongest!.survivalRate} oranında dayandın.',
                          'You\'re strong against ${triggerLabel(i.strongest!.key).toLowerCase()} — you held firm ${i.strongest!.survivalRate}% of the time.'),
                    ),
                  if (i.weakest != null &&
                      i.weakest!.key != i.strongest?.key) ...[
                    const SizedBox(height: 10),
                    _verdictCard(
                      icon: Icons.warning_amber_rounded,
                      color: RC.amber,
                      tint: RC.tintAmber,
                      text: t(
                          '${triggerLabel(i.weakest!.key)} en kırılgan noktan. Bu duruma özel bir planın olsun — nereye gideceğini, kimi arayacağını önceden belirle.',
                          '${triggerLabel(i.weakest!.key)} is your weak spot. Have a plan ready for it — decide in advance where you\'ll go and who you\'ll call.'),
                    ),
                  ],
                ],
                const SizedBox(height: 20),

                // ---- Veri notu ----
                Text(
                    t('${i.sampleCount} kayda dayanıyor. Kayıt biriktikçe desen keskinleşir.',
                        'Based on ${i.sampleCount} records. The pattern sharpens as more are collected.'),
                    style: TextStyle(color: RC.faint, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Yeterli veri yokken: boş kilit ekranı yerine GERÇEK ilerleme göster.
  Widget _collecting(int count) => RCard(
        border: RC.strokeSoft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights_rounded, size: 24, color: RC.purpleBright),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(t('Desenin oluşuyor', 'Your pattern is forming'),
                      style: TextStyle(
                          color: RC.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: (count / kMinSamples).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: RC.card2,
                valueColor: AlwaysStoppedAnimation(RC.purpleBright),
              ),
            ),
            const SizedBox(height: 10),
            Text(
                t('$count / $kMinSamples kayıt toplandı.',
                    '$count of $kMinSamples records collected.'),
                style: TextStyle(color: RC.muted, fontSize: 13)),
            const SizedBox(height: 6),
            Text(
                t('Bir kriz atlattığında ya da nüksettiğinde sorduğumuz tek soruluk anket bu deseni oluşturuyor. Az veriyle kesin konuşmak yerine bekliyoruz — yanlış bir tahmin, hiç tahmin etmemekten kötüdür.',
                    'The one-tap question we ask after a craving or a slip builds this pattern. We wait rather than guess from too little data — a wrong prediction is worse than none.'),
                style: TextStyle(color: RC.muted, fontSize: 12, height: 1.45)),
          ],
        ),
      );

  Widget _triggerRow(TriggerStat tr, int maxCount) {
    final ratio = maxCount == 0 ? 0.0 : tr.count / maxCount;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(triggerLabel(tr.key),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: RC.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Text(
                  t('${tr.count} kez · %${tr.survivalRate} dayandın',
                      '${tr.count}× · held ${tr.survivalRate}%'),
                  style: TextStyle(color: RC.muted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 7,
              backgroundColor: RC.card2,
              valueColor: AlwaysStoppedAnimation(RC.purpleBright),
            ),
          ),
        ],
      ),
    );
  }

  Widget _verdictCard({
    required IconData icon,
    required Color color,
    required Color tint,
    required String text,
  }) =>
      RCard(
        color: tint,
        border: color.withValues(alpha: 0.3),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text,
                  style:
                      TextStyle(color: RC.text, fontSize: 14, height: 1.4)),
            ),
          ],
        ),
      );

  Widget _lockedCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String body,
  }) =>
      RCard(
        color: RC.tintPurple,
        border: RC.purple.withValues(alpha: 0.4),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const PaywallScreen(source: 'insights'))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 26, color: RC.purpleBright),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: RC.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(body,
                      style: TextStyle(
                          color: RC.muted, fontSize: 13, height: 1.4)),
                ],
              ),
            ),
            Icon(Icons.lock_rounded, size: 16, color: RC.purpleBright),
          ],
        ),
      );
}
