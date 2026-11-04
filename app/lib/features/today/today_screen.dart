import 'package:flutter/material.dart';

import '../../core/art/glyphs.dart';
import '../../core/art/hoopoe.dart';
import '../../core/art/mark.dart';
import '../../core/art/puzzle.dart';
import '../../core/data/repo.dart';
import '../../core/format.dart';
import '../../core/theme/tokens.dart';
import '../../core/ui/art_frames.dart';
import '../../core/ui/components.dart';
import '../../core/ui/states.dart';
import '../brain/progress.dart';
import '../item/actions.dart';
import '../shared/list_screen.dart';
import '../shared/open.dart';
import '../shared/tiles.dart';
import 'plan.dart';

/// Today (docs/DESIGN_V5.md §2.5): one thing for right now, said why, then shelves with
/// different shapes so the page has rhythm, not a wall of equal cards.
class TodayScreen extends StatefulWidget {
  const TodayScreen(
      {super.key,
      required this.state,
      required this.onTab,
      required this.onCapture,
      required this.onAccount,
      this.now,
      this.padding = EdgeInsets.zero});
  final BrainState state;
  final ValueChanged<int> onTab;
  final VoidCallback onCapture, onAccount;
  final DateTime? now;
  final EdgeInsets padding;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  int _skip = 0; // "Another" steps through the ranking

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final now = widget.now ?? DateTime.now();
    final c = RbColors.of(context);
    final weekend = weekendFor(Localizations.maybeLocaleOf(context));
    final picks = rankPicks(s, now: now, weekend: weekend);
    final pick = picks.isEmpty ? null : picks[_skip % picks.length];
    final shelves = shelvesOf(s, now: now, pick: pick?.d);
    final open = s.discoveries.where((d) => d.isOpen).length;
    final hour = now.hour;
    final hello = hour < 5
        ? 'Still up'
        : hour < 12
            ? 'Good morning'
            : hour < 18
                ? 'Good afternoon'
                : 'Good evening';
    final name = firstName(s.userName);
    final side = const EdgeInsets.symmetric(horizontal: RbSpace.side);

    final children = <Widget>[
      // Masthead.
      Padding(
        padding: side,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              MonoLabel('${dayMonth(now)} · ${slotLabel(now)}', color: c.faint),
              const SizedBox(height: 10),
              Semantics(
                header: true,
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: name.isEmpty ? '$hello.' : '$hello, '),
                    if (name.isNotEmpty)
                      TextSpan(
                          text: '$name.',
                          style: RbType.serif(RbType.hero,
                              color: c.text, italic: true)),
                  ]),
                  style: RbType.serif(RbType.hero, color: c.text),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                  s.discoveries.isEmpty
                      ? 'Save something you find and Realbrain turns it into something you can use.'
                      : open == 0
                          ? 'Everything you saved is done. Time to discover something new.'
                          : '${count(open, 'discovery', 'discoveries')} wait for you. Here’s one for right now.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: c.muted)),
            ]),
          ),
          const SizedBox(width: 12),
          _AccountButton(state: s, onTap: widget.onAccount),
        ]),
      ),
      if (s.processing.isNotEmpty || s.attention.isNotEmpty) ...[
        const SizedBox(height: 16),
        Padding(padding: side, child: _ArrivingStrip(state: s)),
      ],
      if (s.error != null) ...[
        const SizedBox(height: 12),
        ErrorNote(
            title: 'Can’t reach your archive',
            message: 'Showing what’s on this phone. Pull down to try again.',
            onRetry: () => Repo.instance.refresh()),
      ],
      const SizedBox(height: 24),
    ];

    if (!s.loaded) {
      children.addAll([
        const LoadingMark(),
        for (var i = 0; i < 3; i++) const SkeletonRow(),
      ]);
    } else if (s.discoveries.isEmpty) {
      children.add(EmptyState(
        title: 'Your archive is empty',
        body:
            'Share a reel to Realbrain from TikTok, Instagram or YouTube, or paste a link. '
            'It comes back as a recipe, a place, a tool or whatever it really is.',
        action: 'Save something',
        onAction: widget.onCapture,
        pose: HudhudPose.perched,
        plateCaption: 'Pl. 1 · Hudhud, the scout',
      ));
    } else {
      if (pick != null) {
        children.add(Padding(
          padding: side,
          child: _PickCard(
            pick: pick,
            hasMore: picks.length > 1,
            onAnother: () => setState(() => _skip++),
            onNotNow: () {
              final tomorrow = DateTime(now.year, now.month, now.day + 1, 5);
              Repo.instance.snooze(pick.d, tomorrow);
              toast(context, 'Hidden until tomorrow',
                  action: 'Undo',
                  onAction: () => Repo.instance.snooze(pick.d, now));
            },
          ),
        ));
        children.add(const SizedBox(height: 36));
      }
      var n = 0;
      String idx() => (++n).toString().padLeft(2, '0');
      if (shelves.leftOff.isNotEmpty) {
        children.addAll([
          ShelfHeader(
              index: idx(),
              title: 'Left off',
              caption: 'You opened these. Pick one back up.'),
          _BookmarkShelf(list: shelves.leftOff, uid: s.uid, now: now),
          const SizedBox(height: 32),
        ]);
      }
      if (shelves.notTried.isNotEmpty) {
        final shown = varied(shelves.notTried, 4);
        children.addAll([
          ShelfHeader(
              index: idx(),
              title: 'Not tried yet',
              action: shelves.notTried.length > 4
                  ? 'All ${shelves.notTried.length}'
                  : null,
              onAction: () =>
                  _openList(context, 'Not tried yet', shelves.notTried)),
          Padding(
              padding: side,
              child: _Grid(list: shown, within: shelves.notTried)),
          const SizedBox(height: 32),
        ]);
      }
      if (shelves.fromGroups.isNotEmpty) {
        children.addAll([
          ShelfHeader(
              index: idx(),
              title: 'From your groups',
              action: 'Groups',
              onAction: () => widget.onTab(2)),
          for (final d in shelves.fromGroups.take(3))
            _GroupShare(d: d, state: s, within: shelves.fromGroups),
          const SizedBox(height: 32),
        ]);
      }
      children.addAll([
        ShelfHeader(
            index: idx(),
            title: 'Recently saved',
            action: 'Library',
            onAction: () => widget.onTab(1)),
        Padding(
          padding: side,
          child: Column(children: [
            for (final d in shelves.recent)
              CatalogueRow(d, within: shelves.recent),
          ]),
        ),
        const SizedBox(height: 32),
      ]);
      if (shelves.revisit.due.isNotEmpty) {
        children.addAll([
          ShelfHeader(
              index: idx(),
              title: 'Worth revisiting',
              action: shelves.revisit.due.length > 1
                  ? 'All ${shelves.revisit.due.length}'
                  : null,
              onAction: () => _openRevisit(context, shelves.revisit)),
          Padding(
              padding: side,
              child: RevisitCard(d: shelves.revisit.due.first, now: now)),
          const SizedBox(height: 32),
        ]);
      }
      if (s.settings.puzzle) {
        children.add(Padding(
            padding: side,
            child: _BrainTeaser(state: s, onTap: () => widget.onTab(3))));
      }
    }
    children.add(const SizedBox(height: 24));

    return RefreshIndicator(
      color: c.brand,
      onRefresh: () => Repo.instance.refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: widget.padding,
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: RbSpace.column),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children),
            ),
          ),
        ],
      ),
    );
  }

  void _openList(BuildContext context, String title, List<Discovery> list) =>
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => DiscoveryListScreen(
              title: title, keys: [for (final d in list) d.key])));

  void _openRevisit(BuildContext context, RecallPlan plan) =>
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const RevisitScreen()));
}

String slotLabel(DateTime t) => switch (t.hour) {
      >= 5 && < 12 => 'Morning',
      >= 12 && < 18 => 'Afternoon',
      >= 18 && < 22 => 'Evening',
      _ => 'Night',
    };

class _AccountButton extends StatelessWidget {
  const _AccountButton({required this.state, required this.onTap});
  final BrainState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Settings and account',
        excludeSemantics: true,
        child: Pressable(
          onTap: onTap,
          child: SizedBox.square(
            dimension: RbSpace.touch,
            child: Center(
              child: state.photoUrl != null
                  ? CircleAvatar(
                      radius: 18,
                      backgroundImage: NetworkImage(state.photoUrl!))
                  : Avatar(state.userName.isEmpty ? 'You' : state.userName,
                      size: 36),
            ),
          ),
        ),
      );
}

class _ArrivingStrip extends StatelessWidget {
  const _ArrivingStrip({required this.state});
  final BrainState state;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final busy = state.processing.length, needs = state.attention.length;
    return Pressable(
      onTap: () => openArriving(context),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 10, 10),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.line),
          borderRadius: BorderRadius.circular(RbSpace.cardRadius),
        ),
        child: Row(children: [
          BrainMark(
              size: 30,
              motion: busy > 0 ? MarkMotion.thinking : MarkMotion.still),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
                [
                  if (busy > 0)
                    '${busy == 1 ? 'One save' : '$busy saves'} being understood',
                  if (needs > 0) '$needs need${needs == 1 ? 's' : ''} you',
                ].join(' · '),
                style: Theme.of(context).textTheme.labelLarge),
          ),
          if (needs > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: c.brand,
                  borderRadius: BorderRadius.circular(RbSpace.pill)),
              child: Text('$needs',
                  style: RbType.monoNumber(12, color: c.onBrand)),
            ),
          Icon(Icons.chevron_right, color: c.faint),
        ]),
      ),
    );
  }
}

/// The pick: a large plate with the frame, then why it's picked and what to do.
class _PickCard extends StatelessWidget {
  const _PickCard(
      {required this.pick,
      required this.hasMore,
      required this.onAnother,
      required this.onNotNow});
  final Pick pick;
  final bool hasMore;
  final VoidCallback onAnother, onNotNow;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final d = pick.d;
    return Semantics(
      container: true,
      label: 'Picked for now: ${d.title}. ${pick.reason}',
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(RbSpace.cardRadius + 2),
          border: Border.all(color: c.line),
        ),
        clipBehavior: Clip.antiAlias,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Pressable(
            onTap: () => openDiscovery(context, d),
            child: AspectRatio(
              aspectRatio: 1.12,
              child: Stack(fit: StackFit.expand, children: [
                Hero(
                    tag: 'art-${d.key}-pick',
                    child: DiscoveryArt(d, typeset: false)),
                if (d.frame != null)
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.45, 1],
                        colors: [Color(0x00000000), Color(0xCC0B0A09)],
                      ),
                    ),
                  ),
                PositionedDirectional(
                  start: 16,
                  end: 16,
                  bottom: 14,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CatalogLabel(d, onPhoto: d.frame != null),
                        const SizedBox(height: 6),
                        Text(d.title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: RbType.serif(27,
                                color:
                                    d.frame != null ? Colors.white : c.text)),
                      ]),
                ),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Glyph(Glyphs.piece,
                    size: 14, color: c.brand, fill: c.brand, weight: 1.2),
                const SizedBox(width: 6),
                Flexible(
                    child: MonoLabel('Picked for ${pick.kicker}',
                        color: c.brandText)),
              ]),
              const SizedBox(height: 6),
              Text(pick.reason,
                  style: RbType.serif(18,
                      color: c.muted, italic: true, height: 1.3)),
              if (d.detail.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(d.detail, style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: RbButton(d.action,
                      expand: true, onPressed: () => primaryAction(context, d)),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Not now',
                  onPressed: onNotNow,
                  icon: Icon(Icons.schedule, color: c.muted),
                ),
                if (hasMore)
                  IconButton(
                    tooltip: 'Show another',
                    onPressed: onAnother,
                    icon: Icon(Icons.shuffle, color: c.muted),
                  ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Left off: bookmark cards in a row, each with a saffron ribbon.
class _BookmarkShelf extends StatelessWidget {
  const _BookmarkShelf(
      {required this.list, required this.uid, required this.now});
  final List<Discovery> list;
  final String uid;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    return SizedBox(
      height: 214,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: RbSpace.side),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final d = list[i];
          return Semantics(
            button: true,
            label: '${d.title}, opened ${ago(d.seenBy(uid)!, now: now)}',
            excludeSemantics: true,
            child: Pressable(
              onTap: () => openDiscovery(context, d, within: list),
              child: SizedBox(
                width: 150,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 112,
                        child: Stack(fit: StackFit.expand, children: [
                          DiscoveryArt(d,
                              radius: RbSpace.photoRadius, typeset: false),
                          PositionedDirectional(
                            top: 0,
                            end: 12,
                            child: CustomPaint(
                                size: const Size(14, 26),
                                painter: _Ribbon(c.brand)),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 8),
                      CatalogLabel(d, source: false, number: false),
                      const SizedBox(height: 3),
                      Text(d.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              RbType.serif(15.5, color: c.text, height: 1.2)),
                      const SizedBox(height: 3),
                      Text('Opened ${ago(d.seenBy(uid)!, now: now)}',
                          style: Theme.of(context).textTheme.bodySmall),
                    ]),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Ribbon extends CustomPainter {
  _Ribbon(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final p = Path()
      ..moveTo(0, 0)
      ..lineTo(s.width, 0)
      ..lineTo(s.width, s.height)
      ..lineTo(s.width / 2, s.height - 6)
      ..lineTo(0, s.height)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_Ribbon old) => old.color != color;
}

class _Grid extends StatelessWidget {
  const _Grid({required this.list, required this.within});
  final List<Discovery> list, within;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < list.length; i += 2) {
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: DiscoveryTile(list[i], within: within)),
          const SizedBox(width: 14),
          Expanded(
              child: i + 1 < list.length
                  ? DiscoveryTile(list[i + 1], within: within)
                  : const SizedBox()),
        ]),
      ));
    }
    return Column(children: rows);
  }
}

class _GroupShare extends StatelessWidget {
  const _GroupShare(
      {required this.d, required this.state, required this.within});
  final Discovery d;
  final BrainState state;
  final List<Discovery> within;

  @override
  Widget build(BuildContext context) {
    final g = state.group(d.spaceId);
    final who = g?.nameOf(d.addedBy ?? '') ?? 'Someone';
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(RbSpace.side, 4, RbSpace.side, 0),
          child: Row(children: [
            Avatar(who, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: who, style: t.labelMedium),
                    TextSpan(
                        text:
                            ' shared with ${g?.name ?? 'a group'} · ${ago(d.createdAt)}',
                        style: t.bodySmall),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
        ),
        DiscoveryRow(d, within: within),
      ]),
    );
  }
}

/// Worth revisiting: why it's back, and Not now / Archive right there.
class RevisitCard extends StatelessWidget {
  const RevisitCard({super.key, required this.d, required this.now});
  final Discovery d;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final t = epoch(now);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(RbSpace.cardRadius),
        border: Border.all(color: c.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              MonoLabel('Saved ${span(t - d.createdAt)} ago · never tried',
                  color: c.brandText),
              const SizedBox(height: 6),
              Text(d.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: RbType.serif(20, color: c.text)),
              if (d.goodFor != null) ...[
                const SizedBox(height: 4),
                Text('“${d.note ?? d.goodFor}”',
                    maxLines: 2,
                    style: RbType.serif(15, color: c.muted, italic: true)),
              ],
            ]),
          ),
          const SizedBox(width: 12),
          SizedBox(
              width: 72,
              height: 90,
              child:
                  DiscoveryArt(d, radius: RbSpace.photoRadius, typeset: false)),
        ]),
        const SizedBox(height: 12),
        Wrap(
            spacing: 4,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              RbButton('See it again',
                  small: true, onPressed: () => openDiscovery(context, d)),
              RbButton.quiet('Not now', small: true, onPressed: () {
                Repo.instance.snooze(d, now.add(const Duration(days: 7)));
                toast(context, 'Back in a week');
              }),
              RbButton.quiet('Archive', small: true, onPressed: () {
                Repo.instance.archive(d);
                toast(context, 'Archived. Still in your library.');
              }),
            ]),
      ]),
    );
  }
}

/// A small window onto My Brain at the foot of Today.
class _BrainTeaser extends StatelessWidget {
  const _BrainTeaser({required this.state, required this.onTap});
  final BrainState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final p = progressOf(state);
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: c.line),
          borderRadius: BorderRadius.circular(RbSpace.cardRadius),
        ),
        child: Row(children: [
          PuzzleBrain(
              count: p.levelSize,
              placed: [for (final d in p.inLevel) c.pigment(d.section)],
              found: p.foundInLevel,
              size: 76),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              MonoLabel('My Brain · level ${p.level}', color: c.brandText),
              const SizedBox(height: 4),
              Text(p.name, style: RbType.serif(20, color: c.text)),
              const SizedBox(height: 2),
              Text(
                  p.toNext == 1
                      ? 'One more piece to the next brain.'
                      : '${p.toNext} pieces to the next brain.',
                  style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
          Icon(Icons.chevron_right, color: c.faint),
        ]),
      ),
    );
  }
}

/// Every discovery Recall brought back, with Not now and Archive on each.
class RevisitScreen extends StatelessWidget {
  const RevisitScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BrainState>(
      valueListenable: Repo.instance.state,
      builder: (context, s, _) {
        final now = DateTime.now();
        final plan = recallPlan(s, now: now);
        return Scaffold(
          appBar: AppBar(title: const Text('Worth revisiting')),
          body: plan.due.isEmpty && plan.upcoming.isEmpty
              ? const EmptyState(
                  title: 'Nothing waiting',
                  body:
                      'Things you save and don’t try within a week come back here.',
                  pose: HudhudPose.perched)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                      RbSpace.side, 8, RbSpace.side, 32),
                  children: [
                    for (final d in plan.due)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: RevisitCard(d: d, now: now)),
                    if (plan.upcoming.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Rule(label: 'Coming back later'),
                      const SizedBox(height: 4),
                      for (final d in plan.upcoming)
                        DiscoveryRow(d,
                            note:
                                'Back ${dayMonth(fromEpoch(d.recallAfter!))}'),
                    ],
                  ],
                ),
        );
      },
    );
  }
}
