import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelbrain/features/feed/lanes.dart';
import 'package:reelbrain/main.dart';

final saves = [
  {
    'save_id': 's1',
    'space_id': 'p',
    'created_at': 100,
    'summary': 'Cold showers double your metabolism',
    'verdict': 'mostly_false'
  },
  {
    'save_id': 's2',
    'space_id': 'p',
    'created_at': 300,
    'summary': 'Koshari at home'
  },
  {
    'save_id': 's3',
    'space_id': 'p',
    'created_at': 200,
    'summary': 'A better ls'
  },
];

final items = [
  {
    'save_id': 's1',
    'section': 'fact_check',
    'data': {
      'claims': [
        {'text': 'a', 't': 3.0},
        {'text': 'b', 't': 12.5},
      ]
    }
  },
  {
    'save_id': 's2',
    'section': 'recipe',
    'data': {
      'title': 'Koshari',
      'total_min': 35,
      'servings': 4,
      'steps': [
        {'text': 'boil', 't': 20.0},
        {'text': 'fry', 't': 8.0},
      ]
    }
  },
  {
    'save_id': 's3',
    'section': 'tools',
    'data': {
      'items': [
        {
          'name': 'eza',
          't': 5.0,
          'verified': {'ok': true, 'stars': 12345}
        },
        {'name': 'bat', 't': 9.0},
      ]
    }
  },
  {'save_id': 'gone', 'section': 'places', 'data': {}},
];

void main() {
  test(
      'lanes are ordered by the newest save in each; items without a save are skipped',
      () {
    final lanes = lanesOf(items, saves);
    expect(
        [for (final l in lanes) l.section], ['recipe', 'tools', 'fact_check']);
  });

  test('each card face shows its section data', () {
    expect(cardFace(items[0], saves[0]),
        ('Cold showers double your metabolism', '2 claims'));
    expect(cardFace(items[1], saves[1]), ('Koshari', '35 min, serves 4'));
    expect(cardFace(items[2], saves[2]), ('eza +1', '★ 12.3k'));
    expect(
      cardFace({
        'section': 'workout',
        'data': {
          'exercises': [
            {'name': 'Squats', 'duration_s': 40},
            {'name': 'Plank', 'duration_s': 60},
          ]
        }
      }, {
        'summary': 'Core'
      }),
      ('Core', '2 exercises, about 2 min'),
    );
  });

  test('moments come from every list in the item, sorted', () {
    expect(momentsOf(items[1]), [8.0, 20.0]);
    expect(momentsOf({'data': null}), isEmpty);
  });

  testWidgets('a lane shows its title, count, cards and verdict pill',
      (tester) async {
    final lane = lanesOf(items, saves).last;
    await tester.pumpWidget(ReelbrainApp(
      home: Scaffold(body: LaneView(lane: lane, onSeeAll: () {})),
    ));
    expect(find.text('Fact Check'), findsOneWidget);
    expect(find.text('See all'), findsOneWidget);
    expect(find.text('2 claims'), findsOneWidget);
    expect(find.text('Mostly false'), findsOneWidget);
    expect(find.byType(MomentStrip), findsOneWidget);
  });
}
