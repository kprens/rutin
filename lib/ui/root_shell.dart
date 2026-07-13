import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:provider/provider.dart';

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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      context.read<AppState>().dailyRollover();
    }
  }

  /// Kutlanmamış milestone varsa kutlama ekranını açar; ardından uygun anda
  /// bir kez mağaza puanı ister.
  void _checkCelebration(AppState s) {
    final cel = s.pendingCelebration;
    if (cel == null || _celebrationShowing) return;
    _celebrationShowing = true;
    s.markCelebrated(cel.streak, cel.milestone);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
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
      body: SafeArea(bottom: false, child: _screens[_tab]),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
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
    );
  }

  Widget _navItem(int i) {
    final active = i == _tab;
    final (icon, label) = _items[i];
    final color = active ? RC.purpleBright : RC.muted;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _tab = i),
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
