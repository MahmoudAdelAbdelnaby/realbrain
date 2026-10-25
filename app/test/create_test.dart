import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelbrain/core/orbit.dart';
import 'package:reelbrain/features/create/create_screen.dart';
import 'package:reelbrain/main.dart';

void main() {
  test('links are named by where they come from', () {
    expect(linkPlatform('https://vt.tiktok.com/ZSg/'), 'tiktok');
    expect(linkPlatform('https://www.instagram.com/reel/x'), 'instagram');
    expect(linkPlatform('https://youtu.be/abc'), 'youtube');
    expect(linkPlatform('https://example.com/post'), isNull);
  });

  testWidgets('create needs a link or an idea; an idea defaults to Idea',
      (tester) async {
    await tester.pumpWidget(const ReelbrainApp(home: CreateScreen()));
    await tester.pumpAndSettle();
    expect(find.text('What is this?'), findsOneWidget);
    expect(find.text('Save to'), findsNothing, reason: 'no Home space yet');

    // Nothing to save yet: the button does nothing.
    final list = find.byType(Scrollable).first;
    final button = find.text('Create memory');
    await tester.scrollUntilVisible(button, 300, scrollable: list);
    expect(
        tester
            .widget<Opacity>(
                find.ancestor(of: button, matching: find.byType(Opacity)).first)
            .opacity,
        0.5);

    await tester.scrollUntilVisible(find.byType(TextField), -300,
        scrollable: list);
    await tester.enterText(
        find.byType(TextField), 'https://vt.tiktok.com/ZSg/');
    await tester.pump();
    expect(find.text('From TikTok'), findsOneWidget);

    await tester.drag(list, const Offset(0, 2000)); // back to the top
    await tester.pumpAndSettle();
    await tester.tap(find.text('Idea').first); // the segment, above the grid
    await tester.pumpAndSettle();
    expect(find.text('A thought, a plan, something to try…'), findsOneWidget);
  });

  testWidgets('a Home space adds Save to', (tester) async {
    await tester
        .pumpWidget(const ReelbrainApp(home: CreateScreen(hasHome: true)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Save to'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Save to'), findsOneWidget);
  });

  testWidgets('the onboarding orbit paints', (tester) async {
    await tester.pumpWidget(
        const ReelbrainApp(home: Scaffold(body: Center(child: OrbitBrain()))));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });
}
