import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../insights.dart';
import '../l10n.dart';
import '../models.dart';
import '../store.dart';
import 'rutin_ui.dart';
import 'trigger_sheet.dart';

/// Kriz Modu — "istek geldi" anında kullanıcıyı dalgayı atlatmaya yönlendirir:
/// ~60 sn nefes egzersizi, ardından kazanımlar özeti. Yeni koyu mor/teal
/// tasarım sistemiyle (RC/RG/RButton) uyumlu tam ekran sürüm.
class CrisisScreen extends StatefulWidget {
  final Streak streak;
  const CrisisScreen({super.key, required this.streak});

  @override
  State<CrisisScreen> createState() => _CrisisScreenState();
}

class _CrisisScreenState extends State<CrisisScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath;
  Timer? _timer;
  int _secondsLeft = 60;
  bool _breathing = true;

  List<String> get _quotes => T.en
      ? const [
          'A craving is a wave — it rises, peaks and passes. Just wait it out.',
          'The you who gets through this moment will be stronger tomorrow.',
          'You built this streak. No one can take it — unless you let them.',
          'Giving in is 5 seconds of relief; holding on is a lifetime of pride.',
          'What you feel now is temporary. What you achieved is permanent.',
          'The hardest moment is right now. It only gets easier from here.',
        ]
      : const [
          'İstek bir dalgadır — gelir, yükselir ve geçer. Sen sadece bekle.',
          'Bu anı atlatan sen, yarın çok daha güçlü olacaksın.',
          'Serini sen inşa ettin. Kimse onu senden alamaz — sen izin vermedikçe.',
          'Vazgeçmek 5 saniyelik rahatlama, devam etmek ömürlük gurur.',
          'Şu an hissettiğin şey geçici. Başardıkların kalıcı.',
          'En zor an, tam da şimdi. Sonrası hep daha kolay.',
        ];

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
        vsync: this, duration: const Duration(seconds: 4))
      ..repeat(reverse: true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _breathing = false);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _breath.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RC.bg,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [RC.bgTop, RC.bg],
            begin: Alignment.topCenter,
            end: Alignment.center,
          ),
        ),
        child: SafeArea(
          child: _breathing ? _breathingPhase() : _gainsPhase(),
        ),
      ),
    );
  }

  // ---------- Faz 1: Nefes ----------

  Widget _breathingPhase() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Align(
            alignment: Alignment.topRight,
            child: TextButton(
              onPressed: () => setState(() => _breathing = false),
              child: Text(t('Geç', 'Skip'),
                  style: TextStyle(color: RC.muted)),
            ),
          ),
          const Spacer(),
          AnimatedBuilder(
            animation: _breath,
            builder: (_, __) {
              final v = Curves.easeInOut.transform(_breath.value);
              final size = 130 + v * 90;
              return Column(
                children: [
                  SizedBox(
                    width: 240,
                    height: 240,
                    child: Center(
                      child: Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [RC.purple, RC.teal],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                                color: RC.purple.withValues(alpha: 0.35),
                                blurRadius: 40,
                                spreadRadius: 8),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                      _breath.value > 0.5
                          ? t('Nefes ver…', 'Breathe out…')
                          : t('Nefes al…', 'Breathe in…'),
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: RC.text)),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Text(
              t('İstek bir dalgadır, birazdan geçecek.\nSadece nefesine odaklan.',
                  'A craving is a wave — it will pass.\nJust focus on your breath.'),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, color: RC.muted, height: 1.5)),
          const Spacer(),
          Text('$_secondsLeft',
              style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: RC.purpleBright)),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ---------- Faz 2: Kazanımlar ----------

  Widget _gainsPhase() {
    final s = context.read<AppState>();
    final st = widget.streak;
    final quote = _quotes[Random().nextInt(_quotes.length)];
    // Bir kez hesaplanır (build içinde iki kez çağrılmasın).
    final encouragement = crisisEncouragement(s.triggerLog);

    // ListView (Column + Spacer değil): kullanıcının "Geleceğe Mektup"u
    // 1000 karaktere kadar olabiliyor; sabit bir Column'da uzun mektup +
    // kazanım satırları küçük ekranlarda taşıp overflow şeridi çıkarırdı.
    // Kriz ekranı, hata göstermeye en az tolerans gösterilecek ekrandır.
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Column(
          children: [
          const SizedBox(height: 8),
          Icon(Icons.fitness_center_rounded, size: 48, color: RC.teal),
          const SizedBox(height: 16),
          Text(t('Bak neler başardın', "Look what you've achieved"),
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: RC.text)),

          // ---- Kişisel kanıt ----
          // Kullanıcının KENDİ geçmişinden çıkan somut bir cümle (bkz.
          // insights.dart → crisisEncouragement). Genel bir motivasyon
          // sözünden çok daha ikna edicidir çünkü itiraz edilemez:
          // "bunu daha önce 4 kez atlattın". Veri yoksa hiç gösterilmez —
          // uydurma istatistik göstermektense sessiz kalmak doğrudur.
          if (encouragement != null) ...[
            const SizedBox(height: 10),
            Text(encouragement,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15,
                    color: RC.teal,
                    fontWeight: FontWeight.w600,
                    height: 1.4)),
          ],
          const SizedBox(height: 20),
          _gainRow(Icons.local_fire_department_rounded, t('${st.days} gün', '${st.days} days'),
              t('"${st.name}" olmadan geçen süre', 'Time without "${st.name}"')),
          if (st.bestDays > st.days)
            _gainRow(Icons.military_tech_rounded, t('${st.bestDays} gün', '${st.bestDays} days'),
                t('En uzun serin — ona yeniden ulaşabilirsin',
                    'Your longest streak — you can reach it again')),
          if (st.dailyCost > 0)
            _gainRow(Icons.savings_rounded, '₺${st.moneySaved.toStringAsFixed(0)}',
                t('Cebinde kalan para', 'Money saved')),
          const SizedBox(height: 18),

          // ---- Geleceğe Mektup ----
          // Kullanıcı kendine bir mektup bıraktıysa, kriz anında gösterilecek
          // EN GÜÇLÜ şey budur: dışarıdan gelen genel bir motivasyon sözü
          // değil, kişinin kendi kararı, kendi sözleriyle. Bu yüzden alıntının
          // ÜSTÜNDE ve daha vurgulu gösterilir.
          if (st.letter.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: RC.tintPurple,
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: RC.purple.withValues(alpha: 0.45)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.mark_email_read_rounded,
                          size: 16, color: RC.purpleBright),
                      const SizedBox(width: 6),
                      Text(
                          t('Kendine yazdıkların', 'What you wrote to yourself'),
                          style: TextStyle(
                              color: RC.purpleBright,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text('"${st.letter}"',
                      style: TextStyle(
                          fontSize: 15,
                          color: RC.text,
                          height: 1.5,
                          fontStyle: FontStyle.italic)),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: RC.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: RC.stroke),
            ),
            child: Text('"$quote"',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: RC.muted,
                    height: 1.5)),
          ),
          // ---- Panik butonu: arkadaşa haber ver ----
          // Yalnızca gerçekten arkadaşı olan kullanıcıya gösterilir; kimseye
          // ulaşmayacak bir buton, krizdeki insanı boşuna umutlandırırdı.
          if (s.acceptedFriends.isNotEmpty) ...[
            const SizedBox(height: 20),
            _PanicButton(streakName: st.name),
          ],

          const SizedBox(height: 24),
          RButton(
            t('Geçti, devam ediyorum 💪', "It passed — I'm good 💪"),
            gradient: LinearGradient(colors: [RC.teal, RC.greenDeep]),
            onTap: () {
              // Bu ekran kapandıktan SONRA hem bildirim hem tetikleyici
              // anketi gösterilecek; ikisi de bu State'in context'ini
              // kullanamaz (pop sonrası dispose edilir). Bu yüzden hem
              // messenger hem de Navigator'ın KENDİ context'i önceden
              // yakalanıyor.
              final messenger = ScaffoldMessenger.of(context);
              final navContext = Navigator.of(context).context;
              Navigator.pop(context);
              messenger
                ..clearSnackBars()
                ..showSnackBar(SnackBar(
                    content: Text(t('🎉 Dalgayı atlattın. Serin devam ediyor!',
                        '🎉 You rode out the wave. Streak intact!'))));
              // Kriz ANINDA değil, bittikten sonra tek dokunuşluk soru.
              askTrigger(navContext, streak: st, survived: true);
            },
          ),
          TextButton(
            onPressed: () async {
              // messenger ve navContext, onay diyaloğu AÇILMADAN önce
              // yakalanıyor (yukarıdaki "Geçti" butonuyla aynı gerekçe):
              // onaydan sonra bu ekran pop edilecek ve kendi context'i
              // geçersizleşecek. Await'ten sonra türetmek, ekran bu sırada
              // kapatılmışsa geçersiz bir context kullanmak olurdu.
              final messenger = ScaffoldMessenger.of(context);
              final navContext = Navigator.of(context).context;
              final ok = await _confirm(
                title: t('Emin misin?', 'Are you sure?'),
                message: t(
                    '${st.days} günlük serin ve tüm ilerlemen sıfırlanacak. Bir dakika daha beklemek ister misin?',
                    'Your ${st.days}-day streak and all progress will reset. Want to wait one more minute?'),
                confirmLabel: t('Sıfırla', 'Reset'),
              );
              // `context.mounted` DEĞİL `mounted`: buradaki context bu
              // State'in kendi context'i, dolayısıyla doğru kontrol State'in
              // mounted'ıdır. Onay diyaloğu açıkken kullanıcı ekranı
              // kapatmış olabilir.
              // `mounted` bu State'i, `navContext.mounted` ise aşağıda
              // tetikleyici anketini açacak olan Navigator context'ini korur;
              // ikisi ayrı ağaç düğümü olduğu için ayrı ayrı doğrulanmalı.
              if (!ok || !mounted || !navContext.mounted) return;
              s.resetStreak(st);
              Navigator.pop(context);
              messenger
                ..clearSnackBars()
                ..showSnackBar(SnackBar(
                    content: Text(t(
                        'Sıfırlandı. Düşmek değil, kalkmamak kaybettirir — yeni seri başladı 💪',
                        "Reset done. Falling isn't losing — staying down is. New streak started 💪"))));
              // Nüks sonrası da sorulur — asıl değerli veri budur.
              // Ton suçlayıcı değil (bkz. trigger_sheet.dart).
              askTrigger(navContext, streak: st, survived: false);
            },
            child: Text(t('Yine de sıfırla', 'Reset anyway'),
                style: TextStyle(color: RC.muted, fontSize: 13)),
          ),
          ],
        ),
      ],
    );
  }

  Widget _gainRow(IconData icon, String big, String small) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 24, color: RC.purpleBright),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(big,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: RC.purpleBright)),
                Text(small,
                    style: TextStyle(fontSize: 12, color: RC.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // NOT: Eski `_toast` yardımcısı kaldırıldı. Bu ekranın her iki çıkışı da
  // (atlattım / sıfırla) artık kendi ScaffoldMessenger'ını ÖNCEDEN yakalıyor,
  // çünkü bildirim ekran kapandıktan sonra gösteriliyor ve o noktada bu
  // State'in context'i artık geçerli değil.

  Future<bool> _confirm(
      {required String title,
      required String message,
      required String confirmLabel}) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: RC.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title,
            style: TextStyle(color: RC.text, fontSize: 18)),
        content: Text(message,
            style: TextStyle(color: RC.muted, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: Text(t('Vazgeç', 'Cancel'),
                style: TextStyle(color: RC.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dCtx, true),
            child: Text(confirmLabel,
                style: TextStyle(
                    color: RC.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    return r ?? false;
  }
}

/// "Arkadaşıma haber ver" butonu.
///
/// Yalnız olmadığını hissettirmek, kriz anında en güçlü destektir. Ancak
/// bu buton ANLIK bildirim göndermez (Rutin'de push altyapısı yok, bkz.
/// supabase_panic_signals.sql) — arkadaş uygulamayı bir sonraki açışında
/// görür. Bu, kullanıcıya AÇIKÇA söylenir: krizdeki bir insana
/// tutulamayacak bir söz vermek, tam da güvenin en kritik olduğu anda
/// yalan söylemek olurdu.
class _PanicButton extends StatefulWidget {
  final String streakName;
  const _PanicButton({required this.streakName});

  @override
  State<_PanicButton> createState() => _PanicButtonState();
}

class _PanicButtonState extends State<_PanicButton> {
  bool _sending = false;
  bool _sent = false;

  Future<void> _send() async {
    setState(() => _sending = true);
    final ok =
        await context.read<AppState>().sendPanicSignal(widget.streakName);
    if (!mounted) return;
    setState(() {
      _sending = false;
      _sent = ok;
    });
    if (!ok) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
            content: Text(t('Sinyal gönderilemedi. Bağlantını kontrol et.',
                'Couldn\'t send. Check your connection.'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: RC.tintGreen,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: RC.green.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded, size: 20, color: RC.green),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                  t('Arkadaşlarına iletildi. Uygulamayı açtıklarında görecekler.',
                      'Sent to your friends. They\'ll see it next time they open the app.'),
                  style:
                      TextStyle(color: RC.text, fontSize: 13, height: 1.4)),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _sending ? null : _send,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: RC.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: RC.stroke),
        ),
        child: Row(
          children: [
            if (_sending)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: RC.purpleBright),
              )
            else
              Icon(Icons.waving_hand_rounded, size: 20, color: RC.amber),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('Arkadaşıma haber ver', 'Let a friend know'),
                      style: TextStyle(
                          color: RC.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                      t('Zorlandığını bilsinler — uygulamayı açtıklarında görecekler',
                          'Let them know you\'re struggling — they\'ll see it when they open the app'),
                      style: TextStyle(color: RC.muted, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}