import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelbrain/features/inbox/inbox_screen.dart';
import 'package:reelbrain/main.dart';

Widget inbox(List<Map<String, dynamic>> saves) => ReelbrainApp(
      home: Scaffold(body: InboxList(saves: saves, spaceLabel: (_) => 'Me')),
    );

void main() {
  test('the inbox holds arriving saves and the ones that need you', () {
    const all = ['ready', 'needs_review', 'partial', 'failed', 'extracting'];
    expect([
      for (final s in all)
        if (inInbox({'status': s})) s
    ], [
      'needs_review',
      'partial',
      'failed'
    ]);
    expect([
      for (final s in all)
        if (inInboxList({'status': s})) s
    ], [
      'needs_review',
      'partial',
      'failed',
      'extracting'
    ]);
  });

  testWidgets(
      'rows show source and status; review saves file or retry, failed ones only retry',
      (tester) async {
    await tester.pumpWidget(inbox([
      {
        'save_id': 'a',
        'space_id': 'p',
        'status': 'needs_review',
        'platform': 'instagram',
        'duration_s': 45,
        'summary': 'AirPods sale'
      },
      {
        'save_id': 'b',
        'space_id': 'p',
        'status': 'failed',
        'source_url': 'https://example.com/post',
        'step_text': 'no video or caption'
      },
      {
        'save_id': 'c',
        'space_id': 'p',
        'status': 'extracting',
        'platform': 'tiktok',
        'step_text': 'Watching the video'
      },
    ]));
    expect(find.text('Instagram · Me · 45s'), findsOneWidget);
    expect(find.text('Needs a section'), findsOneWidget);
    expect(find.text('Watching the video'), findsOneWidget);

    await tester.tap(find.text('AirPods sale'));
    await tester.pump(const Duration(seconds: 1)); // a row spins: never settles
    expect(find.text('File this under'), findsOneWidget);
    expect(find.text('Recipes'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10)); // dismiss
    await tester.pump(const Duration(seconds: 1)); // a row spins: never settles

    await tester.tap(find.text('example.com'));
    await tester.pump(const Duration(seconds: 1)); // a row spins: never settles
    expect(find.text('This save failed'), findsOneWidget);
    expect(find.text('Recipes'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('filters split videos from links', (tester) async {
    await tester.pumpWidget(inbox([
      {'status': 'failed', 'platform': 'tiktok', 'summary': 'A reel'},
      {
        'status': 'failed',
        'source_url': 'https://site.org/a',
        'summary': 'A page'
      },
    ]));
    await tester.tap(find.text('Links'));
    await tester.pumpAndSettle();
    expect(find.text('A page'), findsOneWidget);
    expect(find.text('A reel'), findsNothing);
  });

  testWidgets('empty inbox explains itself', (tester) async {
    await tester.pumpWidget(inbox([]));
    expect(find.textContaining('Nothing to sort'), findsOneWidget);
  });
}
