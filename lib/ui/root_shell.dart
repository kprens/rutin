import 'dart:async';

import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:provider/provider.dart';

import '../ads.dart';
import '../analytics.dart';
import '../home_widget_service.dart' as hw;
import '../l10n.dart';
import '../store.dart';
import 'rutin_ui.dart';
import 'celebration_screen.dart';
import 'home_screen.dart';
import 'calendar_screen.dart';
import 'analytics_screen.dart';
import 'recovery_screen.dart';
import 'profile_screen.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});
  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> with WidgetsBindingObserver {
  int _tab = 0;
  bool _celebrationShowing = false;
  late final PageController _pageController;

  static const _screens = [
    HomeScreen(),
    CalendarScreen(),
    AnalyticsScreen(),
    RecoveryScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController(initialPage: _tab);

    // ATT izni (yalnızca iOS) — ana ekrana ULAŞILDIKTAN sonra istenir, açılışta
    // değil. Sistem bu diyaloğu kullanıcı başına bir kez gösterir, o yüzden tek
    // atış kullanıcı uygulamayı gördükten sonra harcanmalı (bkz. ads.dart).
    //
    // Buraya bağlı olması, onboarding'i çoktan bitirmiş MEVCUT kullanıcıların
    // da kapsanmasını sağlıyor; finishOnboarding'e bağlansaydı onlara hiç
    // sorulmazdı ve iOS'ta kalıcı olarak kişiselleştirilmemiş reklam
    // görürlerdi.
    //
    // Gecikme, yeni kullanıcıda onboarding sonrası tetiklenen BİLDİRİM izin
    // diyaloğuyla üst üste binmesin diye. iOS izin diyaloglarını zaten sıraya
    // alır; bu yalnızca sıralamayı öngörülebilir kılıyor.
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) unawaited(Ads.ensureTrackingRequested());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  /// Sekmeler arası hem alt gezinme çubuğuna dokunarak hem de ekranı sağa/
  /// sola kaydırarak (swipe) geçilebilir — ikisi de aynı [PageController]'ı
  /// kullanır, bu yüzden tutarlı kalır (bkz. build() içindeki PageView).
  void _goToTab(int i) {
    if (i == _tab) return;
    _pageController.animateToPage(i,
        duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
  }

  void _onPageChanged(int i) {
    setState(() => _tab = i);
    // Sekme değişimi doğal bir geçiş anı — interstitial için tek tetikleme
    // noktası burası (hem dokunma hem kaydırmayla gelinen geçişleri kapsar).
    // Frekans/ısınma/oturum sınırları Interstitials içinde (bkz. ads.dart).
    Interstitials.instance.maybeShow(isPro: context.read<AppState>().hasPro);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      final state = context.read<AppState>();
      state.dailyRollover();
      // Uygulama arka plandayken widget'ta yapılmış olabilecek dokunmaları
      // (bkz. home_widget_service.dart) gerçek görev listesine işler.
      hw.applyPendingWidgetToggles(state);
      Analytics.instance.log(Ev.appOpen);
    } else if (s == AppLifecycleState.paused) {
      // Bekleyen ölçüm olaylarını arka plana geçmeden gönder; aksi halde
      // sistem uygulamayı öldürürse oturumun olayları bir sonraki açılışa
      // kadar gecikir.
      unawaited(Analytics.instance.onPause());
    }
  }

  /// Kutlanmamış milestone varsa kutlama ekranını açar; ardından uygun anda
  /// bir kez mağaza puanı ister.
  void _checkCelebration(AppState s) {
    final cel = s.pendingCelebration;
    if (cel == null || _celebrationShowing) return;
    _celebrationShowing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      s.markCelebrated(cel.streak, cel.milestone);
      await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => UiCelebrationScreen(
                streak: cel.streak, milestone: cel.milestone)),
      );
      _celebrationShowing = false;
      if (cel.milestone >= 7 && !s.reviewAsked) {
        s.markReviewAsked();
        final review = InAppReview.instance;
        if (await review.isAvailable()) review.requestReview();
      }
    });
  }

  List<(IconData, String)> get _items => [
        (Icons.home_outlined, t('Ana Sayfa', 'Home')),
        (Icons.calendar_today_outlined, t('Takvim', 'Calendar')),
        (Icons.show_chart, t('İstatistik', 'Stats')),
        (Icons.place_outlined, t('Bırakma', 'Recovery')),
        (Icons.person_outline, t('Profil', 'Profile')),
      ];

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    _checkCelebration(s);
    return Scaffold(
      backgroundColor: RC.bg,
      body: SafeArea(
        bottom: false,
        child: PageView(
          controller: _pageController,
          onPageChanged: _onPageChanged,
          children: _screens,
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Reklam yalnızca Pro (kalıcı ya da geçici) OLMAYAN kullanıcılara.
          if (!s.hasPro) const AdBanner(),
          Container(
            decoration: BoxDecoration(
              color: RC.card,
              border: Border(top: BorderSide(color: RC.stroke)),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 66,
                child: Row(
                  children: [
                    for (var i = 0; i < _items.length; i++)
                      Expanded(child: _navItem(i)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(int i) {
    final active = i == _tab;
    final (icon, label) = _items[i];
    final color = active ? RC.purpleBright : RC.muted;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _goToTab(i),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 26,
            height: 3,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: active ? RC.purpleBright : Colors.transparent,
              borderRadius: BorderRadius.circular(99),
              boxShadow: active
                  ? [BoxShadow(color: RC.purple.withValues(alpha: 0.6), blurRadius: 10)]
                  : null,
            ),
          ),
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
        ],
      ),
    );
  }
}