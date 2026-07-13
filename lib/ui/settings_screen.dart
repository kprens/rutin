import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n.dart';
import '../store.dart';
import 'rutin_ui.dart';
import 'ui_logic.dart';
import 'onboarding_screen.dart';
import 'water_screen.dart' show rutinAppBar;

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      backgroundColor: RC.bg,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: RG.header),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              rutinAppBar(context, t('Ayarlar', 'Settings')),
              const SizedBox(height: 24),

              RLabel(t('Bildirimler', 'Notifications')),
              RCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _toggleRow(
                        t('Bildirimler', 'Push Notifications'),
                        t('Hatırlatıcılar & kilometre taşları',
                            'Habit reminders & milestones'),
                        s.pushNotifications,
                        (v) => s.setSettings(push: v)),
                    _sep(),
                    _toggleRow(
                        t('Günlük Hatırlatma', 'Daily Reminders'),
                        t('Alışkanlıkları kontrol et', 'Remind me to check habits'),
                        s.dailyReminders,
                        (v) => s.setSettings(daily: v)),
                    _sep(),
                    _toggleRow(t('Sesler', 'Sounds'), null, s.sounds,
                        (v) => s.setSettings(sounds: v)),
                    _sep(),
                    _toggleRow(t('Titreşim', 'Haptic Feedback'), null, s.haptics,
                        (v) => s.setSettings(haptics: v)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              RLabel(t('Görünüm', 'Appearance')),
              RCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _toggleRow(
                        t('Koyu Mod', 'Dark Mode'),
                        t('En iyi deneyim için hep açık',
                            'Always on for best experience'),
                        true, (_) {
                      _toast(context,
                          t('Koyu mod her zaman açık.', 'Dark mode is always on.'));
                    }),
                    _sep(),
                    _rowWrap(
                      t('Hafta Başlangıcı', 'Week Starts On'),
                      Row(
                        children: [
                          _segment(t('Paz', 'Sun'), !s.weekStartsMonday,
                              () => s.setSettings(weekStartsMonday: false)),
                          const SizedBox(width: 8),
                          _segment(t('Pzt', 'Mon'), s.weekStartsMonday,
                              () => s.setSettings(weekStartsMonday: true)),
                        ],
                      ),
                    ),
                    _sep(),
                    _rowWrap(
                      t('Dil', 'Language'),
                      Row(
                        children: [
                          _segment('TR', !T.en, () => s.setLanguage('tr')),
                          const SizedBox(width: 8),
                          _segment('EN', T.en, () => s.setLanguage('en')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              RLabel(t('Hesap', 'Account')),
              RCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _linkRow(t('Profili Düzenle', 'Edit Profile'), null,
                        () => _editName(context, s)),
                    _sep(),
                    _linkRow(
                        t('Verini Dışa Aktar', 'Export Data'),
                        t('Alışkanlık geçmişini indir',
                            'Download your habit history'),
                        () => SharePlus.instance
                            .share(ShareParams(text: s.exportJson()))),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              RLabel(t('Veri & Gizlilik', 'Data & Privacy')),
              RCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 18),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(t('Hesabı Sil', 'Delete Account'),
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                          GestureDetector(
                            onTap: () => _deleteAccount(context, s),
                            child: Text(t('Sil', 'Delete'),
                                style: const TextStyle(
                                    color: RC.red,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                    t('Rutin v1.0.0 · ❤️ ile yapıldı',
                        'Rutin v1.0.0 · Made with ❤️'),
                    style: const TextStyle(color: RC.faint, fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toast(BuildContext context, String m) =>
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(m)));

  Future<void> _editName(BuildContext context, AppState s) async {
    final ctrl = TextEditingController(text: s.userName);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: RC.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(t('Adını düzenle', 'Edit name'),
            style: const TextStyle(color: RC.text, fontSize: 18)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: RC.text),
          decoration: InputDecoration(
            hintText: t('Ad Soyad', 'Full name'),
            hintStyle: const TextStyle(color: RC.muted),
            filled: true,
            fillColor: RC.card2,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: Text(t('Vazgeç', 'Cancel'),
                  style: const TextStyle(color: RC.muted))),
          TextButton(
              onPressed: () => Navigator.pop(dCtx, true),
              child: Text(t('Kaydet', 'Save'),
                  style: const TextStyle(
                      color: RC.purpleBright, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (ok == true) s.setUserName(ctrl.text);
  }

  Future<void> _deleteAccount(BuildContext context, AppState s) async {
    final ok = await rConfirm(context,
        title: t('Hesabı sil?', 'Delete account?'),
        message: t(
            'Tüm alışkanlıkların, serilerin ve verilerin kalıcı olarak silinecek. Bu geri alınamaz.',
            'All your habits, streaks and data will be permanently deleted. This cannot be undone.'),
        confirmLabel: t('Sil', 'Delete'),
        danger: true);
    if (!ok) return;
    await s.wipeAllData();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
          (r) => false);
    }
  }

  Widget _sep() =>
      const Divider(color: RC.stroke, height: 1, indent: 18, endIndent: 18);

  Widget _toggleRow(
      String title, String? sub, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                if (sub != null) ...[
                  const SizedBox(height: 3),
                  Text(sub,
                      style: const TextStyle(color: RC.muted, fontSize: 13)),
                ],
              ],
            ),
          ),
          RSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _rowWrap(String title, Widget trailing) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            trailing,
          ],
        ),
      );

  Widget _linkRow(String title, String? sub, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  if (sub != null) ...[
                    const SizedBox(height: 3),
                    Text(sub,
                        style: const TextStyle(color: RC.muted, fontSize: 13)),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: RC.muted),
          ],
        ),
      ),
    );
  }

  Widget _segment(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: active ? RC.purple.withValues(alpha: 0.35) : RC.card2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? RC.purple : RC.stroke),
        ),
        child: Text(label,
            style: TextStyle(
                color: active ? RC.text : RC.muted,
                fontWeight: FontWeight.w700)),
      ),
    );
  }
}
