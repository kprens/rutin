import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../store.dart';
import 'rutin_ui.dart';
import 'ui_logic.dart';
import 'achievements_screen.dart';
import 'paywall_screen.dart';
import 'settings_screen.dart';
import 'water_screen.dart';
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
              Text(name, style: RText.h2),
              const SizedBox(height: 4),
              Text(t('Üyelik: $since', 'Member since $since'), style: RText.muted),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: s.isPro ? RC.tintPurple : RC.tintAmber,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                      color: (s.isPro ? RC.purple : RC.amber)
                          .withValues(alpha: 0.4)),
                ),
                child: Text(
                    s.isPro ? '💎  ${t('Pro Üye', 'Pro Member')}' : '⭐  ${t('Ücretsiz', 'Free Plan')}',
                    style: TextStyle(
                        color: s.isPro ? RC.purpleBright : RC.amber,
                        fontWeight: FontWeight.w700)),
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
                        _statMini('🔥', '$totalStreaks',
                            t('Toplam Seri', 'Total Streaks'), RC.amber),
                        _statMini('🏆', '$earned',
                            t('Başarım', 'Achievements'), RC.purpleBright),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _statMini('✅', '${s.tasks.length}',
                            t('Alışkanlık', 'Active Habits'), RC.green),
                        _statMini('📅', '${s.daysActive}',
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
        _menu(context, '🏆', t('Başarımlar', 'Achievements'),
            const AchievementsScreen()),
        const SizedBox(height: 12),
        _menu(context, '💎', t('Pro\'ya Geç', 'Go Premium'),
            const PaywallScreen(),
            highlight: true),
        const SizedBox(height: 12),
        _menu(context, '⚙️', t('Ayarlar', 'Settings'), const SettingsScreen()),
        const SizedBox(height: 12),
        _menu(context, '💧', t('Su Takibi', 'Water Tracker'),
            const WaterScreen()),
        const SizedBox(height: 24),

        // ---- Sign Out ----
        GestureDetector(
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
                style: const TextStyle(
                    color: RC.red, fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(t('Rutin v1.0.0 · ❤️ ile yapıldı', 'Rutin v1.0.0 · Made with ❤️'),
              style: const TextStyle(color: RC.faint, fontSize: 13)),
        ),
      ],
    );
  }

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

  Widget _statMini(String emoji, String value, String label, Color color) {
    return Expanded(
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
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
                    style: const TextStyle(color: RC.muted, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _menu(BuildContext context, String emoji, String label, Widget target,
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
          EmojiTile(emoji,
              tint: highlight ? RC.purple.withValues(alpha: 0.2) : RC.card2),
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
