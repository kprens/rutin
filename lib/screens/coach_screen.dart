import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../coach.dart';
import '../l10n.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// Tona göre vurgu rengi.
Color coachToneColor(RutinColors c, CoachTone tone) {
  switch (tone) {
    case CoachTone.warning:
      return c.amber;
    case CoachTone.positive:
      return c.green;
    case CoachTone.info:
      return c.accent2;
  }
}

/// Tek bir öneri kartı — hem Koç ekranında hem Bugün ekranında kullanılır.
class CoachTipCard extends StatelessWidget {
  final CoachTip tip;
  const CoachTipCard({super.key, required this.tip});

  @override
  Widget build(BuildContext context) {
    final c = RutinColors.of(context);
    final accent = coachToneColor(c, tip.tone);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(18)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Text(tip.emoji,
                          style: const TextStyle(fontSize: 20)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tip.title,
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: c.text)),
                          const SizedBox(height: 4),
                          Text(tip.body,
                              style: TextStyle(
                                  fontSize: 13,
                                  height: 1.45,
                                  color: c.muted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CoachScreen extends StatelessWidget {
  const CoachScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = RutinColors.of(context);
    final tips = generateCoachTips(s);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('🧭', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(t('Rutin Koçu', 'Routine Coach'),
                style: TextStyle(
                    fontSize: 19, fontWeight: FontWeight.w800, color: c.text)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: c.card2,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Text('🔒', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    t('Öneriler alışkanlık verinden yola çıkılarak tamamen cihazında hesaplanır — hiçbir şey buluta gönderilmez.',
                        'Tips are computed entirely on your device from your habit data — nothing is sent to the cloud.'),
                    style: TextStyle(fontSize: 12, color: c.muted, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          SectionTitle(t('Sana Özel Öneriler', 'Personalized Tips')),
          ...tips.map((tip) => CoachTipCard(tip: tip)),
        ],
      ),
    );
  }
}
