import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:reelbrain/core/data/brain.dart';
import 'package:reelbrain/core/format.dart';
import 'package:reelbrain/features/brain/progress.dart';
import 'package:reelbrain/features/today/plan.dart';
import 'package:reelbrain/preview/sample.dart';

final now = DateTime(2026, 11, 3, 19, 20); // a Tuesday evening
final s = sampleState(now);
Discovery find(String prefix) =>
    s.discoveries.firstWhere((d) => d.title.startsWith(prefix));

Json item(String id, String section,
        {String? state, num? seen, num? recall, Json data = const {}}) =>
    {
      'save_id': id,
      'item_id': '0-$section',
      'section': section,
      'user_state': state,
      'data': data,
      if (seen != null) 'seen': {me: seen},
      if (recall != null) 'recall_after': recall,
    };

Json save(String id, num createdAt, {String status = 'ready'}) => {
      'save_id': id,
      'space_id': 'p',
      'status': status,
      'created_at': createdAt,
      'summary': 'Save $id'
    };

void main() {
  final t = epoch(now);
  const day = 86400;

  group('Recall (same rule as backend/app/recall.py)', () {
    test(
        'untried for over a week is due, oldest first; snoozed waits; stamped is done with',
        () {
      final st = BrainState(uid: me, saves: [
        save('old', t - 40 * day),
        save('week', t - 8 * day),
        save('fresh', t - 2 * day),
        save('snoozed', t - 30 * day),
        save('cooked', t - 30 * day),
      ], items: [
        item('old', 'recipe'),
        item('week', 'places', state: 'to_try'),
        item('fresh', 'tools'),
        item('snoozed', 'ideas', recall: t + 3 * day),
        item('cooked', 'recipe', state: 'cooked'),
      ]);
      final plan = recallPlan(st, now: now);
      expect([for (final d in plan.due) d.saveId], ['old', 'week']);
      expect([for (final d in plan.upcoming) d.saveId], ['snoozed']);
    });
  });

  group('the pick for right now', () {
    test('on a Tuesday evening it picks something to do tonight and says why',
        () {
      final picks = rankPicks(s, now: now);
      final top = picks.first;
      expect(top.kicker, 'Tuesday evening');
      expect(top.d.isOpen, isTrue);
      // Something you started is the strongest signal; dinner suits the evening.
      expect(top.d.title, startsWith('Molokhia'));
      expect(top.reason, 'A 35-minute dinner, opened yesterday.');
      expect(picks.any((p) => p.d.isDone), isFalse);
    });

    test('in the morning, a workout rises; a night later, something to watch',
        () {
      final morning = DateTime(2026, 11, 4, 7, 30);
      final st = BrainState(uid: me, saves: [
        save('w', epoch(morning) - 3 * day),
        save('r', epoch(morning) - 3 * day),
        save('e', epoch(morning) - 3 * day),
      ], items: [
        item('w', 'workout', data: {
          'exercises': [
            {'name': 'Squat', 'reps': 10, 'sets': 3}
          ]
        }),
        item('r', 'recipe', data: {'title': 'Stew', 'total_min': 120}),
        item('e', 'entertainment', data: {
          'items': [
            {'kind': 'movie', 'title': 'Film', 't': 1.0}
          ]
        }),
      ]);
      expect(rankPicks(st, now: morning).first.d.section, 'workout');
      expect(rankPicks(st, now: DateTime(2026, 11, 4, 23)).first.d.section,
          'entertainment');
      expect(rankPicks(st, now: DateTime(2026, 11, 4, 23)).first.reason,
          startsWith('Something to watch tonight'));
    });

    test('snoozed, finished and archived things are never picked', () {
      final st = BrainState(uid: me, saves: [
        save('a', t - day),
        save('b', t - day),
        save('c', t - day),
      ], items: [
        item('a', 'recipe', recall: t + day),
        item('b', 'recipe', state: 'cooked'),
        item('c', 'recipe', state: 'archived'),
      ]);
      expect(rankPicks(st, now: now), isEmpty);
    });

    test(
        'Friday and Saturday are the weekend in Egypt; Saturday and Sunday elsewhere',
        () {
      expect(weekendFor(const Locale('en', 'EG')),
          {DateTime.friday, DateTime.saturday});
      expect(
          weekendFor(const Locale('ar')), {DateTime.friday, DateTime.saturday});
      expect(weekendFor(const Locale('en', 'GB')),
          {DateTime.saturday, DateTime.sunday});
    });
  });

  group('shelves', () {
    test('left off, not tried, from groups, recent, revisit', () {
      final pick = rankPicks(s, now: now).first.d;
      final sh = shelvesOf(s, now: now, pick: pick);
      expect(sh.leftOff.map((d) => d.title),
          containsAll(['cursor-rules', 'Qaitbay Citadel']));
      expect(sh.leftOff.contains(pick), isFalse);
      expect(
          sh.notTried.every((d) => d.seenBy(me) == null && d.isOpen), isTrue);
      expect(sh.fromGroups.map((d) => d.addedBy).toSet(), {'salma', 'omar'});
      expect(sh.recent.length, 5);
      expect(
          sh.revisit.due.first.title, 'Cherry galette'); // 41 days, never tried
    });
  });

  group('My Brain', () {
    test('a level fills one piece per finished discovery', () {
      expect(levelPieces(1), 9);
      expect(levelPieces(3), 16);
      expect(levelPieces(12), levelSizes.last + 16);
      final p = progressOf(s);
      final done = s.discoveries.where((d) => d.isDone).length;
      expect(p.placed, done);
      // 9 + 12 pieces fill levels 1 and 2; the rest sit in level 3.
      expect(p.level, 3);
      expect(p.name, 'Explorer');
      expect(p.placedInLevel, done - 21);
      expect(p.inLevel.length, p.placedInLevel);
      expect(p.foundInLevel, greaterThan(0)); // opened but not finished
    });

    test('achievements are earned by doing, with the date you earned them', () {
      final a = {for (final x in achievementsOf(s)) x.id: x};
      expect(a['first_piece']!.earned, isTrue);
      expect(a['reel_to_table']!.earned, isTrue);
      expect(a['toolsmith']!.earned, isTrue);
      expect(a['rediscovery']!.earned, isTrue);
      expect(a['myth_buster']!.earned, isFalse);
      expect(a['myth_buster']!.current, 3);
      expect(a['curator']!.current, s.saves.length);
      expect(a['first_piece']!.earnedAt, isNotNull);
    });

    test('the month in review', () {
      final october = recapOf(s, DateTime(2026, 10));
      expect(october.label, 'October 2026');
      expect(october.saved, isNotEmpty);
      expect(october.done, isNotEmpty);
      expect(october.topCategory, isNotNull);
      expect(october.highlights.length, lessThanOrEqualTo(3));
      expect(recapOf(s, DateTime(2025, 1)).isEmpty, isTrue);
    });

    test('insights notice what you save but rarely use', () {
      final st = BrainState(uid: me, saves: [
        for (var i = 0; i < 5; i++) save('t$i', t - 40 * day),
      ], items: [
        for (var i = 0; i < 5; i++) item('t$i', 'tools'),
      ]);
      final i = insightsOf(st, now: now);
      expect(i.map((x) => x.text), contains('You saved 5 tools and tried 0'));
      expect(i.map((x) => x.text),
          contains('Your tools have waited over a month'));
    });

    test('threads join interests that share topics', () {
      final th = threadsOf(s);
      final recipesPlaces = th.threads
          .firstWhere((x) => {x.a, x.b}.containsAll({'recipe', 'places'}));
      expect(recipesPlaces.shared, contains('egyptian food'));
    });
  });
}
