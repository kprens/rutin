import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import 'paywall_screen.dart';

class CelebrationScreen extends StatefulWidget {
  final Streak streak;
  final int milestone;

  const CelebrationScreen(
      {super.key, required this.streak, required this.milestone});

  @override
  State<CelebrationScreen> createState() => _CelebrationScreenState();
}

class _CelebrationScreenState extends State<CelebrationScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 4))
          ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final c = RutinColors.of(context);
    final m = widget.milestone;

    return Scaffold(
      body: Stack(
        children: [
          // Konfeti
          AnimatedBuilder(
            animation: _controller,
            builder: (_, __) => CustomPaint(
              size: MediaQuery.of(context).size,
              painter: _ConfettiPainter(
                progress: _controller.value,
                colors: [c.accent, c.amber, c.green, c.blue, c.accent2],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Spacer(),
                  const Text('🎉', style: TextStyle(fontSize: 56)),
                  const SizedBox(height: 12),
                  ShaderMask(
                    shaderCallback: (r) => LinearGradient(
                            colors: [c.accent, c.amber])
                        .createShader(r),
                    child: Text(t('$m GÜN', '$m DAYS'),
                        style: const TextStyle(
                            fontSize: 64,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -1)),
                  ),
                  const SizedBox(height: 8),
                  Text(t('"${widget.streak.name}" olmadan $m gün!', '$m days without "${widget.streak.name}"!'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: c.text)),
                  const SizedBox(height: 6),
                  Text(t('Bu ciddi bir başarı. Kendinle gurur duy. 🔥', "That's a real achievement. Be proud. 🔥"),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: c.muted)),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.share),
                      style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                      onPressed: () {
                        final saved = widget.streak.dailyCost > 0
                            ? t(' Cebimde ₺${widget.streak.moneySaved.toStringAsFixed(0)} kaldı. 💰', ' Saved ₺${widget.streak.moneySaved.toStringAsFixed(0)}. 💰')
                            : '';
                        Share.share(t(
                            '$m gündür "${widget.streak.name}" yok! 🔥$saved Rutin ile alışkanlıklarımı takip ediyorum. #rutin',
                            '$m days without "${widget.streak.name}"! 🔥$saved Tracking my habits with Rutin. #rutin'));
                      },
                      label: Text(t('Başarını paylaş', 'Share your win')),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Akıllı paywall: duygusal zirve anında Pro teklifi.
                  if (!s.isPro && m >= 7)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonal(
                        style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14)),
                        onPressed: () {
                          Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const PaywallScreen()));
                        },
                        child: Text(t('🔥 Bu güçle devam et — Rutin Pro', '🔥 Keep the momentum — Rutin Pro')),
                      ),
                    ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(t('Devam', 'Continue'),
                        style: TextStyle(color: c.muted)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfettiParticle {
  final double x, size, speed, drift, spin;
  final int colorIndex;
  _ConfettiParticle(Random r, int colorCount)
      : x = r.nextDouble(),
        size = 6 + r.nextDouble() * 8,
        speed = 0.5 + r.nextDouble() * 0.9,
        drift = (r.nextDouble() - 0.5) * 0.3,
        spin = r.nextDouble() * 6.28,
        colorIndex = r.nextInt(colorCount);
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  final List<Color> colors;
  static final List<_ConfettiParticle> _particles =
      List.generate(90, (_) => _ConfettiParticle(Random(42 + _), 5));

  _ConfettiPainter({required this.progress, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in _particles) {
      final y = (p.speed * progress * 1.4) % 1.2 - 0.1;
      final x = p.x + p.drift * progress;
      if (y < 0 || y > 1) continue;
      paint.color =
          colors[p.colorIndex % colors.length].withValues(alpha: 0.9);
      canvas.save();
      canvas.translate(x * size.width, y * size.height);
      canvas.rotate(p.spin + progress * 8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset.zero, width: p.size, height: p.size * 0.6),
            const Radius.circular(2)),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
