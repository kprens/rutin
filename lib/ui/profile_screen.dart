import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_info.dart';
import '../l10n.dart';
import '../store.dart';
import 'rutin_ui.dart';
import 'ui_logic.dart';
import 'achievements_screen.dart';
import 'friends_screen.dart';
import 'insights_screen.dart';
import 'paywall_screen.dart';
import 'settings_screen.dart';
import 'water_screen.dart';
import 'weekly_report_screen.dart';
import 'onboarding_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final now = DateTime.now();

    // Genel tamamlama oranı (son 30 gün).
    var possible = 0, done = 0;
    for (var i = 0; i < 30; i++) {
      final day = now.subtract(Duration(days: i));
      final ids = s.doneByDate[todayKey(day)] ?? const <int>[];
      for (final task in s.tasks) {
        if (task.activeOn(mondayIndex(day))) {
          possible++;
          if (ids.contains(task.id)) done++;
        }
      }
    }
    final overall = possible == 0 ? 0 : (done / possible * 100).round();

    final totalStreaks = s.streaks.fold<int>(0, (a, b) => a + b.daysOrBest) +
        s.tasks.fold<int>(0, (a, task) => a + s.taskStreak(task));
    final badges = evaluateBadges(s);
    final earned = badges.where((b) => b.earned).length;

    final name = s.userName.isNotEmpty ? s.userName : t('Rutin Kullanıcısı', 'Rutin User');
    final since = s.memberSince == null
        ? '—'
        : DateFormat('MMMM yyyy', T.locale).format(s.memberSince!);

    return RScreen(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: [
        // ---- Avatar ----
        Center(
          child: Column(
            children: [
              Stack(
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      gradient: RG.purpleBtn,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: RC.purple.withValues(alpha: 0.5),
                            blurRadius: 26),
                      ],
                    ),
                    child: const Icon(Icons.person, size: 52, color: Colors.white70),
                  ),
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: RC.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: RC.bg, width: 3),
                      ),
                      child: const Icon(Icons.check, size: 13, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: RText.h2),
              const SizedBox(height: 4),
              Text(t('Üyelik: $since', 'Member since $since'), style: RText.muted),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: s.hasPro ? RC.tintPurple : RC.tintAmber,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                      color: (s.hasPro ? RC.purple : RC.amber)
                          .withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                        s.isPro
                            ? Icons.diamond_rounded
                            : s.proTrialActive
                                ? Icons.hourglass_top_rounded
                                : Icons.star_rounded,
                        size: 16,
                        color: s.hasPro ? RC.purpleBright : RC.amber),
                    const SizedBox(width: 6),
                    Text(
                        s.isPro
                            ? t('Pro Üye', 'Pro Member')
                            : s.proTrialActive
                                ? t('Pro (deneme)', 'Pro (trial)')
                                : t('Ücretsiz', 'Free Plan'),
                        style: TextStyle(
                            color: s.hasPro ? RC.purpleBright : RC.amber,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ---- Stat kartı ----
        RCard(
          child: Row(
            children: [
              ProgressRing(
                value: overall / 100,
                size: 96,
                stroke: 8,
                color: RC.purple,
                center: Text('$overall%',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        _statMini(Icons.local_fire_department_rounded, '$totalStreaks',
                            t('Toplam Seri', 'Total Streaks'), RC.amber),
                        _statMini(Icons.emoji_events_rounded, '$earned',
                            t('Başarım', 'Achievements'), RC.purpleBright),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _statMini(Icons.check_circle_rounded, '${s.tasks.length}',
                            t('Alışkanlık', 'Active Habits'), RC.green),
                        _statMini(Icons.calendar_today_rounded, '${s.daysActive}',
                            t('Aktif Gün', 'Days Active'), RC.blue),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ---- Menü ----
        _menu(context, Icons.psychology_rounded, t('İçgörüler', 'Insights'),
            const InsightsScreen()),
        const SizedBox(height: 12),
        _menu(context, Icons.insights_rounded,
            t('Haftalık Rapor', 'Weekly Report'),
            const WeeklyReportScreen()),
        const SizedBox(height: 12),
        _menu(context, Icons.emoji_events_rounded, t('Başarımlar', 'Achievements'),
            const AchievementsScreen()),
        const SizedBox(height: 12),
        _menu(context, Icons.people_alt_rounded, t('Arkadaşlar', 'Friends'),
            const FriendsScreen()),
        const SizedBox(height: 12),
        // Pro üyeye "Pro'ya Geç" denmez: aynı ekranda "Pro Üye" rozeti dururken
        // vurgulu bir satır ödemiş kullanıcıyı tekrar satın almaya çağırıyordu.
        // Paywall zaten abone için "Pro aktif" durumunu gösteriyor
        // (paywall_screen.dart:414) — burada da abonelik yönetimi girişi olarak
        // adlandırılıyor ve vurgu kaldırılıyor.
        _menu(
            context,
            Icons.diamond_rounded,
            s.isPro
                ? t('Pro Üyeliğin', 'Your Pro Membership')
                : t('Pro\'ya Geç', 'Go Premium'),
            const PaywallScreen(source: 'profile'),
            highlight: !s.isPro),
        const SizedBox(height: 12),
        _menu(context, Icons.settings_rounded, t('Ayarlar', 'Settings'), const SettingsScreen()),
        const SizedBox(height: 12),
        _menu(context, Icons.water_drop_rounded, t('Su Takibi', 'Water Tracker'),
            const WaterScreen()),
        const SizedBox(height: 24),

        _signOutButton(context, s),
        const SizedBox(height: 20),
        Center(
          child: Text(
              t('Rutin v$kAppVersion · ❤️ ile yapıldı',
                  'Rutin v$kAppVersion · Made with ❤️'),
              style: TextStyle(color: RC.faint, fontSize: 13)),
        ),
      ],
    );
  }


  /// Çıkış butonu — onay diyaloğu [_signOut] içinde.
  Widget _signOutButton(BuildContext context, AppState s) => GestureDetector(
        onTap: () => _signOut(context, s),
        child: Container(
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: RC.red.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: RC.red.withValues(alpha: 0.4)),
          ),
          child: Text(t('Çıkış Yap', 'Sign Out'),
              style: TextStyle(
                  color: RC.red,
                  fontWeight: FontWeight.w700,
                  fontSize: 16)),
        ),
      );

  Future<void> _signOut(BuildContext context, AppState s) async {
    final ok = await rConfirm(context,
        title: t('Çıkış yapılsın mı?', 'Sign out?'),
        message: t('Verilerin cihazda kalır. Tekrar giriş yapabilirsin.',
            'Your data stays on device. You can sign back in.'),
        confirmLabel: t('Çıkış Yap', 'Sign Out'),
        danger: true);
    if (!ok) return;
    await s.signOut();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
          (r) => false);
    }
  }

  Widget _statMini(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800, color: color)),
                Text(label,
                    style: TextStyle(color: RC.muted, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _menu(BuildContext context, IconData icon, String label, Widget target,
      {bool highlight = false}) {
    return RCard(
      radius: 18,
      color: highlight ? RC.tintPurple : RC.card,
      border: highlight ? RC.purple.withValues(alpha: 0.4) : RC.stroke,
      padding: const EdgeInsets.all(14),
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => target)),
      child: Row(
        children: [
          IconTile(icon,
              tint: highlight ? RC.purple.withValues(alpha: 0.2) : RC.card2,
              iconColor: highlight ? RC.purpleBright : RC.text),
          const SizedBox(width: 14),
          Text(label,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: highlight ? RC.purpleBright : RC.text)),
          const Spacer(),
          Icon(Icons.chevron_right,
              color: highlight ? RC.purpleBright : RC.muted),
        ],
      ),
    );
  }
}
