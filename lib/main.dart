import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'iap.dart';
import 'l10n.dart';
import 'notifications.dart';
import 'repository.dart';
import 'store.dart';
import 'ui/rutin_ui.dart';
import 'ui/onboarding_screen.dart';
import 'ui/root_shell.dart';

/// Sentry çökme raporlama — sentry.io'da ücretsiz hesap açıp proje DSN'ini
/// buraya yapıştır. Boş bırakılırsa Sentry devre dışı kalır.
const _sentryDsn = '';

Future<void> main() async {
  if (_sentryDsn.isEmpty) {
    await bootRutin();
  } else {
    await SentryFlutter.init(
      (options) {
        options.dsn = _sentryDsn;
        options.tracesSampleRate = 0.2;
      },
      appRunner: bootRutin,
    );
  }
}

/// Uygulamanın gerçek başlangıcı — yeni koyu arayüzü tüm üretim altyapısıyla
/// (durum, kalıcılık, bildirimler, satın alma) ayağa kaldırır.
/// Hem [main] hem de `lib/main_ui.dart` bu fonksiyonu çağırır.
Future<void> bootRutin() async {
  WidgetsFlutterBinding.ensureInitialized();
  T.init();
  await initializeDateFormatting('tr_TR');
  await initializeDateFormatting('en');

  final notifications = NotificationService();
  await notifications.init();
  await notifications.requestPermission();

  final state = AppState(repo: LocalRepository(), notifications: notifications);
  await state.load();

  // Uygulama içi satın alma — App Store / Play Billing. Mağazaya ulaşılamazsa
  // (öykünücü/masaüstü) sessizce devre dışı kalır.
  await Iap.instance.init(onPro: state.activatePro);

  runApp(
    ChangeNotifierProvider.value(value: state, child: const RutinApp()),
  );
}

class RutinApp extends StatelessWidget {
  const RutinApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Dil / onboarding değişince yeniden kurulması için dinle.
    final s = context.watch<AppState>();
    return MaterialApp(
      title: 'Rutin',
      debugShowCheckedModeBanner: false,
      theme: buildRutinDarkTheme(),
      darkTheme: buildRutinDarkTheme(),
      themeMode: ThemeMode.dark,
      home: s.onboarded ? const RootShell() : const OnboardingScreen(),
    );
  }
}
