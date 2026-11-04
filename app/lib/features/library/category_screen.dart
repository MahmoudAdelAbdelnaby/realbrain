import 'package:flutter/material.dart';

import '../../core/art/glyphs.dart';
import '../../core/categories.dart';
import '../../core/data/repo.dart';
import '../../core/format.dart';
import '../../core/native.dart' show apiError;
import '../../core/theme/tokens.dart';
import '../../core/ui/components.dart';
import '../../core/ui/states.dart';
import '../places/places_map.dart';
import '../shared/open.dart';
import '../shared/tiles.dart';
import 'collections.dart';
import 'search.dart';

/// One category: its plate, counts, the filters that matter for it (recipe tags, tool kinds,
/// Movies/Series/Books, product status, cities), list or map, and picking several to make a
/// collection (grocery list, routine, watchlist...).
class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key, required this.section});
  final String section;

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  String? _status, _facet;
  bool _map = false;
  final _picked = <String>{};
  bool _picking = false;

  Category get cat => categoryOf(widget.section);

  /// The category's own facet values for a discovery.
  Set<String> _facets(Discovery d) {
    switch (d.section) {
      case 'recipe':
        return {for (final t in (d.data['tags'] as List?) ?? const []) '$t'};
      case 'tools':
        return {
          for (final t in listOf(d.data['items']))
            cat.kinds[t['kind']] ?? 'Other'
        };
      case 'entertainment':
        return {
          for (final e in listOf(d.data['items']))
            cat.kinds[e['kind']] ?? 'Other'
        };
      case 'places':
        return {
          for (final p in listOf(d.data['items']))
            if (p['city'] != null) '${p['city']}'
        };
      case 'products':
        return {
          for (final p in listOf(d.data['items']))
            if (p['merchant'] != null) '${p['merchant']}'
        };
    }
    return const {};
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BrainState>(
      valueListenable: Repo.instance.state,
      builder: (context, s, _) {
        final c = RbColors.of(context);
        final t = Theme.of(context).textTheme;
        final all = s.inCategory(widget.section);
        final facetCounts = <String, int>{};
        for (final d in all) {
          for (final f in _facets(d)) {
            facetCounts[f] = (facetCounts[f] ?? 0) + 1;
          }
        }
        final facets = (facetCounts.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .take(8)
            .map((e) => e.key)
            .toList();
        final shown = [
          for (final d in all)
            if (statusMatches(d, _status) &&
                (_facet == null || _facets(d).contains(_facet)))
              d
        ];
        final open = all.where((d) => d.isOpen).length;
        final done = all.where((d) => d.isDone).length;
        final lists = [
          for (final l in s.lists)
            if (l['section'] == widget.section) l
        ];
        final pigment = c.pigment(widget.section);
        final places = widget.section == 'places';
        return Scaffold(
          appBar: AppBar(
            title: Text(cat.name),
            actions: [
              if (places)
                IconButton(
                  tooltip: _map ? 'List' : 'Map',
                  onPressed: () => setState(() => _map = !_map),
                  icon: _map
                      ? const Icon(Icons.view_agenda_outlined)
                      : Glyph(Glyphs.map, color: c.text),
                ),
              if (shown.length > 1 && !_map)
                IconButton(
                  tooltip: 'Browse',
                  onPressed: () => openViewer(context, shown, title: cat.name),
                  icon: Glyph(Glyphs.browse, color: c.text),
                ),
            ],
          ),
          body: _map
              ? PlacesMap(discoveries: shown)
              : ListView(
                  padding: const EdgeInsets.only(bottom: 120),
                  children: [
                      // The plate header.
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            RbSpace.side, 4, RbSpace.side, 0),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      MonoLabel(count(all.length, cat.noun),
                                          color: pigment),
                                      const SizedBox(height: 6),
                                      Text(cat.name,
                                          style: RbType.serif(RbType.hero,
                                              color: c.text)),
                                      const SizedBox(height: 4),
                                      Text('$open open · $done ${cat.verb}',
                                          style: t.bodySmall),
                                    ]),
                              ),
                              Glyph(widget.section,
                                  size: 64, color: pigment, weight: 1.1),
                            ]),
                      ),
                      if (lists.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 128,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(
                                horizontal: RbSpace.side),
                            itemCount: lists.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, i) =>
                                CollectionCard(list: lists[i]),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 52,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.fromLTRB(
                              RbSpace.side, 6, RbSpace.side, 0),
                          children: [
                            for (final st in cat.stamps
                                .where((st) => st.state != 'not_useful')) ...[
                              FilterPill(
                                label: st.label,
                                selected: _status == _filterFor(st),
                                onTap: () => setState(() => _status =
                                    _status == _filterFor(st)
                                        ? null
                                        : _filterFor(st)),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (facets.isNotEmpty)
                              Container(
                                  width: 1,
                                  margin: const EdgeInsets.symmetric(
                                      vertical: 12, horizontal: 4),
                                  color: c.line),
                            for (final f in facets) ...[
                              FilterPill(
                                  label: f,
                                  count: facetCounts[f],
                                  selected: _facet == f,
                                  onTap: () => setState(
                                      () => _facet = _facet == f ? null : f)),
                              const SizedBox(width: 8),
                            ],
                          ],
                        ),
                      ),
                      if (cat.collection != null && shown.isNotEmpty)
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(RbSpace.side, 4, 8, 0),
                          child: Row(children: [
                            Expanded(
                              child: Text(
                                  _picking
                                      ? (_picked.isEmpty
                                          ? 'Tap to pick'
                                          : '${_picked.length} picked')
                                      : count(shown.length, cat.noun),
                                  style: t.bodySmall),
                            ),
                            TextButton(
                              onPressed: () => setState(() {
                                _picking = !_picking;
                                _picked.clear();
                              }),
                              child: Text(_picking
                                  ? 'Cancel'
                                  : 'Make a ${cat.collection!.toLowerCase()}'),
                            ),
                          ]),
                        ),
                      if (all.isEmpty)
                        EmptyState(
                          title: 'No ${cat.name.toLowerCase()} yet',
                          body:
                              'Share a reel with ${_example(widget.section)} and it lands here, '
                              'ready to use.',
                        )
                      else if (shown.isEmpty)
                        const EmptyState(
                            compact: true, title: 'Nothing with these filters')
                      else
                        for (final d in shown)
                          _picking
                              ? DiscoveryRow(d,
                                  within: shown,
                                  onTap: () => setState(() =>
                                      _picked.contains(d.key)
                                          ? _picked.remove(d.key)
                                          : _picked.add(d.key)),
                                  trailing: Checkbox(
                                      value: _picked.contains(d.key),
                                      onChanged: (v) => setState(() => v == true
                                          ? _picked.add(d.key)
                                          : _picked.remove(d.key))))
                              : DiscoveryRow(d, within: shown),
                    ]),
          bottomNavigationBar: _picking && _picked.isNotEmpty
              ? SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        RbSpace.side, 8, RbSpace.side, 8),
                    child: RbButton(
                      'Make ${cat.collection!.toLowerCase()} from ${_picked.length}',
                      expand: true,
                      glyph: Glyphs.collection,
                      onPressed: () => _make(context, all),
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }

  String? _filterFor(Stamp st) => st.done
      ? 'done'
      : st.active
          ? 'active'
          : 'open';

  static String _example(String section) => switch (section) {
        'recipe' => 'a dish',
        'workout' => 'a workout',
        'places' => 'a restaurant or a place',
        'tools' => 'an app, a site or a repo',
        'fact_check' => 'a claim worth checking',
        'ideas' => 'a good idea',
        'entertainment' => 'a film, a series or a book',
        'products' => 'a product',
        _ => 'it',
      };

  Future<void> _make(BuildContext context, List<Discovery> all) async {
    final picked = [
      for (final d in all)
        if (_picked.contains(d.key)) d
    ];
    if (widget.section == 'recipe') {
      // A grocery list is computed, not stored: open it straight away.
      await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => GroceryScreen(recipes: picked)));
      return;
    }
    final name = TextEditingController(
        text: widget.section == 'workout'
            ? 'My routine'
            : 'My ${cat.collection!.toLowerCase()}');
    final ok = await showRbSheet<bool>(context,
        title: 'Name it',
        kicker: cat.collection,
        builder: (sheet) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: RbSpace.side),
              child: Column(children: [
                TextField(controller: name, autofocus: true, maxLength: 60),
                const SizedBox(height: 8),
                RbButton('Save',
                    expand: true, onPressed: () => Navigator.pop(sheet, true)),
              ]),
            ));
    if (ok != true || !context.mounted) return;
    try {
      await Repo.instance.createCollection(
          section: widget.section,
          name: name.text.trim(),
          refs: [for (final d in picked) d.key]);
      if (!context.mounted) return;
      setState(() {
        _picking = false;
        _picked.clear();
      });
      toast(context, 'Saved “${name.text.trim()}”');
    } catch (e) {
      if (context.mounted) toast(context, apiError(e));
    }
  }
}
