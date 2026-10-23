import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelbrain/features/save/saves_screen.dart';
import 'package:reelbrain/main.dart';

void main() {
  var saves = '[]';
  setUp(() {
    saves = '[]';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(downloader, (call) async => saves);
  });

  testWidgets('app boots with empty state', (tester) async {
    await tester.pumpWidget(const ReelbrainApp());
    await tester.pump();
    expect(find.text('Reelbrain'), findsOneWidget);
    expect(find.textContaining('No saves yet'), findsOneWidget);
  });

  testWidgets('lists a downloaded and a failed save', (tester) async {
    saves = '[{"id":"1","url":"https://vt.tiktok.com/a/","space":"me",'
        '"status":"downloaded","size_bytes":2400000,"duration_s":23.4,"download_ms":4100},'
        '{"id":"2","url":"https://www.instagram.com/reel/b/","space":"home",'
        '"status":"failed","error":"LOGIN_REQUIRED"}]';
    await tester.pumpWidget(const ReelbrainApp());
    await tester.pump();
    expect(find.text('me · 2.4 MB · 23 s · 4100 ms'), findsOneWidget);
    expect(find.text('home · LOGIN_REQUIRED'), findsOneWidget);
  });

  testWidgets('Arabic locale lays out right-to-left', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('ar')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(const ReelbrainApp());
    await tester.pump();
    final dir = Directionality.of(tester.element(find.text('Reelbrain')));
    expect(dir, TextDirection.rtl);
  });
}
