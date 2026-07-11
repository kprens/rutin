import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

class WaterScreen extends StatelessWidget {
  const WaterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = RutinColors.of(context);
    final w = s.water;
    final pct = (w.count / w.goal).clamp(0.0, 1.0);

    String msg;
    if (w.count == 0) {
      msg = t('Güne su içerek başla 💧', 'Start your day with water 💧');
    } else if (pct < 0.5) {
      msg = t('İyi gidiyorsun, devam! 💪', 'Going strong, keep it up! 💪');
    } else if (pct < 1) {
      msg = t('Hedefe çok az kaldı! 🚀', 'Almost at your goal! 🚀');
    } else {
      msg = t('🎉 Günlük hedef tamamlandı!', '🎉 Daily goal complete!');
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        SectionTitle(t('Su Takibi', 'Water Tracking')),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                SizedBox(
                  width: 170,
                  height: 170,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: pct,
                        strokeWidth: 14,
                        strokeCap: StrokeCap.round,
                        backgroundColor: c.card2,
                        valueColor: AlwaysStoppedAnimation(c.blue),
                      ),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${w.count}',
                                style: const TextStyle(
                                    fontSize: 34, fontWeight: FontWeight.w800)),
                            Text(t('/ ${w.goal} bardak', '/ ${w.goal} glasses'),
                                style: TextStyle(fontSize: 12, color: c.muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(msg, style: TextStyle(fontSize: 14, color: c.muted)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: c.blue),
                      onPressed: () => s.addWater(1),
                      child: Text(t('＋ 1 bardak', '＋ 1 glass')),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.tonal(
                      onPressed: () => s.addWater(-1),
                      child: Text(t('− Geri al', '− Undo')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(t('Günlük hedef', 'Daily goal'),
                        style: TextStyle(fontSize: 14, color: c.muted)),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => s.changeGoal(-1),
                          icon: const Icon(Icons.remove),
                        ),
                        SizedBox(
                          width: 80,
                          child: Text(t('${w.goal} bardak', '${w.goal} glasses'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        IconButton(
                          onPressed: () => s.changeGoal(1),
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(t('Hatırlatıcı', 'Reminder'),
                        style: TextStyle(fontSize: 14, color: c.muted)),
                    DropdownButton<int>(
                      value: w.intervalMinutes,
                      borderRadius: BorderRadius.circular(12),
                      items: [
                        DropdownMenuItem(value: 0, child: Text(t('Kapalı', 'Off'))),
                        DropdownMenuItem(value: 30, child: Text(t('30 dk', '30 min'))),
                        DropdownMenuItem(value: 60, child: Text(t('1 saat', '1 hour'))),
                        DropdownMenuItem(value: 90, child: Text(t('1,5 saat', '1.5 hours'))),
                        DropdownMenuItem(value: 120, child: Text(t('2 saat', '2 hours'))),
                      ],
                      onChanged: (v) async {
                        await s.setWaterInterval(v ?? 0);
                        if (context.mounted) {
                          toast(
                              context,
                              (v ?? 0) > 0
                                  ? t('💧 Her $v dakikada bir hatırlatılacak (08–22 arası)', '💧 Reminders every $v minutes (08–22)')
                                  : t('Su hatırlatıcısı kapatıldı', 'Water reminder turned off'));
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  t('Hatırlatıcılar uygulama kapalıyken de çalışır; gece 22:00 – sabah 08:00 arası sessizdir.', 'Reminders work even when the app is closed; silent between 22:00 and 08:00.'),
                  style: TextStyle(fontSize: 12, color: c.muted),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
