import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/native.dart';
import '../save/save_screen.dart';
import '../save/saves_screen.dart';
import '../spaces/household_screen.dart';

/// Section ids from the AI contract, named in words (Design system: sections have no colours).
const sectionLabels = {
  'fact_check': 'Fact Check',
  'tools': 'Dev and Tools',
  'recipe': 'Recipes',
  'places': 'Places',
  'workout': 'Workouts',
};

const _processing = {
  'received',
  'uploaded',
  'fetching',
  'extracting',
  'enriching'
};

/// Items you haven't acted on yet (no state, or explicitly "to try"), per section.
Map<String, int> toTryCounts(Iterable<Map<String, dynamic>> items) {
  final counts = <String, int>{};
  for (final item in items) {
    final state = item['user_state'];
    if (state == null || state == 'to_try') {
      final section = item['section'] as String? ?? '?';
      counts[section] = (counts[section] ?? 0) + 1;
    }
  }
  return counts;
}

/// Home feed (P1-05): saves from every space you're in, live from Firestore, newest first.
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _subs = <StreamSubscription<Object?>>[];
  final _saves = <String, List<Map<String, dynamic>>>{}; // per space
  final _items = <String, List<Map<String, dynamic>>>{}; // per space
  Map<String, String> _spaces = {}; // label -> space id
  String? _error;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    _subs.add(
        FirebaseFirestore.instance.doc('users/$uid').snapshots().listen((snap) {
      final spaces =
          (snap.data()?['spaces'] as Map?)?.cast<String, String>() ?? {};
      if (spaces.toString() != _spaces.toString()) _listen(spaces);
      if (spaces.isEmpty) {
        setState(() => _loaded = true); // backend not reached yet
      }
    }, onError: _fail));
  }

  void _listen(Map<String, String> spaces) {
    for (final s in _subs.skip(1)) {
      s.cancel();
    }
    _subs.removeRange(1, _subs.length);
    _saves.clear();
    _items.clear();
    _spaces = spaces;
    final db = FirebaseFirestore.instance;
    for (final id in spaces.values.toSet()) {
      _subs.add(db
          .collection('spaces/$id/saves')
          .orderBy('created_at', descending: true)
          .limit(50)
          .snapshots()
          .listen(
              (q) => setState(() {
                    _saves[id] = [for (final d in q.docs) d.data()];
                    _loaded = true;
                  }),
              onError: _fail));
      _subs.add(db
          .collectionGroup('items')
          .where('space_id', isEqualTo: id)
          .snapshots()
          .listen(
              (q) => setState(
                  () => _items[id] = [for (final d in q.docs) d.data()]),
              onError: _fail));
    }
  }

  void _fail(Object e) {
    if (mounted) setState(() => _error = '$e');
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  Future<void> _refresh() async {
    // Firestore is already live; refreshing resends saves that waited on the phone.
    await native.invokeMethod('retryWaiting');
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  @override
  Widget build(BuildContext context) {
    final labelOf = {for (final e in _spaces.entries) e.value: e.key};
    final saves = [for (final list in _saves.values) ...list]..sort((a, b) =>
        ((b['created_at'] ?? 0) as num)
            .compareTo((a['created_at'] ?? 0) as num));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reelbrain'),
        actions: [
          IconButton(
            tooltip: 'Phone queue',
            icon: const Icon(Icons.download_outlined),
            onPressed: () => _push(const SavesScreen()),
          ),
          IconButton(
            tooltip: 'Spaces',
            icon: const Icon(Icons.group_outlined),
            onPressed: () => _push(const HouseholdScreen()),
          ),
          PopupMenuButton<String>(
            onSelected: (_) => FirebaseAuth.instance.signOut(),
            itemBuilder: (_) =>
                const [PopupMenuItem(value: 'out', child: Text('Sign out'))],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FeedList(
          saves: saves,
          counts: toTryCounts([for (final list in _items.values) ...list]),
          spaceLabel: (id) => labelOf[id] == 'home' ? 'Home' : 'Me',
          loading: !_loaded,
          error: _error,
        ),
      ),
    );
  }

  void _push(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
}

/// The feed body, separate from Firestore so it can be tested with plain data.
class FeedList extends StatelessWidget {
  const FeedList({
    super.key,
    required this.saves,
    required this.counts,
    required this.spaceLabel,
    this.loading = false,
    this.error,
  });

  final List<Map<String, dynamic>> saves;
  final Map<String, int> counts;
  final String Function(String spaceId) spaceLabel;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      if (error != null) _Note('Could not load your saves. $error'),
      if (counts.isNotEmpty) _Counters(counts),
      if (loading) ...[const SkeletonCard(), const SkeletonCard()],
      if (!loading && saves.isEmpty && error == null)
        const _Note(
            'Nothing saved yet. Share a reel from TikTok, Instagram or YouTube '
            'to Reelbrain · Me or Reelbrain · Home.'),
      for (final s in saves)
        SaveCard(save: s, space: spaceLabel(s['space_id'] as String? ?? '')),
    ];
    // Always scrollable, so pull-to-refresh works on a short or empty feed.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: children,
    );
  }
}

class _Counters extends StatelessWidget {
  const _Counters(this.counts);
  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) {
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final e in entries)
            Chip(label: Text('${sectionLabels[e.key] ?? e.key} ${e.value}')),
        ],
      ),
    );
  }
}

/// One save. While processing it shows the live step text over flat grey bars at the final
/// layout's size (Design system: no shimmer).
class SaveCard extends StatelessWidget {
  const SaveCard({super.key, required this.save, required this.space});
  final Map<String, dynamic> save;
  final String space;

  @override
  Widget build(BuildContext context) {
    final status = save['status'] as String? ?? 'received';
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final meta = [
      space,
      if (save['platform'] != null) _platform(save['platform'] as String),
      if (save['creator'] != null) save['creator'] as String,
    ].join(' · ');
    final processing = _processing.contains(status);
    final sections = (save['sections'] as List?)?.cast<String>() ?? const [];
    final flag = switch (status) {
      'needs_review' => 'Needs review: no clear section',
      'partial' => 'Caption only: the video could not be fetched',
      'failed' => 'Failed: ${save['step_text'] ?? 'unknown error'}',
      _ => null,
    };
    final saveId = save['save_id'] as String?;
    final spaceId = save['space_id'] as String?;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: saveId == null || spaceId == null
            ? null
            : () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => SaveScreen(spaceId: spaceId, saveId: saveId),
                )),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Frame(stored: save['key_frame_url'] as String?),
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(meta, style: TextStyle(color: muted, fontSize: 12)),
                    const SizedBox(height: 4),
                    if (processing) ...[
                      Text(save['step_text'] as String? ?? 'Waiting to start',
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      const _Bar(widthFactor: 0.9),
                      const SizedBox(height: 6),
                      const _Bar(widthFactor: 0.6),
                    ] else ...[
                      Text(
                        save['summary'] as String? ??
                            save['source_url'] as String? ??
                            '',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (sections.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                            sections
                                .map((s) => sectionLabels[s] ?? s)
                                .join(' · '),
                            style: TextStyle(color: muted, fontSize: 12)),
                      ],
                      if (flag != null) ...[
                        const SizedBox(height: 6),
                        Text(flag,
                            style: TextStyle(
                                color: status == 'failed'
                                    ? Theme.of(context).colorScheme.error
                                    : muted,
                                fontSize: 12)),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _platform(String p) => switch (p) {
        'tiktok' => 'TikTok',
        'instagram' => 'Instagram',
        'youtube' => 'YouTube',
        _ => p,
      };
}

class _Frame extends StatelessWidget {
  const _Frame({this.stored});
  final String? stored;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const SizedBox.expand(),
    );
    // Rebuilds when the backend's address arrives or changes (relative frame paths).
    return ValueListenableBuilder<String?>(
      valueListenable: backendUrl,
      builder: (context, _, __) {
        final url = frameUrl(stored);
        return SizedBox(
          width: 88,
          height: 132, // 2:3, close to a 9:16 reel frame cropped for the list
          child: url == null
              ? placeholder
              : Image.network(url,
                  fit: BoxFit.cover, errorBuilder: (_, __, ___) => placeholder),
        );
      },
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.widthFactor});
  final double widthFactor;

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
        widthFactor: widthFactor,
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          height: 12,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      );
}

/// Loading placeholder at the size of a real card.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) =>
      const SaveCard(save: {'status': 'received', 'step_text': ' '}, space: '');
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 24), child: Text(text));
}
