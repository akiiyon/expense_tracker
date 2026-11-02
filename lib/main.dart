import 'package:expense_tracker/core/config.dart';
import 'package:expense_tracker/core/theme.dart';
import 'package:expense_tracker/data/api_client.dart';
import 'package:expense_tracker/screens/splash_screen.dart';
import 'package:expense_tracker/sms/sms_service.dart';
import 'package:expense_tracker/state/finance_provider.dart';
import 'package:expense_tracker/state/session_provider.dart';
import 'package:expense_tracker/state/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // fonts are fetched once and cached; fall back to the system font when offline
  GoogleFonts.config.allowRuntimeFetching = true;
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final settings = SettingsProvider();
  await settings.load();
  runApp(ExpensifyApp(settings: settings));
}

class ExpensifyApp extends StatelessWidget {
  const ExpensifyApp({super.key, required this.settings, this.api});

  final SettingsProvider settings;
  final ApiClient? api;

  @override
  Widget build(BuildContext context) {
    final client = api ?? ApiClient();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider(create: (_) => SessionProvider(client)),
        ChangeNotifierProvider(create: (_) => FinanceProvider(client)),
        ChangeNotifierProvider(create: (c) => SmsSync(finance: c.read<FinanceProvider>(), settings: settings)),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, s, _) => MaterialApp(
          title: AppConfig.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: s.themeMode,
          home: const SplashScreen(),
        ),
      ),
    );
  }
}

/// Fade + slight zoom page transition used between top-level screens.
Route<T> fadeRoute<T>(Widget page) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 550),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(scale: Tween(begin: 1.04, end: 1.0).animate(curved), child: child),
        );
      },
    );
