import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelbrain/features/factcheck/fact_check_view.dart';
import 'package:reelbrain/main.dart';

Widget view(Map<String, dynamic> data) => ReelbrainApp(
      home: Scaffold(
          body: SingleChildScrollView(
              child: FactCheckView(saveId: 's1', data: data))),
    );

void main() {
  testWidgets(
      'checked claims show verdicts, corrections, sources and the AI label',
      (tester) async {
    await tester.pumpWidget(view({
      'checked_at': 1792800000,
      'overall': 'mostly_false',
      'claims': [
        {
          'text': 'Lemon water detoxes the liver',
          't': 3,
          'verdict': 'false',
          'correction': 'The liver does that itself.'
        },
        {
          'text': 'Lemons contain vitamin C',
          't': 9,
          'verdict': 'true',
          'correction': ''
        },
      ],
      'sources': [
        {'title': 'who.int', 'url': 'https://who.int/a'},
      ],
    }));
    expect(find.textContaining('AI-generated · checked'), findsOneWidget);
    expect(find.text('Mostly false'), findsOneWidget);
    expect(find.text('False'), findsOneWidget);
    expect(find.text('True'), findsOneWidget);
    expect(find.text('The liver does that itself.'), findsOneWidget);
    expect(find.text('who.int'), findsOneWidget);
    expect(find.text('Dive deeper'), findsOneWidget);
  });

  testWidgets('unchecked claims say so and still offer Dive deeper',
      (tester) async {
    await tester.pumpWidget(view({
      'claims': [
        {'text': 'X cures Y', 't': 1},
      ],
    }));
    expect(find.text('AI-generated · not checked yet'), findsOneWidget);
    expect(find.text('Unverified'), findsOneWidget);
  });

  testWidgets('an explainer replaces the button', (tester) async {
    await tester.pumpWidget(view(
        {'claims': const [], 'explainer': 'Here is what the evidence says.'}));
    expect(find.text('Here is what the evidence says.'), findsOneWidget);
    expect(find.text('Dive deeper'), findsNothing);
  });

  test('verdict colours differ by theme and kind', () {
    expect(verdictColors('false', Brightness.dark).$1, const Color(0xFFE5566F));
    expect(verdictColors('mostly_true', Brightness.light).$2,
        const Color(0xFFDCFAE5));
    expect(verdictColors('unverifiable', Brightness.dark),
        isNot(verdictColors('true', Brightness.dark)));
  });
}
