import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/brain_mark.dart';
import '../../core/nav_bar.dart';
import '../../core/native.dart';
import '../../core/surface.dart';
import '../../core/theme/gallery.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets.dart';
import '../factcheck/fact_check_view.dart' show verdictLabels;
import '../inbox/inbox_screen.dart';
import '../library/library_screen.dart';
import '../places/places_map.dart';
import '../reels/reels_screen.dart';
import '../save/save_screen.dart';
import '../save/saves_screen.dart';
import '../section/section_screen.dart';
import '../settings/settings_screen.dart';
import '../spaces/household_screen.dart';
import 'lanes.dart';

/// Section ids from the AI contract, named in words.
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

/// The app shell (design v4): Home, Memories, Recall and Threads, live from Firestore, with the
/// + button and the processing status above the tab bar.
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
  final _inbox = ValueNotifier<List<Map<String, dynamic>>>(const []);
  final _allItems = ValueNotifier<List<Map<String, dynamic>>>(const []);

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
    _inbox.dispose();
    _allItems.dispose();
    _flashTimer?.cancel();
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
    String spaceLabel(String id) => labelOf[id] == 'home' ? 'Home' : 'Me';
    final inbox = saves.where(inInbox).toList();
    // The Inbox and section screens listen to these, so they stay live while open.
    final allItems = [for (final list in _items.values) ...list];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inbox.value = inbox;
      _allItems.value = allItems;
    });
    final processing =
        saves.where((s) => _processing.contains(s['status'])).toList();
    _trackReady(saves);
    final flash = _flash;
    final PillStatus? status = processing.isNotEmpty
        ? _pillStatus(processing.first,
            processing.first['step_text'] as String? ?? 'Understanding…')
        : flash != null
            ? _pillStatus(flash, _readyLine(flash))
            : null;
    if (_loaded && _known == null) {
      _known = {for (final s in saves) s['save_id'] as String? ?? ''};
    }
    final ready = waiting(allItems, saves);
    final recall = waiting(allItems, saves, olderThan: _recallAfter);
    final pad = EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 12, bottom: _barRoom + 16);
    final tabs = [
      RefreshIndicator(
        onRefresh: _refresh,
        child: _brain(context, saves, allItems, inbox, ready, recall,
            spaceLabel, pad),
      ),
      _memories(context, saves, allItems, spaceLabel, pad),
      _recallTab(context, recall, pad),
      _threads(context, allItems, pad),
    ];
    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (popped, _) {
        if (!popped) {
          setState(() => _tab = 0); // Back from a tab goes Home first
        }
      },
      child: Scaffold(
        extendBody: true,
        body: IndexedStack(index: _tab, children: tabs),
        bottomNavigationBar: NavBar(
          selected: _tab,
          onSelect: (i) => setState(() => _tab = i),
          onCreate: () => addLink(context),
          status: status,
          destinations: [
            (
              icon: (c) => BrainMark(size: 26, color: c),
              label: 'Home',
              badge: 0
            ),
            (
              icon: (c) => Icon(Icons.layers_outlined, color: c, size: 24),
              label: 'Memories',
              badge: 0
            ),
            (
              icon: (c) => Icon(Icons.history, color: c, size: 24),
              label: 'Recall',
              badge: recall.length
            ),
            (
              icon: (c) => Icon(Icons.hub_outlined, color: c, size: 24),
              label: 'Threads',
              badge: 0
            ),
          ],
        ),
      ),
    );
  }

  /// Brain (Home): greeting, the three numbers, Ready for you, then the section lanes.
  Widget _brain(
      BuildContext context,
      List<Map<String, dynamic>> saves,
      List<Map<String, dynamic>> allItems,
      List<Map<String, dynamic>> inbox,
      List<WaitingCard> ready,
      List<WaitingCard> recall,
      String Function(String) spaceLabel,
      EdgeInsets pad) {
    final t = Theme.of(context).textTheme;
    final c = RbColors.of(context);
    final lanes = lanesOf(allItems, saves);
    const side = EdgeInsets.symmetric(horizontal: RbSpace.side);
    final name = (FirebaseAuth.instance.currentUser?.displayName ?? '')
        .trim()
        .split(' ')
        .first;
    final hour = DateTime.now().hour;
    final hello = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: pad,
      children: [
        Padding(
          padding: side,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              // Long-press the greeting for the hidden design gallery (P1-01).
              child: GestureDetector(
                onLongPress: () => _push(const DesignGallery()),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name.isEmpty ? '$hello.' : '$hello,\n$name',
                          style: t.headlineMedium),
                      const SizedBox(height: 6),
                      Text(
                          ready.isEmpty
                              ? 'Share a reel and your brain takes it from there.'
                              : 'Your brain found ${ready.length} '
                                  'thing${ready.length == 1 ? '' : 's'} worth your attention.',
                          style: t.bodyMedium?.copyWith(color: c.muted)),
                    ]),
              ),
            ),
            _AccountMenu(onOpen: _push),
          ]),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: side,
          child: Row(children: [
            _Stat('${ready.length}', 'New items'),
            const SizedBox(width: 10),
            _Stat('${saves.length}', 'Memories',
                onTap: () => setState(() => _tab = 1)),
            const SizedBox(width: 10),
            _Stat('${recall.length}', 'To revisit',
                onTap: () => setState(() => _tab = 2)),
          ]),
        ),
        const SizedBox(height: 20),
        if (inbox.isNotEmpty)
          _NeedsALook(
              count: inbox.length,
              onTap: () =>
                  _push(InboxScreen(saves: _inbox, spaceLabel: spaceLabel))),
        if (_error != null)
          EmptyState(title: 'Could not load your saves', body: _error),
        if (!_loaded) const Padding(padding: side, child: SkeletonCard()),
        if (_loaded && saves.isEmpty && _error == null)
          const EmptyState(
              title: 'Nothing saved yet',
              body: 'Share a reel from TikTok, Instagram or YouTube '
                  'to Realbrain · Me or Realbrain · Home, or tap +.'),
        if (ready.isNotEmpty) ...[
          Padding(
            padding:
                const EdgeInsetsDirectional.fromSTEB(RbSpace.side, 0, 4, 8),
            child: Row(children: [
              Expanded(child: Text('Ready for you', style: t.titleLarge)),
              if (ready.length > _readyShown)
                TextButton(
                    onPressed: () => setState(() => _tab = 1),
                    child: const Text('See all')),
            ]),
          ),
          Padding(
            padding: side,
            child: Column(children: [
              for (final card in ready.take(_readyShown))
                ReadyCard(item: card.item, save: card.save),
            ]),
          ),
          const SizedBox(height: 12),
        ],
        for (final lane in lanes)
          LaneView(
            lane: lane,
            onSeeAll: () => _push(
                SectionScreen(section: lane.section, items: _allItems)),
            isNew: _arrived,
            extra: lane.section == 'places'
                ? TextButton(
                    onPressed: () => setState(() {
                          _tab = 1;
                          _memView = 2;
                        }),
                    child: const Text('on the map'))
                : null,
          ),
      ],
    );
  }

  /// Memories: everything, as a list, a search, the map or full-screen reels.
  Widget _memories(
      BuildContext context,
      List<Map<String, dynamic>> saves,
      List<Map<String, dynamic>> allItems,
      String Function(String) spaceLabel,
      EdgeInsets pad) {
    final t = Theme.of(context).textTheme;
    final views = [
      RefreshIndicator(
        onRefresh: _refresh,
        child: FeedList(
          saves: saves,
          counts: toTryCounts(allItems),
          onSection: (s) => _push(SectionScreen(section: s, items: _allItems)),
          spaceLabel: spaceLabel,
          loading: !_loaded,
          error: _error,
          padding:
              EdgeInsets.fromLTRB(RbSpace.side, 0, RbSpace.side, pad.bottom),
        ),
      ),
      const Padding(
          padding: EdgeInsets.only(bottom: _barRoom), child: LibraryScreen()),
      Padding(
        padding: const EdgeInsets.only(bottom: _barRoom),
        child: PlacesMap(items: [
          for (final i in allItems)
            if (i['section'] == 'places') i
        ]),
      ),
      ReelsView(saves: saves, items: allItems),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: EdgeInsets.fromLTRB(RbSpace.side, pad.top, RbSpace.side, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Memories', style: t.headlineMedium),
          const SizedBox(height: 12),
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 0, label: Text('All')),
              ButtonSegment(value: 1, label: Text('Search')),
              ButtonSegment(value: 2, label: Text('Map')),
              ButtonSegment(value: 3, label: Text('Reels')),
            ],
            selected: {_memView},
            onSelectionChanged: (v) => setState(() => _memView = v.first),
          ),
        ]),
      ),
      Expanded(child: IndexedStack(index: _memView, children: views)),
    ]);
  }

  /// Recall: things you saved a while ago and haven't tried yet. The lite version: the daily
  /// nudge and Not now / Archive come with design v4 step 4.
  Widget _recallTab(
      BuildContext context, List<WaitingCard> recall, EdgeInsets pad) {
    final t = Theme.of(context).textTheme;
    final now = DateTime.now().millisecondsSinceEpoch / 1000;
    String ago(Map<String, dynamic> save) {
      final days =
          ((now - ((save['created_at'] ?? now) as num)) / 86400).floor();
      return 'Saved $days days ago';
    }

    return ListView(
      padding: pad.add(const EdgeInsets.symmetric(horizontal: RbSpace.side)),
      children: [
        Text('Recall', style: t.headlineMedium),
        const SizedBox(height: 6),
        Text('Your brain brings things back when they matter.',
            style: t.bodyMedium?.copyWith(color: RbColors.of(context).muted)),
        const SizedBox(height: 20),
        if (recall.isEmpty)
          const EmptyState(
              icon: Icons.history,
              title: 'Nothing to bring back yet',
              body: 'Saves you haven’t tried after a week come back here.'),
        for (final card in recall.reversed) // the oldest first
          ReadyCard(item: card.item, save: card.save, note: ago(card.save)),
      ],
    );
  }

  /// Threads: your interests, each with its hue and count. The lite version: the constellation
  /// comes with design v4 step 5.
  Widget _threads(BuildContext context, List<Map<String, dynamic>> allItems,
      EdgeInsets pad) {
    final t = Theme.of(context).textTheme;
    final c = RbColors.of(context);
    final counts = <String, int>{};
    for (final i in allItems) {
      final s = i['section'] as String?;
      if (sectionLabels.containsKey(s)) counts[s!] = (counts[s] ?? 0) + 1;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ListView(
      padding: pad.add(const EdgeInsets.symmetric(horizontal: RbSpace.side)),
      children: [
        Text('Threads', style: t.headlineMedium),
        const SizedBox(height: 6),
        Text('Your interests, connected.',
            style: t.bodyMedium?.copyWith(color: c.muted)),
        const SizedBox(height: 20),
        if (entries.isEmpty)
          const EmptyState(
              icon: Icons.hub_outlined,
              title: 'No threads yet',
              body: 'Your interests show up here as you save.'),
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Pressable(
              onTap: () =>
                  _push(SectionScreen(section: e.key, items: _allItems)),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(RbSpace.cardRadius),
                  border: Border.all(color: c.line),
                ),
                child: Row(children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.section(e.key).withValues(alpha: 0.18),
                      border: Border.all(color: c.section(e.key)),
                    ),
                    child: Icon(sectionIcons[e.key],
                        size: 18, color: c.section(e.key)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                      child:
                          Text(sectionLabels[e.key]!, style: t.titleMedium)),
                  Text('${e.value}',
                      style: t.titleMedium?.copyWith(color: c.muted)),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, color: c.faint),
                ]),
              ),
            ),
          ),
      ],
    );
  }

  /// Room the tab bar takes at the bottom of each tab.
  static const _barRoom = 88.0;
  static const _readyShown = 5;
  static const _recallAfter = Duration(days: 7);
  int _tab = 0, _memView = 0;

  // Saves on screen when Brain first loaded; any later one "arrives" (slides in once).
  Set<String>? _known;
  bool _arrived(String id) => _known != null && _known!.add(id);

  // "Ready" flash: a save that was processing a moment ago and just finished.
  final _wasProcessing = <String>{};
  Map<String, dynamic>? _flash;
  Timer? _flashTimer;

  void _trackReady(List<Map<String, dynamic>> saves) {
    for (final s in saves) {
      final id = s['save_id'] as String?;
      if (id == null) continue;
      final busy = _processing.contains(s['status']);
      if (busy) {
        _wasProcessing.add(id);
      } else if (_wasProcessing.remove(id) &&
          (s['status'] == 'ready' || s['status'] == 'partial')) {
        _flash = s;
        _flashTimer?.cancel();
        _flashTimer = Timer(const Duration(seconds: 4), () {
          if (mounted) setState(() => _flash = null);
        });
      }
    }
  }

  PillStatus _pillStatus(Map<String, dynamic> save, String text) {
    final url = frameUrl(save['key_frame_url'] as String?);
    final id = save['save_id'] as String?, space = save['space_id'] as String?;
    return (
      key: '${id}_${save['status']}',
      thumb: url == null
          ? const BrainMark(animate: true)
          : Image.network(url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox()),
      text: text,
      onTap: id == null || space == null
          ? null
          : () => _push(SaveScreen(spaceId: space, saveId: id)),
    );
  }

  void _push(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
}

/// Every save as a list (Memories · All), separate from Firestore so it can be tested with plain
/// data.
class FeedList extends StatelessWidget {
  const FeedList({
    super.key,
    required this.saves,
    required this.counts,
    required this.spaceLabel,
    this.loading = false,
    this.error,
    this.onSection,
    this.header = const [],
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  final List<Widget> header;
  final EdgeInsetsGeometry padding;

  final List<Map<String, dynamic>> saves;
  final Map<String, int> counts;
  final String Function(String spaceId) spaceLabel;
  final bool loading;
  final String? error;
  final void Function(String section)? onSection;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      ...header,
      if (error != null) _Note('Could not load your saves. $error'),
      if (counts.isNotEmpty) _Counters(counts, onSection),
      if (loading) ...[const SkeletonCard(), const SkeletonCard()],
      if (!loading && saves.isEmpty && error == null)
        const EmptyState(
            title: 'Nothing saved yet',
            body: 'Share a reel from TikTok, Instagram or YouTube '
                'to Realbrain · Me or Realbrain · Home.'),
      for (final s in saves)
        SaveCard(save: s, space: spaceLabel(s['space_id'] as String? ?? '')),
    ];
    // Always scrollable, so pull-to-refresh works on a short or empty feed.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding,
      children: children,
    );
  }
}

class _Counters extends StatelessWidget {
  const _Counters(this.counts, this.onSection);
  final Map<String, int> counts;
  final void Function(String section)? onSection;

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
            SectionChip(
                section: e.key,
                label: sectionLabels[e.key] ?? e.key,
                count: e.value,
                onTap: onSection == null ? null : () => onSection!(e.key)),
        ],
      ),
    );
  }
}

/// One save. While processing it shows the live step text over flat grey bars at the final
/// layout's size (no shimmer).
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
      child: Pressable(
        onTap: saveId == null || spaceId == null
            ? null
            : () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => SaveScreen(
                      spaceId: spaceId,
                      saveId: saveId,
                      initial: save,
                      heroTag: 'frame-$saveId-latest'),
                )),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Skeletons have no id, and two of them would share a tag.
            HeroMode(
              enabled: saveId != null,
              child: Hero(
                tag: 'frame-$saveId-latest',
                child: _Frame(stored: save['key_frame_url'] as String?),
              ),
            ),
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
                                .map((s) => s == 'fact_check' &&
                                        save['verdict'] != null
                                    ? 'Fact Check: ${verdictLabels[save['verdict']] ?? save['verdict']}'
                                    : sectionLabels[s] ?? s)
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

/// The status pill's "ready" line: the section and what was found ("Recipes · Koshari...").
String _readyLine(Map<String, dynamic> save) {
  final sections = (save['sections'] as List?)?.cast<String>() ?? const [];
  final what = sections.isEmpty
      ? 'Added to your brain'
      : sections.first == 'fact_check' && save['verdict'] != null
          ? 'Fact Check: ${verdictLabels[save['verdict']] ?? save['verdict']}'
          : sectionLabels[sections.first] ?? sections.first;
  final summary = save['summary'] as String?;
  return summary == null ? what : '$what · $summary';
}

/// The avatar next to the greeting: Settings and the less used screens.
class _AccountMenu extends StatelessWidget {
  const _AccountMenu({required this.onOpen});
  final void Function(Widget screen) onOpen;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final photo = user?.photoURL;
    // Provider sign-in can leave the name and email empty strings, not null.
    final initial = [user?.displayName, user?.email, '?']
        .firstWhere((s) => s != null && s.trim().isNotEmpty)!
        .trim()
        .characters
        .first
        .toUpperCase();
    return PopupMenuButton<String>(
      tooltip: 'Account',
      onSelected: (v) => switch (v) {
        'out' => FirebaseAuth.instance.signOut(),
        'queue' => onOpen(const SavesScreen()),
        'spaces' => onOpen(const HouseholdScreen()),
        _ => onOpen(const SettingsScreen()),
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'settings', child: Text('Settings')),
        PopupMenuItem(value: 'spaces', child: Text('Spaces')),
        PopupMenuItem(value: 'queue', child: Text('Phone queue')),
        PopupMenuItem(value: 'out', child: Text('Sign out')),
      ],
      child: CircleAvatar(
        radius: 20,
        backgroundColor: RbColors.of(context).raised,
        backgroundImage: photo == null ? null : NetworkImage(photo),
        child: photo == null ? Text(initial) : null,
      ),
    );
  }
}

/// Inbox nudge on Brain: only while saves need a look.
class _NeedsALook extends StatelessWidget {
  const _NeedsALook({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(RbSpace.side, 0, RbSpace.side, 16),
        child: Pressable(
          onTap: onTap,
          child: Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.inbox_outlined),
              title: Text(count == 1
                  ? 'Inbox · 1 save needs a look'
                  : 'Inbox · $count saves need a look'),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
        ),
      );
}

/// One of Brain's three numbers.
class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label, {this.onTap});
  final String value, label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final t = Theme.of(context).textTheme;
    return Expanded(
      child: Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.line),
          ),
          child: Column(children: [
            Text(value, style: t.headlineSmall?.copyWith(fontSize: 24)),
            const SizedBox(height: 2),
            Text(label, style: t.bodySmall, maxLines: 1),
          ]),
        ),
      ),
    );
  }
}

/// The + button: paste a link and pick a space; it saves exactly like a share.
Future<void> addLink(BuildContext context) async {
  final clip = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim();
  final field = TextEditingController(
      text: clip != null && Uri.tryParse(clip)?.hasScheme == true ? clip : '');
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  Future<void> save(BuildContext sheet, String space) async {
    final url = field.text.trim();
    if (Uri.tryParse(url)?.hasScheme != true) return;
    Navigator.of(sheet).pop();
    await native.invokeMethod('enqueue', {'url': url, 'space': space});
    messenger
        .showSnackBar(const SnackBar(content: Text('Added to your brain')));
  }

  await showRbSheet<void>(context, title: 'Add to your brain', children: [
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: RbSpace.side),
      child: TextField(
        controller: field,
        autofocus: field.text.isEmpty,
        keyboardType: TextInputType.url,
        decoration:
            const InputDecoration(hintText: 'Paste a link to a reel or video'),
      ),
    ),
    Builder(
      builder: (sheet) => Padding(
        padding: EdgeInsets.fromLTRB(RbSpace.side, RbSpace.side, RbSpace.side,
            RbSpace.side + MediaQuery.viewInsetsOf(sheet).bottom),
        child: Row(children: [
          Expanded(
              child: PillButton(
                  label: 'Save to Me', onPressed: () => save(sheet, 'me'))),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton(
                onPressed: () => save(sheet, 'home'),
                child: const Text('Save to Home')),
          ),
        ]),
      ),
    ),
  ]);
  field.dispose();
}
