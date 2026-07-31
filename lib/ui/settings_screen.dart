import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../ads.dart';
import '../analytics.dart';
import '../app_info.dart';
import '../iap.dart';
import '../l10n.dart';
import '../legal.dart';
import '../store.dart';
import 'rutin_ui.dart';
import 'ui_logic.dart';
import 'onboarding_screen.dart';
import 'themes_screen.dart';

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
                        t('Kapatırsan açık temaya geçersin',
                            'Turn off to switch to light theme'),
                        s.darkMode,
                        (v) => s.setDarkMode(v)),
                    _sep(),
                    _linkRow(
                      t('Tema', 'Theme'),
                      t('Renk ve görünümünü değiştir',
                          'Change colors and appearance'),
                      () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const ThemesScreen())),
                    ),
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
                          .share(ShareParams(text: s.exportJson())),
                    ),
                    // Abonelik yönetimi yalnızca Pro'su olana gösterilir —
                    // hiç satın alma yapmamış kullanıcıya boş bir mağaza
                    // sayfası açan satır göstermek kafa karıştırır.
                    //
                    // İptal uygulama içinden YAPILAMAZ (mağaza kontrolünde);
                    // kullanıcıyı doğru sayfaya götürmemek "iptal edemiyorum"
                    // şikâyetlerinin ve iadelerin en yaygın sebebidir.
                    if (s.isPro) ...[
                      _sep(),
                      _linkRow(
                        t('Aboneliği Yönet', 'Manage Subscription'),
                        t('Planını değiştir veya iptal et',
                            'Change your plan or cancel'),
                        // openLegalUrl adı dar kalıyor ama işlevi genel:
                        // harici bağlantıyı açar ve açılamazsa kullanıcıya
                        // sessiz kalmak yerine bilgi verir.
                        () => openLegalUrl(context, Iap.manageSubscriptionsUrl),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              RLabel(t('Veri & Gizlilik', 'Data & Privacy')),
              RCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    // Gizlilik politikası ve kullanım koşullarına uygulama
                    // içinden erişim mağazalar tarafından ZORUNLU tutuluyor
                    // (App Store 5.1.1 / 3.1.2, Google Play). Daha önce
                    // uygulamada hiçbir yasal bağlantı yoktu.
                    _linkRow(
                      t('Gizlilik Politikası', 'Privacy Policy'),
                      t('Verini nasıl işliyoruz', 'How we handle your data'),
                      () => openLegalUrl(context, kPrivacyPolicyUrl),
                    ),
                    _sep(),
                    _linkRow(
                      t('Kullanım Koşulları', 'Terms of Use'),
                      null,
                      () => openLegalUrl(context, kTermsOfUseUrl),
                    ),
                    // Reklam rızası yalnızca EEA/BK gibi gerekli bölgelerde
                    // anlamlıdır; diğer bölgelerde bu satır hiç görünmez.
                    const _AdPrivacyOptionsRow(),
                    _sep(),
                    // Ürün analitiği opt-out. Toplanan veri anonim ve kendi
                    // sunucumuzda kalıyor (bkz. analytics.dart), yine de
                    // kullanıcının kapatabilmesi hem doğru olan hem de
                    // gizlilik beyanlarını kolaylaştıran şey.
                    const _AnalyticsToggleRow(),
                    _sep(),
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
                                style: TextStyle(
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
                    t('Rutin v$kAppVersion · ❤️ ile yapıldı',
                        'Rutin v$kAppVersion · Made with ❤️'),
                    style: TextStyle(color: RC.faint, fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editName(BuildContext context, AppState s) async {
    final ctrl = TextEditingController(text: s.userName);
    try {
      await _editNameDialog(context, s, ctrl);
    } finally {
      // Diyalog her kapanışta (kaydet/vazgeç/geri tuşu) controller serbest
      // bırakılmalı; aksi halde ad her düzenlenişinde bir TextEditingController
      // ve ona bağlı dinleyiciler sızar.
      ctrl.dispose();
    }
  }

  Future<void> _editNameDialog(
      BuildContext context, AppState s, TextEditingController ctrl) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: RC.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(t('Adını düzenle', 'Edit name'),
            style: TextStyle(color: RC.text, fontSize: 18)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: RC.text),
          decoration: InputDecoration(
            hintText: t('Ad Soyad', 'Full name'),
            hintStyle: TextStyle(color: RC.muted),
            filled: true,
            fillColor: RC.card2,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: Text(t('Vazgeç', 'Cancel'),
                  style: TextStyle(color: RC.muted))),
          TextButton(
              onPressed: () => Navigator.pop(dCtx, true),
              child: Text(t('Kaydet', 'Save'),
                  style: TextStyle(
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
    final serverDeleted = await s.wipeAllData();
    if (!context.mounted) return;
    // Sunucudaki hesap silinemediyse kullanıcıya bunu SÖYLE. Sessiz kalmak,
    // App Store 5.1.1(v) kapsamında yapılmamış bir silmeyi yapılmış gibi
    // göstermek olurdu; kullanıcı da hesabının hâlâ durduğunu bilemezdi.
    if (!serverDeleted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          duration: const Duration(seconds: 8),
          content: Text(t(
              'Cihazındaki veriler silindi, ancak sunucudaki hesabına şu an ulaşılamadı. İnternete bağlanıp tekrar dene ya da destek ile iletişime geç.',
              'Your on-device data was deleted, but we couldn\'t reach your server account. Reconnect and try again, or contact support.')),
        ));
    }
    Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        (r) => false);
  }

  Widget _sep() =>
      Divider(color: RC.stroke, height: 1, indent: 18, endIndent: 18);

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
                      style: TextStyle(color: RC.muted, fontSize: 13)),
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
                        style: TextStyle(color: RC.muted, fontSize: 13)),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: RC.muted),
          ],
        ),
      ),
    );
  }

  static Widget _sepStatic() =>
      Divider(color: RC.stroke, height: 1, indent: 18, endIndent: 18);

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

/// Ürün analitiği açma/kapama satırı.
class _AnalyticsToggleRow extends StatefulWidget {
  const _AnalyticsToggleRow();

  @override
  State<_AnalyticsToggleRow> createState() => _AnalyticsToggleRowState();
}

class _AnalyticsToggleRowState extends State<_AnalyticsToggleRow> {
  late bool _on = Analytics.instance.enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('Kullanım İstatistikleri', 'Usage Analytics'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(
                    t('Anonim kullanım verisiyle uygulamayı geliştirmemize yardım et',
                        'Help us improve with anonymous usage data'),
                    style: TextStyle(color: RC.muted, fontSize: 13)),
              ],
            ),
          ),
          RSwitch(
            value: _on,
            onChanged: (v) {
              setState(() => _on = v);
              Analytics.instance.setEnabled(v);
            },
          ),
        ],
      ),
    );
  }
}

/// "Reklam Tercihleri" satırı — GDPR'ın rızayı geri çekme hakkı için.
///
/// Gereklilik durumu bir platform çağrısıyla öğrenildiği için bir kez
/// [initState]'te sorulur; Ayarlar her yeniden çizildiğinde tekrar tekrar
/// kanala gitmemesi için `FutureBuilder` yerine durum tutuluyor.
class _AdPrivacyOptionsRow extends StatefulWidget {
  const _AdPrivacyOptionsRow();

  @override
  State<_AdPrivacyOptionsRow> createState() => _AdPrivacyOptionsRowState();
}

class _AdPrivacyOptionsRowState extends State<_AdPrivacyOptionsRow> {
  bool _required = false;

  @override
  void initState() {
    super.initState();
    Ads.privacyOptionsRequired().then((v) {
      if (mounted && v) setState(() => _required = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_required) return const SizedBox.shrink();
    return Column(
      children: [
        SettingsScreen._sepStatic(),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: Ads.showPrivacyOptions,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t('Reklam Tercihleri', 'Ad Preferences'),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text(
                          t('Reklam rızanı değiştir',
                              'Change your ad consent choices'),
                          style: TextStyle(color: RC.muted, fontSize: 13)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: RC.muted),
              ],
            ),
          ),
        ),
      ],
    );
  }
}