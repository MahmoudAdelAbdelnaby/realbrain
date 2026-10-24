import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelbrain/core/liquid_pill.dart';
import 'package:reelbrain/core/theme/theme.dart';

const _dests = <PillDestination>[
  (
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    label: 'Home',
    badge: 0
  ),
  (icon: Icons.search, selectedIcon: Icons.search, label: 'Search', badge: 0),
  (
    icon: Icons.inbox_outlined,
    selectedIcon: Icons.inbox,
    label: 'Inbox',
    badge: 2
  ),
];

Widget pill(
        {int selected = 0,
        PillStatus? status,
        Widget? replace,
        ValueChanged<int>? onSelect}) =>
    MaterialApp(
      theme: rbTheme(Brightness.dark),
      home: Scaffold(
        bottomNavigationBar: LiquidPill(
            destinations: _dests,
            selected: selected,
            status: status,
            replace: replace,
            onSelect: onSelect),
      ),
    );

void main() {
  testWidgets(
      'only the selected destination shows its name; badges show counts',
      (tester) async {
    int? tapped;
    await tester.pumpWidget(pill(onSelect: (i) => tapped = i));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Search'), findsNothing);
    expect(find.text('2'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.search));
    expect(tapped, 1);
  });

  testWidgets('the pill grows to show a processing save, then shrinks back',
      (tester) async {
    await tester.pumpWidget(pill());
    await tester.pumpAndSettle();
    final idle = tester.getSize(find.byType(LiquidPill)).height;
    await tester.pumpWidget(pill(status: (
      key: 'a',
      thumb: null,
      text: 'Watching the video',
      onTap: null
    )));
    await tester.pumpAndSettle();
    expect(find.text('Watching the video'), findsOneWidget);
    expect(tester.getSize(find.byType(LiquidPill)).height, greaterThan(idle));
    await tester.pumpWidget(pill());
    await tester.pumpAndSettle();
    expect(find.text('Watching the video'), findsNothing);
  });

  testWidgets(
      'a screen can replace the destinations (the timer in cooking mode)',
      (tester) async {
    await tester.pumpWidget(pill(replace: const Text('4:32')));
    await tester.pumpAndSettle();
    expect(find.text('4:32'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
  });
}
