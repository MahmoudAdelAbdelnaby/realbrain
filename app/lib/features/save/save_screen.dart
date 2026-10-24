import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/native.dart';
import '../feed/feed_screen.dart' show sectionLabels;
import '../inbox/inbox_screen.dart' show fileUnder;

/// One save in full (P1-06 tap target): key frame, summary and every extracted item.
/// ponytail: plain generic rendering; each section gets its own card in P1-08..P1-13.
class SaveScreen extends StatelessWidget {
  const SaveScreen({super.key, required this.spaceId, required this.saveId});
  final String spaceId;
  final String saveId;

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance.doc('spaces/$spaceId/saves/$saveId');
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snap) {
        final save = snap.data?.data();
        final settled = save != null && !_processing.contains(save['status']);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Save'),
            actions: [
              if (settled)
                TextButton(
                  onPressed: () => changeSection(context, save),
                  child: const Text('Change section'),
                ),
            ],
          ),
          body: switch (snap) {
            AsyncSnapshot(hasError: true) =>
              _pad(Text('Could not open this save: ${snap.error}')),
            AsyncSnapshot(hasData: false) =>
              const Center(child: CircularProgressIndicator()),
            _ when save == null =>
              _pad(const Text('This save no longer exists.')),
            _ => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: ref.collection('items').snapshots(),
                builder: (context, items) => SaveDetail(
                  save: save,
                  items: [
                    for (final d in items.data?.docs ?? const []) d.data()
                  ],
                ),
              ),
          },
        );
      },
    );
  }
}

const _processing = {'received', 'uploaded', 'fetching', 'extracting'};

/// Re-file a save: a section re-reads the video with that hint; "None of these" keeps it as a
/// plain save (for things no section covers yet, like products before P3-02).
Future<void> changeSection(
    BuildContext context, Map<String, dynamic> save) async {
  final current = (save['sections'] as List?)?.cast<String>() ?? const [];
  final section = await showModalBottomSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(
            title: Text('File this under'),
            subtitle: Text('Reelbrain re-reads the video for that section.'),
          ),
          for (final e in sectionLabels.entries)
            ListTile(
              title: Text(e.value),
              trailing:
                  current.contains(e.key) ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(context, e.key),
            ),
          ListTile(
            title: const Text('None of these'),
            subtitle: const Text('Keep it as a plain save'),
            onTap: () => Navigator.pop(context, 'none'),
          ),
        ],
      ),
    ),
  );
  if (section != null && context.mounted) {
    await fileUnder(context, save, section);
  }
}

Widget _pad(Widget child) =>
    Padding(padding: const EdgeInsets.all(16), child: child);

/// The body, separate from Firestore so it can be tested with plain data.
class SaveDetail extends StatelessWidget {
  const SaveDetail({super.key, required this.save, required this.items});
  final Map<String, dynamic> save;
  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final frame = frameUrl(save['key_frame_url'] as String?);
    final source = save['source_url'] as String? ?? '';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (frame != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 9 / 16,
              child: Image.network(frame,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox()),
            ),
          ),
        const SizedBox(height: 12),
        Text(
            [save['creator'], save['platform']].whereType<String>().join(' · '),
            style: TextStyle(color: muted)),
        const SizedBox(height: 8),
        Text(save['summary'] as String? ?? save['step_text'] as String? ?? '',
            style: t.titleMedium),
        const SizedBox(height: 8),
        InkWell(
          onTap: () {
            Clipboard.setData(ClipboardData(text: source));
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Link copied')));
          },
          child: Text(source,
              style: TextStyle(
                  color: muted, decoration: TextDecoration.underline)),
        ),
        for (final item in items) ...[
          const Divider(height: 32),
          Text(sectionLabels[item['section']] ?? '${item['section']}',
              style: t.titleSmall),
          const SizedBox(height: 8),
          ..._lines(item).map((l) => Padding(
              padding: const EdgeInsets.only(bottom: 6), child: Text(l))),
        ],
      ],
    );
  }

  static String _at(Object? t) {
    final s = (t as num?)?.round();
    return s == null
        ? ''
        : '  (${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')})';
  }

  /// One readable line per extracted thing, with the second it appears in the reel.
  static List<String> _lines(Map<String, dynamic> item) {
    final d = (item['data'] as Map?)?.cast<String, dynamic>() ?? {};
    List<Map<String, dynamic>> list(String k) => [
          for (final x in (d[k] as List?) ?? const [])
            (x as Map).cast<String, dynamic>()
        ];
    return switch (item['section']) {
      'fact_check' => [
          for (final c in list('claims')) '• ${c['text']}${_at(c['t'])}'
        ],
      'tools' => [
          for (final x in list('items'))
            '• ${x['name']}${x['url_guess'] != null ? ' · ${x['url_guess']}' : ''}'
                '${x['snippet'] != null ? '\n   ${x['snippet']}' : ''}${_at(x['t'])}',
        ],
      'recipe' => [
          if (d['title'] != null)
            '${d['title']}${d['servings'] != null ? ' · serves ${d['servings']}' : ''}',
          for (final i in list('ingredients'))
            '• ${[
              i['qty'],
              i['unit'],
              i['name']
            ].where((v) => v != null).join(' ')}${i['estimated'] == true ? ' (estimated)' : ''}',
          for (final (n, s) in list('steps').indexed)
            '${n + 1}. ${s['text']}${_at(s['t'])}',
        ],
      'places' => [
          for (final p in list('items'))
            '• ${p['name']}${[
              p['area'],
              p['city']
            ].whereType<String>().isEmpty ? '' : ', ${[
                    p['area'],
                    p['city']
                  ].whereType<String>().join(', ')}'}'
                '${p['why_go'] != null ? '\n   ${p['why_go']}' : ''}${_at(p['t'])}',
        ],
      'workout' => [
          for (final e in list('exercises'))
            '• ${e['name']}: ${e['duration_s'] != null ? '${e['duration_s']} s' : '${e['reps'] ?? '?'} reps'}'
                '${e['sets'] != null ? ' × ${e['sets']}' : ''}${_at(e['t'])}',
        ],
      _ => ['$d'],
    };
  }
}
