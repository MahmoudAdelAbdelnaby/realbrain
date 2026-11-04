import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/art/glyphs.dart';
import '../../core/categories.dart';
import '../../core/data/repo.dart';
import '../../core/format.dart';
import '../../core/links.dart';
import '../../core/native.dart' show apiError;
import '../../core/theme/tokens.dart';
import '../../core/ui/art_frames.dart';
import '../../core/ui/components.dart';
import '../recipes/recipe_math.dart';
import '../recipes/cook_timers.dart' show clock;
import 'actions.dart' show productUrl, shareToGroup, toolUrl;

/// The category's own content on a discovery's page (docs/DESIGN_V5.md §2.6): each kind of thing
/// laid out for how it's used, not one card for everything.
class DiscoveryBody extends StatelessWidget {
  const DiscoveryBody(this.d, {super.key});
  final Discovery d;

  @override
  Widget build(BuildContext context) => switch (d.section) {
        'recipe' => RecipeBody(d),
        'workout' => WorkoutBody(d),
        'places' => PlacesBody(d),
        'tools' => ToolsBody(d),
        'fact_check' => FactCheckBody(d),
        'ideas' => IdeasBody(d),
        'entertainment' => EntertainmentBody(d),
        'products' => ProductsBody(d),
        _ => Text(d.summary),
      };
}

/// A section heading inside a body: mono kicker + serif title.
class BodyHeading extends StatelessWidget {
  const BodyHeading(this.title, {super.key, this.kicker, this.trailing});
  final String title;
  final String? kicker;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Semantics(
            header: true,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (kicker != null) ...[
                MonoLabel(kicker!),
                const SizedBox(height: 3),
              ],
              Text(title, style: RbType.serif(21, color: c.text)),
            ]),
          ),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

// --- recipes ---

class RecipeBody extends StatefulWidget {
  const RecipeBody(this.d, {super.key});
  final Discovery d;

  @override
  State<RecipeBody> createState() => _RecipeBodyState();
}

class _RecipeBodyState extends State<RecipeBody> {
  late final int? _base = (widget.d.data['servings'] as num?)?.toInt();
  late int _servings = _base ?? 0;
  final _have = <int>{};

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final d = widget.d.data;
    final ingredients = listOf(d['ingredients']);
    final steps = listOf(d['steps']);
    final tags = ((d['tags'] as List?) ?? const []).cast<String>();
    final lines = [
      for (final i in ingredients)
        ingredientLine(i, from: _base, to: _base == null ? null : _servings)
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (tags.isNotEmpty)
        Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final tag in tags) FactChip(tag)]),
      if (ingredients.isNotEmpty) ...[
        BodyHeading(
          'Ingredients',
          kicker: '${ingredients.length} items',
          trailing: _base == null
              ? null
              : _Stepper(
                  value: _servings,
                  label: 'serves',
                  onChanged: (v) => setState(() => _servings = v)),
        ),
        for (final (n, line) in lines.indexed)
          _Check(
            text: line,
            done: _have.contains(n),
            onTap: () => setState(
                () => _have.contains(n) ? _have.remove(n) : _have.add(n)),
          ),
        if (ingredients.any((i) => i['estimated'] == true))
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('≈ estimated: the video didn’t say the amount',
                style: t.bodySmall),
          ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: RbButton.quiet('Share the shopping list',
              small: true,
              icon: Icons.ios_share,
              onPressed: () => shareOut(
                  '${widget.d.title}\n${lines.map((l) => '- $l').join('\n')}')),
        ),
      ],
      if (steps.isNotEmpty) ...[
        BodyHeading('Method',
            kicker: [
              '${steps.length} steps',
              if (d['total_min'] != null) '${d['total_min']} min',
            ].join(' · ')),
        for (final (n, s) in steps.indexed)
          _Step(n: n, step: s, section: 'recipe'),
      ],
    ]);
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper(
      {required this.value, required this.label, required this.onChanged});
  final int value;
  final String label;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    Widget btn(IconData i, String tip, VoidCallback? f) => IconButton(
        tooltip: tip,
        visualDensity: VisualDensity.compact,
        onPressed: f,
        icon: Icon(i, size: 18, color: f == null ? c.faint : c.text));
    return Container(
      decoration: BoxDecoration(
          border: Border.all(color: c.line),
          borderRadius: BorderRadius.circular(RbSpace.pill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        btn(Icons.remove, 'Fewer servings',
            value > 1 ? () => onChanged(value - 1) : null),
        Text('$label $value', style: RbType.monoNumber(13, color: c.text)),
        btn(Icons.add, 'More servings', () => onChanged(value + 1)),
      ]),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.text, required this.done, required this.onTap});
  final String text;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    return Semantics(
      checked: done,
      label: text,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration:
              BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
          child: Row(children: [
            AnimatedContainer(
              duration: RbMotion.fast,
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: done ? c.text : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: done ? c.text : c.faint, width: 1.4),
              ),
              child: done ? Icon(Icons.check, size: 14, color: c.ground) : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(text,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: done ? c.faint : c.text,
                      decoration: done ? TextDecoration.lineThrough : null)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.step, required this.section});
  final int n;
  final Json step;
  final String section;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final timer = (step['timer_s'] as num?)?.toInt();
    final frame = step['frame'] as String?;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 34,
          child: Text('${n + 1}'.padLeft(2, '0'),
              style: RbType.monoNumber(14, color: c.brandText)),
        ),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${step['text']}',
                style: Theme.of(context).textTheme.bodyLarge),
            if (timer != null || step['t'] != null) ...[
              const SizedBox(height: 6),
              Wrap(spacing: 10, children: [
                if (timer != null)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.timer_outlined, size: 15, color: c.muted),
                    const SizedBox(width: 4),
                    Text(clock(Duration(seconds: timer)),
                        style: RbType.monoNumber(12.5, color: c.muted)),
                  ]),
                if (step['t'] != null)
                  Text('at ${mmss(step['t'] as num)} in the reel',
                      style: Theme.of(context).textTheme.bodySmall),
              ]),
            ],
          ]),
        ),
        if (frame != null) ...[
          const SizedBox(width: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(RbSpace.photoRadius),
            child: SizedBox(
              width: 72,
              height: 90,
              child: FrameImage(
                  stored: frame, fallback: ColoredBox(color: c.raised)),
            ),
          ),
        ],
      ]),
    );
  }
}

// --- workouts ---

class WorkoutBody extends StatelessWidget {
  const WorkoutBody(this.d, {super.key});
  final Discovery d;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final t = Theme.of(context).textTheme;
    final ex = listOf(d.data['exercises']);
    final mins = workoutMinutes(ex);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      BodyHeading('The plan',
          kicker: [
            count(ex.length, 'exercise'),
            if (mins > 0) 'about $mins min'
          ].join(' · ')),
      for (final (n, e) in ex.indexed)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration:
              BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(RbSpace.photoRadius),
              child: SizedBox(
                width: 64,
                height: 64,
                child: FrameImage(
                  stored: e['frame'] as String?,
                  fallback: ColoredBox(
                      color: c.raised,
                      child: Center(
                          child: Text('${n + 1}',
                              style: RbType.monoNumber(18, color: c.faint)))),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${e['name']}',
                        style: RbType.serif(18, color: c.text)),
                    const SizedBox(height: 3),
                    Text(_dose(e),
                        style: RbType.label(color: c.brandText, size: 12)),
                    if (e['cues'] != null) ...[
                      const SizedBox(height: 4),
                      Text('${e['cues']}', style: t.bodySmall),
                    ],
                  ]),
            ),
          ]),
        ),
      if (ex.any((e) => e['estimated'] == true))
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
              '≈ some times were not said in the video; they start at 40 s',
              style: t.bodySmall),
        ),
    ]);
  }

  static String _dose(Json e) {
    final sets = (e['sets'] as num?)?.toInt();
    final what = e['duration_s'] != null
        ? '${e['duration_s']} s'
        : e['reps'] != null
            ? '${e['reps']} reps'
            : 'until done';
    final rest = e['rest_s'] != null ? ' · rest ${e['rest_s']} s' : '';
    return '${sets != null && sets > 1 ? '$sets × ' : ''}$what$rest'
        '${e['estimated'] == true ? ' ≈' : ''}';
  }
}

// --- places ---

class PlacesBody extends StatelessWidget {
  const PlacesBody(this.d, {super.key});
  final Discovery d;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final t = Theme.of(context).textTheme;
    final places = listOf(d.data['items']);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (places.length > 1)
        BodyHeading('${places.length} places', kicker: 'In this reel'),
      for (final p in places)
        Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.line),
            borderRadius: BorderRadius.circular(RbSpace.cardRadius),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Glyph(Glyphs.map, size: 18, color: c.pigment('places')),
              const SizedBox(width: 8),
              Expanded(
                child: MonoLabel([
                  if ((p['geo'] as Map?)?['matched'] == 'area') 'Area only',
                  p['area'],
                  p['city'],
                ].whereType<String>().join(' · ')),
              ),
            ]),
            const SizedBox(height: 6),
            Text('${p['name']}', style: RbType.serif(22, color: c.text)),
            if (p['why_go'] != null) ...[
              const SizedBox(height: 8),
              Text('${p['why_go']}', style: t.bodyMedium),
            ],
            if (p['what_to_order'] != null) ...[
              const SizedBox(height: 10),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const MonoLabel('Order'),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('${p['what_to_order']}',
                      style: RbType.serif(16, color: c.text, italic: true)),
                ),
              ]),
            ],
            const SizedBox(height: 12),
            Wrap(spacing: 6, runSpacing: 4, children: [
              RbButton.secondary('Open in Maps',
                  small: true,
                  glyph: Glyphs.map,
                  onPressed: () => openUrl(context, mapsUrl(p))),
              if (Repo.instance.now.groups.isNotEmpty)
                RbButton.quiet('Plan a visit',
                    small: true,
                    icon: Icons.event_outlined,
                    onPressed: () => shareToGroup(context, d, kind: 'plan')),
            ]),
          ]),
        ),
    ]);
  }
}

// --- tools ---

class ToolsBody extends StatelessWidget {
  const ToolsBody(this.d, {super.key});
  final Discovery d;

  static String _check(Json tool) {
    final v = (tool['verified'] as Map?)?.cast<String, dynamic>();
    if (v == null) return 'Link not checked yet';
    if (v['source'] == 'github' && v['matched_by'] == 'name') {
      return 'Found on GitHub by name: check it’s the right one';
    }
    final stars = v['stars'] as num?;
    if (stars != null) {
      final last = DateTime.tryParse('${v['last_commit']}');
      return '★ ${compactNumber(stars)}${last == null ? '' : ' · updated ${ago(epoch(last))}'}';
    }
    return v['ok'] == true ? 'Link checked' : 'Link broken or guessed';
  }

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final t = Theme.of(context).textTheme;
    final tools = listOf(d.data['items']);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final tool in tools) ...[
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
              child: Text('${tool['name']}',
                  style: RbType.serif(22, color: c.text))),
          if (d.category.kinds[tool['kind']] != null)
            MonoLabel(d.category.kinds[tool['kind']]!,
                color: c.pigment('tools')),
        ]),
        const SizedBox(height: 4),
        Text(_check(tool), style: t.bodySmall),
        if (tool['use_shown'] != null) ...[
          const SizedBox(height: 10),
          Text('${tool['use_shown']}', style: t.bodyLarge),
        ],
        if ((tool['snippet'] as String?)?.isNotEmpty ?? false) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 6, 4, 6),
            decoration: BoxDecoration(
                color: c.raised,
                borderRadius: BorderRadius.circular(RbSpace.photoRadius)),
            child: Row(children: [
              Expanded(
                child: SelectableText('${tool['snippet']}',
                    textDirection: TextDirection.ltr,
                    style: RbType.monoNumber(13, color: c.text)
                        .copyWith(height: 1.5, fontWeight: FontWeight.w400)),
              ),
              IconButton(
                tooltip: 'Copy',
                icon: Icon(Icons.copy_rounded, size: 18, color: c.muted),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: '${tool['snippet']}'));
                  toast(context, 'Copied');
                },
              ),
            ]),
          ),
        ],
        if (toolUrl(tool) != null) ...[
          const SizedBox(height: 8),
          RbButton.secondary(Uri.tryParse(toolUrl(tool)!)?.host ?? 'Open',
              small: true,
              icon: Icons.open_in_new,
              onPressed: () => openUrl(context, toolUrl(tool)!)),
        ],
        const SizedBox(height: 8),
        if (tool != tools.last) Container(height: 1, color: c.line),
      ],
    ]);
  }
}

// --- fact checks ---

const verdictLabels = {
  'true': 'True',
  'mostly_true': 'Mostly true',
  'mixed': 'Mixed',
  'mostly_false': 'Mostly false',
  'false': 'False',
  'unverifiable': 'Unverified',
};

(Color, Color) verdictColors(BuildContext context, String v) {
  final c = RbColors.of(context);
  return switch (v) {
    'true' || 'mostly_true' => (c.trueFg, c.trueBg),
    'mixed' => (c.mixedFg, c.mixedBg),
    'false' || 'mostly_false' => (c.falseFg, c.falseBg),
    _ => (c.muted, c.raised),
  };
}

class VerdictPill extends StatelessWidget {
  const VerdictPill(this.verdict, {super.key});
  final String verdict;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = verdictColors(context, verdict);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(RbSpace.tagRadius)),
      child: Text((verdictLabels[verdict] ?? verdict).toUpperCase(),
          style: RbType.label(color: fg, size: 11, weight: FontWeight.w600)),
    );
  }
}

class FactCheckBody extends StatefulWidget {
  const FactCheckBody(this.d, {super.key});
  final Discovery d;

  @override
  State<FactCheckBody> createState() => _FactCheckBodyState();
}

class _FactCheckBodyState extends State<FactCheckBody> {
  bool _asked = false;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final t = Theme.of(context).textTheme;
    final d = widget.d.data;
    final claims = listOf(d['claims']);
    final sources = listOf(d['sources']);
    final overall = d['overall'] as String?;
    final checked = d['checked_at'] as num?;
    final explainer = d['explainer'] as String?;
    final explainError = d['explain_error'] as String?;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (overall != null)
        Builder(builder: (context) {
          final (fg, bg) = verdictColors(context, overall);
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(RbSpace.cardRadius)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              MonoLabel('Overall verdict', color: fg),
              const SizedBox(height: 4),
              Text(verdictLabels[overall] ?? overall,
                  style: RbType.serif(30, color: fg)),
            ]),
          );
        }),
      const SizedBox(height: 10),
      Text(
          checked == null
              ? 'AI-generated · not checked against sources yet'
              : 'AI-generated · checked against sources ${dayMonth(fromEpoch(checked))} ${fromEpoch(checked).year}',
          style: t.bodySmall),
      BodyHeading('The claims', kicker: count(claims.length, 'claim')),
      for (final cl in claims)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: c.line),
            borderRadius: BorderRadius.circular(RbSpace.cardRadius),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              VerdictPill(cl['verdict'] as String? ?? 'unverifiable'),
              const Spacer(),
              if (cl['t'] != null)
                Text(mmss(cl['t'] as num),
                    style: RbType.monoNumber(12, color: c.faint)),
            ]),
            const SizedBox(height: 8),
            Text('“${cl['text']}”',
                style:
                    RbType.serif(17, color: c.text, italic: true, height: 1.3)),
            if ((cl['correction'] as String?)?.isNotEmpty ?? false) ...[
              const SizedBox(height: 8),
              Text('${cl['correction']}',
                  style: t.bodyMedium?.copyWith(color: c.muted)),
            ],
          ]),
        ),
      if (sources.isNotEmpty) ...[
        BodyHeading('Sources', kicker: count(sources.length, 'source')),
        for (final s in sources)
          InkWell(
            onTap: s['url'] == null
                ? null
                : () => openUrl(context, s['url'] as String),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(children: [
                Icon(Icons.north_east, size: 16, color: c.muted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('${s['title'] ?? s['url']}',
                      style: t.bodyMedium
                          ?.copyWith(decoration: TextDecoration.underline)),
                ),
              ]),
            ),
          ),
      ],
      const SizedBox(height: 12),
      if (explainer != null) ...[
        BodyHeading('Deeper', kicker: 'Explainer'),
        Text(explainer, style: t.bodyLarge),
      ] else
        RbButton.secondary(
          _asked && explainError == null
              ? 'Writing the explainer…'
              : 'Dive deeper',
          icon: Icons.auto_stories_outlined,
          busy: _asked && explainError == null,
          onPressed: _asked && explainError == null
              ? null
              : () async {
                  setState(() => _asked = true);
                  try {
                    await Repo.instance.deepDive(widget.d.save);
                  } catch (e) {
                    if (!context.mounted) return;
                    setState(() => _asked = false);
                    toast(context, apiError(e));
                  }
                },
        ),
      if (explainError != null) ...[
        const SizedBox(height: 6),
        Text(explainError, style: t.bodySmall),
      ],
    ]);
  }
}

// --- ideas ---

class IdeasBody extends StatefulWidget {
  const IdeasBody(this.d, {super.key});
  final Discovery d;

  @override
  State<IdeasBody> createState() => _IdeasBodyState();
}

class _IdeasBodyState extends State<IdeasBody> {
  final _done = <int>{};

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final d = widget.d.data;
    final steps = ((d['next_steps'] as List?) ?? const []).cast<String>();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (d['idea'] != null)
        Container(
          padding: const EdgeInsetsDirectional.only(start: 16),
          decoration: BoxDecoration(
              border: BorderDirectional(
                  start: BorderSide(color: c.pigment('ideas'), width: 3))),
          child: Text('${d['idea']}',
              style:
                  RbType.serif(21, color: c.text, italic: true, height: 1.35)),
        ),
      if (steps.isNotEmpty) ...[
        BodyHeading('Next steps',
            kicker: '${_done.length} of ${steps.length} done'),
        for (final (n, s) in steps.indexed)
          _Check(
              text: s,
              done: _done.contains(n),
              onTap: () => setState(
                  () => _done.contains(n) ? _done.remove(n) : _done.add(n))),
      ],
    ]);
  }
}

// --- watch & read ---

class EntertainmentBody extends StatelessWidget {
  const EntertainmentBody(this.d, {super.key});
  final Discovery d;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final t = Theme.of(context).textTheme;
    final titles = listOf(d.data['items']);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final e in titles) ...[
        const SizedBox(height: 12),
        Row(children: [
          Glyph(e['kind'] as String? ?? 'entertainment',
              size: 18, color: c.pigment('entertainment')),
          const SizedBox(width: 8),
          MonoLabel(
              [
                kindNouns[e['kind']] ?? 'title',
                if (e['year'] != null) '${e['year']}',
                if (e['kind'] == 'series' && e['seasons'] != null)
                  '${e['seasons']} season${e['seasons'] == 1 ? '' : 's'}',
                if (e['kind'] == 'series' && e['episodes'] != null)
                  '${e['episodes']} episodes',
              ].join(' · '),
              color: c.pigment('entertainment')),
        ]),
        const SizedBox(height: 6),
        Text('${e['title']}',
            style: RbType.serif(26, color: c.text, italic: true)),
        if (e['creator'] != null) ...[
          const SizedBox(height: 2),
          Text(e['kind'] == 'book' ? 'by ${e['creator']}' : '${e['creator']}',
              style: t.bodyMedium?.copyWith(color: c.muted)),
        ],
        if (((e['genres'] as List?) ?? const []).isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final g in (e['genres'] as List)) FactChip('$g'),
          ]),
        ],
        if (e['premise'] != null) ...[
          const SizedBox(height: 14),
          Text('${e['premise']}', style: t.bodyLarge),
        ],
        if (e['why'] != null) ...[
          const SizedBox(height: 14),
          const MonoLabel('Why it was recommended'),
          const SizedBox(height: 4),
          Text('“${e['why']}”',
              style: RbType.serif(17, color: c.text, italic: true)),
        ],
        if (((e['platforms'] as List?) ?? const []).isNotEmpty) ...[
          const SizedBox(height: 14),
          const MonoLabel('Mentioned in the video'),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final p in (e['platforms'] as List))
              FactChip('$p', icon: Icons.play_circle_outline),
          ]),
        ],
        const SizedBox(height: 14),
        Wrap(spacing: 6, runSpacing: 4, children: [
          if (e['kind'] == 'book') ...[
            RbButton.secondary('Goodreads',
                small: true,
                icon: Icons.north_east,
                onPressed: () =>
                    openUrl(context, goodreadsSearch('${e['title']}'))),
          ] else ...[
            RbButton.secondary('Where to watch',
                small: true,
                icon: Icons.north_east,
                onPressed: () =>
                    openUrl(context, justWatchSearch('${e['title']}'))),
            RbButton.quiet('IMDb',
                small: true,
                onPressed: () => openUrl(context,
                    imdbSearch('${e['title']} ${e['year'] ?? ''}'.trim()))),
          ],
        ]),
        if (e['estimated'] == true) ...[
          const SizedBox(height: 8),
          Text(
              'Some details come from the AI’s general knowledge, not the video.',
              style: t.bodySmall),
        ],
        if (e != titles.last) ...[
          const SizedBox(height: 16),
          Container(height: 1, color: c.line),
        ],
      ],
    ]);
  }
}

// --- products ---

class ProductsBody extends StatelessWidget {
  const ProductsBody(this.d, {super.key});
  final Discovery d;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final t = Theme.of(context).textTheme;
    final products = listOf(d.data['items']);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final p in products) ...[
        const SizedBox(height: 12),
        if (p['brand'] != null)
          MonoLabel('${p['brand']}', color: c.pigment('products')),
        const SizedBox(height: 4),
        Text('${p['name']}', style: RbType.serif(24, color: c.text)),
        if (priceText(p) != null) ...[
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(priceText(p)!, style: RbType.monoNumber(24, color: c.text)),
            const SizedBox(width: 10),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                    p['price_text'] != null && p['price'] == null
                        ? 'as said in the video'
                        : 'as said in the video; check before buying',
                    style: t.bodySmall),
              ),
            ),
          ]),
        ],
        if (p['description'] != null) ...[
          const SizedBox(height: 12),
          Text('${p['description']}', style: t.bodyLarge),
        ],
        if (((p['specs'] as List?) ?? const []).isNotEmpty) ...[
          const SizedBox(height: 14),
          const MonoLabel('Details'),
          const SizedBox(height: 6),
          for (final s in (p['specs'] as List))
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: c.line))),
              child: Text('$s', style: t.bodyMedium),
            ),
        ],
        if (p['why'] != null) ...[
          const SizedBox(height: 14),
          const MonoLabel('Why it was recommended'),
          const SizedBox(height: 4),
          Text('“${p['why']}”',
              style: RbType.serif(17, color: c.text, italic: true)),
        ],
        const SizedBox(height: 14),
        Wrap(spacing: 6, runSpacing: 4, children: [
          if (productUrl(p) != null)
            RbButton.secondary(
                p['merchant'] != null
                    ? 'View at ${p['merchant']}'
                    : 'View product',
                small: true,
                icon: Icons.north_east,
                onPressed: () => openUrl(context, productUrl(p)!)),
          if (p['affiliate_url'] != null && p['url_guess'] != null)
            RbButton.quiet('Original link',
                small: true,
                onPressed: () => openUrl(context, '${p['url_guess']}')),
        ]),
        if (p['affiliate_url'] != null) ...[
          const SizedBox(height: 8),
          Text(
              'Affiliate link: Realbrain may earn a small commission. The recommendation came '
              'from the video, not from us, and the original link is always here.',
              style: t.bodySmall),
        ],
        if (p != products.last) ...[
          const SizedBox(height: 16),
          Container(height: 1, color: c.line),
        ],
      ],
    ]);
  }
}
