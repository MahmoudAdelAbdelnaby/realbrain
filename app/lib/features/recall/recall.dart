import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/surface.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets.dart';
import '../feed/feed_screen.dart' show sectionLabels;
import '../feed/lanes.dart' show FrameImage, cardFace, kindLabels;
import '../save/save_screen.dart';
import '../section/section_screen.dart' show setItemState;

typedef Memory = ({Map<String, dynamic> item, Map<String, dynamic> save});

const _week = 7 * 86400;

/// What Recall shows (design v4 revision 2): Today's picks with the reason they're back, this
/// week's saves by section, and what you snoozed. Same rule as backend/app/recall.py.
class RecallPlan {
  RecallPlan(this.due, this.week, this.upcoming);

  /// Still to try, saved over a week ago, not snoozed; oldest first.
  final List<Memory> due;

  /// Sections with two or more saves this week, most first.
  final List<(String section, List<Memory> saves)> week;

  /// Snoozed, soonest back first.
  final List<Memory> upcoming;

  List<Memory> get today => due.take(3).toList();
}

RecallPlan recallPlan(
    Iterable<Map<String, dynamic>> items, Iterable<Map<String, dynamic>> saves,
    {DateTime? now}) {
  final t = (now ?? DateTime.now()).millisecondsSinceEpoch / 1000;
  final byId = {for (final s in saves) s['save_id']: s};
  final due = <Memory>[], fresh = <String, List<Memory>>{}, later = <Memory>[];
  for (final item in items) {
    final save = byId[item['save_id']];
    final state = item['user_state'];
    if (save == null ||
        !sectionLabels.containsKey(item['section']) ||
        !(save['status'] == 'ready' || save['status'] == 'partial') ||
        (state != null && state != 'to_try')) {
      continue;
    }
    final at = (save['created_at'] ?? t) as num;
    final back = (item['recall_after'] as num?) ?? 0;
    final m = (item: item, save: save);
    if (back > t) {
      later.add(m);
    } else if (at <= t - _week) {
      due.add(m);
    } else {
      (fresh[item['section'] as String] ??= []).add(m);
    }
  }
  num at(Memory m) => (m.save['created_at'] ?? 0) as num;
  due.sort((a, b) => at(a).compareTo(at(b)));
  later.sort((a, b) => ((a.item['recall_after'] as num))
      .compareTo(b.item['recall_after'] as num));
  final week = [
    for (final e in fresh.entries)
      if (e.value.length >= 2) (e.key, e.value)
  ]..sort((a, b) => b.$2.length.compareTo(a.$2.length));
  return RecallPlan(due, week, later);
}

/// "3 days", "2 weeks", "3 months": how long ago something was saved.
String ago(num seconds) {
  final days = seconds ~/ 86400;
  if (days < 14) return '$days days';
  if (days < 60) return '${days ~/ 7} weeks';
  return '${days ~/ 30} months';
}

/// Not now: back in a week.
Future<void> snooze(Map<String, dynamic> item, {DateTime? now}) =>
    FirebaseFirestore.instance
        .doc(
            'spaces/${item['space_id']}/saves/${item['save_id']}/items/${item['item_id']}')
        .update({
      'recall_after': (now ?? DateTime.now())
              .add(const Duration(days: 7))
              .millisecondsSinceEpoch /
          1000
    });

/// Archive: out of Recall for good (still in Memories).
Future<void> archive(Map<String, dynamic> item) =>
    setItemState(item, 'archived');

const _weekLines = {
  'recipe': ('recipes', 'Pick one for tonight?'),
  'tools': ('tools', 'Try one today?'),
  'places': ('places', 'Plan a visit?'),
  'workout': ('workouts', 'Start one today?'),
  'fact_check': ('claims to check', 'Read one now?'),
  'ideas': ('ideas', 'Pick one to act on?'),
};

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

/// The Recall tab.
class RecallView extends StatefulWidget {
  const RecallView(
      {super.key,
      required this.plan,
      required this.onSection,
      this.padding = EdgeInsets.zero,
      this.now});
  final RecallPlan plan;
  final void Function(String section) onSection;
  final EdgeInsets padding;
  final DateTime? now;

  @override
  State<RecallView> createState() => _RecallViewState();
}

class _RecallViewState extends State<RecallView> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = RbColors.of(context);
    final plan = widget.plan;
    final now = (widget.now ?? DateTime.now()).millisecondsSinceEpoch / 1000;
    final today = _all ? plan.due : plan.today;
    Widget heading(String s) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 10),
        child: Text(s, style: t.titleLarge));
    return ListView(
      padding: widget.padding
          .add(const EdgeInsets.symmetric(horizontal: RbSpace.side)),
      children: [
        Text('Recall', style: t.headlineMedium),
        const SizedBox(height: 6),
        Text('Your brain brings things back when they matter.',
            style: t.bodyMedium?.copyWith(color: c.muted)),
        if (plan.due.isEmpty && plan.week.isEmpty && plan.upcoming.isEmpty)
          const EmptyState(
              icon: Icons.history,
              title: 'Nothing to bring back yet',
              body: 'Saves you haven’t tried after a week come back here.'),
        if (plan.due.isNotEmpty) ...[
          heading('Today'),
          for (final m in today)
            _RecallCard(
              memory: m,
              reason:
                  '${ago(now - ((m.save['created_at'] ?? now) as num))} ago you saved '
                  '${_what(m)}. You never tried it.',
            ),
          if (plan.due.length > plan.today.length)
            TextButton(
              onPressed: () => setState(() => _all = !_all),
              child: Text(
                  _all ? 'Show fewer' : 'Show all ${plan.due.length} waiting'),
            ),
        ],
        if (plan.week.isNotEmpty) ...[
          heading('This week'),
          for (final (section, saves) in plan.week)
            _WeekCard(
              section: section,
              saves: saves,
              onTap: () => widget.onSection(section),
            ),
        ],
        if (plan.upcoming.isNotEmpty) ...[
          heading('Upcoming'),
          for (final m in plan.upcoming) _UpcomingRow(memory: m),
        ],
      ],
    );
  }

  static String _what(Memory m) {
    final (title, _) = cardFace(m.item, m.save);
    final kind = (kindLabels[m.item['section']] ?? 'this').toLowerCase();
    return title.isEmpty ? 'a $kind' : 'a $kind: “$title”';
  }
}

/// A frame that opens its memory.
class _Thumb extends StatelessWidget {
  const _Thumb({required this.save, this.size = 56});
  final Map<String, dynamic> save;
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox.square(dimension: size, child: FrameImage(save: save)),
      );
}

void _open(BuildContext context, Map<String, dynamic> save) {
  final id = save['save_id'] as String?, space = save['space_id'] as String?;
  if (id == null || space == null) return;
  Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SaveScreen(spaceId: space, saveId: id, initial: save)));
}

class _RecallCard extends StatelessWidget {
  const _RecallCard({required this.memory, required this.reason});
  final Memory memory;
  final String reason;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = RbColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(RbSpace.cardRadius),
          border: Border.all(color: c.line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: Text(reason,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyMedium)),
            const SizedBox(width: 12),
            _Thumb(save: memory.save),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            PillButton(
                small: true,
                label: 'See it again',
                onPressed: () => _open(context, memory.save)),
            const Spacer(),
            TextButton(
                onPressed: () => snooze(memory.item),
                child: const Text('Not now')),
            TextButton(
                onPressed: () => archive(memory.item),
                child: Text('Archive', style: TextStyle(color: c.muted))),
          ]),
        ]),
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard(
      {required this.section, required this.saves, required this.onTap});
  final String section;
  final List<Memory> saves;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = RbColors.of(context);
    final (noun, ask) = _weekLines[section] ?? ('saves', 'Pick one?');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(RbSpace.cardRadius),
          border: Border.all(color: c.line),
        ),
        child: Row(children: [
          _Thumb(save: saves.first.save, size: 64),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('You saved ${saves.length} $noun this week. $ask',
                  style: t.bodyMedium),
              const SizedBox(height: 10),
              PillButton(
                  small: true,
                  label:
                      'View ${sectionLabels[section]?.toLowerCase() ?? noun}',
                  onPressed: onTap),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({required this.memory});
  final Memory memory;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final back = DateTime.fromMillisecondsSinceEpoch(
        ((memory.item['recall_after'] as num) * 1000).round());
    final (title, _) = cardFace(memory.item, memory.save);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Pressable(
        onTap: () => _open(context, memory.save),
        child: Row(children: [
          _Thumb(save: memory.save, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleSmall),
              Text(
                  'Back on ${_weekdays[back.weekday - 1]} ${back.day} ${_months[back.month - 1]}',
                  style: t.bodySmall),
            ]),
          ),
        ]),
      ),
    );
  }
}
