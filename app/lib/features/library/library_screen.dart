import 'package:flutter/material.dart';

import '../../core/art/glyphs.dart';
import '../../core/categories.dart';
import '../../core/data/repo.dart';
import '../../core/format.dart';
import '../../core/theme/tokens.dart';
import '../../core/ui/components.dart';
import '../../core/ui/states.dart';
import '../places/places_map.dart';
import '../shared/open.dart';
import '../shared/tiles.dart';
import 'collections.dart';
import 'search.dart';

/// The Library (docs/DESIGN_V5.md §2.5): search first; then the index (categories as catalogue
/// drawers, with what's still open), your collections, and the ways to browse.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen(
      {super.key, required this.state, this.padding = EdgeInsets.zero});
  final BrainState state;
  final EdgeInsets padding;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _query = TextEditingController();
  final _focus = FocusNode();
  String? _status, _section, _source;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _searching =>
      _query.text.trim().isNotEmpty ||
      _status != null ||
      _section != null ||
      _source != null;

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final c = RbColors.of(context);
    final side = const EdgeInsets.symmetric(horizontal: RbSpace.side);
    return GestureDetector(
      onTap: () => _focus.unfocus(),
      child: ListView(
        padding: widget.padding,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          Padding(
            padding: side,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              MonoLabel(
                  'The archive · ${count(s.discoveries.length, 'discovery', 'discoveries')}'),
              const SizedBox(height: 10),
              Semantics(
                  header: true,
                  child: Text('Library',
                      style: RbType.serif(RbType.hero, color: c.text))),
              const SizedBox(height: 16),
              RbSearchField(
                controller: _query,
                focusNode: _focus,
                hint: 'Search everything you saved',
                onChanged: (_) => setState(() {}),
              ),
            ]),
          ),
          if (_searching || _focus.hasFocus)
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.fromLTRB(RbSpace.side, 6, RbSpace.side, 0),
                children: [
                  for (final e in statusFilters.entries) ...[
                    FilterPill(
                        label: e.value,
                        selected: _status == e.key,
                        onTap: () => setState(
                            () => _status = _status == e.key ? null : e.key)),
                    const SizedBox(width: 8),
                  ],
                  for (final p in const [
                    'tiktok',
                    'instagram',
                    'youtube',
                    'idea'
                  ]) ...[
                    FilterPill(
                        label: platformName(p),
                        selected: _source == p,
                        onTap: () =>
                            setState(() => _source = _source == p ? null : p)),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          if (_searching) ..._results(context, s) else ..._index(context, s),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  List<Widget> _results(BuildContext context, BrainState s) {
    final q = _query.text.trim();
    final found = [
      for (final d in s.discoveries)
        if (matches(d, q) &&
            statusMatches(d, _status) &&
            (_section == null || d.section == _section) &&
            (_source == null || d.platform == _source))
          d
    ];
    final plain = _status == null && _section == null && q.isNotEmpty
        ? [
            for (final p in s.plain)
              if (saveMatches(p, q) &&
                  (_source == null || p['platform'] == _source))
                p
          ]
        : const <Json>[];
    final bySection = <String, int>{};
    for (final d in found) {
      bySection[d.section] = (bySection[d.section] ?? 0) + 1;
    }
    return [
      if (bySection.length > 1 || _section != null)
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.fromLTRB(RbSpace.side, 6, RbSpace.side, 0),
            children: [
              for (final cat in categories)
                if (bySection.containsKey(cat.id) || _section == cat.id) ...[
                  FilterPill(
                      label: cat.name,
                      glyph: cat.id,
                      count: bySection[cat.id],
                      selected: _section == cat.id,
                      onTap: () => setState(
                          () => _section = _section == cat.id ? null : cat.id)),
                  const SizedBox(width: 8),
                ],
            ],
          ),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(RbSpace.side, 14, RbSpace.side, 4),
        child: Row(children: [
          Expanded(
            child: MonoLabel(found.isEmpty && plain.isEmpty
                ? 'No matches'
                : count(found.length + plain.length, 'match', 'matches')),
          ),
          if (found.length > 1)
            RbButton.quiet('Browse',
                small: true,
                glyph: Glyphs.browse,
                onPressed: () => openViewer(context, found,
                    title: q.isEmpty ? 'Filtered' : '“$q”')),
        ]),
      ),
      if (found.isEmpty && plain.isEmpty)
        EmptyState(
          compact: true,
          title: 'Nothing matches',
          body: q.isEmpty
              ? 'Try another filter.'
              : 'Search looks through titles, transcripts, ingredients, tools, places, titles '
                  'and notes. Try fewer words.',
        ),
      for (final d in found) DiscoveryRow(d, within: found),
      for (final p in plain) _PlainRow(save: p),
    ];
  }

  List<Widget> _index(BuildContext context, BrainState s) {
    final c = RbColors.of(context);
    final per = <String, List<Discovery>>{};
    for (final d in s.discoveries) {
      (per[d.section] ??= []).add(d);
    }
    final open = [
      for (final d in s.discoveries)
        if (d.isOpen) d
    ];
    final places = s.inCategory('places');
    return [
      SizedBox(
        height: 56,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(RbSpace.side, 8, RbSpace.side, 0),
          children: [
            RbButton.secondary('Browse what’s open',
                small: true,
                glyph: Glyphs.browse,
                onPressed: open.isEmpty
                    ? null
                    : () => openViewer(context, open, title: 'Open')),
            const SizedBox(width: 8),
            if (places.isNotEmpty) ...[
              RbButton.secondary('Map',
                  small: true,
                  glyph: Glyphs.map,
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const PlacesMapScreen()))),
              const SizedBox(width: 8),
            ],
            RbButton.secondary(
                s.processing.isEmpty && s.attention.isEmpty
                    ? 'Arriving'
                    : 'Arriving · ${s.processing.length + s.attention.length}',
                small: true,
                glyph: Glyphs.arriving,
                onPressed: () => openArriving(context)),
          ],
        ),
      ),
      const SizedBox(height: 22),
      const ShelfHeader(index: 'Index', title: 'Categories'),
      if (!s.loaded)
        const LoadingMark()
      else if (s.discoveries.isEmpty)
        const EmptyState(
            compact: true,
            title: 'Nothing catalogued yet',
            body: 'Everything you save is filed here by what it is.')
      else
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: RbSpace.side),
          child: LayoutBuilder(builder: (context, box) {
            final cols = box.maxWidth > 560 ? 3 : 2;
            final w = (box.maxWidth - (cols - 1) * 12) / cols;
            return Wrap(spacing: 12, runSpacing: 12, children: [
              for (final cat in categories)
                SizedBox(
                    width: w,
                    child: _Drawer(cat: cat, items: per[cat.id] ?? const [])),
            ]);
          }),
        ),
      const SizedBox(height: 32),
      ShelfHeader(
          index: 'Kept together',
          title: 'Collections',
          caption: s.lists.isEmpty
              ? 'Routines, grocery lists, watchlists: pick several in a category to make one.'
              : null),
      if (s.lists.isNotEmpty)
        SizedBox(
          height: 128,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: RbSpace.side),
            itemCount: s.lists.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) => CollectionCard(list: s.lists[i]),
          ),
        ),
      if (s.plain.isNotEmpty) ...[
        const SizedBox(height: 32),
        ShelfHeader(
            index: 'Unfiled',
            title: 'Plain saves',
            caption: 'Kept as links, with no category.'),
        for (final p in s.plain.take(5)) _PlainRow(save: p),
      ],
      Padding(
        padding: const EdgeInsets.fromLTRB(RbSpace.side, 28, RbSpace.side, 0),
        child: Text(
            'Realbrain files each save by what it is. Wrong? Open it and choose “File under another category”.',
            style: TextStyle(fontSize: 12.5, color: c.faint)),
      ),
    ];
  }
}

/// One category as a catalogue drawer: its glyph, name, count, and what's still open.
class _Drawer extends StatelessWidget {
  const _Drawer({required this.cat, required this.items});
  final Category cat;
  final List<Discovery> items;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final t = Theme.of(context).textTheme;
    final open = items.where((d) => d.isOpen).length;
    final done = items.where((d) => d.isDone).length;
    final pigment = c.pigment(cat.id);
    final empty = items.isEmpty;
    return Semantics(
      button: true,
      label: '${cat.name}: ${items.length}, $open open',
      excludeSemantics: true,
      child: Pressable(
        onTap: () => openCategory(context, cat.id),
        child: Container(
          height: 128,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(RbSpace.cardRadius),
            border: Border.all(color: c.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(children: [
            // The drawer's label strip in the category pigment.
            Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: Container(height: 3, color: empty ? c.line : pigment)),
            PositionedDirectional(
              end: -22,
              bottom: -24,
              child: Glyph(cat.id,
                  size: 96,
                  color: (empty ? c.faint : pigment).withValues(alpha: 0.11),
                  weight: 1.1),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Glyph(cat.id,
                          size: 22,
                          color: empty ? c.faint : pigment,
                          weight: 1.7),
                      const Spacer(),
                      Text('${items.length}',
                          style: RbType.monoNumber(18,
                              color: empty ? c.faint : c.text)),
                    ]),
                    const Spacer(),
                    Text(cat.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            RbType.serif(19, color: empty ? c.muted : c.text)),
                    const SizedBox(height: 2),
                    Text(
                        empty
                            ? 'Nothing yet'
                            : [
                                if (open > 0) '$open open',
                                if (done > 0) '$done done'
                              ].join(' · '),
                        style: t.bodySmall),
                  ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _PlainRow extends StatelessWidget {
  const _PlainRow({required this.save});
  final Json save;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final t = Theme.of(context).textTheme;
    final url = save['source_url'] as String?;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: RbSpace.side),
      leading: Glyph(Glyphs.bookmark, color: c.muted),
      title: Text(save['summary'] as String? ?? url ?? 'Saved',
          maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodyMedium),
      subtitle:
          Text(platformName(save['platform'] as String?), style: t.bodySmall),
      onTap: () => openSave(context, save['save_id'] as String),
    );
  }
}
