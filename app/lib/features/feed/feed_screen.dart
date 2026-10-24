import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/native.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/gallery.dart';
import '../../core/liquid_pill.dart';
import '../../core/widgets.dart';
import '../places/places_map.dart';
import '../../core/glass.dart';
import 'lanes.dart';
import '../factcheck/fact_check_view.dart' show verdictLabels;
import '../inbox/inbox_screen.dart';
import '../library/library_screen.dart';
import '../save/save_screen.dart';
import '../section/section_screen.dart';
import '../settings/settings_screen.dart';
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
    // The Inbox screen listens to this, so it stays live while open.
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
            processing.first['step_text'] as String? ?? 'Saving')
        : flash != null
            ? _pillStatus(flash, _readyLine(flash))
            : null;
    if (_loaded && _known == null) {
      _known = {for (final s in saves) s['save_id'] as String? ?? ''};
    }
    void openSection(String section) =>
        _push(SectionScreen(section: section, items: _allItems));
    final home = Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        // Glass once content scrolls under it (design v3).
        flexibleSpace: _scrolled
            ? const Glass(radius: 0, shadow: false, child: SizedBox.expand())
            : null,
        // Long-press the title for the hidden design gallery (P1-01).
        title: GestureDetector(
          onLongPress: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const DesignGallery())),
          child: const Text('Reelbrain'),
        ),
        actions: [_AccountMenu(onOpen: _push)],
      ),
      body: Builder(builder: (context) {
        final top = MediaQuery.paddingOf(context).top;
        final header = <Widget>[
          if (inbox.isNotEmpty)
            _NeedsALook(
                count: inbox.length, onTap: () => setState(() => _tab = 3)),
          Padding(
            padding:
                const EdgeInsets.fromLTRB(RbSpace.side, 4, RbSpace.side, 16),
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('Sections')),
                ButtonSegment(value: true, label: Text('Latest')),
              ],
              selected: {_latest},
              onSelectionChanged: (v) => setState(() => _latest = v.first),
            ),
          ),
        ];
        final lanes = lanesOf(allItems, saves);
        final Widget list = _latest
            ? FeedList(
                saves: saves,
                counts: toTryCounts(allItems),
                onSection: openSection,
                spaceLabel: spaceLabel,
                loading: !_loaded,
                error: _error,
                header: header,
                padding: EdgeInsets.fromLTRB(
                    RbSpace.side, top + 8, RbSpace.side, _pillRoom + 16),
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(top: top + 8, bottom: _pillRoom + 16),
                children: [
                  ...header,
                  if (_error != null)
                    EmptyState(
                        title: 'Could not load your saves', body: _error),
                  if (!_loaded)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: RbSpace.side),
                      child: SkeletonCard(),
                    ),
                  if (_loaded && lanes.isEmpty && _error == null)
                    const EmptyState(
                        title: 'Nothing saved yet',
                        body: 'Share a reel from TikTok, Instagram or YouTube '
                            'to Reelbrain · Me or Reelbrain · Home.'),
                  for (final lane in lanes)
                    LaneView(
                      lane: lane,
                      onSeeAll: () => openSection(lane.section),
                      isNew: _arrived,
                      extra: lane.section == 'places'
                          ? TextButton(
                              onPressed: () => setState(() => _tab = 2),
                              child: const Text('on the map'))
                          : null,
                    ),
                ],
              );
        return Stack(children: [
          Positioned.fill(
              child: _Wash(
                  save: saves
                      .where((s) => s['key_frame_url'] != null)
                      .firstOrNull)),
          NotificationListener<ScrollNotification>(
            onNotification: (n) {
              final under =
                  n.metrics.axis == Axis.vertical && n.metrics.pixels > 4;
              if (n.depth == 0 && under != _scrolled) {
                setState(() => _scrolled = under);
              }
              return false;
            },
            child: RefreshIndicator(
                onRefresh: _refresh, edgeOffset: top, child: list),
          ),
        ]);
      }),
    );
    // Tabs other than Home end above the pill instead of scrolling under it.
    Widget above(Widget w) =>
        Padding(padding: const EdgeInsets.only(bottom: _pillRoom), child: w);
    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (popped, _) {
        if (!popped) {
          setState(() => _tab = 0); // Back from a tab goes Home first
        }
      },
      child: Scaffold(
        extendBody: true,
        body: IndexedStack(index: _tab, children: [
          home,
          above(const LibraryScreen()),
          above(ValueListenableBuilder<List<Map<String, dynamic>>>(
            valueListenable: _allItems,
            builder: (context, all, _) => PlacesMap(items: [
              for (final i in all)
                if (i['section'] == 'places') i
            ]),
          )),
          above(InboxScreen(saves: _inbox, spaceLabel: spaceLabel)),
        ]),
        bottomNavigationBar: LiquidPill(
          selected: _tab,
          onSelect: (i) => setState(() => _tab = i),
          status: status,
          destinations: [
            (
              icon: Icons.home_outlined,
              selectedIcon: Icons.home,
              label: 'Home',
              badge: 0
            ),
            (
              icon: Icons.search,
              selectedIcon: Icons.search,
              label: 'Search',
              badge: 0
            ),
            (
              icon: Icons.map_outlined,
              selectedIcon: Icons.map,
              label: 'Map',
              badge: 0
            ),
            (
              icon: Icons.inbox_outlined,
              selectedIcon: Icons.inbox,
              label: 'Inbox',
              badge: inbox.length
            ),
          ],
        ),
      ),
    );
  }

  static const _pillRoom = 88.0;
  int _tab = 0;
  bool _latest = false, _scrolled = false;

  // Saves on screen when Home first loaded; any later one "arrives" (slides in once).
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
          ? null
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

/// The feed body, separate from Firestore so it can be tested with plain data.
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
                'to Reelbrain · Me or Reelbrain · Home.'),
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

/// The pill's "ready" line: the section and what was found ("Recipes · Koshari at home...").
String _readyLine(Map<String, dynamic> save) {
  final sections = (save['sections'] as List?)?.cast<String>() ?? const [];
  final what = sections.isEmpty
      ? 'Saved'
      : sections.first == 'fact_check' && save['verdict'] != null
          ? 'Fact Check: ${verdictLabels[save['verdict']] ?? save['verdict']}'
          : sectionLabels[sections.first] ?? sections.first;
  final summary = save['summary'] as String?;
  return summary == null ? what : '$what · $summary';
}

/// The avatar in the top bar: Settings and the less used screens (design v3).
class _AccountMenu extends StatelessWidget {
  const _AccountMenu({required this.onOpen});
  final void Function(Widget screen) onOpen;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final photo = user?.photoURL;
    final initial = (user?.displayName ?? user?.email ?? '?')
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
      child: Padding(
        padding: const EdgeInsetsDirectional.only(end: RbSpace.side),
        child: CircleAvatar(
          radius: 16,
          backgroundImage: photo == null ? null : NetworkImage(photo),
          child: photo == null ? Text(initial) : null,
        ),
      ),
    );
  }
}

/// Inbox nudge on Home: only while saves need a look.
class _NeedsALook extends StatelessWidget {
  const _NeedsALook({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(RbSpace.side, 0, RbSpace.side, 12),
        child: Pressable(
          onTap: onTap,
          child: Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.inbox_outlined),
              title: Text(count == 1
                  ? '1 save needs a look'
                  : '$count saves need a look'),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
        ),
      );
}

/// Home's background: the newest reel's frame, blurred and dim, so the glass picks up the reels'
/// own colour (design v3). Flat ground when there's no frame.
class _Wash extends StatelessWidget {
  const _Wash({this.save});
  final Map<String, dynamic>? save;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final url = frameUrl(save?['key_frame_url'] as String?);
    return ColoredBox(
      color: c.ground,
      child: url == null
          ? const SizedBox.expand()
          : Stack(fit: StackFit.expand, children: [
              Opacity(
                opacity: dark ? 0.35 : 0.25,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(
                      sigmaX: 60, sigmaY: 60, tileMode: TileMode.decal),
                  child: Image.network(url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox()),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [c.ground.withValues(alpha: 0), c.ground],
                    stops: const [0.2, 0.9],
                  ),
                ),
              ),
            ]),
    );
  }
}
