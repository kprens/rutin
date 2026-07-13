import 'package:flutter/material.dart';

import '../l10n.dart';
import 'rutin_ui.dart';
import 'auth_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _page = 0;

  List<(String, String, String, Color)> get _pages => [
        (
          '✨',
          t('Daha İyi Alışkanlıklar', 'Build Better Habits'),
          t('Günlük alışkanlıkları takip et, seriler oluştur ve her gün biraz daha değiş.',
              'Track daily habits, build streaks, and watch yourself transform — one day at a time.'),
          RC.purple
        ),
        (
          '💚',
          t('Bağımlılığı Yen', 'Overcome Addiction'),
          t('Kurtuluş yolculuğun tek bir adımla başlar. Her temiz günü ve biriken parayı takip ederiz.',
              'Your recovery journey starts with a single step. We track every day clean, every dollar saved.'),
          RC.teal
        ),
        (
          '🏆',
          t('Başarımlar Kazan', 'Earn Achievements'),
          t('Rozetler, kilometre taşları ve serilerle kazanımlarını kutla, motive kal.',
              'Celebrate your wins with badges, milestones, and streaks that keep you motivated.'),
          RC.amber
        ),
      ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _pages.length - 1) {
      _ctrl.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    } else {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const AuthScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RC.bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _ctrl,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) {
                  final (emoji, title, sub, color) = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 200,
                          height: 200,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color.withValues(alpha: 0.1),
                            border: Border.all(
                                color: color.withValues(alpha: 0.2), width: 1),
                          ),
                          child: Text(emoji, style: const TextStyle(fontSize: 76)),
                        ),
                        const SizedBox(height: 48),
                        Text(title,
                            textAlign: TextAlign.center, style: RText.h1),
                        const SizedBox(height: 18),
                        Text(sub,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: RC.muted, fontSize: 16, height: 1.5)),
                      ],
                    ),
                  );
                },
              ),
            ),
            // ---- Sayfa noktaları ----
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 28 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? _pages[_page].$4 : RC.faint,
                    borderRadius: BorderRadius.circular(99),
                  ),
                );
              }),
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: RButton(
                _page == _pages.length - 1
                    ? t('Başlayalım', 'Get Started')
                    : t('Devam', 'Continue'),
                onTap: _next,
                height: 60,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
