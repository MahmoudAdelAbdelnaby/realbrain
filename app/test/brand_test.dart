import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelbrain/core/brain_mark.dart';
import 'package:reelbrain/core/surface.dart';
import 'package:reelbrain/core/theme/theme.dart';

void main() {
  const sections = [
    'fact_check',
    'tools',
    'recipe',
    'places',
    'workout',
    'ideas'
  ];

  test(
      'every interest has its own hue in both themes, distinct from each other',
      () {
    for (final c in [RbColors.dark, RbColors.light]) {
      final hues = [for (final s in sections) c.section(s)];
      expect(hues.toSet(), hasLength(sections.length));
      expect(c.section('unknown'), c.accent);
    }
  });

  test('hues stay readable as text on cards (chip labels)', () {
    for (final c in [RbColors.dark, RbColors.light]) {
      for (final s in sections) {
        expect(contrast(c.section(s), c.surface), greaterThanOrEqualTo(4.5),
            reason: '$s in ${c == RbColors.dark ? 'dark' : 'light'}');
      }
    }
  });

  test('pill labels and the + icon stay readable', () {
    for (final c in [RbColors.dark, RbColors.light]) {
      for (final fill in [c.primaryFill, c.capture.$1, c.capture.$2]) {
        expect(contrast(c.primaryLabel, fill), greaterThanOrEqualTo(4.5));
      }
    }
  });

  test('everyday text reads on charcoal and white', () {
    for (final c in [RbColors.dark, RbColors.light]) {
      for (final fg in [c.text, c.muted, c.faint]) {
        expect(contrast(fg, c.surface), greaterThanOrEqualTo(4.5));
        expect(contrast(fg, c.ground), greaterThanOrEqualTo(4.5));
      }
    }
  });

  test('the mesh is one connected drawing: every edge joins known points', () {
    const o = BrainMesh.outline, i = BrainMesh.inner;
    for (final (a, b) in BrainMesh.spokes) {
      expect(a, lessThan(o.length));
      expect(b, lessThan(i.length));
    }
    for (final (a, b) in [...BrainMesh.mesh, ...BrainMesh.simple]) {
      expect(a, lessThan(i.length));
      expect(b, lessThan(i.length));
    }
    // Every inner point is reached by some line.
    final touched = {
      for (final (_, b) in BrainMesh.spokes) b,
      for (final (a, b) in BrainMesh.mesh) ...[a, b],
    };
    expect(touched, hasLength(i.length));
  });

  testWidgets('the mark paints full, simplified and working', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: rbTheme(Brightness.dark),
      home: const Haze(
        child: Row(children: [
          BrainMark(size: 120),
          BrainMark(),
          BrainMark(animate: true, size: 48),
        ]),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel('Working'), findsOneWidget);
    expect(find.bySemanticsLabel('Realbrain'), findsNWidgets(2));
  });

  testWidgets('pill buttons fire, and a disabled one does not', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      theme: rbTheme(Brightness.dark),
      home: Column(children: [
        PillButton(label: 'Cook now', onPressed: () => taps++),
        PillButton(
            label: 'Start cooking', action: true, onPressed: () => taps++),
        const PillButton(label: 'Off', onPressed: null),
      ]),
    ));
    await tester.tap(find.text('Cook now'));
    await tester.tap(find.text('Start cooking'));
    await tester.tap(find.text('Off'));
    expect(taps, 2);
  });
}
