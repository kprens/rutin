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

  /// En popüler 20 bağımlılık — ortak listeden (l10n.dart).
  List<(String, String)> get _addictions => addictionPresets();

  @override
  void dispose() {
    _pageCtrl.dispose();
    _streakCtrl.dispose();
    super.dispose();
  }

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
                physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics()),
                onPageChanged: (i) {
                  FocusScope.of(context).unfocus();
                  setState(() => _page = i);
                },
                children: [
                  _animatedPage(0, _scroll(_welcomePage(c))),
                  _animatedPage(1, _scroll(_streakPage(c))),
                  _animatedPage(2, _scroll(_tasksPage(c))),
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

  /// Kaydırma sırasında sayfaya yumuşak ölçek + solma geçişi uygular.
  /// [index] sayfanın sırası. (t() gölgelememek için 'yakinlik' kullanıldı.)
  Widget _animatedPage(int index, Widget child) {
    return AnimatedBuilder(
      animation: _pageCtrl,
      child: child,
      builder: (context, ch) {
        double delta = (_page - index).toDouble();
        if (_pageCtrl.hasClients && _pageCtrl.position.haveDimensions) {
          delta = (_pageCtrl.page ?? index.toDouble()) - index;
        }
        final yakinlik = (1 - delta.abs()).clamp(0.0, 1.0);
        return Opacity(
          opacity: 0.35 + 0.65 * yakinlik,
          child: Transform.scale(
            scale: 0.92 + 0.08 * yakinlik,
            child: ch,
          ),
        );
      },
    );
  }

  /// Sayfayı ortalar ama alan yetmezse (klavye açıkken) kaydırılabilir yapar,
  /// böylece taşma (overflow) olmaz.
  Widget _scroll(Widget child) => LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(child: child),
          ),
        ),
      );

  /// Sayfa başlığı için gradyanlı, gölgeli, parlak halkalı emoji rozeti.
  Widget _emojiBadge(String emoji, List<Color> colors) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colors.first, colors.last],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.30), width: 2),
          boxShadow: [
            BoxShadow(
              color: colors.last.withValues(alpha: 0.50),
              blurRadius: 30,
              spreadRadius: 1,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 46)),
      );

  Widget _welcomePage(RutinColors c) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _emojiBadge('🔥', [c.accent, c.amber]),
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
    final current = _streakCtrl.text.trim().toLowerCase();
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _emojiBadge('🚭', [c.red, c.accent]),
          const SizedBox(height: 18),
          Text(t('Neyi bırakmak istiyorsun?', 'What do you want to quit?'),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: c.text)),
          const SizedBox(height: 8),
          Text(
            t('Birini seç ya da kendin yaz. Sayacın bugünden saymaya başlar — boş da bırakabilirsin.',
                'Pick one or write your own. Your counter starts today — you can leave it empty.'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: c.muted, height: 1.5),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: _addictions.map((a) {
              final on = current == a.$2.toLowerCase();
              return GestureDetector(
                onTap: () => setState(() {
                  if (on) {
                    _streakCtrl.clear();
                  } else {
                    _streakCtrl.text = a.$2;
                  }
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                  decoration: BoxDecoration(
                    color: on ? c.accent.withValues(alpha: 0.15) : c.card,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                        color: on ? c.accent : c.cardBorder,
                        width: on ? 2 : 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(a.$1, style: const TextStyle(fontSize: 15)),
                      const SizedBox(width: 6),
                      Text(a.$2,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                              color: on ? c.accent : c.text)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _streakCtrl,
            textAlign: TextAlign.center,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
                hintText: t('Listede yok mu? Kendin yaz…',
                    'Not listed? Write your own…')),
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
          _emojiBadge('✅', [c.green, c.blue]),
          const SizedBox(height: 18),
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
