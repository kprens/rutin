import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../friends.dart';
import '../l10n.dart';
import '../store.dart';
import 'paywall_screen.dart';
import 'rutin_ui.dart';
import 'ui_logic.dart';

/// Arkadaş / Sorumluluk Ortağı ekranı.
///
/// Backend (Supabase) yapılandırılmışsa: kendi arkadaşlık kodunu gösterir,
/// başka bir kodla istek gönderir, gelen/giden istekleri yönetir ve kabul
/// edilen arkadaşların paylaştığı streak'leri listeler. Backend yokken de
/// çökmez — sadece boş/uyarı durumları gösterir (bkz. friends.dart).
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});
  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _codeCtrl = TextEditingController();
  bool _sending = false;

  /// Kabul/reddet/kaldır sırasında hangi istek işleniyor — o kartta
  /// buton yerine küçük bir spinner gösterilir, tekrar tıklamayı engeller.
  final Set<int> _busyIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) {
      final st = context.read<AppState>();
      st.loadFriends();
      // Arkadaşlardan gelen "zorlanıyorum" sinyalleri (bkz. panik butonu,
      // crisis_screen.dart). Push altyapısı olmadığı için sinyaller ancak
      // ekran açıldığında görülür.
      st.loadPanicSignals();
    });
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  void _toast(String m) => ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(m)));

  Future<void> _send() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      _toast(t('Bir kod gir.', 'Enter a code.'));
      return;
    }
    setState(() => _sending = true);
    final err = await context.read<AppState>().addFriendByCode(code);
    if (!mounted) return;
    setState(() => _sending = false);
    if (err != null) {
      _toast(err);
    } else {
      _codeCtrl.clear();
      FocusScope.of(context).unfocus();
      _toast(t('İstek gönderildi 🎉', 'Request sent 🎉'));
    }
  }

  Future<void> _respond(FriendshipView f, {required bool accept}) async {
    setState(() => _busyIds.add(f.id));
    await context.read<AppState>().respondToFriendRequest(f, accept: accept);
    if (!mounted) return;
    setState(() => _busyIds.remove(f.id));
    if (accept) {
      _toast(t('Artık arkadaşsınız 🎉', 'You\'re friends now 🎉'));
    }
  }

  Future<void> _cancelOutgoing(FriendshipView f) async {
    setState(() => _busyIds.add(f.id));
    await context.read<AppState>().removeFriend(f);
    if (!mounted) return;
    setState(() => _busyIds.remove(f.id));
  }

  Future<void> _confirmRemove(FriendshipView f) async {
    final ok = await rConfirm(context,
        title: t('Arkadaşlıktan çıkar?', 'Remove friend?'),
        message: t('"${f.other.username}" arkadaş listenden kaldırılacak.',
            '"${f.other.username}" will be removed from your friends.'),
        confirmLabel: t('Kaldır', 'Remove'),
        danger: true);
    if (!ok || !mounted) return;
    setState(() => _busyIds.add(f.id));
    await context.read<AppState>().removeFriend(f);
    if (!mounted) return;
    setState(() => _busyIds.remove(f.id));
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    _toast(t('Kod kopyalandı', 'Code copied'));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final incoming = s.incomingRequests;
    final outgoing = s.outgoingRequests;
    final friends = s.acceptedFriends;

    return Scaffold(
      backgroundColor: RC.bg,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: RG.header),
        child: SafeArea(
          child: RefreshIndicator(
            color: RC.purpleBright,
            onRefresh: () async {
              final st = context.read<AppState>();
              await st.loadFriends();
              await st.loadPanicSignals();
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                rutinAppBar(context, t('Arkadaşlar', 'Friends')),
                const SizedBox(height: 20),
                Text(
                    t('Sorumluluk ortağınla birlikte ilerle',
                        'Stay accountable together'),
                    style: RText.muted),
                const SizedBox(height: 20),

                // ---- Arkadaştan gelen "zorlanıyorum" sinyalleri ----
                // Her şeyin ÜSTÜNDE gösterilir: bir arkadaşın kriz anında
                // yardım istemesi, bu ekrandaki diğer her şeyden önceliklidir.
                for (final sig in s.panicSignals)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _panicCard(context, s, sig),
                  ),

                // Bkz. themes_screen.dart'taki aynı not: tanıtım kartı ilk
                // hafta gösterilmez (AppState.showPremiumPromos).
                if (s.showPremiumPromos)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: RCard(
                      color: RC.tintAmber,
                      border: RC.amber.withValues(alpha: 0.3),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const PaywallScreen(source: 'friends'))),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                                t(
                                    'Sorumluluk Ortağı Pro\'da — ücretsizde de deneyebilirsin, sınırsız erişim için Pro\'ya geç.',
                                    'Accountability Partner is a Pro perk — you can try it free, go Pro for unlimited access.'),
                                style:
                                    TextStyle(color: RC.amber, fontSize: 13)),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.chevron_right, color: RC.amber),
                        ],
                      ),
                    ),
                  ),

                if (s.friendsLoading && friends.isEmpty && incoming.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (s.friendsError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: RCard(
                      color: RC.tintPink,
                      border: RC.red.withValues(alpha: 0.3),
                      child: Row(
                        children: [
                          Expanded(
                              child: Text(s.friendsError!,
                                  style: TextStyle(color: RC.red))),
                          TextButton(
                            onPressed: () =>
                                context.read<AppState>().loadFriends(),
                            child: Text(t('Tekrar dene', 'Retry'),
                                style: TextStyle(
                                    color: RC.red, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ---- Benim kodum ----
                RCard(
                  color: RC.tintPurple,
                  border: RC.purple.withValues(alpha: 0.3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t('Senin kodun', 'Your code'),
                                style: RText.muted),
                            const SizedBox(height: 6),
                            Text(s.myFriendCode ?? '——————',
                                style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 3,
                                    color: RC.purpleBright)),
                          ],
                        ),
                      ),
                      if (s.myFriendCode != null) ...[
                        IconButton(
                          tooltip: t('Kopyala', 'Copy'),
                          icon: Icon(Icons.copy_rounded,
                              color: RC.purpleBright),
                          onPressed: () => _copyCode(s.myFriendCode!),
                        ),
                        IconButton(
                          tooltip: t('Paylaş', 'Share'),
                          icon: Icon(Icons.ios_share, color: RC.purpleBright),
                          onPressed: () => SharePlus.instance.share(
                            ShareParams(
                              text: t(
                                  'Rutin\'de arkadaşım ol! Kodum: ${s.myFriendCode}',
                                  'Be my accountability partner on Rutin! My code: ${s.myFriendCode}'),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ---- Kod ile ekle ----
                Text(t('Arkadaş Ekle', 'Add Friend'), style: RText.title),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _codeCtrl,
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 6,
                        onSubmitted: (_) {
                          if (!_sending) _send();
                        },
                        style: TextStyle(
                            color: RC.text,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w700),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: t('Arkadaşının kodu', 'Friend\'s code'),
                          hintStyle:
                              TextStyle(color: RC.muted, letterSpacing: 0),
                          filled: true,
                          fillColor: RC.card,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: RC.stroke),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: RC.stroke),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: RC.purple),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _sending ? null : _send,
                      child: Container(
                        width: 54,
                        height: 54,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: RG.purpleBtn,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: _sending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.arrow_forward,
                                color: Colors.white),
                      ),
                    ),
                  ],
                ),

                // ---- Bekleyen istekler (gelen) ----
                if (incoming.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(t('Bekleyen İstekler', 'Pending Requests'),
                      style: RText.title),
                  const SizedBox(height: 12),
                  ...incoming.map((f) {
                    final busy = _busyIds.contains(f.id);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: RCard(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            _avatar(f.other.username, tint: RC.tintPurple),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Text(f.other.username,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: RC.text,
                                        fontWeight: FontWeight.w600))),
                            if (busy)
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child:
                                        CircularProgressIndicator(strokeWidth: 2)),
                              )
                            else ...[
                              IconButton(
                                icon: Icon(Icons.check_circle, color: RC.green),
                                onPressed: () => _respond(f, accept: true),
                              ),
                              IconButton(
                                icon: Icon(Icons.cancel, color: RC.red),
                                onPressed: () => _respond(f, accept: false),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                ],

                // ---- Gönderilen istekler ----
                if (outgoing.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(t('Gönderilen İstekler', 'Sent Requests'),
                      style: RText.title),
                  const SizedBox(height: 12),
                  ...outgoing.map((f) {
                    final busy = _busyIds.contains(f.id);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: RCard(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            _avatar(f.other.username, tint: RC.card2),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Text(f.other.username,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: RC.text))),
                            Text(t('Bekleniyor', 'Pending'),
                                style:
                                    TextStyle(color: RC.muted, fontSize: 12)),
                            const SizedBox(width: 8),
                            busy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : TextButton(
                                    onPressed: () => _cancelOutgoing(f),
                                    child: Text(t('İptal Et', 'Cancel'),
                                        style: TextStyle(color: RC.muted)),
                                  ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],

                // ---- Arkadaşlar ----
                const SizedBox(height: 24),
                Text(t('Arkadaşların', 'Your Friends'), style: RText.title),
                const SizedBox(height: 12),
                if (friends.isEmpty && !s.friendsLoading)
                  REmpty(
                    icon: Icons.group_outlined,
                    title: t('Henüz arkadaşın yok', 'No friends yet'),
                    message: t(
                        'Yukarıdaki davet kodunu paylaş ya da bir arkadaşının kodunu gir.',
                        "Share your invite code above, or enter a friend's code."),
                  )
                else
                  ...friends.map((f) => _friendCard(context, s, f)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Kullanıcı adının ilk harfini gösteren avatar — jenerik 👤 yerine.
  /// Bir arkadaşın gönderdiği "zorlanıyorum" sinyali kartı.
  ///
  /// Amaç kullanıcıyı harekete geçirmek: sinyali görmek yetmez, karşı tarafa
  /// "yanındayım" demek tek dokunuş olmalı. Onaylandığında kart kaybolmaz —
  /// gönderen kişi de onaylandığını görebilsin diye durum değişir.
  Widget _panicCard(BuildContext context, AppState s, PanicSignal sig) {
    final mins = sig.age.inMinutes;
    final ago = mins < 60
        ? t('$mins dk önce', '${mins}m ago')
        : t('${sig.age.inHours} saat önce', '${sig.age.inHours}h ago');

    return RCard(
      color: sig.acknowledged ? RC.card : RC.tintAmber,
      border: sig.acknowledged
          ? RC.stroke
          : RC.amber.withValues(alpha: 0.5),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                  sig.acknowledged
                      ? Icons.check_circle_rounded
                      : Icons.waving_hand_rounded,
                  size: 22,
                  color: sig.acknowledged ? RC.green : RC.amber),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                    sig.username.isEmpty
                        ? t('Bir arkadaşın zorlanıyor',
                            'A friend is struggling')
                        : t('${sig.username} zorlanıyor',
                            '${sig.username} is struggling'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: RC.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
              ),
              Text(ago,
                  style: TextStyle(color: RC.muted, fontSize: 12)),
            ],
          ),
          if (sig.streakName.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
                t('"${sig.streakName}" için destek istiyor.',
                    'Asking for support with "${sig.streakName}".'),
                style: TextStyle(color: RC.muted, fontSize: 13)),
          ],
          const SizedBox(height: 12),
          if (sig.acknowledged)
            Text(t('Yanında olduğunu bildirdin.', 'You let them know you\'re there.'),
                style: TextStyle(
                    color: RC.green, fontSize: 13, fontWeight: FontWeight.w600))
          else
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => s.acknowledgePanic(sig),
              child: Container(
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: RG.purpleBtn,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(t('Yanındayım', 'I\'m here'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _avatar(String name, {Color? tint}) {
    final letter = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint ?? RC.card2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: RC.stroke),
      ),
      child: Text(letter,
          style: TextStyle(
              color: RC.text, fontWeight: FontWeight.w800, fontSize: 16)),
    );
  }

  Widget _friendCard(BuildContext context, AppState s, FriendshipView f) {
    final shared = s.sharedStreaksOf(f.other.id);
    final busy = _busyIds.contains(f.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: RCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _avatar(f.other.username, tint: RC.tintTeal),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(f.other.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: RC.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w700))),
                if (busy)
                  const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                else
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_horiz, color: RC.muted),
                    color: RC.card,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    onSelected: (_) => _confirmRemove(f),
                    itemBuilder: (_) => [
                      PopupMenuItem<String>(
                        value: 'remove',
                        child: Text(t('Arkadaşlıktan çıkar', 'Remove friend'),
                            style: TextStyle(color: RC.red)),
                      ),
                    ],
                  ),
              ],
            ),
            if (shared.isNotEmpty) ...[
              const SizedBox(height: 12),
              Divider(color: RC.stroke, height: 1),
              const SizedBox(height: 12),
              ...shared.map((s0) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                            child: Text(s0.name,
                                style: TextStyle(color: RC.text),
                                overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 8),
                        Text(
                            t('${s0.days} gün temiz', '${s0.days} days clean'),
                            style: TextStyle(
                                color: RC.teal, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  )),
            ] else ...[
              const SizedBox(height: 6),
              Text(
                  t('Henüz bir şey paylaşmamış.',
                      'Hasn\'t shared anything yet.'),
                  style: TextStyle(color: RC.muted, fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }
}
