import 'package:flutter/material.dart';

import '../../core/surface.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets.dart';
import '../feed/feed_screen.dart' show sectionLabels;

/// One insight (design v4 revision 2 "Brain Boosts"): a line, a quiet dot row and one action.
typedef Boost = ({
  String section,
  String text,
  String? delta,
  int filled,
  int dots,
  String action
});

/// The brain that grows, per section, and what you did with it.
const _nouns = {
  'recipe': ('cooking', 'recipes', 'cooked'),
  'tools': ('tools', 'tools', 'tried'),
  'places': ('places', 'places', 'visited'),
  'workout': ('fitness', 'workouts', 'did'),
  'fact_check': ('learning', 'claims', 'read'),
  'ideas': ('ideas', 'ideas', 'acted on'),
};

/// At most four calm insights from what you saved and did: what grew this week, what you saved
/// but rarely used, and what has waited a month. No streaks or badges.
List<Boost> boostsOf(
    Iterable<Map<String, dynamic>> items, Iterable<Map<String, dynamic>> saves,
    {DateTime? now}) {
  final t = (now ?? DateTime.now()).millisecondsSinceEpoch / 1000;
  final at = {
    for (final s in saves) s['save_id']: (s['created_at'] ?? t) as num
  };
  final per = <String, List<Map<String, dynamic>>>{};
  for (final i in items) {
    final s = i['section'] as String?;
    if (_nouns.containsKey(s) && at.containsKey(i['save_id'])) {
      (per[s!] ??= []).add(i);
    }
  }
  bool open(Map<String, dynamic> i) =>
      i['user_state'] == null || i['user_state'] == 'to_try';
  final grew = <Boost>[], unused = <Boost>[], waited = <Boost>[];
  for (final MapEntry(key: s, value: list) in per.entries) {
    final (brain, plural, verb) = _nouns[s]!;
    final week = list.where((i) => at[i['save_id']]! > t - 7 * 86400).length;
    if (week > 0) {
      grew.add((
        section: s,
        text: 'Your $brain brain grew this week',
        delta: '+$week',
        filled: week.clamp(0, 5),
        dots: 5,
        action: 'View ${sectionLabels[s]!.toLowerCase()}'
      ));
    }
    final used =
        list.where((i) => !open(i) && i['user_state'] != 'archived').length;
    if (list.length >= 5 && used * 3 < list.length) {
      unused.add((
        section: s,
        text: 'You saved ${list.length} $plural but $verb only $used',
        delta: null,
        filled: (used * 5 / list.length).round(),
        dots: 5,
        action: 'Pick one'
      ));
    }
    final waiting = list.where(open).toList();
    final newest = waiting.isEmpty
        ? null
        : waiting.map((i) => at[i['save_id']]!).reduce((a, b) => a > b ? a : b);
    if (waiting.length >= 2 && newest! < t - 30 * 86400) {
      waited.add((
        section: s,
        text: 'Your $plural have waited over 30 days',
        delta: null,
        filled: 0,
        dots: 5,
        action: 'Explore now'
      ));
    }
  }
  return [...grew, ...unused, ...waited].take(4).toList();
}

/// The Brain Boosts screen, opened from Home.
class BrainBoostsScreen extends StatelessWidget {
  const BrainBoostsScreen(
      {super.key, required this.boosts, required this.onSection});
  final List<Boost> boosts;
  final void Function(String section) onSection;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = RbColors.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(RbSpace.side, 0, RbSpace.side, 24),
        children: [
          Text('Brain Boosts', style: t.headlineMedium),
          const SizedBox(height: 6),
          Text('Small reminders. Big progress.',
              style: t.bodyMedium?.copyWith(color: c.muted)),
          const SizedBox(height: 20),
          if (boosts.isEmpty)
            const EmptyState(
                icon: Icons.insights_outlined,
                title: 'Nothing to tell you yet',
                body: 'Insights appear as you save and try things.'),
          for (final b in boosts)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: BoostCard(boost: b, onTap: () => onSection(b.section)),
            ),
        ],
      ),
    );
  }
}

class BoostCard extends StatelessWidget {
  const BoostCard({super.key, required this.boost, required this.onTap});
  final Boost boost;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = RbColors.of(context);
    final hue = c.section(boost.section);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(RbSpace.cardRadius),
        border: Border.all(color: c.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(boost.text, style: t.titleSmall)),
          if (boost.delta != null)
            Text(boost.delta!, style: t.labelMedium?.copyWith(color: hue)),
        ]),
        const SizedBox(height: 12),
        // Quiet progress: filled dots in the section's accent, the rest outlined.
        Semantics(
          label: '${boost.filled} of ${boost.dots}',
          child: Row(children: [
            for (var i = 0; i < boost.dots; i++)
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsetsDirectional.only(end: 6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < boost.filled ? hue : null,
                  border: Border.all(color: i < boost.filled ? hue : c.line),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        PillButton(small: true, label: boost.action, onPressed: onTap),
      ]),
    );
  }
}
