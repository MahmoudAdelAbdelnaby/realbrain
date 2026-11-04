import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/art/glyphs.dart';
import '../../core/art/hoopoe.dart';
import '../../core/art/mark.dart';
import '../../core/art/puzzle.dart';
import '../../core/categories.dart';
import '../../core/data/repo.dart';
import '../../core/format.dart';
import '../../core/theme/tokens.dart';
import '../../core/ui/art_frames.dart';
import '../../core/ui/components.dart';
import '../../core/ui/states.dart';
import '../shared/open.dart';
import 'progress.dart';
import 'share_card.dart';

/// My Brain (docs/DESIGN_V5.md §2.5): what you've discovered and actually used. The puzzle
/// fills one piece per finished discovery (hideable); levels, achievements, the month, insights
/// and the threads between your interests. Optional by design: nothing here nags.
class MyBrainScreen extends StatefulWidget {
  const MyBrainScreen(
      {super.key,
      required this.state,
      this.padding = EdgeInsets.zero,
      this.now});
  final BrainState state;
  final EdgeInsets padding;
  final DateTime? now;

  @override
  State<MyBrainScreen> createState() => _MyBrainScreenState();
}

class _MyBrainScreenState extends State<MyBrainScreen> {
  int _monthBack = 0;

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final c = RbColors.of(context);
    final t = Theme.of(context).textTheme;
    final now = widget.now ?? DateTime.now();
    final p = progressOf(s);
    final achievements = achievementsOf(s);
    final earned = achievements.where((a) => a.earned).length;
    final month = DateTime(now.year, now.month - _monthBack);
    final recap = recapOf(s, month);
    final insights = insightsOf(s, now: now);
    final threads = threadsOf(s);
    final side = const EdgeInsets.symmetric(horizontal: RbSpace.side);
    final width = MediaQuery.sizeOf(context).width;
    final puzzleSize = math.min(width - 2 * RbSpace.side, 340.0);
    final placedColors = [for (final d in p.inLevel) c.pigment(d.section)];

    if (!s.loaded) return const LoadingMark();

    return ListView(padding: widget.padding, children: [
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: RbSpace.column),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: side,
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MonoLabel('My Brain · level ${p.level}',
                            color: c.brandText),
                        const SizedBox(height: 10),
                        Semantics(
                            header: true,
                            child: Text(p.name,
                                style:
                                    RbType.serif(RbType.hero, color: c.text))),
                      ]),
                ),
                IconButton(
                  tooltip: 'Share your level',
                  onPressed: () => shareCard(
                      context,
                      ShareCard(
                        kicker: 'Level ${p.level}',
                        title: p.name,
                        line:
                            '${count(p.placed, 'discovery', 'discoveries')} actually used, from things I saved.',
                        art: PuzzleBrain(
                            count: p.levelSize,
                            placed: placedColors,
                            found: p.foundInLevel,
                            size: 230),
                        stats: [
                          ('${s.discoveries.length}', 'Saved'),
                          ('${p.placed}', 'Used'),
                          ('$earned', 'Medals')
                        ],
                      ),
                      'I’m a level ${p.level} ${p.name} on Realbrain: ${p.placed} things I saved, actually used.'),
                  icon: Icon(Icons.ios_share, color: c.text),
                ),
              ]),
            ),
            const SizedBox(height: 8),
            if (s.settings.puzzle) ...[
              Center(
                child: PuzzleBrain(
                    count: p.levelSize,
                    placed: placedColors,
                    found: p.foundInLevel,
                    size: puzzleSize,
                    fresh: p.placedInLevel > 0 ? p.placedInLevel - 1 : null),
              ),
              Padding(
                padding: side,
                child: Column(children: [
                  Text(
                      p.placedInLevel == 0
                          ? 'A new brain. Finish something you saved to place the first piece.'
                          : '${p.placedInLevel} of ${p.levelSize} pieces · ${p.toNext} to ${p.nextName}',
                      textAlign: TextAlign.center,
                      style: RbType.serif(17, color: c.text, italic: true)),
                  const SizedBox(height: 8),
                  Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 16,
                      runSpacing: 6,
                      children: [
                        _Legend(color: c.brand, label: 'Finished'),
                        _Legend(
                            color: Colors.transparent,
                            border: c.brand,
                            hatched: true,
                            label: 'Opened'),
                        _Legend(
                            color: Colors.transparent,
                            border: c.faint,
                            label: 'Waiting'),
                      ]),
                  TextButton(
                    onPressed: () =>
                        Repo.instance.patchSettings({'puzzle': false}),
                    child: Text('Hide the puzzle', style: t.bodySmall),
                  ),
                ]),
              ),
            ] else
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(RbSpace.side, 8, RbSpace.side, 0),
                child: Row(children: [
                  Expanded(
                    child: Text(
                        'The puzzle is hidden. Your progress still counts.',
                        style: t.bodySmall),
                  ),
                  TextButton(
                      onPressed: () =>
                          Repo.instance.patchSettings({'puzzle': true}),
                      child: const Text('Show it')),
                ]),
              ),
            const SizedBox(height: 18),
            Padding(
              padding: side,
              child: Row(children: [
                _Stat('${s.discoveries.length}', 'Saved'),
                _Stat('${p.placed + p.explored}', 'Explored'),
                _Stat('${p.placed}', 'Finished'),
              ]),
            ),
            if (p.level > 1) ...[
              const SizedBox(height: 22),
              Padding(
                padding: side,
                child: Wrap(spacing: 10, runSpacing: 8, children: [
                  for (var l = 1; l < p.level; l++)
                    Tooltip(
                      message: 'Level $l · ${levelName(l)} · complete',
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
                        decoration: BoxDecoration(
                            border: Border.all(color: c.line),
                            borderRadius: BorderRadius.circular(RbSpace.pill)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          BrainMark(size: 26, color: c.text),
                          const SizedBox(width: 4),
                          Text(levelName(l), style: t.labelMedium),
                        ]),
                      ),
                    ),
                ]),
              ),
            ],
            const SizedBox(height: 32),
            ShelfHeader(
                index: 'By category',
                title: 'What you use',
                caption: 'Finished of saved, per category.'),
            Padding(padding: side, child: _ByCategory(state: s)),
            const SizedBox(height: 32),
            ShelfHeader(
                index: '$earned of ${achievements.length}',
                title: 'Achievements'),
            Padding(
              padding: side,
              child: LayoutBuilder(builder: (context, box) {
                final cols = box.maxWidth > 520 ? 4 : 3;
                final w = (box.maxWidth - (cols - 1) * 10) / cols;
                final sorted = [...achievements]..sort(
                    (a, b) => (b.earned ? 1 : 0).compareTo(a.earned ? 1 : 0));
                return Wrap(spacing: 10, runSpacing: 14, children: [
                  for (final a in sorted)
                    SizedBox(width: w, child: _Medal(a: a)),
                ]);
              }),
            ),
            const SizedBox(height: 32),
            ShelfHeader(
              index: _monthBack == 0 ? 'This month' : 'Recap',
              title: recap.label,
              action: _monthBack == 0 ? 'Last month' : 'This month',
              onAction: () =>
                  setState(() => _monthBack = _monthBack == 0 ? 1 : 0),
            ),
            Padding(padding: side, child: _Recap(recap: recap)),
            if (insights.isNotEmpty) ...[
              const SizedBox(height: 32),
              const ShelfHeader(index: 'Noticed', title: 'Insights'),
              for (final i in insights)
                Padding(padding: side, child: _InsightCard(i: i)),
            ],
            if (threads.interests.length > 1) ...[
              const SizedBox(height: 32),
              const ShelfHeader(
                  index: 'Threads',
                  title: 'How your interests connect',
                  caption: 'Topics they share.'),
              Padding(padding: side, child: _Threads(model: threads)),
            ],
            if (s.discoveries.isEmpty)
              const EmptyState(
                  title: 'Your brain starts here',
                  body:
                      'Every discovery you finish places a piece. Save something, then use it.',
                  pose: HudhudPose.carrying),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    ]);
  }
}

class _Legend extends StatelessWidget {
  const _Legend(
      {required this.color,
      required this.label,
      this.border,
      this.hatched = false});
  final Color color;
  final Color? border;
  final String label;
  final bool hatched;

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 12,
          height: 12,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
              border: border == null ? null : Border.all(color: border!)),
          child: hatched ? CustomPaint(painter: _Hatch(border ?? color)) : null,
        ),
        const SizedBox(width: 6),
        MonoLabel(label, size: 10),
      ]);
}

class _Hatch extends CustomPainter {
  _Hatch(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var x = -size.height; x < size.width; x += 3) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), p);
    }
  }

  @override
  bool shouldRepaint(_Hatch old) => old.color != color;
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);
  final String value, label;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
            border: Border(top: BorderSide(color: c.text, width: 1.2))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: RbType.serif(30, color: c.text)),
          const SizedBox(height: 2),
          MonoLabel(label),
        ]),
      ),
    );
  }
}

class _ByCategory extends StatelessWidget {
  const _ByCategory({required this.state});
  final BrainState state;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final rows = [
      for (final cat in categories) (cat, state.inCategory(cat.id)),
    ].where((r) => r.$2.isNotEmpty).toList()
      ..sort((a, b) => b.$2.length.compareTo(a.$2.length));
    if (rows.isEmpty) return const SizedBox.shrink();
    final most = rows.first.$2.length;
    return Column(children: [
      for (final (cat, list) in rows)
        Pressable(
          onTap: () => openCategory(context, cat.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(children: [
              Glyph(cat.id, size: 20, color: c.pigment(cat.id)),
              const SizedBox(width: 10),
              SizedBox(
                  width: 96,
                  child: Text(cat.name,
                      style: Theme.of(context).textTheme.labelMedium)),
              Expanded(
                child: LayoutBuilder(builder: (context, box) {
                  final total = box.maxWidth * list.length / most;
                  final done = list.where((d) => d.isDone).length;
                  return Stack(children: [
                    Container(
                        height: 10,
                        width: total,
                        decoration: BoxDecoration(
                            color: c.pigment(cat.id).withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(2))),
                    Container(
                        height: 10,
                        width: total * done / list.length,
                        decoration: BoxDecoration(
                            color: c.pigment(cat.id),
                            borderRadius: BorderRadius.circular(2))),
                  ]);
                }),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 44,
                child: Text(
                    '${list.where((d) => d.isDone).length}/${list.length}',
                    textAlign: TextAlign.end,
                    style: RbType.monoNumber(12, color: c.muted)),
              ),
            ]),
          ),
        ),
    ]);
  }
}

/// An achievement as an engraved medal: the glyph in a double ring; saffron when earned.
class _Medal extends StatelessWidget {
  const _Medal({required this.a});
  final Achievement a;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final color = a.earned ? c.brandText : c.faint;
    return Semantics(
      button: true,
      label:
          '${a.title}. ${a.body} ${a.earned ? 'Earned' : '${a.current} of ${a.target}'}',
      excludeSemantics: true,
      child: Pressable(
        onTap: () => _open(context),
        child: Column(children: [
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(alignment: Alignment.center, children: [
              CustomPaint(
                  size: const Size(72, 72),
                  painter: _MedalRing(
                      color: color,
                      fraction: a.fraction,
                      earned: a.earned,
                      track: c.line)),
              Glyph(a.glyph,
                  size: 28, color: color, weight: a.earned ? 1.6 : 1.3),
            ]),
          ),
          const SizedBox(height: 6),
          Text(a.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: RbType.serif(14,
                  color: a.earned ? c.text : c.muted, height: 1.15)),
          const SizedBox(height: 2),
          MonoLabel(
              a.earned
                  ? (a.earnedAt == null
                      ? 'Earned'
                      : short(months[fromEpoch(a.earnedAt!).month - 1]))
                  : '${math.min(a.current, a.target)}/${a.target}',
              size: 9.5),
        ]),
      ),
    );
  }

  void _open(BuildContext context) {
    final c = RbColors.of(context);
    showRbSheet<void>(context,
        title: a.title,
        kicker: a.earned ? 'Achievement' : 'In progress',
        builder: (sheet) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: RbSpace.side),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.body, style: Theme.of(sheet).textTheme.bodyLarge),
                    const SizedBox(height: 8),
                    Text(
                        a.earned
                            ? (a.earnedAt == null
                                ? 'Earned.'
                                : 'Earned ${dayMonth(fromEpoch(a.earnedAt!))} ${fromEpoch(a.earnedAt!).year}.')
                            : '${math.min(a.current, a.target)} of ${a.target} so far.',
                        style: Theme.of(sheet).textTheme.bodySmall),
                    const SizedBox(height: 16),
                    if (a.earned)
                      RbButton('Share it',
                          icon: Icons.ios_share,
                          onPressed: () => shareCard(
                              sheet,
                              ShareCard(
                                kicker: 'Achievement',
                                title: a.title,
                                line: a.body,
                                art: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      CustomPaint(
                                          size: const Size(170, 170),
                                          painter: _MedalRing(
                                              color: RbColors.light.brandText,
                                              fraction: 1,
                                              earned: true,
                                              track: c.line)),
                                      Glyph(a.glyph,
                                          size: 70,
                                          color: RbColors.light.brandText,
                                          weight: 1.3),
                                    ]),
                              ),
                              'Achievement on Realbrain: ${a.title}. ${a.body}')),
                  ]),
            ));
  }
}

class _MedalRing extends CustomPainter {
  _MedalRing(
      {required this.color,
      required this.fraction,
      required this.earned,
      required this.track});
  final Color color, track;
  final double fraction;
  final bool earned;

  @override
  void paint(Canvas canvas, Size size) {
    final ctr = size.center(Offset.zero);
    final r = size.width / 2 - 3;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(
        ctr,
        r,
        p
          ..color = track
          ..strokeWidth = 2);
    if (fraction > 0) {
      canvas.drawArc(
          Rect.fromCircle(center: ctr, radius: r),
          -math.pi / 2,
          2 * math.pi * fraction,
          false,
          p
            ..color = color
            ..strokeWidth = earned ? 2.6 : 2);
    }
    // The inner engraved ring with its notches.
    canvas.drawCircle(
        ctr,
        r - 6,
        p
          ..color = color.withValues(alpha: earned ? 0.7 : 0.35)
          ..strokeWidth = 0.8);
    if (earned) {
      for (var i = 0; i < 24; i++) {
        final a = i * math.pi / 12;
        final o = Offset(math.cos(a), math.sin(a));
        canvas.drawLine(
            ctr + o * (r - 9), ctr + o * (r - 7.4), p..strokeWidth = 0.8);
      }
    }
  }

  @override
  bool shouldRepaint(_MedalRing old) =>
      old.color != color || old.fraction != fraction || old.earned != earned;
}

class _Recap extends StatelessWidget {
  const _Recap({required this.recap});
  final Recap recap;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final t = Theme.of(context).textTheme;
    if (recap.isEmpty) {
      return Text(
          'Nothing saved or finished in ${months[recap.month.month - 1]}.',
          style: t.bodySmall);
    }
    final top = recap.topCategory;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(RbSpace.cardRadius),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _Stat('${recap.saved.length}', 'Saved'),
          _Stat('${recap.done.length}', 'Finished'),
          _Stat('${recap.explored}', 'Opened'),
        ]),
        const SizedBox(height: 10),
        if (top != null)
          Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'Mostly '),
                TextSpan(
                    text: categoryOf(top).name.toLowerCase(),
                    style: TextStyle(
                        color: c.pigment(top), fontWeight: FontWeight.w600)),
                if (recap.busiestDay != null)
                  TextSpan(text: ', and mostly on ${recap.busiestDay}s.')
                else
                  const TextSpan(text: '.'),
              ]),
              style: RbType.serif(17, color: c.text, italic: true)),
        if (recap.highlights.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(children: [
            for (final (i, d) in recap.highlights.indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: Pressable(
                  onTap: () =>
                      openDiscovery(context, d, within: recap.highlights),
                  child: AspectRatio(
                      aspectRatio: 4 / 5,
                      child: DiscoveryArt(d,
                          radius: RbSpace.photoRadius, typeset: false)),
                ),
              ),
            ],
            for (var i = recap.highlights.length; i < 3; i++) ...[
              const SizedBox(width: 8),
              const Expanded(child: SizedBox())
            ],
          ]),
        ],
        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: RbButton.secondary('Share the month',
              small: true,
              icon: Icons.ios_share,
              onPressed: () => shareCard(
                  context,
                  ShareCard(
                    kicker: recap.label,
                    title:
                        '${recap.done.length} used, ${recap.saved.length} saved',
                    line: top == null
                        ? 'A month of discoveries.'
                        : 'Mostly ${categoryOf(top).name.toLowerCase()}.',
                    art: Row(mainAxisSize: MainAxisSize.min, children: [
                      for (final d in recap.highlights)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: SizedBox(
                              width: 96,
                              height: 120,
                              child: DiscoveryArt(d, radius: 4)),
                        ),
                    ]),
                    stats: [
                      ('${recap.saved.length}', 'Saved'),
                      ('${recap.done.length}', 'Finished'),
                      ('${recap.explored}', 'Opened')
                    ],
                  ),
                  '${recap.label} on Realbrain: ${recap.done.length} things I saved, actually used.')),
        ),
      ]),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.i});
  final Insight i;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final hue = c.pigment(i.section);
    return Pressable(
      onTap: () => openCategory(context, i.section),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: c.line),
          borderRadius: BorderRadius.circular(RbSpace.cardRadius),
        ),
        child: Row(children: [
          Glyph(i.section, size: 26, color: hue),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(i.text, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              Row(children: [
                for (var k = 0; k < i.of; k++)
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsetsDirectional.only(end: 5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: k < i.filled ? hue : null,
                      border: Border.all(color: k < i.filled ? hue : c.line),
                    ),
                  ),
                // All the room the dots leave (a Spacer would take half of it).
                Expanded(
                    child: Text(i.action,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(color: c.muted))),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Threads extends StatelessWidget {
  const _Threads({required this.model});
  final ({List<Interest> interests, List<Thread> threads}) model;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final t = Theme.of(context).textTheme;
    if (model.threads.isEmpty) {
      return Text(
          'No shared topics yet. They appear as you save across categories.',
          style: t.bodySmall);
    }
    return Column(children: [
      for (final th in model.threads.take(5))
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration:
              BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Glyph(th.a, size: 20, color: c.pigment(th.a)),
            SizedBox(
              width: 28,
              child: Center(
                  child: Container(
                      height: 1,
                      width: 18,
                      margin: const EdgeInsets.only(top: 10),
                      color: c.faint)),
            ),
            Glyph(th.b, size: 20, color: c.pigment(th.b)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '${categoryOf(th.a).name} and ${categoryOf(th.b).name.toLowerCase()}',
                        style: t.titleSmall),
                    const SizedBox(height: 2),
                    Text(th.shared.take(4).join(' · '),
                        style: RbType.serif(15, color: c.muted, italic: true)),
                  ]),
            ),
          ]),
        ),
    ]);
  }
}
