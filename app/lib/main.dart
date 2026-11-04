import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/data/repo.dart';
import 'core/platform_setup.dart'
    if (dart.library.js_interop) 'core/native_web.dart';
import 'core/theme/theme.dart';
import 'features/auth/auth_gate.dart';
import 'features/settings/settings_screen.dart' show localeOf, themeModeOf;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Android: options from google-services.json; web: from Firebase Hosting.
  await Firebase.initializeApp(options: await platformSetup());
  runApp(const ReelbrainApp());
}

/// The app: Realbrain V5 themes (Ink and Paper), language from Settings, RTL for Arabic.
class ReelbrainApp extends StatelessWidget {
  const ReelbrainApp({super.key, this.home = const AuthGate()});
  final Widget home;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: appPrefs,
      builder: (context, prefs, _) => MaterialApp(
        title: 'Realbrain',
        debugShowCheckedModeBanner: false,
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
