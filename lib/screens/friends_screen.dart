import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n.dart';
import '../social.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  bool _loading = false;
  Map<String, dynamic>? _profile;
  List<FriendRequest> _requests = [];
  List<FriendEntry> _board = [];

  // Giriş formu
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _username = TextEditingController();
  final _code = TextEditingController();
  bool _registerMode = true;

  @override
  void initState() {
    super.initState();
    if (Social.signedIn) _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final s = context.read<AppState>();
      await Social.syncSharedStreaks(s.streaks, s.sharedStreakIds);
      _profile = await Social.myProfile();
      _requests = await Social.pendingRequests();
      _board = await Social.leaderboard(
          (_profile?['username'] ?? 'Ben') as String);
    } catch (e) {
      if (mounted) toast(context, t('Bağlantı sorunu: $e', 'Connection issue: $e'));
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _auth() async {
    final email = _email.text.trim();
    final pass = _password.text;
    if (email.isEmpty || pass.length < 6) {
      toast(context, t('Geçerli e-posta ve en az 6 haneli şifre gir', 'Enter a valid email and a 6+ character password'));
      return;
    }
    setState(() => _loading = true);
    try {
      if (_registerMode) {
        final name = _username.text.trim();
        if (name.isEmpty) {
          toast(context, t('Bir kullanıcı adı seç', 'Pick a username'));
          setState(() => _loading = false);
          return;
        }
        await Social.signUp(email, pass, name);
      } else {
        await Social.signIn(email, pass);
      }
      await _refresh();
    } catch (e) {
      if (mounted) toast(context, t('Olmadı: $e', 'Failed: $e'));
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = RutinColors.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(t('Arkadaşlar', 'Friends'),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        actions: [
          if (Social.signedIn)
            IconButton(
              tooltip: t('Yenile', 'Refresh'),
              icon: Icon(Icons.refresh, color: c.muted),
              onPressed: _refresh,
            ),
        ],
      ),
      body: !Social.signedIn
          ? _authView(c)
          : RefreshIndicator(
              onRefresh: _refresh,
              child: _mainView(c),
            ),
    );
  }

  // ---------- Giriş / kayıt ----------

  Widget _authView(RutinColors c) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 12),
        const Center(child: Text('👥', style: TextStyle(fontSize: 48))),
        const SizedBox(height: 12),
        Center(
          child: Text(t('Arkadaşlarınla birlikte güçlü kal', 'Stay strong with your friends'),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: c.text)),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            t("Streak'lerinizi birbirinize gösterin, başarı listesinde yarışın. Sadece paylaşmayı seçtiklerin görünür.", 'Show each other your streaks and climb the leaderboard. Only what you choose to share is visible.'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: c.muted, height: 1.5),
          ),
        ),
        const SizedBox(height: 24),
        if (_registerMode) ...[
          TextField(
            controller: _username,
            decoration:
                InputDecoration(hintText: t('Kullanıcı adı (örn. alper)', 'Username (e.g. alper)')),
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(hintText: t('E-posta', 'Email')),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _password,
          obscureText: true,
          decoration: InputDecoration(hintText: t('Şifre (en az 6 hane)', 'Password (min 6 characters)')),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: _loading ? null : _auth,
            child: Text(_loading
                ? t('Bekle…', 'Wait…')
                : (_registerMode ? t('Hesap Oluştur', 'Create Account') : t('Giriş Yap', 'Sign In'))),
          ),
        ),
        TextButton(
          onPressed: () => setState(() => _registerMode = !_registerMode),
          child: Text(
              _registerMode
                  ? t('Zaten hesabın var mı? Giriş yap', 'Already have an account? Sign in')
                  : t('Hesabın yok mu? Kayıt ol', "Don't have an account? Sign up"),
              style: TextStyle(color: c.muted, fontSize: 13)),
        ),
      ],
    );
  }

  // ---------- Ana görünüm ----------

  Widget _mainView(RutinColors c) {
    final s = context.watch<AppState>();
    final myCode = (_profile?['friend_code'] ?? '······') as String;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // Davet kodum
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(t('DAVET KODUN', 'YOUR INVITE CODE'),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: c.muted)),
                const SizedBox(height: 6),
                Text(myCode,
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 6,
                        color: c.accent2)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton.tonal(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: myCode));
                        toast(context, t('Kod kopyalandı', 'Code copied'));
                      },
                      child: Text(t('Kopyala', 'Copy')),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => Share.share(
                          t("Rutin'de arkadaş olalım! Davet kodum: $myCode 🔥", "Let's be friends on Rutin! My invite code: $myCode 🔥")),
                      child: Text(t('Paylaş', 'Share')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Kodla ekle
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    decoration:
                        InputDecoration(hintText: t('Arkadaş kodu gir', 'Enter friend code')),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () async {
                    final msg = await Social.addFriendByCode(_code.text);
                    _code.clear();
                    if (mounted) toast(context, msg);
                    _refresh();
                  },
                  child: Text(t('Ekle', 'Add')),
                ),
              ],
            ),
          ),
        ),

        // Bekleyen istekler
        if (_requests.isNotEmpty) ...[
          SectionTitle(t('Gelen İstekler', 'Incoming Requests')),
          ..._requests.map((r) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Text('👋', style: TextStyle(fontSize: 20)),
                  title: Text(r.username,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.check_circle, color: c.green),
                        onPressed: () async {
                          await Social.acceptRequest(r.id);
                          _refresh();
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.cancel, color: c.muted),
                        onPressed: () async {
                          await Social.declineRequest(r.id);
                          _refresh();
                        },
                      ),
                    ],
                  ),
                ),
              )),
        ],

        // Başarı listesi
        SectionTitle(t('Başarı Listesi', 'Leaderboard')),
        if (_loading)
          const Center(
              child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator()))
        else if (_board.length <= 1 && _board.every((e) => e.isMe))
          EmptyCard(t(
              'Henüz arkadaşın yok.\nKodunu paylaş, birlikte motive olun 💪', 'No friends yet.\nShare your code and get motivated together 💪'))
        else
          ...List.generate(_board.length, (i) {
            final e = _board[i];
            final medal = i == 0
                ? '👑'
                : i == 1
                    ? '🥈'
                    : i == 2
                        ? '🥉'
                        : '  ';
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(medal, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            e.isMe ? t('${e.username} (sen)', '${e.username} (you)') : e.username,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: e.isMe ? c.accent2 : c.text),
                          ),
                        ),
                        Text(t('${e.topDays} gün', '${e.topDays} days'),
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: c.accent2)),
                      ],
                    ),
                    if (e.streaks.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 30, top: 4),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: e.streaks
                              .map((st) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: c.card2,
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                    child: Text(
                                        t('🔥 ${st.name}: ${st.days} gün', '🔥 ${st.name}: ${st.days} days'),
                                        style: TextStyle(
                                            fontSize: 11, color: c.muted)),
                                  ))
                              .toList(),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),

        // Paylaşım ayarları
        SectionTitle(t('Neleri Paylaşıyorsun?', 'What Do You Share?')),
        if (s.streaks.isEmpty)
          EmptyCard(t("Henüz streak'in yok.\nStreak sekmesinden ekle 🔥", 'No streaks yet.\nAdd one from the Streaks tab 🔥'))
        else
          ...s.streaks.map((st) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: SwitchListTile(
                  title: Text(st.name,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  subtitle: Text(
                      s.sharedStreakIds.contains(st.id)
                          ? t('Arkadaşların görebilir', 'Visible to your friends')
                          : t('Gizli — sadece sen görürsün', 'Private — only you can see it'),
                      style: TextStyle(fontSize: 12, color: c.muted)),
                  activeThumbColor: c.accent,
                  value: s.sharedStreakIds.contains(st.id),
                  onChanged: (v) async {
                    s.toggleSharedStreak(st.id);
                    await Social.syncSharedStreaks(
                        s.streaks, s.sharedStreakIds);
                    _refresh();
                  },
                ),
              )),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () async {
              await Social.signOut();
              setState(() {});
            },
            child: Text(t('Çıkış yap', 'Sign out'),
                style: TextStyle(color: c.muted, fontSize: 13)),
          ),
        ),
        Center(
          child: TextButton(
            onPressed: () async {
              final ok = await confirm(
                context,
                title: t('Hesabı sil?', 'Delete account?'),
                text:
                    t('Hesabın, arkadaşlıkların ve paylaştığın tüm veriler kalıcı olarak silinir. Telefonundaki veriler etkilenmez. Bu işlem geri alınamaz.', 'Your account, friendships and all shared data will be permanently deleted. Data on your phone is not affected. This cannot be undone.'),
                confirmLabel: t('Hesabı Sil', 'Delete Account'),
              );
              if (ok) {
                try {
                  await Social.deleteAccount();
                  if (context.mounted) {
                    toast(context, t('Hesabın silindi.', 'Your account was deleted.'));
                    setState(() {});
                  }
                } catch (e) {
                  if (context.mounted) toast(context, t('Silinemedi: $e', 'Could not delete: $e'));
                }
              }
            },
            child: Text(t('Hesabı kalıcı olarak sil', 'Permanently delete account'),
                style: TextStyle(color: c.red, fontSize: 12)),
          ),
        ),
      ],
    );
  }
}
