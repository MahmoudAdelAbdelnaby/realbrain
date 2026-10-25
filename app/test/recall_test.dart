import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelbrain/features/recall/boosts.dart';
import 'package:reelbrain/features/recall/recall.dart';
import 'package:reelbrain/main.dart';

final now = DateTime(2026, 10, 25, 20);
final t = now.millisecondsSinceEpoch / 1000;
const day = 86400;

Map<String, dynamic> save(String id, int ageDays, {String status = 'ready'}) =>
    {
      'save_id': id,
      'space_id': 'p',
      'status': status,
      'created_at': t - ageDays * day,
      'summary': id,
    };

Map<String, dynamic> item(String id,
        {String section = 'recipe', String? state, num? back}) =>
    {
      'save_id': id,
      'item_id': '0-$section',
      'space_id': 'p',
      'section': section,
      'user_state': state,
      'recall_after': back,
      'data': {'title': id},
    };

void main() {
  test('Recall: old untried saves are due, this week groups, snoozed wait', () {
    final saves = [
      save('old', 90),
      save('older', 120),
      save('mid', 10),
      save('new1', 1),
      save('new2', 2),
      save('tool', 3),
      save('nap', 40),
      save('done', 50),
      save('busy', 30, status: 'extracting'),
    ];
    final items = [
      item('old'),
      item('older'),
      item('mid'),
      item('new1'),
      item('new2'),
      item('tool', section: 'tools'),
      item('nap', back: t + 3 * day),
      item('done', state: 'cooked'),
      item('busy'),
    ];
    final plan = recallPlan(items, saves, now: now);
    expect(
        [for (final m in plan.due) m.save['save_id']], ['older', 'old', 'mid']);
    expect(plan.week.map((w) => (w.$1, w.$2.length)), [('recipe', 2)],
        reason: 'one tool this week is not a group');
    expect([for (final m in plan.upcoming) m.save['save_id']], ['nap']);
  });

  test('ago reads naturally', () {
    expect(ago(3 * day), '3 days');
    expect(ago(20 * day), '2 weeks');
    expect(ago(95 * day), '3 months');
  });

  test('boosts: what grew, what went unused, what waited', () {
    final saves = [
      for (var i = 0; i < 6; i++) save('r$i', i < 2 ? 1 : 60),
      save('w1', 45),
      save('w2', 50),
    ];
    final items = [
      for (var i = 0; i < 6; i++) item('r$i', state: i == 0 ? 'cooked' : null),
      item('w1', section: 'workout'),
      item('w2', section: 'workout'),
    ];
    final b = boostsOf(items, saves, now: now);
    expect(b.map((x) => x.text), [
      'Your cooking brain grew this week',
      'You saved 6 recipes but cooked only 1',
      'Your workouts have waited over 30 days',
    ]);
    expect(b.first.delta, '+2');
    expect(b.first.filled, 2);
  });

  testWidgets('the Recall tab shows why each memory is back', (tester) async {
    final plan = recallPlan([item('old')], [save('old', 90)], now: now);
    String? opened;
    await tester.pumpWidget(ReelbrainApp(
      home: Scaffold(
          body: RecallView(plan: plan, now: now, onSection: (s) => opened = s)),
    ));
    expect(find.text('Today'), findsOneWidget);
    expect(
        find.text(
            '3 months ago you saved a recipe: “old”. You never tried it.'),
        findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
    expect(find.text('Archive'), findsOneWidget);
    expect(opened, isNull);
  });
}
