import 'package:flutter_test/flutter_test.dart';
import 'package:reelbrain/main.dart';

void main() {
  testWidgets('app boots', (tester) async {
    await tester.pumpWidget(const ReelbrainApp());
    expect(find.text('Reelbrain'), findsOneWidget);
  });
}
