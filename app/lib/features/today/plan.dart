/// Today's arithmetic (docs/DESIGN_V5.md §2.5): Recall's rules, the pick for right now with the
/// reason it was picked, and the shelves. Pure: unit tested with fixed clocks.
library;

import 'dart:ui' show Locale;

import '../../core/categories.dart';
import '../../core/data/brain.dart';
import '../../core/format.dart';

const _week = 7 * 86400;

// --- Recall (same rule as backend/app/recall.py) ---

class RecallPlan {
  RecallPlan(this.due, this.upcoming);

  /// Still to try (never stamped), saved over a week ago, not snoozed; oldest first.
  final List<Discovery> due;

  /// Snoozed, soonest back first.
  final List<Discovery> upcoming;
}

RecallPlan recallPlan(BrainState s, {DateTime? now}) {
  final t = epoch(now ?? DateTime.now());
  final due = <Discovery>[], later = <Discovery>[];
  for (final d in s.discoveries) {
    if (d.state != null && d.state != 'to_try') continue;
    if ((d.recallAfter ?? 0) > t) {
      later.add(d);
    } else if (d.createdAt <= t - _week) {
      due.add(d);
    }
  }
  due.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  later.sort((a, b) => a.recallAfter!.compareTo(b.recallAfter!));
  return RecallPlan(due, later);
}

// --- the pick for right now ---

/// Countries whose weekend is Friday and Saturday.
const _friSat = {
  'EG', 'SA', 'AE', 'KW', 'QA', 'BH', 'OM', 'JO', 'IQ', 'YE', 'DZ', 'LY', 'SD',
  'SY', //
};

/// Weekend days for a locale: Friday-Saturday across most of the Arab world (and for Arabic
/// with no country), Saturday-Sunday elsewhere.
Set<int> weekendFor(Locale? locale) {
  final cc = locale?.countryCode?.toUpperCase();
  if (cc != null && cc.isNotEmpty) {
    return _friSat.contains(cc)
        ? {DateTime.friday, DateTime.saturday}
        : {DateTime.saturday, DateTime.sunday};
  }
  return locale?.languageCode == 'ar'
      ? {DateTime.friday, DateTime.saturday}
      : {DateTime.saturday, DateTime.sunday};
}

class Pick {
  Pick(this.d, this.score, this.reason, this.kicker);
  final Discovery d;
  final double score;

  /// One sentence, in the person's terms: "A 25-minute dinner you saved 3 days ago."
  final String reason;

  /// "TUESDAY EVENING": when this was picked for.
  final String kicker;
}

int _stableHash(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0x7fffffff;
  }
  return h;
}

/// Open discoveries ranked for right now: the part of the day and the week, how fresh it is,
/// whether you started it, how long it takes, whether someone in a group shared it. A small
/// daily jitter rotates near-ties so the same thing doesn't sit there all week.
List<Pick> rankPicks(BrainState s,
    {DateTime? now,
    Set<int> weekend = const {DateTime.friday, DateTime.saturday}}) {
  final n = now ?? DateTime.now();
  final t = epoch(n);
  final slot = slotOf(n);
  final isWeekend = weekend.contains(n.weekday);
  final day = '${n.year}-${n.month}-${n.day}-${slot.index}';
  final kicker = '${weekdays[n.weekday - 1]} ${slotNames[slot]}';
  final picks = <Pick>[];
  for (final d in s.discoveries) {
    if (!d.isOpen || (d.recallAfter ?? 0) > t) continue;
    final cat = d.category;
    var score = 0.6 + (cat.slot[slot] ?? 0.4);
    if (isWeekend) score += cat.weekend;
    final age = t - d.createdAt;
    final seen = d.seenBy(s.uid);
    final mine = d.addedBy == null || d.addedBy == s.uid;
    String suffix;
    if (seen != null) {
      score += 0.45;
      suffix = 'opened ${_dayWord(fromEpoch(seen), n)}';
    } else if (age < 2 * 86400) {
      score += 0.35;
      suffix = 'saved ${ago(d.createdAt, now: n)}';
    } else if (!mine && s.isGroupSpace(d.spaceId)) {
      score += 0.2;
      final g = s.group(d.spaceId);
      suffix =
          'shared by ${g?.nameOf(d.addedBy!) ?? 'someone'} in ${g?.name ?? 'a group'}';
    } else if (age > 30 * 86400) {
      score += 0.2;
      suffix = 'waiting ${span(age)}';
    } else {
      score += age < _week ? 0.15 : 0;
      suffix = 'saved ${ago(d.createdAt, now: n)}';
    }
    final effort = d.effortMin ??
        (d.section == 'recipe' ? (d.data['total_min'] as num?)?.toInt() : null);
    if (effort != null && !isWeekend) {
      if (slot == DaySlot.evening && effort <= 45) score += 0.2;
      if (effort > 90) score -= 0.35;
    }
    if (d.isActive) score += 0.25; // in progress: finish it
    score += (_stableHash('$day ${d.key}') % 1000) / 1000 * 0.14;
    picks.add(Pick(
        d, score, '${_phrase(d, slot, isWeekend, effort)}, $suffix.', kicker));
  }
  picks.sort((a, b) => b.score.compareTo(a.score));
  return picks;
}

String _dayWord(DateTime then, DateTime now) {
  final days = DateTime(now.year, now.month, now.day)
      .difference(DateTime(then.year, then.month, then.day))
      .inDays;
  if (days <= 0) return 'earlier today';
  if (days == 1) return 'yesterday';
  if (days < 7) return 'on ${weekdays[then.weekday - 1]}';
  return ago(epoch(then), now: now);
}

String _phrase(Discovery d, DaySlot slot, bool weekend, int? effort) {
  final mins = effort == null ? '' : '$effort-minute ';
  switch (d.section) {
    case 'recipe':
      if (weekend) return 'A ${mins}weekend cook';
      return switch (slot) {
        DaySlot.morning => 'A ${mins}recipe for later',
        DaySlot.midday => 'A ${mins}lunch',
        _ => 'A ${mins}dinner',
      };
    case 'workout':
      final m = workoutMinutes(listOf(d.data['exercises']));
      final len = m > 0 ? '$m-minute ' : '';
      return slot == DaySlot.morning
          ? 'A ${len}morning workout'
          : 'A ${len}workout';
    case 'places':
      if (weekend) return 'A place for your weekend';
      return switch (slot) {
        DaySlot.midday => 'A lunch spot',
        DaySlot.evening => 'Somewhere for tonight',
        _ => 'A place you wanted to visit',
      };
    case 'tools':
      return slot == DaySlot.evening || slot == DaySlot.night
          ? 'A tool you meant to try'
          : 'A tool to try while you work';
    case 'fact_check':
      return slot == DaySlot.morning
          ? 'A claim to check over coffee'
          : 'A claim to check';
    case 'ideas':
      return 'An idea worth acting on';
    case 'entertainment':
      final book = d.kind == 'book';
      return slot == DaySlot.evening || slot == DaySlot.night
          ? 'Something to ${book ? 'read' : 'watch'} tonight'
          : 'Something to ${book ? 'read' : 'watch'}';
    case 'products':
      return 'Something you were weighing up';
  }
  return 'Worth a look';
}

// --- shelves ---

class Shelves {
  Shelves({
    required this.leftOff,
    required this.notTried,
    required this.fromGroups,
    required this.recent,
    required this.revisit,
  });

  /// Opened by you, not finished: most recently opened first.
  final List<Discovery> leftOff;

  /// Never opened, saved in the last month: newest first.
  final List<Discovery> notTried;

  /// Shared into your groups by someone else: newest first.
  final List<Discovery> fromGroups;

  /// Everything, newest first.
  final List<Discovery> recent;

  /// Recall: untried for over a week.
  final RecallPlan revisit;

  bool get isEmpty =>
      leftOff.isEmpty &&
      notTried.isEmpty &&
      fromGroups.isEmpty &&
      recent.isEmpty;
}

Shelves shelvesOf(BrainState s, {DateTime? now, Discovery? pick}) {
  final t = epoch(now ?? DateTime.now());
  final open = [
    for (final d in s.discoveries)
      if (d.isOpen && d != pick && (d.recallAfter ?? 0) <= t) d
  ];
  final leftOff = [
    for (final d in open)
      if (d.seenBy(s.uid) != null) d
  ]..sort((a, b) => b.seenBy(s.uid)!.compareTo(a.seenBy(s.uid)!));
  final revisit = recallPlan(s, now: now);
  final featured = revisit.due.take(1).toSet();
  final notTried = [
    for (final d in open)
      if (d.seenBy(s.uid) == null &&
          d.createdAt > t - 30 * 86400 &&
          !featured.contains(d))
        d
  ];
  final fromGroups = [
    for (final d in s.discoveries)
      if (s.isGroupSpace(d.spaceId) && d.addedBy != null && d.addedBy != s.uid)
        d
  ];
  return Shelves(
    leftOff: leftOff.take(10).toList(),
    notTried: notTried,
    fromGroups: fromGroups.take(8).toList(),
    recent: [
      for (final d in s.discoveries)
        if (d != pick) d
    ].take(5).toList(),
    revisit: revisit,
  );
}
