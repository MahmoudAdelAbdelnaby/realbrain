/// My Brain's arithmetic (docs/DESIGN_V5.md §2.5): pieces, levels, achievements, the monthly
/// recap, insights and threads. Pure: everything comes from a [BrainState], unit tested.
library;

import 'dart:math' as math;

import '../../core/categories.dart';
import '../../core/data/brain.dart';
import '../../core/format.dart';

/// Pieces per level: each brain is a bigger puzzle than the last.
const levelSizes = [9, 12, 16, 20, 25, 30, 36, 42, 49, 56];
const levelNames = [
  'Curious',
  'Collector',
  'Explorer',
  'Tinkerer',
  'Connoisseur',
  'Polymath',
  'Scholar',
  'Sage',
  'Luminary',
  'Archivist',
];

int levelPieces(int level) => level <= levelSizes.length
    ? levelSizes[level - 1]
    : levelSizes.last + 8 * (level - levelSizes.length);

String levelName(int level) => level <= levelNames.length
    ? levelNames[level - 1]
    : 'Archivist ${level - levelNames.length + 1}';

class Progress {
  Progress({
    required this.placedOrder,
    required this.explored,
    required this.level,
    required this.placedInLevel,
    required this.foundInLevel,
  });

  /// Finished discoveries, in the order they were finished: piece 1 first.
  final List<Discovery> placedOrder;

  /// Opened (by you) but not finished.
  final int explored;
  final int level, placedInLevel, foundInLevel;

  int get placed => placedOrder.length;
  int get levelSize => _size(level);
  int get toNext => levelSize - placedInLevel;
  String get name => levelName(level);
  String get nextName => levelName(level + 1);

  /// The discoveries whose pieces sit in the current brain, in order.
  List<Discovery> get inLevel =>
      placedOrder.sublist(placed - placedInLevel, placed);

  static int _size(int l) => levelPieces(l);
}

num _doneTime(Discovery d) => d.doneAt ?? d.createdAt;

Progress progressOf(BrainState s) {
  final done = [
    for (final d in s.discoveries)
      if (d.isDone) d
  ]..sort((a, b) => _doneTime(a).compareTo(_doneTime(b)));
  final explored = s.discoveries
      .where((d) => !d.isDone && !d.isArchived && d.seenBy(s.uid) != null)
      .length;
  var level = 1, left = done.length;
  while (left >= levelPieces(level)) {
    left -= levelPieces(level);
    level++;
  }
  return Progress(
    placedOrder: done,
    explored: explored,
    level: level,
    placedInLevel: left,
    foundInLevel: math.min(explored, levelPieces(level) - left),
  );
}

// --- achievements ---

class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.body,
    required this.glyph,
    required this.target,
    required this.current,
    this.earnedAt,
  });

  final String id, title, body, glyph;
  final int target, current;
  final num? earnedAt;

  bool get earned => current >= target;
  double get fraction => (current / target).clamp(0.0, 1.0);
}

List<Achievement> achievementsOf(BrainState s) {
  final all = s.discoveries;
  final done = [
    for (final d in all)
      if (d.isDone) d
  ]..sort((a, b) => _doneTime(a).compareTo(_doneTime(b)));
  List<Discovery> doneIn(String section, [Set<String>? states]) => [
        for (final d in done)
          if (d.section == section &&
              (states == null || states.contains(d.state)))
            d
      ];
  num? nth(List<Discovery> l, int n) =>
      l.length >= n ? _doneTime(l[n - 1]) : null;

  final categoriesDone = <String>{};
  num? polymathAt;
  for (final d in done) {
    categoriesDone.add(d.section);
    if (categoriesDone.length == 5 && polymathAt == null) {
      polymathAt = _doneTime(d);
    }
  }
  final rediscovered = [
    for (final d in done)
      if ((d.doneAt ?? 0) - d.createdAt >= 30 * 86400) d
  ];
  final together = [
    for (final d in done)
      if (s.isGroupSpace(d.spaceId)) d
  ];
  final savesAsc = [...s.saves]..sort((a, b) =>
      ((a['created_at'] ?? 0) as num).compareTo((b['created_at'] ?? 0) as num));

  Achievement a(String id, String title, String body, String glyph, int target,
          List<Discovery> list) =>
      Achievement(
          id: id,
          title: title,
          body: body,
          glyph: glyph,
          target: target,
          current: list.length,
          earnedAt: nth(list, target));

  return [
    a('first_piece', 'First piece', 'Finish your first discovery.', 'piece', 1,
        done),
    a('reel_to_table', 'From reel to table', 'Cook a recipe you saved.',
        'recipe', 1, doneIn('recipe')),
    a('out_the_door', 'Out the door', 'Visit a place you saved.', 'places', 1,
        doneIn('places')),
    a('sweat_equity', 'Sweat equity', 'Finish a saved workout.', 'workout', 1,
        doneIn('workout')),
    a('toolsmith', 'Toolsmith', 'Try three tools.', 'tools', 3,
        doneIn('tools')),
    a('myth_buster', 'Myth buster', 'Read five fact checks.', 'fact_check', 5,
        doneIn('fact_check')),
    a('the_end', 'The end', 'Finish a film, series or book you saved.',
        'entertainment', 1, doneIn('entertainment')),
    a(
        'considered',
        'Considered purchase',
        'Buy something you saved and thought over.',
        'products',
        1,
        doneIn('products', {'purchased'})),
    a(
        'rediscovery',
        'Rediscovery',
        'Finish something you saved over a month earlier.',
        'quote',
        1,
        rediscovered),
    a('together', 'Better together',
        'Finish something from one of your groups.', 'groups', 1, together),
    Achievement(
      id: 'polymath',
      title: 'Polymath',
      body: 'Finish something in five different categories.',
      glyph: 'ideas',
      target: 5,
      current: categoriesDone.length,
      earnedAt: polymathAt,
    ),
    Achievement(
      id: 'curator',
      title: 'Curator',
      body: 'Save fifty discoveries.',
      glyph: 'library',
      target: 50,
      current: s.saves.length,
      earnedAt:
          savesAsc.length >= 50 ? savesAsc[49]['created_at'] as num? : null,
    ),
  ];
}

// --- monthly recap ---

class Recap {
  Recap({
    required this.month,
    required this.saved,
    required this.done,
    required this.explored,
    required this.byCategory,
    required this.highlights,
    this.busiestDay,
  });

  final DateTime month;
  final List<Discovery> saved, done;
  final int explored;
  final Map<String, int> byCategory;
  final List<Discovery> highlights;
  final String? busiestDay;

  String get label => '${months[month.month - 1]} ${month.year}';
  String? get topCategory {
    if (byCategory.isEmpty) return null;
    return (byCategory.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .first
        .key;
  }

  bool get isEmpty => saved.isEmpty && done.isEmpty;
}

Recap recapOf(BrainState s, DateTime month) {
  final start = DateTime(month.year, month.month);
  final end = DateTime(month.year, month.month + 1);
  bool inMonth(num? t) {
    if (t == null) return false;
    final d = fromEpoch(t);
    return !d.isBefore(start) && d.isBefore(end);
  }

  final saved = [
    for (final d in s.discoveries)
      if (inMonth(d.createdAt)) d
  ];
  final done = [
    for (final d in s.discoveries)
      if (d.isDone && inMonth(d.doneAt)) d
  ];
  final explored = s.discoveries.where((d) => inMonth(d.seenBy(s.uid))).length;
  final by = <String, int>{};
  final days = <int, int>{};
  for (final d in saved) {
    by[d.section] = (by[d.section] ?? 0) + 1;
    final wd = fromEpoch(d.createdAt).weekday;
    days[wd] = (days[wd] ?? 0) + 1;
  }
  final busiest = days.isEmpty
      ? null
      : weekdays[(days.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .first
              .key -
          1];
  final pool = [...done, ...saved.where((d) => !done.contains(d))];
  pool.sort(
      (a, b) => (b.frame != null ? 1 : 0).compareTo(a.frame != null ? 1 : 0));
  return Recap(
    month: start,
    saved: saved,
    done: done,
    explored: explored,
    byCategory: by,
    highlights: pool.take(3).toList(),
    busiestDay: busiest,
  );
}

// --- insights ---

class Insight {
  const Insight(this.section, this.text, this.action,
      {this.filled = 0, this.of = 5});
  final String section, text, action;
  final int filled, of;
}

/// At most four calm observations: what grew this week, what you save but rarely use, what has
/// waited a month. No streaks.
List<Insight> insightsOf(BrainState s, {DateTime? now}) {
  final t = epoch(now ?? DateTime.now());
  final per = <String, List<Discovery>>{};
  for (final d in s.discoveries) {
    (per[d.section] ??= []).add(d);
  }
  final grew = <Insight>[], unused = <Insight>[], waited = <Insight>[];
  for (final MapEntry(key: id, value: list) in per.entries) {
    final cat = categoryOf(id);
    final week = list.where((d) => d.createdAt > t - 7 * 86400).length;
    if (week > 0) {
      grew.add(Insight(id, 'You saved ${count(week, cat.noun)} this week',
          'See ${cat.name.toLowerCase()}',
          filled: week.clamp(0, 5)));
    }
    final used = list.where((d) => d.isDone).length;
    if (list.length >= 4 && used * 3 < list.length) {
      unused.add(Insight(
          id,
          'You saved ${list.length} ${cat.noun}s and ${cat.verb} $used',
          'Pick one',
          filled: (used * 5 / list.length).round()));
    }
    final open = list.where((d) => d.isOpen).toList();
    if (open.length >= 2 && open.every((d) => d.createdAt < t - 30 * 86400)) {
      waited.add(Insight(
          id,
          'Your ${cat.name.toLowerCase()} have waited over a month',
          'Explore now'));
    }
  }
  return [...grew, ...unused, ...waited].take(4).toList();
}

// --- threads: what connects your interests ---

typedef Interest = ({
  String section,
  List<Discovery> items,
  Map<String, int> topics
});
typedef Thread = ({String a, String b, List<String> shared});

/// What a discovery is about: the save's topics, plus what older saves already carry.
Set<String> topicsOf(Discovery d) => {
      for (final t in d.topics) t.toLowerCase(),
      if (d.section == 'recipe')
        for (final t in (d.data['tags'] as List?) ?? const [])
          '$t'.toLowerCase(),
      if (d.section == 'places')
        for (final p in listOf(d.data['items']))
          if (p['city'] != null) '${p['city']}'.toLowerCase(),
      if (d.section == 'entertainment')
        for (final e in listOf(d.data['items']))
          for (final g in (e['genres'] as List?) ?? const [])
            '$g'.toLowerCase(),
    };

({List<Interest> interests, List<Thread> threads}) threadsOf(BrainState s) {
  final items = <String, List<Discovery>>{};
  final topics = <String, Map<String, int>>{};
  for (final d in s.discoveries) {
    (items[d.section] ??= []).add(d);
    for (final t in topicsOf(d)) {
      final m = topics[d.section] ??= {};
      m[t] = (m[t] ?? 0) + 1;
    }
  }
  final interests = [
    for (final e in items.entries)
      (
        section: e.key,
        items: e.value,
        topics: topics[e.key] ?? const <String, int>{}
      )
  ]..sort((a, b) => b.items.length.compareTo(a.items.length));
  final threads = <Thread>[];
  for (var i = 0; i < interests.length; i++) {
    for (var j = i + 1; j < interests.length; j++) {
      final shared = interests[i]
          .topics
          .keys
          .where(interests[j].topics.containsKey)
          .toList()
        ..sort();
      if (shared.isNotEmpty) {
        threads.add(
            (a: interests[i].section, b: interests[j].section, shared: shared));
      }
    }
  }
  return (interests: interests, threads: threads);
}
