import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelbrain/core/nav_bar.dart';
import 'package:reelbrain/core/theme/theme.dart';

final _dests = <NavDestination>[
  (icon: (c) => Icon(Icons.home_outlined, color: c), label: 'Brain', badge: 0),
  (icon: (c) => Icon(Icons.search, color: c), label: 'Memories', badge: 0),
  (icon: (c) => Icon(Icons.history, color: c), label: 'Recall', badge: 2),
  (icon: (c) => Icon(Icons.hub_outlined, color: c), label: 'Threads', badge: 0),
];

Widget bar(
        {int selected = 0,
        PillStatus? status,
        Widget? replace,
        ValueChanged<int>? onSelect,
        VoidCallback? onCreate}) =>
    MaterialApp(
      theme: rbTheme(Brightness.dark),
      home: Scaffold(
        bottomNavigationBar: NavBar(
            destinations: _dests,
            selected: selected,
            status: status,
            replace: replace,
            onSelect: onSelect,
            onCreate: onCreate),
      ),
    );

void main() {
  testWidgets('every destination is labelled; + sits in the middle',
      (tester) async {
    int? tapped;
    var created = false;
    await tester.pumpWidget(
        bar(onSelect: (i) => tapped = i, onCreate: () => created = true));
    await tester.pumpAndSettle();
    for (final l in ['Brain', 'Memories', 'Recall', 'Threads']) {
      expect(find.text(l), findsOneWidget);
    }
    expect(find.text('2'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.search));
    expect(tapped, 1);
    final plus = tester.getCenter(find.byIcon(Icons.add)).dx;
    expect(plus, greaterThan(tester.getCenter(find.text('Memories')).dx));
    expect(plus, lessThan(tester.getCenter(find.text('Recall')).dx));
    await tester.tap(find.byIcon(Icons.add));
    expect(created, isTrue);
  });

  testWidgets('a status springs in above the bar, then goes', (tester) async {
    await tester.pumpWidget(bar());
    await tester.pumpAndSettle();
    final idle = tester.getSize(find.byType(NavBar)).height;
    await tester.pumpWidget(bar(status: (
      key: 'a',
      thumb: null,
      text: 'Watching the video',
      onTap: null
    )));
    await tester.pumpAndSettle();
    expect(find.text('Watching the video'), findsOneWidget);
    expect(tester.getSize(find.byType(NavBar)).height, greaterThan(idle));
    await tester.pumpWidget(bar());
    await tester.pumpAndSettle();
    expect(find.text('Watching the video'), findsNothing);
  });

  testWidgets('a screen can replace the bar (the timer in cooking mode)',
      (tester) async {
    await tester.pumpWidget(bar(replace: const Text('4:32')));
    await tester.pumpAndSettle();
    expect(find.text('4:32'), findsOneWidget);
    expect(find.text('Brain'), findsNothing);
  });
}
