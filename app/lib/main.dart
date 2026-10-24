import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/theme.dart';
import 'features/auth/auth_gate.dart';
import 'features/settings/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase
      .initializeApp(); // options from android/app/google-services.json
  runApp(const ReelbrainApp());
}

/// Lets screens hear when one above them is popped (the liquid's back wave).
final routeObserver = RouteObserver<ModalRoute<void>>();

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
        title: 'Reelbrain',
        theme: rbTheme(Brightness.light),
        darkTheme: rbTheme(Brightness.dark),
        themeMode: themeModeOf(prefs.theme),
        locale: localeOf(prefs.lang),
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: home,
        navigatorObservers: [routeObserver],
      ),
    );
  }
}
