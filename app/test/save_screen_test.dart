import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelbrain/features/save/save_screen.dart';
import 'package:reelbrain/main.dart';

void main() {
  testWidgets('a save shows each section as readable lines with timestamps',
      (tester) async {
    await tester.pumpWidget(ReelbrainApp(
      home: Scaffold(
        body: SaveDetail(
          save: const {
            'summary': 'Koshari at home',
            'creator': 'chef',
            'platform': 'tiktok',
            'source_url': 'https://vt.tiktok.com/x/',
          },
          items: const [
            {
              'section': 'recipe',
              'data': {
                'title': 'Koshari',
                'servings': 4,
                'ingredients': [
                  {
                    'name': 'lentils',
                    'qty': 200,
                    'unit': 'g',
                    'estimated': false
                  },
                  {'name': 'salt', 'estimated': true},
                ],
                'steps': [
                  {'text': 'Boil the lentils', 't': 41.0},
                ],
              },
            },
            {
              'section': 'places',
              'data': {
                'items': [
                  {
                    'name': 'Abou Tarek',
                    'area': 'Downtown',
                    'city': 'Cairo',
                    't': 8
                  },
                ],
              },
            },
          ],
        ),
      ),
    ));
    expect(find.text('Recipes'), findsOneWidget);
    expect(find.text('Koshari'), findsOneWidget);
    expect(find.text('Serves'), findsOneWidget);
    expect(find.text('• 200 g lentils'), findsOneWidget);
    expect(find.text('• ≈ salt'), findsOneWidget);
    expect(find.text('1. Boil the lentils'), findsOneWidget);
    expect(find.text('Start cooking'), findsOneWidget);
    expect(find.text('Abou Tarek'), findsOneWidget);
    expect(find.text('Downtown, Cairo'), findsOneWidget);
    expect(find.text('Open in Maps'), findsOneWidget);
  });

  test('the source line and the memory chips', () {
    final save = {
      'platform': 'instagram',
      'creator': 'chef',
      'created_at': DateTime(2026, 4, 12).millisecondsSinceEpoch / 1000,
      'effort_min': 12,
      'difficulty': 'easy',
      'impact': 'high',
    };
    expect(sourceLine(save), 'From Instagram · chef · Saved 12 Apr');
    expect([for (final (_, l) in metaChips(save)) l],
        ['12 min', 'Easy', 'High impact']);
    expect(metaChips({}), isEmpty);
  });

  testWidgets('why you saved it: the AI guess until you write your own',
      (tester) async {
    Widget detail(Map<String, dynamic> save) => ReelbrainApp(
        home: Scaffold(
            body: SaveDetail(save: save, items: const [], onEditWhy: () {})));
    await tester
        .pumpWidget(detail({'summary': 'S', 'good_for': 'Quick dinner'}));
    expect(find.text('“Quick dinner” · tap to put it in your words'),
        findsOneWidget);
    await tester.pumpWidget(detail(
        {'summary': 'S', 'good_for': 'Quick dinner', 'note': 'For Friday'}));
    expect(find.text('“For Friday”'), findsOneWidget);
  });
}
