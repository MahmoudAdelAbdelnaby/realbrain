import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/art/mark.dart';
import '../../core/data/repo.dart';
import '../../core/format.dart';
import '../../core/theme/theme.dart';
import '../../core/ui/art_frames.dart';
import '../../core/ui/components.dart';
import '../item/actions.dart';
import '../item/bodies.dart' show VerdictPill, verdictLabels;
import '../shared/open.dart';
import '../shared/tiles.dart';

/// One extracted moment in a reel: its frame and what it says.
typedef Moment = ({
  double t,
  String? frame,
  String title,
  String? detail,
  String? verdict
});

/// Every moment in a discovery, in reel order: steps, exercises, claims, tools, places, titles,
/// products.
List<Moment> momentsOf(Discovery d) {
  final out = <Moment>[];
  Moment m(Json e, String title, String? detail, [String? verdict]) => (
        t: (e['t'] as num?)?.toDouble() ?? 0,
        frame: e['frame'] as String?,
        title: title,
        detail: detail == null || detail.isEmpty ? null : detail,
        verdict: verdict,
      );
  final data = d.data;
  switch (d.section) {
    case 'recipe':
      for (final s in listOf(data['steps'])) {
        final timer = (s['timer_s'] as num?)?.toInt();
        out.add(m(
            s, '${s['text']}', timer == null ? null : 'Timer ${mmss(timer)}'));
      }
    case 'workout':
      for (final e in listOf(data['exercises'])) {
        out.add(m(
            e,
            '${e['name']}',
            [
              if (e['sets'] != null) '${e['sets']} sets',
              if (e['reps'] != null) '${e['reps']} reps',
              if (e['duration_s'] != null) '${e['duration_s']} s',
              if (e['cues'] != null) '${e['cues']}',
            ].join(' · ')));
      }
    case 'fact_check':
      for (final c in listOf(data['claims'])) {
        out.add(m(c, '“${c['text']}”', c['correction'] as String?,
            c['verdict'] as String? ?? 'unverifiable'));
      }
    case 'tools':
      for (final x in listOf(data['items'])) {
        out.add(m(x, '${x['name']}',
            x['use_shown'] as String? ?? x['snippet'] as String?));
      }
    case 'places':
      for (final p in listOf(data['items'])) {
        out.add(m(p, '${p['name']}',
            [p['why_go'], p['what_to_order']].whereType<String>().join(' · ')));
      }
    case 'entertainment':
      for (final e in listOf(data['items'])) {
        out.add(m(e, '${e['title']}',
            e['premise'] as String? ?? e['why'] as String?));
      }
    case 'products':
      for (final p in listOf(data['items'])) {
        out.add(m(p, '${p['name']}',
            [priceText(p), p['why']].whereType<String>().join(' · ')));
      }
    case 'ideas':
      final steps = ((data['next_steps'] as List?) ?? const []).cast<String>();
      for (final (i, s) in steps.indexed) {
        out.add((
          t: i.toDouble(),
          frame: null,
          title: s,
          detail: 'Next step ${i + 1}',
          verdict: null
        ));
      }
  }
  return out..sort((a, b) => a.t.compareTo(b.t));
}

/// The viewer (docs/DESIGN_V5.md §2.5): swipe up for the next discovery, sideways through its
/// moments; finish it from here; see what's next. Always ink (immersive, photos first).
class ViewerScreen extends StatefulWidget {
  const ViewerScreen(
      {super.key, required this.keys, this.start = 0, this.title = 'Browse'});
  final List<String> keys;
  final int start;
  final String title;

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  late final _pages = PageController(initialPage: widget.start);
  late int _at = widget.start;
  Timer? _seen;
  int _placed = 0; // bumps to replay the piece animation

  @override
  void initState() {
    super.initState();
    _scheduleSeen();
  }

  void _scheduleSeen() {
    _seen?.cancel();
    _seen = Timer(const Duration(milliseconds: 1200), () {
      final d = Repo.instance.now.find(widget.keys[_at]);
      if (d != null) Repo.instance.markSeen(d).ignore();
    });
  }

  @override
  void dispose() {
    _seen?.cancel();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: rbTheme(Brightness.dark),
      child: Builder(builder: (context) {
        final c = RbColors.of(context);
        return Scaffold(
          backgroundColor: c.ground,
          body: ValueListenableBuilder<BrainState>(
            valueListenable: Repo.instance.state,
            builder: (context, s, _) {
              final list = [for (final k in widget.keys) s.find(k)];
              return Stack(children: [
                PageView.builder(
                  controller: _pages,
                  scrollDirection: Axis.vertical,
                  itemCount: list.length,
                  onPageChanged: (i) {
                    setState(() => _at = i);
                    _scheduleSeen();
                  },
                  itemBuilder: (context, i) {
                    final d = list[i];
                    if (d == null) return const SizedBox.shrink();
                    final next = i + 1 < list.length ? list[i + 1] : null;
                    return _ViewerPage(
                      key: ValueKey(d.key),
                      d: d,
                      next: next,
                      onNext: next == null
                          ? null
                          : () => _pages.nextPage(
                              duration: RbMotion.base, curve: RbMotion.curve),
                      onPlaced: () => setState(() => _placed++),
                    );
                  },
                ),
                // Top bar: close, where you are in the list.
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(6, 4, 16, 0),
                      child: Row(children: [
                        PhotoIconButton(
                            icon: Icons.close,
                            label: 'Close',
                            onTap: () => Navigator.of(context).maybePop()),
                        const SizedBox(width: 6),
                        Expanded(
                          child: MonoLabel(
                              '${widget.title} · ${_at + 1} of ${list.length}',
                              color: Colors.white),
                        ),
                      ]),
                    ),
                  ),
                ),
                if (_placed > 0) _PiecePlaced(key: ValueKey(_placed)),
              ]);
            },
          ),
        );
      }),
    );
  }
}

class _ViewerPage extends StatefulWidget {
  const _ViewerPage(
      {super.key,
      required this.d,
      required this.next,
      required this.onNext,
      required this.onPlaced});
  final Discovery d;
  final Discovery? next;
  final VoidCallback? onNext;
  final VoidCallback onPlaced;

  @override
  State<_ViewerPage> createState() => _ViewerPageState();
}

class _ViewerPageState extends State<_ViewerPage> {
  final _moments = PageController();
  int _m = 0; // 0: the overview; 1..n: moments

  @override
  void didUpdateWidget(_ViewerPage old) {
    super.didUpdateWidget(old);
    // Just finished: the piece drops into the brain.
    if (!old.d.isDone && widget.d.isDone) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onPlaced());
    }
  }

  @override
  void dispose() {
    _moments.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final t = Theme.of(context).textTheme;
    final d = widget.d;
    final moments = momentsOf(d);
    final current = _m == 0 || moments.isEmpty ? null : moments[_m - 1];
    final h = MediaQuery.sizeOf(context).height;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    return Column(children: [
      // The image: swipe sideways through the moments.
      SizedBox(
        height: h * 0.5,
        child: Stack(fit: StackFit.expand, children: [
          PageView.builder(
            controller: _moments,
            itemCount: moments.length + 1,
            onPageChanged: (i) => setState(() => _m = i),
            itemBuilder: (context, i) {
              final frame = i == 0 ? d.frame : moments[i - 1].frame ?? d.frame;
              return _Drift(child: DiscoveryArt(d, frame: frame));
            },
          ),
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, 0.25, 0.7, 1],
                  colors: [
                    Color(0xAA000000),
                    Color(0x00000000),
                    Color(0x00000000),
                    Color(0xFF121110)
                  ],
                ),
              ),
            ),
          ),
          if (moments.isNotEmpty)
            Positioned(
              left: RbSpace.side,
              right: RbSpace.side,
              bottom: 12,
              child: Row(children: [
                for (var i = 0; i <= moments.length; i++)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _moments.animateToPage(i,
                          duration: RbMotion.base, curve: RbMotion.curve),
                      child: Container(
                        height: 18,
                        alignment: Alignment.center,
                        child: AnimatedContainer(
                          duration: RbMotion.fast,
                          height: i == _m ? 3 : 2,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: i == _m
                                ? c.brand
                                : Colors.white.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
        ]),
      ),
      // The panel: what it is, the moment, and what to do.
      Expanded(
        child: Padding(
          padding:
              EdgeInsets.fromLTRB(RbSpace.side, 6, RbSpace.side, bottomPad + 8),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CatalogLabel(d),
            const SizedBox(height: 8),
            Text(d.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: RbType.serif(26, color: c.text)),
            const SizedBox(height: 10),
            Expanded(
              child: AnimatedSwitcher(
                duration: RbMotion.base,
                switchInCurve: RbMotion.enter,
                child: current == null
                    ? _Overview(
                        key: const ValueKey(-1), d: d, moments: moments.length)
                    : _MomentText(
                        key: ValueKey(_m),
                        m: current,
                        index: _m,
                        of: moments.length,
                        section: d.section),
              ),
            ),
            Row(children: [
              StampButton(d),
              const SizedBox(width: 10),
              Expanded(
                child: RbButton(d.action,
                    small: true,
                    expand: true,
                    onPressed: () => primaryAction(context, d)),
              ),
              IconButton(
                tooltip: 'Open the full page',
                onPressed: () => openDiscovery(context, d),
                icon: Icon(Icons.article_outlined, color: c.text),
              ),
            ]),
            const SizedBox(height: 6),
            if (widget.next != null)
              Semantics(
                button: true,
                label: 'Up next: ${widget.next!.title}',
                excludeSemantics: true,
                child: InkWell(
                  onTap: widget.onNext,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: c.line))),
                    child: Row(children: [
                      Icon(Icons.keyboard_arrow_up, color: c.muted, size: 20),
                      const SizedBox(width: 6),
                      const MonoLabel('Up next'),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(widget.next!.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.bodyMedium?.copyWith(color: c.muted)),
                      ),
                    ]),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: MonoLabel('End of the list', color: c.faint),
              ),
          ]),
        ),
      ),
    ]);
  }
}

class _Overview extends StatelessWidget {
  const _Overview({super.key, required this.d, required this.moments});
  final Discovery d;
  final int moments;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final t = Theme.of(context).textTheme;
    final why = d.note ?? d.goodFor;
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (d.detail.isNotEmpty)
          Text(d.detail, style: RbType.label(color: c.brandText, size: 12)),
        if (d.section == 'fact_check' && d.verdict != null) ...[
          const SizedBox(height: 6),
          VerdictPill(d.verdict!),
        ],
        if (why != null) ...[
          const SizedBox(height: 8),
          Text('“$why”',
              maxLines: 2,
              style: RbType.serif(17, color: c.muted, italic: true)),
        ] else if (d.summary.isNotEmpty && d.summary != d.title) ...[
          const SizedBox(height: 8),
          Text(d.summary,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: t.bodyMedium?.copyWith(color: c.muted)),
        ],
        if (moments > 0) ...[
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.swipe_left_outlined, size: 16, color: c.faint),
            const SizedBox(width: 6),
            Text(
                moments == 1
                    ? 'Swipe the picture for the moment found'
                    : 'Swipe the picture through $moments moments',
                style: t.bodySmall),
          ]),
        ],
      ]),
    );
  }
}

class _MomentText extends StatelessWidget {
  const _MomentText(
      {super.key,
      required this.m,
      required this.index,
      required this.of,
      required this.section});
  final Moment m;
  final int index, of;
  final String section;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final t = Theme.of(context).textTheme;
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          MonoLabel(
              '$index of $of${section == 'ideas' ? '' : ' · ${mmss(m.t)}'}',
              color: c.brandText),
          if (m.verdict != null) ...[
            const SizedBox(width: 10),
            VerdictPill(m.verdict!),
          ],
        ]),
        const SizedBox(height: 6),
        Text(m.title, style: RbType.serif(19, color: c.text, height: 1.3)),
        if (m.detail != null) ...[
          const SizedBox(height: 6),
          Text(m.detail!, style: t.bodyMedium?.copyWith(color: c.muted)),
        ],
        if (m.verdict != null && verdictLabels[m.verdict] != null)
          const SizedBox.shrink(),
      ]),
    );
  }
}

/// The frame drifts slowly closer while it's on screen (the reel's motion, not a video).
class _Drift extends StatelessWidget {
  const _Drift({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (RbMotion.reduced(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: 1.06),
      duration: const Duration(seconds: 9),
      curve: Curves.easeOut,
      builder: (_, s, c) => Transform.scale(scale: s, child: c),
      child: child,
    );
  }
}

/// The piece dropping into the brain when something is finished in the viewer.
class _PiecePlaced extends StatefulWidget {
  const _PiecePlaced({super.key});

  @override
  State<_PiecePlaced> createState() => _PiecePlacedState();
}

class _PiecePlacedState extends State<_PiecePlaced> {
  bool _gone = false;

  @override
  Widget build(BuildContext context) {
    if (_gone) return const SizedBox.shrink();
    return IgnorePointer(
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 1500),
          onEnd: () => setState(() => _gone = true),
          builder: (context, v, child) => Opacity(
              opacity: v < 0.8 ? 1 : (1 - (v - 0.8) / 0.2), child: child),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const BrainMark(
                  size: 96, motion: MarkMotion.arriving, color: Colors.white),
              const SizedBox(height: 10),
              MonoLabel('Piece placed', color: RbColors.dark.brand),
            ]),
          ),
        ),
      ),
    );
  }
}
