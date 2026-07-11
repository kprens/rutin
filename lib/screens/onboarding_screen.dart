import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../store.dart';
import '../theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  final _streakCtrl = TextEditingController();
  int _page = 0;

  List<(String, String)> get _samples => T.en
      ? const [
          ('💪', 'Work out'),
          ('📖', 'Read 10 pages'),
          ('🌅', 'Wake up early'),
          ('🧘', '5 min meditation'),
          ('🚶', 'Go for a walk'),
        ]
      : const [
          ('💪', 'Spor yap'),
          ('📖', '10 sayfa kitap oku'),
          ('🌅', 'Erken uyan'),
          ('🧘', '5 dk meditasyon'),
          ('🚶', 'Yürüyüşe çık'),
        ];
  final Set<int> _selectedSamples = {0, 1};

  void _next() {
    if (_page < 2) {
      _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    } else {
      _finish();
    }
  }

  void _finish() {
    context.read<AppState>().finishOnboarding(
          streakName: _streakCtrl.text,
          sampleTasks:
              _selectedSamples.map((i) => _samples[i].$2).toList(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final c = RutinColors.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _welcomePage(c),
                  _streakPage(c),
                  _tasksPage(c),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) => Container(
                          width: i == _page ? 22 : 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: i == _page ? c.accent : c.card2,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        )),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15)),
                      onPressed: _next,
                      child: Text(_page == 2 ? t('Başla 🚀', 'Start 🚀') : t('Devam', 'Continue')),
                    ),
                  ),
                  if (_page > 0)
                    TextButton(
                      onPressed: _finish,
                      child: Text(t('Atla', 'Skip'), style: TextStyle(color: c.muted)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _welcomePage(RutinColors c) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [c.accent, c.amber]),
              shape: BoxShape.circle,
            ),
            child: const Text('🔥', style: TextStyle(fontSize: 44)),
          ),
          const SizedBox(height: 24),
          Text(t("Rutin'e hoş geldin", 'Welcome to Rutin'),
              style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w800, color: c.text)),
          const SizedBox(height: 12),
          Text(
            t('Kötü alışkanlıkları bırak, iyilerini kazan.\nStreak sayacı, günlük liste, su takibi ve takvim — hepsi tek yerde.', 'Quit bad habits, build good ones.\nStreak counter, daily list, water tracking and calendar — all in one.'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: c.muted, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _streakPage(RutinColors c) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🚭', style: TextStyle(fontSize: 44)),
          const SizedBox(height: 20),
          Text(t('Neyi bırakmak istiyorsun?', 'What do you want to quit?'),
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: c.text)),
          const SizedBox(height: 10),
          Text(
            t('Sigara, şeker, sosyal medya… Sayacın bugünden itibaren saymaya başlar. Boş bırakabilirsin.', 'Smoking, sugar, social media… Your counter starts today. You can leave it empty.'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: c.muted, height: 1.5),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _streakCtrl,
            textAlign: TextAlign.center,
            decoration: InputDecoration(hintText: t('örn. Sigara', 'e.g. Smoking')),
          ),
        ],
      ),
    );
  }

  Widget _tasksPage(RutinColors c) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('✅', style: TextStyle(fontSize: 44)),
          const SizedBox(height: 20),
          Text(t('Günlük hedeflerini seç', 'Pick your daily goals'),
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: c.text)),
          const SizedBox(height: 10),
          Text(t('Her gün listende görünsün. Sonra dilediğin gibi değiştirirsin.', "They'll show on your daily list. Change anytime."),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: c.muted)),
          const SizedBox(height: 20),
          ...List.generate(_samples.length, (i) {
            final on = _selectedSamples.contains(i);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => setState(() {
                  if (on) {
                    _selectedSamples.remove(i);
                  } else {
                    _selectedSamples.add(i);
                  }
                }),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: on ? c.accent : c.cardBorder,
                        width: on ? 2 : 1),
                  ),
                  child: Row(
                    children: [
                      Text(_samples[i].$1, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(_samples[i].$2,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: c.text))),
                      if (on) Icon(Icons.check_circle, color: c.accent, size: 20),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
