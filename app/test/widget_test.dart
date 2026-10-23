import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelbrain/main.dart';

void main() {
  testWidgets('app boots', (tester) async {
    await tester.pumpWidget(const ReelbrainApp());
    expect(find.text('Reelbrain'), findsOneWidget);
  });

  testWidgets('Arabic locale lays out right-to-left', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('ar')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(const ReelbrainApp());
    final dir = Directionality.of(tester.element(find.text('Reelbrain')));
    expect(dir, TextDirection.rtl);
  });
}
