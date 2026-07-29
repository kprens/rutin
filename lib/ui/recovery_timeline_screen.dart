/// Sağlık Geri Kazanım Zaman Çizelgesi ekranı.
///
/// Kullanıcının bırakma kaydına özel iyileşme kilometre taşlarını, ulaşılan /
/// sıradaki / kilitli olarak dikey bir zaman çizelgesinde gösterir.
///
/// Ürün mantığı (bkz. ABONELIK-STRATEJISI.md):
///  • İlk [_freeMilestones] kilometre taşı HERKESE açıktır — değeri önce
///    yaşat, sonra sat. Ayrıca en erken kilometre taşları (ilk 72 saat)
///    kullanıcının en çok desteğe ihtiyaç duyduğu andır; onları paraya
///    çevirmek etik olmaz.
///  • Sonrası Pro'da. "Sıradaki kilometre taşı" hep görünür durur ki
///    kullanıcı neyi bekleyeceğini bilsin (Zeigarnik etkisi).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../models.dart';
import '../recovery_timeline.dart';
import '../store.dart';
import 'letter_screen.dart';
import 'paywall_screen.dart';
import 'rutin_ui.dart';

/// Ücretsiz kullanıcıya açık kilometre taşı sayısı.
const _freeMilestones = 3;

/// Bir kilometre taşına ulaşıldı mı?
///
/// Uygulamanın geri kalanı (Streak.days, ana ekran, kartlar) TAKVİM GÜNÜ
/// sayar — gece yarısı geçince +1. Bu ekran ise saat/dakikalık taşlar için
/// gerçek geçen süreye ihtiyaç duyuyor. İkisi karıştırılırsa görünür bir
/// çelişki doğar: dün 23:00'te bırakan kullanıcı ana ekranda "1 gün temiz"
/// görürken burada 1 günlük eşiği geçmemiş görünürdü.
///
/// Çözüm: 1 günün ALTINDAKİ taşlar için gerçek süre (20 dakika, 12 saat,
/// 72 saat gibi taşlar zaten böyle anlamlı), 1 gün ve ÜSTÜ taşlar için
/// uygulamanın geri kalanıyla aynı takvim günü sayacı.
bool _reached(Duration after, Duration elapsed, int calendarDays) =>
    after.inDays < 1 ? elapsed >= after : calendarDays >= after.inDays;

class RecoveryTimelineScreen extends StatelessWidget {
  final Streak streak;
  const RecoveryTimelineScreen({super.key, required this.streak});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final category = categoryFor(emoji: streak.emoji, name: streak.name);
    final milestones = milestonesFor(category);
    final elapsed = DateTime.now().difference(streak.start);

    final reachedCount =
        milestones.where((m) => _reached(m.after, elapsed, streak.days)).length;
    final nextIndex = reachedCount < milestones.length ? reachedCount : null;

    return Scaffold(
      backgroundColor: RC.bg,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: RG.header),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              rutinAppBar(context, t('İyileşme Yolculuğun', 'Your Recovery')),
              const SizedBox(height: 18),

              // ---- Özet kartı ----
              RCard(
                color: RC.tintTeal,
                border: RC.teal.withValues(alpha: 0.25),
                child: Row(
                  children: [
                    Icon(Icons.favorite_rounded, size: 32, color: RC.teal),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(streak.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: RC.text,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text(
                              t('$reachedCount / ${milestones.length} kilometre taşı geçildi',
                                  '$reachedCount of ${milestones.length} milestones reached'),
                              style:
                                  TextStyle(color: RC.muted, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ---- Geleceğe Mektup girişi ----
              RCard(
                color: streak.letter.isEmpty ? RC.card : RC.tintPurple,
                border: streak.letter.isEmpty
                    ? RC.stroke
                    : RC.purple.withValues(alpha: 0.35),
                padding: const EdgeInsets.all(14),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => LetterScreen(streak: streak))),
                child: Row(
                  children: [
                    Icon(
                        streak.letter.isEmpty
                            ? Icons.edit_note_rounded
                            : Icons.mark_email_read_rounded,
                        size: 24,
                        color: streak.letter.isEmpty
                            ? RC.muted
                            : RC.purpleBright),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              t('Geleceğe Mektup', 'Letter to Future You'),
                              style: TextStyle(
                                  color: RC.text,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(
                              streak.letter.isEmpty
                                  ? t('Zor bir anda kendini ikna etmen için şimdi yaz',
                                      'Write now so you can convince yourself later')
                                  : t('Yazıldı — kriz anında karşına çıkacak',
                                      'Written — it will appear when a craving hits'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  TextStyle(color: RC.muted, fontSize: 12)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: RC.muted, size: 20),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ---- Zaman çizelgesi ----
              for (var i = 0; i < milestones.length; i++)
                _MilestoneRow(
                  milestone: milestones[i],
                  elapsed: elapsed,
                  calendarDays: streak.days,
                  isLast: i == milestones.length - 1,
                  // Kilitli mi: Pro değilse ve ücretsiz kotanın dışındaysa.
                  // "Sıradaki" taş, kilitli olsa bile başlığı görünür kalır —
                  // kullanıcı neyi beklediğini bilmeli.
                  locked: !s.hasPro && i >= _freeMilestones,
                  isNext: nextIndex == i,
                  onLockedTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PaywallScreen(source: 'recovery_timeline'))),
                ),

              const SizedBox(height: 10),

              // ---- Tıbbi sorumluluk reddi (ZORUNLU) ----
              RCard(
                color: RC.card2,
                border: RC.strokeSoft,
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 16, color: RC.muted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(medicalDisclaimer,
                          style: TextStyle(
                              color: RC.muted, fontSize: 12, height: 1.4)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  final RecoveryMilestone milestone;
  final Duration elapsed;
  final int calendarDays;
  final bool isLast;
  final bool locked;
  final bool isNext;
  final VoidCallback onLockedTap;

  const _MilestoneRow({
    required this.milestone,
    required this.elapsed,
    required this.calendarDays,
    required this.isLast,
    required this.locked,
    required this.isNext,
    required this.onLockedTap,
  });

  @override
  Widget build(BuildContext context) {
    final reached = _reached(milestone.after, elapsed, calendarDays);
    final remaining = milestone.after - elapsed;

    final dotColor = reached
        ? RC.teal
        : isNext
            ? RC.purpleBright
            : RC.stroke;

    return GestureDetector(
      onTap: locked ? onLockedTap : null,
      behavior: HitTestBehavior.opaque,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- Sol: nokta + dikey çizgi ----
            Column(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: reached ? RC.teal : Colors.transparent,
                    border: Border.all(color: dotColor, width: 2),
                  ),
                  child: reached
                      ? const Icon(Icons.check,
                          size: 13, color: Colors.white)
                      : null,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: reached ? RC.teal.withValues(alpha: 0.4) : RC.stroke,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),

            // ---- Sağ: içerik ----
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(whenLabel(milestone.after),
                            style: TextStyle(
                                color: reached ? RC.teal : RC.muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                        if (isNext && !reached) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(remainingLabel(remaining),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: RC.purpleBright, fontSize: 12)),
                          ),
                        ],
                        if (locked) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.lock_rounded, size: 12, color: RC.muted),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(milestone.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: reached || isNext ? RC.text : RC.muted,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 1.2)),
                    const SizedBox(height: 3),
                    if (locked)
                      Text(
                          t('Pro ile bu kilometre taşını ve devamını gör',
                              'See this milestone and beyond with Pro'),
                          style: TextStyle(
                              color: RC.purpleBright,
                              fontSize: 13,
                              fontWeight: FontWeight.w600))
                    else
                      Text(milestone.body,
                          style: TextStyle(
                              color: RC.muted, fontSize: 13, height: 1.35)),
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
