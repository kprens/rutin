import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'crisis_screen.dart';
import 'paywall_screen.dart';

class StreaksScreen extends StatefulWidget {
  const StreaksScreen({super.key});

  @override
  State<StreaksScreen> createState() => _StreaksScreenState();
}

class _StreaksScreenState extends State<StreaksScreen> {
  final _nameCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  DateTime? _startDate;

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _startDate = d);
  }

  void _add(AppState s) {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      toast(context, t('Bir isim yaz 🙂', 'Type a name 🙂'));
      return;
    }
    if (!s.canAddStreak) {
      // Ücretsiz limit doldu → en doğal paywall anı.
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const PaywallScreen()));
      return;
    }
    final cost =
        double.tryParse(_costCtrl.text.trim().replaceAll(',', '.')) ?? 0;
    s.addStreak(name, start: _startDate, dailyCost: cost);
    _nameCtrl.clear();
    _costCtrl.clear();
    setState(() => _startDate = null);
    toast(context, t('🔥 "$name" sayacı başladı!', '🔥 "$name" counter started!'));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = RutinColors.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        SectionTitle(t('Bağımlılık / Streak Sayacı', 'Quit Habit / Streak Counter')),
        if (s.streaks.isEmpty)
          EmptyCard(t(
              'Henüz sayaç yok.\nBırakmak istediğin bir alışkanlık ekle — sigara, şeker, sosyal medya…', 'No counters yet.\nAdd a habit to quit — smoking, sugar, social media…'))
        else
          ...s.streaks.map((st) => _StreakCard(streak: st)),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(t('Hazır seçenekler', 'Quick picks'),
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: c.muted)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: addictionPresets().map((a) {
                    final on =
                        _nameCtrl.text.trim().toLowerCase() == a.$2.toLowerCase();
                    return GestureDetector(
                      onTap: () => setState(() {
                        if (on) {
                          _nameCtrl.clear();
                        } else {
                          _nameCtrl.text = a.$2;
                        }
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: on
                              ? c.accent.withValues(alpha: 0.15)
                              : c.card2,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                              color: on ? c.accent : c.cardBorder,
                              width: on ? 2 : 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(a.$1, style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 5),
                            Text(a.$2,
                                style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: on
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: on ? c.accent : c.text)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameCtrl,
                  decoration:
                      InputDecoration(hintText: t('Neyi bırakıyorsun? (örn. Sigara)', 'What are you quitting? (e.g. Smoking)')),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _add(s),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _costCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                      hintText: t('Günlük maliyeti ₺ (isteğe bağlı, örn. 90)', 'Daily cost (optional, e.g. 90)')),
                  onSubmitted: (_) => _add(s),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.event, size: 18),
                        label: Text(_startDate == null
                            ? t('Bırakma tarihi (boşsa bugün)', 'Quit date (today if empty)')
                            : DateFormat('d MMMM y', T.locale).format(_startDate!)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: c.muted,
                          side: BorderSide(color: c.cardBorder),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                      onPressed: () => _add(s), child: Text(t('＋ Sayaç Başlat', '＋ Start Counter'))),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StreakCard extends StatelessWidget {
  final Streak streak;
  const _StreakCard({required this.streak});

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final c = RutinColors.of(context);
    final days = streak.days;
    final since = DateFormat('d MMMM y', T.locale).format(streak.start);

    String subtitle;
    if (days >= 1) {
      subtitle = t('gün temiz', 'days clean');
    } else {
      final diff = DateTime.now().difference(streak.start);
      subtitle = t('${diff.inHours} saat ${diff.inMinutes % 60} dk', '${diff.inHours} h ${diff.inMinutes % 60} min');
    }

    final next = milestones.where((m) => m > days).firstOrNull;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(streak.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    Text(t('$since tarihinden beri', 'since $since'),
                        style: TextStyle(fontSize: 12, color: c.muted)),
                  ],
                ),
                if (streak.bestDays > 0)
                  Text(t('🏅 En iyi: ${streak.bestDays} gün', '🏅 Best: ${streak.bestDays} days'),
                      style: TextStyle(fontSize: 12, color: c.amber)),
              ],
            ),
            const SizedBox(height: 12),
            ShaderMask(
              shaderCallback: (r) => LinearGradient(
                colors: [c.accent, c.amber],
              ).createShader(r),
              child: Text('$days',
                  style: const TextStyle(
                      fontSize: 44, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
            Text(subtitle, style: TextStyle(fontSize: 13, color: c.muted)),
            if (streak.dailyCost > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.green.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                      t('💰 ₺${streak.moneySaved.toStringAsFixed(0)} cebinde kaldı', '💰 ₺${streak.moneySaved.toStringAsFixed(0)} saved'),
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: c.green)),
                ),
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ...milestones
                    .where((m) => days >= m)
                    .map((m) => _badge(c, t('$m gün ✓', '$m days ✓'), won: true)),
                if (next != null)
                  _badge(c, t('Sıradaki: $next gün (${next - days} kaldı)', 'Next: $next days (${next - days} to go)'), dashed: true)
                else
                  _badge(c, t('Efsane! 🏆', 'Legend! 🏆'), won: true),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Text('🆘', style: TextStyle(fontSize: 16)),
                style: FilledButton.styleFrom(
                  backgroundColor: c.amber.withValues(alpha: .18),
                  foregroundColor: c.accent2,
                ),
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => CrisisScreen(streak: streak))),
                label: Text(t('İstek geldi — yardım al', 'Craving? Get help')),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: c.red.withValues(alpha: .15),
                    foregroundColor: c.red,
                  ),
                  onPressed: () async {
                    final ok = await confirm(
                      context,
                      title: t('Sayacı sıfırla?', 'Reset counter?'),
                      text:
                          t('"${streak.name}" — $days günlük serin sıfırlanacak. Düşme olur, önemli olan yeniden başlamak. 💪', '"${streak.name}" — your $days-day streak will reset. Slips happen; what matters is starting again. 💪'),
                      confirmLabel: t('Sıfırla', 'Reset'),
                    );
                    if (ok) {
                      s.resetStreak(streak);
                      if (context.mounted) {
                        toast(context, t('Sayaç sıfırlandı. Yeni seri şimdi başladı 💪', 'Counter reset. New streak starts now 💪'));
                      }
                    }
                  },
                  child: Text(t('Sıfırla', 'Reset')),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: () async {
                    final ok = await confirm(
                      context,
                      title: t('Sayacı sil?', 'Delete counter?'),
                      text: t('"${streak.name}" tamamen silinecek.', '"${streak.name}" will be permanently deleted.'),
                      confirmLabel: t('Sil', 'Delete'),
                    );
                    if (ok) {
                      s.deleteStreak(streak);
                      if (context.mounted) {
                        toastUndo(context, t('"${streak.name}" silindi', '"${streak.name}" deleted'),
                            () => s.restoreStreak(streak));
                      }
                    }
                  },
                  child: Text(t('Sil', 'Delete')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(RutinColors c, String text, {bool won = false, bool dashed = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: won ? c.green.withValues(alpha: .15) : c.card2,
        borderRadius: BorderRadius.circular(99),
        border: dashed ? Border.all(color: c.muted, width: .8) : null,
      ),
      child: Text(text,
          style: TextStyle(fontSize: 11, color: won ? c.green : c.muted)),
    );
  }
}
