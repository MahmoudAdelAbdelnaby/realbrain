import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelbrain/core/brain_mark.dart';
import 'package:reelbrain/core/liquid.dart';
import 'package:reelbrain/core/theme/theme.dart';
import 'package:reelbrain/features/feed/lanes.dart';

void main() {
  test('every section has its own hue in both themes, distinct from each other',
      () {
    for (final c in [RbColors.dark, RbColors.light]) {
      final hues = [
        for (final s in ['fact_check', 'tools', 'recipe', 'places', 'workout'])
          c.section(s)
      ];
      expect(hues.toSet(), hasLength(5));
      expect(c.section('unknown'), c.accent);
    }
  });

  test('the brand fill keeps its label readable', () {
    for (final c in [RbColors.dark, RbColors.light]) {
      expect(
          contrast(c.primaryLabel, c.primaryFill), greaterThanOrEqualTo(4.5));
    }
  });

  test('develop goes from a negative to the picture unchanged', () {
    expect(
        developFilter(1),
        const ColorFilter.matrix(<double>[
          1,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
          0,
          0,
          0,
          0,
          1,
          0
        ]));
    expect(developFilter(0), isNot(developFilter(1)));
  });

  testWidgets('the mark paints still and breathing', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: rbTheme(Brightness.dark),
      home: const Row(
          children: [BrainMark(), BrainMark(animate: true, size: 48)]),
    ));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.bySemanticsLabel('Working'), findsOneWidget);
    expect(find.bySemanticsLabel('Reelbrain'), findsOneWidget);
  });

  testWidgets('the liquid shows the plain ground until its shader is ready',
      (tester) async {
    final liquid = LiquidController();
    await tester.pumpWidget(MaterialApp(
      theme: rbTheme(Brightness.dark),
      home: LiquidBackground(controller: liquid),
    ));
    liquid
      ..scrolled(40)
      ..wave()
      ..setHeat(true);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });
}
