import 'package:flutter/material.dart';

import '../../core/art/glyphs.dart';
import '../../core/categories.dart';
import '../../core/data/repo.dart';
import '../../core/format.dart';
import '../../core/links.dart';
import '../../core/theme/tokens.dart';
import '../../core/ui/art_frames.dart';
import '../../core/ui/components.dart';
import '../../core/ui/states.dart';
import '../recipes/cook_timers.dart' show clock;
import '../recipes/recipe_math.dart';
import '../shared/open.dart';
import '../shared/tiles.dart';
import '../workouts/workout_mode.dart';
import '../workouts/workout_plan.dart';

List<Discovery> collectionItems(BrainState s, Json list) => [
      for (final r in ((list['item_refs'] as List?) ?? const []).cast<String>())
        if (s.find(r) != null) s.find(r)!,
    ];

/// A collection as a small card: the first frames fanned, name, count.
class CollectionCard extends StatelessWidget {
  const CollectionCard({super.key, required this.list});
  final Json list;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final s = Repo.instance.now;
    final items = collectionItems(s, list);
    final cat = categoryOf(list['section'] as String?);
    return Semantics(
      button: true,
      label: '${list['name']}, ${count(items.length, cat.noun)}',
      excludeSemantics: true,
      child: Pressable(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) =>
                CollectionScreen(listId: list['list_id'] as String))),
        child: Container(
          width: 168,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.line),
            borderRadius: BorderRadius.circular(RbSpace.cardRadius),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              height: 44,
              child: Stack(children: [
                for (final (i, d) in items.take(3).indexed)
                  PositionedDirectional(
                    start: i * 26.0,
                    child: Container(
                      width: 40,
                      height: 44,
                      decoration: BoxDecoration(
                          border: Border.all(color: c.surface, width: 2),
                          borderRadius:
                              BorderRadius.circular(RbSpace.photoRadius)),
                      child: DiscoveryArt(d,
                          radius: RbSpace.tagRadius, typeset: false),
                    ),
                  ),
                if (items.isEmpty)
                  Glyph(Glyphs.collection, size: 32, color: c.faint),
              ]),
            ),
            const Spacer(),
            Text('${list['name']}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: RbType.serif(17, color: c.text)),
            const SizedBox(height: 2),
            MonoLabel('${cat.collection ?? 'Collection'} · ${items.length}',
                color: c.pigment(cat.id)),
          ]),
        ),
      ),
    );
  }
}

/// A collection: its items, and what it's for (start the routine, browse the watchlist).
class CollectionScreen extends StatelessWidget {
  const CollectionScreen({super.key, required this.listId});
  final String listId;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BrainState>(
      valueListenable: Repo.instance.state,
      builder: (context, s, _) {
        final list = s.lists.where((l) => l['list_id'] == listId).firstOrNull;
        if (list == null) {
          return Scaffold(appBar: AppBar(), body: const LoadingMark());
        }
        final items = collectionItems(s, list);
        final cat = categoryOf(list['section'] as String?);
        final overrides =
            (list['overrides'] as Map?)?.cast<String, dynamic>() ?? const {};
        final workout = cat.id == 'workout';
        return Scaffold(
          appBar: AppBar(title: Text('${list['name']}')),
          body:
              ListView(padding: const EdgeInsets.only(bottom: 120), children: [
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(RbSpace.side, 0, RbSpace.side, 8),
              child: MonoLabel(
                  '${cat.collection} · ${count(items.length, cat.noun)}',
                  color: RbColors.of(context).pigment(cat.id)),
            ),
            if (items.isEmpty)
              const EmptyState(
                  compact: true,
                  title: 'Empty',
                  body: 'Its items may have been archived.'),
            if (workout)
              for (final d in items)
                for (final (n, e) in listOf(d.data['exercises']).indexed)
                  _EditableExercise(
                    exercise: {
                      ...e,
                      ...((overrides['${d.saveId}/${d.itemId}#$n'] as Map?)
                              ?.cast<String, dynamic>() ??
                          const {})
                    },
                    onSeconds: (sec) => Repo.instance.setOverride(list,
                        '${d.saveId}/${d.itemId}#$n', {'duration_s': sec}),
                  )
            else
              for (final d in items) DiscoveryRow(d, within: items),
          ]),
          bottomNavigationBar: items.isEmpty
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        RbSpace.side, 8, RbSpace.side, 8),
                    child: workout
                        ? RbButton('Start the routine',
                            expand: true,
                            icon: Icons.play_arrow_rounded,
                            onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    fullscreenDialog: true,
                                    builder: (_) => WorkoutMode(
                                        phases: buildPhases(
                                            routineExercises(items, overrides)),
                                        items: items))))
                        : RbButton('Browse',
                            expand: true,
                            glyph: Glyphs.browse,
                            onPressed: () => openViewer(context, items,
                                title: '${list['name']}')),
                  ),
                ),
        );
      },
    );
  }
}

/// Exercises of several workouts with a routine's overrides applied.
List<Json> routineExercises(
        List<Discovery> items, Map<String, dynamic> overrides) =>
    [
      for (final d in items)
        for (final (n, e) in listOf(d.data['exercises']).indexed)
          {
            ...e,
            ...((overrides['${d.saveId}/${d.itemId}#$n'] as Map?)
                    ?.cast<String, dynamic>() ??
                const {})
          },
    ];

class _EditableExercise extends StatelessWidget {
  const _EditableExercise({required this.exercise, required this.onSeconds});
  final Json exercise;
  final void Function(int seconds) onSeconds;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final s = (exercise['duration_s'] as num?)?.toInt();
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: RbSpace.side, vertical: 10),
      decoration:
          BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
      child: Row(children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${exercise['name']}', style: RbType.serif(17, color: c.text)),
            Text(
                s == null
                    ? '${exercise['reps'] ?? '?'} reps'
                    : clock(Duration(seconds: s)),
                style: RbType.label(color: c.brandText, size: 12)),
          ]),
        ),
        if (s != null) ...[
          IconButton(
              tooltip: '5 seconds less',
              onPressed: s > 5 ? () => onSeconds(s - 5) : null,
              icon: const Icon(Icons.remove)),
          IconButton(
              tooltip: '5 seconds more',
              onPressed: () => onSeconds(s + 5),
              icon: const Icon(Icons.add)),
        ],
      ]),
    );
  }
}

/// Everything to buy for the picked recipes (each at its own servings), merged, tickable,
/// shareable.
class GroceryScreen extends StatefulWidget {
  const GroceryScreen({super.key, required this.recipes});
  final List<Discovery> recipes;

  @override
  State<GroceryScreen> createState() => _GroceryScreenState();
}

class _GroceryScreenState extends State<GroceryScreen> {
  final _have = <String>{};

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final t = Theme.of(context).textTheme;
    final lines = groceries([
      for (final r in widget.recipes)
        (
          title: r.title,
          ingredients: listOf(r.data['ingredients']),
          from: (r.data['servings'] as num?)?.toInt(),
          to: (r.data['servings'] as num?)?.toInt() ?? 1,
        ),
    ]);
    final text = lines.map((l) => '- ${l.text}').join('\n');
    return Scaffold(
      appBar: AppBar(title: const Text('Grocery list'), actions: [
        IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.ios_share),
            onPressed: () => shareOut(text)),
      ]),
      body: ListView(
          padding: const EdgeInsets.fromLTRB(RbSpace.side, 0, RbSpace.side, 32),
          children: [
            MonoLabel(
                '${count(widget.recipes.length, 'recipe')} · ${count(lines.length, 'item')}'),
            const SizedBox(height: 6),
            Text(widget.recipes.map((r) => r.title).join(' · '),
                style: t.bodySmall),
            const SizedBox(height: 12),
            for (final l in lines)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _have.contains(l.text),
                onChanged: (v) => setState(
                    () => v == true ? _have.add(l.text) : _have.remove(l.text)),
                title: Text(l.text,
                    style: t.bodyLarge?.copyWith(
                        color: _have.contains(l.text) ? c.faint : c.text,
                        decoration: _have.contains(l.text)
                            ? TextDecoration.lineThrough
                            : null)),
                subtitle:
                    l.recipes.length > 1 ? Text(l.recipes.join(' · ')) : null,
              ),
          ]),
    );
  }
}
