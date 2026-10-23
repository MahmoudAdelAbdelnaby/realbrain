import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'features/save/saves_screen.dart';

void main() => runApp(const ReelbrainApp());

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

class ReelbrainApp extends StatelessWidget {
  const ReelbrainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reelbrain',
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const SavesScreen(),
    );
  }
}
