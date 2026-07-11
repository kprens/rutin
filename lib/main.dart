import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'ads.dart';
import 'l10n.dart';
import 'notifications.dart';
import 'repository.dart';
import 'social.dart';
import 'screens/calendar_screen.dart';
import 'screens/celebration_screen.dart';
import 'screens/friends_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/themes_screen.dart';
import 'screens/streaks_screen.dart';
import 'screens/today_screen.dart';
import 'screens/water_screen.dart';
import 'store.dart';
import 'theme.dart';

/// Sentry çökme raporlama — sentry.io'da ücretsiz hesap açıp
/// proje DSN'ini buraya yapıştır. Boş bırakılırsa Sentry devre dışı kalır.
const _sentryDsn = '';

Future<void> main() async {
  if (_sentryDsn.isEmpty) {
    await _boot();
  } else {
    await SentryFlutter.init(
      (options) {
        options.dsn = _sentryDsn;
        options.tracesSampleRate = 0.2;
      },
      appRunner: _boot,
    );
  }
}

Future<void> _boot() async {
  WidgetsFlutterBinding.ensureInitialized();
  T.init();
  await initializeDateFormatting('tr_TR');
  await initializeDateFormatting('en');

  final notifications = NotificationService();
  await notifications.init();
  await notifications.requestPermission();
  await Ads.init();
  await Social.init();

  final state = AppState(repo: LocalRepository(), notifications: notifications);
  await state.load();

  runApp(
    ChangeNotifierProvider.value(value: state, child: const RutinApp()),
  );
}

class RutinApp extends StatelessWidget {
  const RutinApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Tema değiştiğinde MaterialApp'in yeniden kurulması için dinle.
    final s = context.watch<AppState>();
    return MaterialApp(
      title: 'Rutin',
      debugShowCheckedModeBanner: false,
      theme: rutinLightTheme(),
      darkTheme: rutinDarkTheme(),
      themeMode: ThemeMode.system,
      home: s.onboarded ? const RootScreen() : const OnboardingScreen(),
    );
  }
}

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> with WidgetsBindingObserver {
  int _tab = 0;

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
    // Uygulama öne gelince gün dönümünü kontrol et.
    if (s == AppLifecycleState.resumed) {
      context.read<AppState>().dailyRollover();
    }
  }

  bool _celebrationShowing = false;

  /// Kutlanmamış milestone varsa kutlama ekranını aç.
  void _checkCelebration(AppState s) {
    final cel = s.pendingCelebration;
    if (cel == null || _celebrationShowing) return;
    _celebrationShowing = true;
    s.markCelebrated(cel.streak, cel.milestone);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => CelebrationScreen(
                streak: cel.streak, milestone: cel.milestone)),
      );
      _celebrationShowing = false;
      // 7+ gün kutlamasından sonra (mutluluk anında) bir kez puan iste.
      if (cel.milestone >= 7 && !s.reviewAsked) {
        s.markReviewAsked();
        final review = InAppReview.instance;
        if (await review.isAvailable()) review.requestReview();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = RutinColors.of(context);
    _checkCelebration(s);
    final dateChip = DateFormat('EEEE d MMMM', T.locale).format(DateTime.now());
    final screens = const [
      TodayScreen(),
      WaterScreen(),
      CalendarScreen(),
      StatsScreen(),
      StreaksScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: RichText(
          text: TextSpan(
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800, color: c.text),
            children: [
              const TextSpan(text: 'Rutin'),
              TextSpan(text: '.', style: TextStyle(color: c.accent)),
            ],
          ),
        ),
        actions: [
          Chip(
            label: Text(dateChip,
                style: TextStyle(fontSize: 12, color: c.muted)),
            backgroundColor: c.card,
            side: BorderSide.none,
          ),
          IconButton(
            tooltip: t('Arkadaşlar', 'Friends'),
            icon: Icon(Icons.people_outline, color: c.accent2),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const FriendsScreen())),
          ),
          IconButton(
            tooltip: t('Temalar', 'Themes'),
            icon: Icon(Icons.palette_outlined, color: c.accent2),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ThemesScreen())),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(index: _tab, children: screens),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pro kullanıcılar reklam görmez.
          if (!s.isPro) const AdBanner(),
          NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: [
          NavigationDestination(icon: const Text('✅', style: TextStyle(fontSize: 20)), label: t('Bugün', 'Today')),
          NavigationDestination(icon: const Text('💧', style: TextStyle(fontSize: 20)), label: t('Su', 'Water')),
          NavigationDestination(icon: const Text('📅', style: TextStyle(fontSize: 20)), label: t('Takvim', 'Calendar')),
          NavigationDestination(icon: const Text('📊', style: TextStyle(fontSize: 20)), label: t('İstatistik', 'Stats')),
          NavigationDestination(icon: const Text('🔥', style: TextStyle(fontSize: 20)), label: t('Streak', 'Streaks')),
            ],
          ),
        ],
      ),
    );
  }
}
