import 'package:flutter/material.dart';

import '../analytics.dart';
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

  /// Kaydırma ilerlemesi.
  ///
  /// Bu değer `setState` ile TUTULMUYOR. Eskiden kaydırma dinleyicisi her
  /// karede `setState` çağırıyordu; bu, saniyede 60–120 kez TÜM onboarding
  /// ağacının (PageView, üç sayfanın içeriği, gradyanlar, gölgeler)
  /// yeniden kurulması demekti ve kullanıcının uygulamada gördüğü İLK
  /// ekranda hissedilir bir takılmaya yol açıyordu — premium algısının en
  /// kritik olduğu an burasıdır. Artık yalnızca renge bağlı üç küçük parça
  /// (arka plan gradyanı, sayfa noktaları, buton) bu değeri dinliyor.
  final ValueNotifier<double> _fraction = ValueNotifier<double>(0);

  List<(IconData, String, String, Color)> get _pages => [
        (
          Icons.auto_awesome_rounded,
          t('Daha İyi Alışkanlıklar', 'Build Better Habits'),
          t('Günlük alışkanlıkları takip et, seriler oluştur ve her gün biraz daha değiş.',
              'Track daily habits, build streaks, and watch yourself transform — one day at a time.'),
          RC.purple
        ),
        (
          Icons.favorite_rounded,
          t('Bağımlılığı Yen', 'Overcome Addiction'),
          t('Kurtuluş yolculuğun tek bir adımla başlar. Her temiz günü ve biriken parayı takip ederiz.',
              'Your recovery journey starts with a single step. We track every day clean, every dollar saved.'),
          RC.teal
        ),
        (
          Icons.emoji_events_rounded,
          t('Başarımlar Kazan', 'Earn Achievements'),
          t('Rozetler, kilometre taşları ve serilerle kazanımlarını kutla, motive kal.',
              'Celebrate your wins with badges, milestones, and streaks that keep you motivated.'),
          RC.amber
        ),
      ];

  @override
  void initState() {
    super.initState();
    Analytics.instance.log(Ev.onboardingStart);
    _ctrl.addListener(() {
      final p = _ctrl.page;
      if (p != null) _fraction.value = p;
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _fraction.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _pages.length - 1) {
      _ctrl.nextPage(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic);
    } else {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const AuthScreen()));
    }
  }

  void _skip() {
    // Hangi slaytta atlandığı, hangi mesajın tutmadığını gösterir.
    Analytics.instance.log(Ev.onboardingSkip, {'step': _page});
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const AuthScreen()));
  }

  /// İki sayfa rengi arasında kaydırma ilerlemesine göre yumuşak geçiş.
  Color _blendedColor(double fraction) {
    final from = fraction.floor().clamp(0, _pages.length - 1);
    final to = fraction.ceil().clamp(0, _pages.length - 1);
    final t = fraction - fraction.floor();
    return Color.lerp(_pages[from].$4, _pages[to].$4, t) ?? _pages[_page].$4;
  }

  /// Yalnızca renge bağlı parçaları [_fraction]'a abone eder — ağacın geri
  /// kalanı kaydırma sırasında yeniden çizilmez.
  Widget _tinted(Widget Function(Color blended) build) =>
      ValueListenableBuilder<double>(
        valueListenable: _fraction,
        builder: (_, f, __) => build(_blendedColor(f)),
      );

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _pages.length - 1;
    return Scaffold(
      backgroundColor: RC.bg,
      body: Stack(
        children: [
          // Arka plan gradyanı kaydırmayla renk değiştiren TEK ayrı katman;
          // içeriğin yeniden çizilmesine yol açmaz.
          Positioned.fill(
            child: _tinted((blended) => DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.4),
                      radius: 1.2,
                      colors: [blended.withValues(alpha: 0.16), RC.bg],
                      stops: const [0, 0.7],
                    ),
                  ),
                )),
          ),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 4, 20, 0),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: isLast ? 0 : 1,
                      child: TextButton(
                        onPressed: isLast ? null : _skip,
                        child: Text(t('Atla', 'Skip'),
                            style: TextStyle(
                                color: RC.muted, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _ctrl,
                    itemCount: _pages.length,
                    onPageChanged: (i) {
                    setState(() => _page = i);
                    Analytics.instance.log(Ev.onboardingStep, {'step': i});
                  },
                    itemBuilder: (_, i) {
                      final (icon, title, sub, color) = _pages[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _EntranceFade(
                              key: ValueKey('icon_$i'),
                              child: Container(
                                width: 188,
                                height: 188,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(colors: [
                                    color.withValues(alpha: 0.22),
                                    color.withValues(alpha: 0.05),
                                  ]),
                                ),
                                child: Container(
                                  width: 116,
                                  height: 116,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        color,
                                        Color.lerp(color, Colors.black, 0.25)!,
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                          color: color.withValues(alpha: 0.45),
                                          blurRadius: 28,
                                          offset: const Offset(0, 12)),
                                    ],
                                  ),
                                  child:
                                      Icon(icon, size: 52, color: Colors.white),
                                ),
                              ),
                            ),
                            const SizedBox(height: 44),
                            _EntranceFade(
                              key: ValueKey('title_$i'),
                              delay: const Duration(milliseconds: 80),
                              child: Text(title,
                                  textAlign: TextAlign.center, style: RText.h1),
                            ),
                            const SizedBox(height: 14),
                            _EntranceFade(
                              key: ValueKey('sub_$i'),
                              delay: const Duration(milliseconds: 140),
                              child: Text(sub,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: RC.muted,
                                      fontSize: 16,
                                      height: 1.5)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                // ---- Sayfa noktaları ----
                _tinted((blended) => Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_pages.length, (i) {
                        final active = i == _page;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: active ? 28 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: active ? blended : RC.faint,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        );
                      }),
                    )),
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: _tinted((blended) => RButton(
                        isLast
                            ? t('Başlayalım', 'Get Started')
                            : t('Devam', 'Continue'),
                        onTap: _next,
                        height: 56,
                        gradient: LinearGradient(colors: [
                          blended,
                          Color.lerp(blended, Colors.black, 0.25)!,
                        ]),
                        leading: isLast
                            ? null
                            : const Icon(Icons.arrow_forward_rounded,
                                color: Colors.white, size: 20),
                      )),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sayfa her göründüğünde hafif bir yukarı-kayma + belirme animasyonu.
/// PageView.builder her sayfaya her gelindiğinde yeni bir örnek kurduğu için
/// bu, kaydırdıkça tekrar tekrar oynayan hoş bir giriş efekti sağlar.
class _EntranceFade extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const _EntranceFade(
      {super.key, required this.child, this.delay = Duration.zero});

  @override
  State<_EntranceFade> createState() => _EntranceFadeState();
}

class _EntranceFadeState extends State<_EntranceFade> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      offset: _visible ? Offset.zero : const Offset(0, 0.12),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOut,
        opacity: _visible ? 1 : 0,
        child: widget.child,
      ),
    );
  }
}
