import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../factcheck/fact_check_view.dart';
import '../feed/feed_screen.dart' show sectionLabels;
import '../save/save_screen.dart';

/// Status choices per section (Backend contract user_state values).
const statusChoices = {
  'tools': {
    'to_try': 'To try',
    'tried': 'Tried',
    'using': 'Using',
    'not_useful': 'Not useful'
  },
  'recipe': {'to_try': 'To try', 'cooked': 'Cooked'},
  'places': {'to_try': 'To try', 'visited': 'Visited'},
  'workout': {'to_try': 'To try', 'done': 'Done'},
  'fact_check': {'to_try': 'To read', 'done': 'Read'},
};

const toolKinds = {
  'github_repo': 'GitHub repo',
  'website': 'Website',
  'app': 'App',
  'cli': 'CLI',
  'library': 'Library',
  'extension': 'Extension',
};

/// Sets an item's state (the only item field the rules let the app write).
Future<void> setItemState(Map<String, dynamic> item, String? state) =>
    FirebaseFirestore.instance
        .doc(
            'spaces/${item['space_id']}/saves/${item['save_id']}/items/${item['item_id']}')
        .update({'user_state': state});

/// One section across your spaces (opened from a feed counter). Live from the feed's listener.
class SectionScreen extends StatelessWidget {
  const SectionScreen({super.key, required this.section, required this.items});
  final String section;
  final ValueListenable<List<Map<String, dynamic>>> items;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(sectionLabels[section] ?? section)),
      body: ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: items,
        builder: (context, all, _) => SectionList(
          section: section,
          items: [
            for (final i in all)
              if (i['section'] == section) i,
          ]..sort((a, b) => ((b['created_at'] ?? 0) as num)
              .compareTo((a['created_at'] ?? 0) as num)),
        ),
      ),
    );
  }
}

class SectionList extends StatefulWidget {
  const SectionList({super.key, required this.section, required this.items});
  final String section;
  final List<Map<String, dynamic>> items;

  @override
  State<SectionList> createState() => _SectionListState();
}

class _SectionListState extends State<SectionList> {
  String? _kind; // tools filter

  @override
  Widget build(BuildContext context) {
    final tools = widget.section == 'tools';
    final kinds = {
      if (tools)
        for (final i in widget.items)
          for (final t in _tools(i)) (t['kind'] as String?) ?? 'other',
    };
    if (widget.items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
            'Nothing here yet. Share a reel and it lands in the right section.'),
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        if (tools && kinds.length > 1)
          Wrap(spacing: 8, children: [
            ChoiceChip(
                label: const Text('All'),
                selected: _kind == null,
                onSelected: (_) => setState(() => _kind = null)),
            for (final k in kinds)
              ChoiceChip(
                label: Text(toolKinds[k] ?? 'Other'),
                selected: _kind == k,
                onSelected: (_) => setState(() => _kind = k),
              ),
          ]),
        for (final item in widget.items)
          if (!tools ||
              _kind == null ||
              _tools(item)
                  .any((t) => ((t['kind'] as String?) ?? 'other') == _kind))
            _ItemCard(item: item, kind: _kind),
      ],
    );
  }
}

List<Map<String, dynamic>> _tools(Map<String, dynamic> item) => [
      for (final t in ((item['data'] as Map?)?['items'] as List?) ?? const [])
        (t as Map).cast<String, dynamic>(),
    ];

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, this.kind});
  final Map<String, dynamic> item;
  final String? kind;

  @override
  Widget build(BuildContext context) {
    final section = item['section'] as String;
    final data = (item['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    final choices = statusChoices[section] ?? const {};
    final state = item['user_state'] as String?;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (section == 'tools') ...[
              for (final t in _tools(item))
                if (kind == null || ((t['kind'] as String?) ?? 'other') == kind)
                  ToolTile(tool: t),
            ] else if (section == 'fact_check')
              FactCheckView(saveId: item['save_id'] as String?, data: data)
            else
              ...SaveDetail.itemLines(item).map((l) => Padding(
                  padding: const EdgeInsets.only(bottom: 4), child: Text(l))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final e in choices.entries)
                  ChoiceChip(
                    label: Text(e.value),
                    selected: (state ?? 'to_try') == e.key,
                    onSelected: item['item_id'] == null
                        ? null
                        : (_) => setItemState(item, e.key),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => SaveScreen(
                        spaceId: item['space_id'] as String,
                        saveId: item['save_id'] as String),
                  )),
                  child: const Text('Open save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _ago(String? iso) {
  final d = iso == null ? null : DateTime.tryParse(iso);
  if (d == null) return '';
  final days = DateTime.now().difference(d).inDays;
  return days < 1
      ? 'updated today'
      : days < 60
          ? 'updated $days days ago'
          : 'updated ${days ~/ 30} months ago';
}

String _stars(num n) =>
    n >= 1000 ? '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}k' : '$n';

/// One tool: name, link check, what it was used for, snippet with Copy, Open.
class ToolTile extends StatelessWidget {
  const ToolTile({super.key, required this.tool});
  final Map<String, dynamic> tool;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final v = (tool['verified'] as Map?)?.cast<String, dynamic>();
    final url = (v?['url'] ?? tool['url_guess']) as String?;
    final check = switch (v) {
      null => 'Link not checked',
      {'source': 'github', 'matched_by': 'name'} =>
        'Found on GitHub by name, check it is the right one',
      {'source': 'github', 'stars': final num stars} =>
        '★ ${_stars(stars)} · ${_ago(v['last_commit'] as String?)}',
      {'ok': true} => 'Link checked',
      _ => 'Link broken or guessed',
    };
    final snippet = tool['snippet'] as String?;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${tool['name']}',
              style: Theme.of(context).textTheme.titleSmall),
          Text(check, style: TextStyle(color: muted, fontSize: 12)),
          if (tool['use_shown'] != null)
            Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('${tool['use_shown']}')),
          if (snippet != null && snippet.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsetsDirectional.fromSTEB(10, 4, 4, 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                Expanded(
                  child: Text(snippet,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 13),
                      textDirection: TextDirection.ltr),
                ),
                IconButton(
                  tooltip: 'Copy',
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: snippet));
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('Copied')));
                  },
                ),
              ]),
            ),
          if (url != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => openUrl(context, url),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text(Uri.tryParse(url)?.host ?? url),
              ),
            ),
        ],
      ),
    );
  }
}
