import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelbrain/features/threads/threads.dart';
import 'package:reelbrain/main.dart';

Map<String, dynamic> save(String id, List<String> topics) => {
      'save_id': id,
      'space_id': 'p',
      'status': 'ready',
      'created_at': 1,
      'summary': id,
      'topics': topics,
    };

Map<String, dynamic> item(String id, String section, [Map? data]) =>
    {'save_id': id, 'section': section, 'data': data ?? {}};

final saves = [
  save('bowl', ['protein', 'meal prep']),
  save('soup', []),
  save('lift', ['protein']),
  save('cafe', []),
];
final items = [
  item('bowl', 'recipe', {
    'title': 'Protein bowl',
    'tags': ['Egyptian']
  }),
  item('soup', 'recipe', {
    'title': 'Lentil soup',
    'tags': ['egyptian']
  }),
  item('lift', 'workout'),
  item('cafe', 'places', {
    'items': [
      {'name': 'Abou Tarek', 'city': 'Cairo'}
    ]
  }),
];

void main() {
  test('topics come from the save, recipe tags and a place\'s city', () {
    expect(topicsOf(items[0], saves[0]), {'protein', 'meal prep', 'egyptian'});
    expect(topicsOf(items[3], saves[3]), {'cairo'});
  });

  test('interests are joined only by the topics they share', () {
    final m = threadsOf(items, saves);
    expect([for (final i in m.interests) i.section],
        ['recipe', 'workout', 'places']);
    expect(m.interests.first.topics['egyptian'], 2);
    expect([for (final t in m.threads) (t.a, t.b, t.shared.join(','))],
        [('recipe', 'workout', 'protein')]);
    expect(m.of('places'), isEmpty);
  });

  testWidgets('tap an interest: its topics, why it connects, its memories',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    String? seeAll;
    await tester.pumpWidget(ReelbrainApp(
      home: Scaffold(
          body: ThreadsView(
              model: threadsOf(items, saves), onSection: (s) => seeAll = s)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Cooking'), findsWidgets);
    expect(find.text('Protein bowl'), findsOneWidget);
    expect(find.textContaining('through protein'), findsOneWidget);

    // Filter by a topic.
    await tester.tap(find.text('meal prep · 1'));
    await tester.pumpAndSettle();
    expect(find.text('Lentil soup'), findsNothing);

    // Follow the thread to Fitness.
    await tester.tap(find.bySemanticsLabel('Fitness, 1 memories'));
    await tester.pumpAndSettle();
    expect(find.text('lift'), findsOneWidget);
    expect(seeAll, isNull);
  });
}
