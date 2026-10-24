import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelbrain/features/reels/reels_screen.dart';
import 'package:reelbrain/main.dart';

final items = <Map<String, dynamic>>[
  {
    'save_id': 's1',
    'section': 'recipe',
    'data': {
      'steps': [
        {
          'text': 'Fry the onions',
          't': 30.0,
          'timer_s': 600,
          'frame': 'f/s1-steps-1.jpg'
        },
        {'text': 'Boil the lentils', 't': 8.0},
        {'text': 'No time stamp'},
      ]
    }
  },
  {
    'save_id': 's1',
    'section': 'fact_check',
    'data': {
      'claims': [
        {
          'text': 'Lentils double protein',
          't': 20.0,
          'verdict': 'mostly_false',
          'correction': 'About 9 g per 100 g.'
        },
      ]
    }
  },
];

void main() {
  test('moments from every section, in reel order, with their own data', () {
    final m = reelMoments(items);
    expect([for (final x in m) x.t], [8.0, 20.0, 30.0]);
    expect(m[1].verdict, 'mostly_false');
    expect(m[1].detail, 'About 9 g per 100 g.');
    expect(m[2].detail, 'Timer 10:00');
    expect(m[2].frame, 'f/s1-steps-1.jpg');
    expect(m[0].frame, isNull,
        reason: 'older saves fall back to the key frame');
  });

  testWidgets('a reel shows its summary first, then a moment when swiped',
      (tester) async {
    await tester.pumpWidget(ReelbrainApp(
      home: Scaffold(
        body: ReelsView(saves: const [
          {
            'save_id': 's1',
            'space_id': 'p',
            'status': 'ready',
            'summary': 'Koshari at home',
            'sections': ['recipe']
          },
          {'save_id': 's2', 'status': 'extracting'},
        ], items: items),
      ),
    ));
    expect(find.text('Koshari at home'), findsOneWidget);
    expect(find.text('Swipe through 3 moments'), findsOneWidget);
    await tester.fling(find.byType(PageView).last, const Offset(-400, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.text('Boil the lentils'), findsOneWidget);
  });
}
