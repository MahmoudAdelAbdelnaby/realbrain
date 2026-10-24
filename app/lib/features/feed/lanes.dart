import 'package:flutter/material.dart';

import '../../core/glass.dart';
import '../../core/native.dart';
import '../../core/theme/tokens.dart';
import '../factcheck/fact_check_view.dart' show VerdictPill;
import '../save/save_screen.dart';
import '../workouts/workout_plan.dart';
import 'feed_screen.dart' show sectionLabels;

/// One section lane on Home (design v3): its items newest first, each with its save.
typedef Lane = ({
  String section,
  List<({Map<String, dynamic> item, Map<String, dynamic> save})> cards
});

/// Lanes for every section that has saves, ordered by the most recent activity. Items whose save
/// isn't loaded (yet) are skipped.
List<Lane> lanesOf(Iterable<Map<String, dynamic>> items,
    Iterable<Map<String, dynamic>> saves) {
  final byId = {for (final s in saves) s['save_id']: s};
  final groups = <String,
      List<({Map<String, dynamic> item, Map<String, dynamic> save})>>{};
  for (final item in items) {
    final save = byId[item['save_id']];
    final section = item['section'] as String?;
    if (save == null ||
        section == null ||
        !sectionLabels.containsKey(section)) {
      continue;
    }
    (groups[section] ??= []).add((item: item, save: save));
  }
  num at(({Map<String, dynamic> item, Map<String, dynamic> save}) c) =>
      (c.save['created_at'] ?? c.item['created_at'] ?? 0) as num;
  for (final g in groups.values) {
    g.sort((a, b) => at(b).compareTo(at(a)));
  }
  return [for (final e in groups.entries) (section: e.key, cards: e.value)]
    ..sort((a, b) => at(b.cards.first).compareTo(at(a.cards.first)));
}

/// What a card shows for its section: a title and one line of that section's own data.
(String title, String detail) cardFace(
    Map<String, dynamic> item, Map<String, dynamic> save) {
  final data = (item['data'] as Map?)?.cast<String, dynamic>() ?? const {};
  List<Map<String, dynamic>> list(String key) => [
        for (final e in (data[key] as List?) ?? const [])
          (e as Map).cast<String, dynamic>()
      ];
  String more(List<Map<String, dynamic>> l) =>
      l.length > 1 ? ' +${l.length - 1}' : '';
  final summary = save['summary'] as String? ?? '';
  switch (item['section']) {
    case 'fact_check':
      final claims = list('claims');
      return (
        summary,
        '${claims.length} claim${claims.length == 1 ? '' : 's'}'
      );
    case 'recipe':
      return (
        data['title'] as String? ?? summary,
        [
          if (data['total_min'] != null) '${data['total_min']} min',
          if (data['servings'] != null) 'serves ${data['servings']}',
        ].join(', '),
      );
    case 'tools':
      final tools = list('items');
      if (tools.isEmpty) return (summary, '');
      final v = (tools.first['verified'] as Map?) ?? const {};
      final stars = v['stars'] as num?;
      return (
        '${tools.first['name']}${more(tools)}',
        stars != null
            ? '★ ${stars >= 1000 ? '${(stars / 1000).toStringAsFixed(1)}k' : stars}'
            : v['ok'] == true
                ? 'Link checked'
                : 'Not checked',
      );
    case 'places':
      final places = list('items');
      if (places.isEmpty) return (summary, '');
      return (
        '${places.first['name']}${more(places)}',
        [places.first['area'], places.first['city']]
            .whereType<String>()
            .join(', '),
      );
    case 'workout':
      final ex = list('exercises');
      final secs = buildPhases(ex).fold<int>(0, (t, p) => t + (p.seconds ?? 0));
      return (
        summary,
        '${ex.length} exercise${ex.length == 1 ? '' : 's'}${secs > 0 ? ', about ${(secs / 60).ceil()} min' : ''}',
      );
  }
  return (summary, '');
}

/// Seconds of every extracted moment in an item (claims, steps, tools, places, exercises).
List<double> momentsOf(Map<String, dynamic> item) {
  final data = (item['data'] as Map?) ?? const {};
  return [
    for (final v in data.values)
      if (v is List)
        for (final e in v)
          if (e is Map && e['t'] is num) (e['t'] as num).toDouble(),
  ]..sort();
}

/// One lane: the section's name, count, See all, then horizontally snapping cards.
class LaneView extends StatelessWidget {
  const LaneView(
      {super.key,
      required this.lane,
      required this.onSeeAll,
      this.extra,
      this.isNew});
  final Lane lane;
  final VoidCallback onSeeAll;

  /// A second action next to the title (Places: "on the map").
  final Widget? extra;

  /// Saves that arrived while Home was open: they slide in (design v3 arrival).
  final bool Function(String saveId)? isNew;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = RbColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(RbSpace.side, 0, 4, 4),
          child: Row(children: [
            // Each section's own hue (docs/BRAND.md).
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsetsDirectional.only(end: 10),
              decoration: BoxDecoration(
                  color: c.section(lane.section), shape: BoxShape.circle),
            ),
            Text(sectionLabels[lane.section] ?? lane.section,
                style: t.titleLarge),
            const SizedBox(width: 8),
            Text('${lane.cards.length}',
                style: t.titleLarge?.copyWith(color: c.faint)),
            if (extra != null) ...[const SizedBox(width: 4), extra!],
            const Spacer(),
            TextButton(onPressed: onSeeAll, child: const Text('See all')),
          ]),
        ),
        SizedBox(
          height: 292,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: RbSpace.side),
            physics: const PageScrollPhysics()
                .applyTo(const BouncingScrollPhysics()),
            itemCount: lane.cards.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final card = lane.cards[i];
              final id = card.save['save_id'] as String? ?? '';
              return LaneCard(
                  item: card.item,
                  save: card.save,
                  arriving: isNew?.call(id) ?? false);
            },
          ),
        ),
      ]),
    );
  }
}

/// A card: the reel frame at 3:4 with the moment strip along its bottom, then the section's face.
class LaneCard extends StatelessWidget {
  const LaneCard(
      {super.key,
      required this.item,
      required this.save,
      this.arriving = false});
  final Map<String, dynamic> item, save;
  final bool arriving;

  static const width = 168.0;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = RbColors.of(context);
    final (title, detail) = cardFace(item, save);
    final saveId = save['save_id'] as String?,
        spaceId = save['space_id'] as String?;
    final verdict =
        item['section'] == 'fact_check' ? save['verdict'] as String? : null;
    // One tag per lane: a save filed under two sections has a card in each.
    final hero = 'frame-$saveId-${item['section']}';
    final card = Pressable(
      onTap: saveId == null || spaceId == null
          ? null
          : () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SaveScreen(
                  spaceId: spaceId,
                  saveId: saveId,
                  initial: save,
                  heroTag: hero))),
      child: SizedBox(
        width: width,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(RbSpace.cardRadius),
            child: SizedBox(
              width: width,
              height: width * 4 / 3,
              child: Stack(fit: StackFit.expand, children: [
                Hero(
                    tag: hero,
                    child: ClipRRect(
                        borderRadius: BorderRadius.circular(RbSpace.cardRadius),
                        child: FrameImage(save: save))),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 10,
                  child: MomentStrip(
                    moments: momentsOf(item),
                    duration: (save['duration_s'] as num?)?.toDouble(),
                    color: verdict == null
                        ? c.section(item['section'] as String?)
                        : null,
                    verdict: verdict,
                  ),
                ),
                if (verdict != null)
                  Positioned(top: 10, left: 10, child: VerdictPill(verdict)),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          Text(title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.titleSmall),
          if (detail.isNotEmpty)
            Text(detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.bodySmall),
        ]),
      ),
    );
    if (!arriving || RbMotion.reduced(context)) return card;
    // Arrival: rises out of the pill's direction on a spring, then develops from a red-lit
    // negative to full colour (docs/BRAND.md "Develop").
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1600),
      builder: (context, v, child) {
        final rise = RbMotion.bouncy.transform((v / 0.35).clamp(0.0, 1.0));
        final dev =
            Curves.easeOutCubic.transform(((v - 0.2) / 0.8).clamp(0.0, 1.0));
        return Transform.translate(
          offset: Offset(0, (1 - rise) * 120),
          child: Transform.scale(
            scale: 0.85 + 0.15 * rise,
            child: Opacity(
              opacity: (v / 0.2).clamp(0.0, 1.0),
              child:
                  ColorFiltered(colorFilter: developFilter(dev), child: child),
            ),
          ),
        );
      },
      child: card,
    );
  }
}

/// The save's key frame, or a flat placeholder at the same size.
class FrameImage extends StatelessWidget {
  const FrameImage({super.key, required this.save});
  final Map<String, dynamic> save;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(color: RbColors.of(context).raised);
    return ValueListenableBuilder<String?>(
      valueListenable: backendUrl,
      builder: (context, _, __) {
        final url = frameUrl(save['key_frame_url'] as String?);
        return url == null
            ? placeholder
            : Image.network(url,
                fit: BoxFit.cover, errorBuilder: (_, __, ___) => placeholder);
      },
    );
  }
}

/// Design signature kept from v2: a thin bar the length of the reel with a tick at each moment
/// something was extracted. Verdict colour on Fact Check, the accent elsewhere.
class MomentStrip extends StatelessWidget {
  const MomentStrip(
      {super.key,
      required this.moments,
      this.duration,
      this.color,
      this.verdict});
  final List<double> moments;
  final double? duration;
  final Color? color;
  final String? verdict;

  @override
  Widget build(BuildContext context) {
    if (moments.isEmpty) return const SizedBox.shrink();
    final c = RbColors.of(context);
    final tick = color ??
        switch (verdict) {
          'true' || 'mostly_true' => c.trueFg,
          'mixed' => c.mixedFg,
          'false' || 'mostly_false' => c.falseFg,
          _ => c.accent,
        };
    // Without a stored length (older saves), the last moment sits at 90% of the bar.
    final length =
        duration != null && duration! > 0 ? duration! : moments.last / 0.9;
    return SizedBox(
      height: 6,
      child: LayoutBuilder(builder: (context, box) {
        return Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(
            top: 2,
            bottom: 2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          for (final m in moments)
            Positioned(
              left: (m / length).clamp(0.0, 1.0) * (box.maxWidth - 3),
              top: 0,
              bottom: 0,
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                    color: tick, borderRadius: BorderRadius.circular(2)),
              ),
            ),
        ]);
      }),
    );
  }
}

/// The darkroom develop: 0 is a red-lit negative (inverted, grey, under safelight), 1 is the
/// picture as it is. Lerps the colour matrix, so it costs one filter per developing card.
ColorFilter developFilter(double t) {
  // Negative: invert, desaturate, tint red.
  const neg = <double>[
    -0.30, -0.59, -0.11, 0, 255, //
    -0.10, -0.20, -0.04, 0, 90, //
    -0.08, -0.16, -0.03, 0, 70, //
    0, 0, 0, 1, 0,
  ];
  const id = <double>[
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0
  ];
  return ColorFilter.matrix(
      [for (var i = 0; i < 20; i++) neg[i] + (id[i] - neg[i]) * t]);
}
