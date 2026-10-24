import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelbrain/features/save/saves_screen.dart';
import 'package:reelbrain/features/settings/settings_screen.dart';
import 'package:reelbrain/main.dart';

void main() {
  test('settings map to theme modes and locales', () {
    expect(themeModeOf('dark'), ThemeMode.dark);
    expect(themeModeOf('system'), ThemeMode.system);
    expect(localeOf('ar'), const Locale('ar'));
    expect(localeOf('system'), isNull);
  });

  testWidgets('choosing Arabic in Settings flips the app to right-to-left',
      (tester) async {
    addTearDown(() => appPrefs.value = (lang: 'system', theme: 'system'));
    await tester.pumpWidget(const ReelbrainApp(home: SavesScreen()));
    appPrefs.value = (lang: 'ar', theme: 'dark');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // the theme change animates
    final ctx = tester.element(find.text('Phone queue'));
    expect(Directionality.of(ctx), TextDirection.rtl);
    expect(Theme.of(ctx).brightness, Brightness.dark);
  });
}
