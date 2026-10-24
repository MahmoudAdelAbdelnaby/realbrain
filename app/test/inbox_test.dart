import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelbrain/features/inbox/inbox_screen.dart';
import 'package:reelbrain/main.dart';

Widget inbox(List<Map<String, dynamic>> saves) => ReelbrainApp(
      home: Scaffold(body: InboxList(saves: saves, spaceLabel: (_) => 'Me')),
    );

void main() {
  test('the inbox holds unsure, caption-only and failed saves', () {
    expect(
      [
        for (final s in [
          'ready',
          'needs_review',
          'partial',
          'failed',
          'extracting'
        ])
          if (inInbox({'status': s})) s,
      ],
      ['needs_review', 'partial', 'failed'],
    );
  });

  testWidgets('review saves can be filed or retried; failed ones only retried',
      (tester) async {
    await tester.pumpWidget(inbox([
      {
        'save_id': 'a',
        'space_id': 'p',
        'status': 'needs_review',
        'summary': 'AirPods sale'
      },
      {
        'save_id': 'b',
        'space_id': 'p',
        'status': 'failed',
        'step_text': 'no video or caption'
      },
    ]));
    expect(find.text('File as'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'Recipes'), findsOneWidget);
    expect(find.text('Retry'), findsNWidgets(2));
  });

  testWidgets('empty inbox explains itself', (tester) async {
    await tester.pumpWidget(inbox([]));
    expect(find.textContaining('Nothing to sort'), findsOneWidget);
  });
}
