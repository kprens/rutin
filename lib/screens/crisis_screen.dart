import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// Kriz Modu — "istek geldi" anında kullanıcıyı dalgayı atlatmaya
/// yönlendirir: 60 sn nefes egzersizi, ardından kazanımlar.
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
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
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
    final c = RutinColors.of(context);
    return Scaffold(
      body: SafeArea(
        child: _breathing ? _breathingPhase(c) : _gainsPhase(c),
      ),
    );
  }

  // ---------- Faz 1: Nefes ----------

  Widget _breathingPhase(RutinColors c) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Align(
            alignment: Alignment.topRight,
            child: TextButton(
              onPressed: () => setState(() => _breathing = false),
              child: Text(t('Geç', 'Skip'), style: TextStyle(color: c.muted)),
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
                          gradient: LinearGradient(colors: [c.accent, c.amber]),
                          boxShadow: [
                            BoxShadow(
                                color: c.accent.withValues(alpha: .35),
                                blurRadius: 40,
                                spreadRadius: 8),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(_breath.value > 0.5 ? t('Nefes ver…', 'Breathe out…') : t('Nefes al…', 'Breathe in…'),
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: c.text)),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Text(t('İstek bir dalgadır, birazdan geçecek.\nSadece nefesine odaklan.', 'A craving is a wave — it will pass.\nJust focus on your breath.'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: c.muted, height: 1.5)),
          const Spacer(),
          Text('$_secondsLeft',
              style: TextStyle(
                  fontSize: 30, fontWeight: FontWeight.w800, color: c.accent2)),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ---------- Faz 2: Kazanımlar ----------

  Widget _gainsPhase(RutinColors c) {
    final s = context.read<AppState>();
    final st = widget.streak;
    final quote = _quotes[Random().nextInt(_quotes.length)];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Spacer(),
          const Text('💪', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(t('Bak neler başardın', "Look what you've achieved"),
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: c.text)),
          const SizedBox(height: 20),
          _gainRow(c, '🔥', t('${st.days} gün', '${st.days} days'),
              t('"${st.name}" olmadan geçen süre', 'Time without "${st.name}"')),
          if (st.bestDays > st.days)
            _gainRow(c, '🏅', t('${st.bestDays} gün', '${st.bestDays} days'),
                t('En uzun serin — ona yeniden ulaşabilirsin', 'Your longest streak — you can reach it again')),
          if (st.dailyCost > 0)
            _gainRow(c, '💰', '₺${st.moneySaved.toStringAsFixed(0)}',
                t('Cebinde kalan para', 'Money saved')),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.cardBorder),
            ),
            child: Text('"$quote"',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: c.muted,
                    height: 1.5)),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: c.green,
                  padding: const EdgeInsets.symmetric(vertical: 15)),
              onPressed: () {
                Navigator.pop(context);
                toast(context, t('🎉 Dalgayı atlattın. Serin devam ediyor!', '🎉 You rode out the wave. Streak intact!'));
              },
              child: Text(t('Geçti, devam ediyorum 💪', "It passed — I'm good 💪")),
            ),
          ),
          TextButton(
            onPressed: () async {
              final ok = await confirm(
                context,
                title: t('Emin misin?', 'Are you sure?'),
                text:
                    t('${st.days} günlük serin ve tüm ilerlemen sıfırlanacak. Bir dakika daha beklemek ister misin?', 'Your ${st.days}-day streak and all progress will reset. Want to wait one more minute?'),
                confirmLabel: t('Sıfırla', 'Reset'),
              );
              if (ok && context.mounted) {
                s.resetStreak(st);
                Navigator.pop(context);
                toast(context,
                    t('Sıfırlandı. Düşmek değil, kalkmamak kaybettirir — yeni seri başladı 💪', "Reset done. Falling isn't losing — staying down is. New streak started 💪"));
              }
            },
            child: Text(t('Yine de sıfırla', 'Reset anyway'),
                style: TextStyle(color: c.muted, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _gainRow(RutinColors c, String emoji, String big, String small) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(big,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: c.accent2)),
                Text(small, style: TextStyle(fontSize: 12, color: c.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
