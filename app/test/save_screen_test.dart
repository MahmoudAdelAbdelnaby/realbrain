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
    expect(find.text('Cook'), findsOneWidget);
    expect(find.text('• Abou Tarek, Downtown, Cairo  (0:08)'), findsOneWidget);
  });
}
