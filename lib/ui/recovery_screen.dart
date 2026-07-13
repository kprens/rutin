import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../models.dart';
import '../store.dart';
import 'rutin_ui.dart';
import 'ui_logic.dart';

class RecoveryScreen extends StatelessWidget {
  const RecoveryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final totalDays = s.streaks.fold<int>(0, (a, b) => a + b.days);
    final totalMoney = s.streaks.fold<double>(0, (a, b) => a + b.moneySaved);
    final totalHours = s.streaks.fold<double>(0, (a, b) => a + b.hoursSaved);

    return RScreen(
      children: [
        const SizedBox(height: 8),
        Text(t('Bırakma', 'Recovery'), style: RText.h1),
        const SizedBox(height: 6),
        Text(t('Özgürlüğe giden yolculuğun', 'Your journey to freedom'),
            style: RText.muted),
        const SizedBox(height: 20),

        // ---- Combined impact ----
        RCard(
          color: RC.tintTeal,
          border: RC.teal.withValues(alpha: 0.25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t('Birleşik etki', 'Combined impact'), style: RText.muted),
              const SizedBox(height: 14),
              IntrinsicHeight(
                child: Row(
                  children: [
                    _impact('$totalDays', t('toplam temiz gün', 'days clean total'),
                        RC.teal),
                    _divider(),
                    _impact('\$${totalMoney.toStringAsFixed(0)}',
                        t('biriken para', 'money saved'), RC.teal),
                    _divider(),
                    _impact('${totalHours.toStringAsFixed(0)}s',
                        t('geri kazanılan', 'time reclaimed'), RC.purpleBright),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ---- Active Recovery ----
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(t('Aktif Kayıtlar', 'Active Recovery'), style: RText.title),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => showRecoverySheet(context),
              child: Text(t('+ Yeni Başlat', '+ Start New'),
                  style: const TextStyle(
                      color: RC.teal,
                      fontWeight: FontWeight.w600,
                      fontSize: 15)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (s.streaks.isEmpty)
          RCard(
            border: RC.strokeSoft,
            child: Text(
                t('Henüz kayıt yok. Bırakmak istediğin bir alışkanlık ekle.',
                    'No recoveries yet. Add a habit you want to quit.'),
                style: const TextStyle(color: RC.muted, height: 1.5)),
          )
        else
          ...s.streaks.map((r) => _recoveryCard(context, s, r)),

        const SizedBox(height: 6),

        // ---- Emergency Support ----
        RCard(
          color: RC.tintPink,
          border: RC.red.withValues(alpha: 0.3),
          onTap: () => openSos(context),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: RC.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('SOS',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t('Acil Destek', 'Emergency Support'),
                        style: const TextStyle(
                            color: RC.red,
                            fontSize: 17,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(t('İstek geldiğinde dokun', 'Tap when you feel a craving'),
                        style: const TextStyle(color: RC.muted, fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: RC.red),
            ],
          ),
        ),
      ],
    );
  }

  Widget _impact(String value, String label, Color color) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 26, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: RC.muted, fontSize: 12)),
          ],
        ),
      );

  Widget _divider() => Container(
        width: 1,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        color: RC.stroke,
      );

  Widget _recoveryCard(BuildContext context, AppState s, Streak r) {
    final days = r.days;
    final next = nextMilestone(days);
    final progress = (days / next.target).clamp(0.0, 1.0);
    final toGo = (next.target - days).clamp(0, next.target);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: () => _recoveryActions(context, s, r),
        child: RCard(
          child: Column(
            children: [
              Row(
                children: [
                  ProgressRing(
                    value: progress,
                    size: 74,
                    stroke: 6,
                    color: RC.teal,
                    center: Text(recoveryEmojiFor(r),
                        style: const TextStyle(fontSize: 26)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.name,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(
                            t('${_fmt(r.start)} tarihinden beri',
                                'Since ${_fmt(r.start)}'),
                            style: const TextStyle(
                                color: RC.muted, fontSize: 13)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('$days',
                          style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: RC.teal)),
                      Text(t('gün temiz', 'days clean'),
                          style: const TextStyle(color: RC.muted, fontSize: 12)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  if (r.dailyCost > 0) ...[
                    _tag('💰', '\$${r.moneySaved.toStringAsFixed(0)}', RC.teal),
                    const SizedBox(width: 18),
                  ],
                  if (r.dailyHours > 0) ...[
                    _tag('⏰', t('${r.hoursSaved.toStringAsFixed(0)}s',
                        '${r.hoursSaved.toStringAsFixed(0)}h'), RC.purpleBright),
                    const SizedBox(width: 18),
                  ],
                  if (r.relapses > 0)
                    _tag('📊', t('${r.relapses} nüks', '${r.relapses} relapse'),
                        RC.muted),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(color: RC.stroke, height: 1),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(t('Sıradaki: ${next.label}', 'Next: ${next.label}'),
                      style: const TextStyle(color: RC.muted, fontSize: 14)),
                  Text(t('$toGo gün kaldı', '$toGo days to go'),
                      style: const TextStyle(
                          color: RC.teal,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: RC.card2,
                  valueColor: const AlwaysStoppedAnimation(RC.teal),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(DateTime d) => '${d.day}.${d.month}.${d.year}';

  void _recoveryActions(BuildContext context, AppState s, Streak r) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: RC.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Text('🆘', style: TextStyle(fontSize: 20)),
              title: Text(t('İstek geldi — yardım al', 'Craving? Get help'),
                  style: const TextStyle(color: RC.text)),
              onTap: () {
                Navigator.pop(sheetCtx);
                openSos(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: RC.purpleBright),
              title: Text(t('Düzenle', 'Edit'),
                  style: const TextStyle(color: RC.text)),
              onTap: () {
                Navigator.pop(sheetCtx);
                showRecoverySheet(context, existing: r);
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh, color: RC.amber),
              title: Text(t('Sıfırla (nüksetme)', 'Reset (relapse)'),
                  style: const TextStyle(color: RC.text)),
              onTap: () async {
                Navigator.pop(sheetCtx);
                final ok = await rConfirm(context,
                    title: t('Sıfırlansın mı?', 'Reset counter?'),
                    message: t(
                        '"${r.name}" — ${r.days} günlük serin sıfırlanacak. Düşme olur, önemli olan yeniden başlamak. 💪',
                        '"${r.name}" — your ${r.days}-day streak will reset. Slips happen; what matters is starting again. 💪'),
                    confirmLabel: t('Sıfırla', 'Reset'),
                    danger: true);
                if (ok) s.resetStreak(r);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: RC.red),
              title: Text(t('Sil', 'Delete'),
                  style: const TextStyle(color: RC.red)),
              onTap: () async {
                Navigator.pop(sheetCtx);
                final ok = await rConfirm(context,
                    title: t('Silinsin mi?', 'Delete?'),
                    message: t('"${r.name}" tamamen silinecek.',
                        '"${r.name}" will be permanently deleted.'),
                    confirmLabel: t('Sil', 'Delete'),
                    danger: true);
                if (ok) {
                  s.deleteStreak(r);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                      ..clearSnackBars()
                      ..showSnackBar(SnackBar(
                        content: Text(t('"${r.name}" silindi',
                            '"${r.name}" deleted')),
                        action: SnackBarAction(
                            label: t('Geri al', 'Undo'),
                            onPressed: () => s.restoreStreak(r)),
                      ));
                  }
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _tag(String emoji, String text, Color color) => Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 5),
          Text(text,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      );
}
