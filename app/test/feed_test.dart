import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelbrain/features/feed/feed_screen.dart';
import 'package:reelbrain/main.dart';

Widget feed(List<Map<String, dynamic>> saves,
        {Map<String, int> counts = const {}, bool loading = false}) =>
    ReelbrainApp(
      home: Scaffold(
        body: FeedList(
            saves: saves,
            counts: counts,
            spaceLabel: (id) => id == 'h1' ? 'Home' : 'Me',
            loading: loading),
      ),
    );

void main() {
  test('to-try counts skip items already acted on', () {
    expect(
      toTryCounts([
        {'section': 'tools', 'user_state': null},
        {'section': 'tools', 'user_state': 'to_try'},
        {'section': 'tools', 'user_state': 'tried'},
        {'section': 'recipe', 'user_state': 'cooked'},
        {'section': 'places'},
      ]),
      {'tools': 2, 'places': 1},
    );
  });

  testWidgets('ready, processing and failed cards', (tester) async {
    await tester.pumpWidget(feed([
      {
        'space_id': 'h1',
        'status': 'ready',
        'platform': 'tiktok',
        'creator': 'itstundealao',
        'summary':
            'Testing VoiceStudio, a free local alternative to ElevenLabs.',
        'sections': ['tools', 'fact_check'],
      },
      {
        'space_id': 'p1',
        'status': 'extracting',
        'platform': 'instagram',
        'step_text': 'Watching the video'
      },
      {
        'space_id': 'p1',
        'status': 'failed',
        'step_text': 'no video or caption from any source'
      },
    ], counts: {
      'tools': 3,
      'recipe': 1
    }));
    expect(find.text('Home · TikTok · itstundealao'), findsOneWidget);
    expect(find.text('Dev and Tools · Fact Check'), findsOneWidget);
    expect(find.text('Watching the video'), findsOneWidget);
    expect(find.text('Failed: no video or caption from any source'),
        findsOneWidget);
    expect(find.text('Dev and Tools 3'), findsOneWidget);
    expect(find.text('Recipes 1'), findsOneWidget);
  });

  testWidgets('empty and loading states', (tester) async {
    await tester.pumpWidget(feed([]));
    expect(find.textContaining('Nothing saved yet'), findsOneWidget);
    await tester.pumpWidget(feed([], loading: true));
    expect(find.byType(SkeletonCard), findsNWidgets(2));
    expect(find.textContaining('Nothing saved yet'), findsNothing);
  });

  testWidgets('Arabic summaries lay out right to left', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('ar')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(feed([
      {
        'space_id': 'p1',
        'status': 'ready',
        'summary': 'جولة داخل سفينة كروز أرويا',
        'sections': ['places']
      },
    ]));
    final dir = Directionality.of(
        tester.element(find.text('جولة داخل سفينة كروز أرويا')));
    expect(dir, TextDirection.rtl);
  });
}
