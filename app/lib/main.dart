import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/platform_setup.dart'
    if (dart.library.js_interop) 'core/native_web.dart';
import 'core/theme/theme.dart';
import 'features/auth/auth_gate.dart';
import 'features/settings/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Android: options from google-services.json; web: from Firebase Hosting.
  await Firebase.initializeApp(options: await platformSetup());
  runApp(const ReelbrainApp());
}

/// Light theme on its own, for cooking mode (always light: bright kitchen).
final lightTheme = rbTheme(Brightness.light);

class ReelbrainApp extends StatelessWidget {
  const ReelbrainApp({super.key, this.home = const AuthGate()});
  final Widget home;

  @override
  Widget build(BuildContext context) {
    // Language and theme from Settings (P1-16); "system" follows the phone.
    return ValueListenableBuilder(
      valueListenable: appPrefs,
      builder: (context, prefs, _) => MaterialApp(
        title: 'Realbrain',
        theme: rbTheme(Brightness.light),
        darkTheme: rbTheme(Brightness.dark),
        themeMode: themeModeOf(prefs.theme),
        locale: localeOf(prefs.lang),
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: home,
      ),
    );
  }
}
