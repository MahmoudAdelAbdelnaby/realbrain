import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'features/auth/auth_gate.dart';
import 'features/settings/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase
      .initializeApp(); // options from android/app/google-services.json
  runApp(const ReelbrainApp());
}

// ponytail: ground/surface/text/muted only; full token set lands in P1-01 (lib/core/theme).
ThemeData _theme(Brightness b) {
  final dark = b == Brightness.dark;
  final text = dark ? const Color(0xFFFFFFFF) : const Color(0xFF111111);
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: text,
      brightness: b,
      surface: dark ? const Color(0xFF18181A) : const Color(0xFFFFFFFF),
      onSurface: text,
      onSurfaceVariant:
          dark ? const Color(0xFFB4B4B4) : const Color(0xFF5F6368),
    ),
    scaffoldBackgroundColor:
        dark ? const Color(0xFF0E0E0F) : const Color(0xFFF7F7F5),
  );
}

/// Light theme on its own, for cooking mode (always light: bright kitchen).
final lightTheme = _theme(Brightness.light);

class ReelbrainApp extends StatelessWidget {
  const ReelbrainApp({super.key, this.home = const AuthGate()});
  final Widget home;

  @override
  Widget build(BuildContext context) {
    // Language and theme from Settings (P1-16); "system" follows the phone.
    return ValueListenableBuilder(
      valueListenable: appPrefs,
      builder: (context, prefs, _) => MaterialApp(
        title: 'Reelbrain',
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        themeMode: themeModeOf(prefs.theme),
        locale: localeOf(prefs.lang),
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: home,
      ),
    );
  }
}
