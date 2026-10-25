import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/native.dart';
import '../../core/surface.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets.dart';
import '../factcheck/fact_check_view.dart';
import '../feed/feed_screen.dart' show sectionLabels;
import '../feed/lanes.dart' show FrameImage, kindLabels;
import '../inbox/inbox_screen.dart' show fileUnder;
import '../places/places_view.dart';
import '../recipes/recipe_view.dart';
import '../section/section_screen.dart'
    show setItemState, statusChoices, toolKinds;
import '../workouts/workout_view.dart';

/// One memory in full (design v4 revision 2): the frame edge to edge, what it is, the section's
/// own content and action, why you saved it, related memories, and Share · Done · More.
class SaveScreen extends StatelessWidget {
  const SaveScreen(
      {super.key,
      required this.spaceId,
      required this.saveId,
      this.initial,
      this.heroTag});
  final String spaceId;
  final String saveId;

  /// The save as the card that opened it had it: drawn at once, so the frame can fly in before
  /// Firestore answers.
  final Map<String, dynamic>? initial;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance.doc('spaces/$spaceId/saves/$saveId');
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snap) {
        final save = snap.data?.data() ?? (snap.hasData ? null : initial);
        Widget plain(Widget body) =>
            Scaffold(appBar: AppBar(), body: _pad(body));
        if (snap.hasError) {
          return plain(Text('Could not open this save: ${snap.error}'));
        }
        if (save == null) {
          return snap.hasData
              ? plain(const Text('This save no longer exists.'))
              : plain(const Center(child: CircularProgressIndicator()));
        }
        final settled = !_processing.contains(save['status']);
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: ref.collection('items').snapshots(),
          builder: (context, itemSnap) {
            final items = <Map<String, dynamic>>[
              for (final d in itemSnap.data?.docs ?? const []) d.data()
            ];
            return Scaffold(
              body: _Related(
                spaceId: spaceId,
                save: save,
                builder: (related) => SaveDetail(
                  heroTag: heroTag,
                  save: save,
                  items: items,
                  related: related,
                  onMore: settled ? () => _more(context, save, items) : null,
                  onEditWhy: () => _editWhy(context, ref, save),
                ),
              ),
              bottomNavigationBar: _ActionBar(save: save, items: items),
            );
          },
        );
      },
    );
  }
}

const _processing = {'received', 'uploaded', 'fetching', 'extracting'};

/// Other memories in the same space and section (no index needed: one array-contains filter).
class _Related extends StatelessWidget {
  const _Related(
      {required this.spaceId, required this.save, required this.builder});
  final String spaceId;
  final Map<String, dynamic> save;
  final Widget Function(List<Map<String, dynamic>> related) builder;

  @override
  Widget build(BuildContext context) {
    final sections = (save['sections'] as List?)?.cast<String>() ?? const [];
    if (sections.isEmpty) return builder(const []);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('spaces/$spaceId/saves')
          .where('sections', arrayContains: sections.first)
          .limit(9)
          .snapshots(),
      builder: (context, snap) => builder([
        for (final d in snap.data?.docs ?? const [])
          if (d.id != save['save_id']) d.data()
      ]),
    );
  }
}

/// More: re-file, copy the link, and the memory's profile (Memory DNA).
Future<void> _more(BuildContext context, Map<String, dynamic> save,
    List<Map<String, dynamic>> items) async {
  final source = save['source_url'] as String? ?? '';
  final choice = await showRbSheet<String>(context, children: [
    ListTile(
        leading: const Icon(Icons.fingerprint),
        title: const Text('Memory details'),
        onTap: () => Navigator.pop(context, 'dna')),
    ListTile(
        leading: const Icon(Icons.drive_file_move_outline),
        title: const Text('Change section'),
        onTap: () => Navigator.pop(context, 'section')),
    ListTile(
        leading: const Icon(Icons.link),
        title: const Text('Copy link'),
        onTap: () => Navigator.pop(context, 'copy')),
    const SizedBox(height: 8),
  ]);
  if (!context.mounted) return;
  switch (choice) {
    case 'dna':
      await showRbSheet<void>(context,
          title: 'Memory details',
          children: [MemoryDna(save: save, items: items)]);
    case 'section':
      await changeSection(context, save);
    case 'copy':
      await Clipboard.setData(ClipboardData(text: source));
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Link copied')));
      }
  }
}

/// "Why you saved this" in your own words: stored in the save's note (the one save field the
/// rules let the app write).
Future<void> _editWhy(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> save) async {
  final field = TextEditingController(text: save['note'] as String? ?? '');
  final text = await showRbSheet<String>(context,
      title: 'Why you saved this',
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: RbSpace.side),
          child: TextField(
            controller: field,
            autofocus: true,
            maxLength: 2000,
            minLines: 1,
            maxLines: 4,
            decoration: InputDecoration(
                hintText: save['good_for'] as String? ?? 'In your words'),
          ),
        ),
        Builder(
          builder: (sheet) => Padding(
            padding: EdgeInsets.fromLTRB(RbSpace.side, 8, RbSpace.side,
                RbSpace.side + MediaQuery.viewInsetsOf(sheet).bottom),
            child: PillButton(
                label: 'Save',
                onPressed: () => Navigator.pop(sheet, field.text.trim())),
          ),
        ),
      ]);
  field.dispose();
  if (text != null) await ref.update({'note': text.isEmpty ? null : text});
}

/// Re-file a save: a section re-reads the video with that hint; "None of these" keeps it as a
/// plain save (for things no section covers yet, like products before P3-02).
Future<void> changeSection(
    BuildContext context, Map<String, dynamic> save) async {
  final current = (save['sections'] as List?)?.cast<String>() ?? const [];
  final section = await showRbSheet<String>(
    context,
    title: 'File this under',
    children: [
      const ListTile(
          dense: true,
          title: Text('Realbrain re-reads the video for that section.')),
      for (final e in sectionLabels.entries)
        ListTile(
          leading: Icon(sectionIcons[e.key]),
          title: Text(e.value),
          trailing: current.contains(e.key) ? const Icon(Icons.check) : null,
          onTap: () => Navigator.pop(context, e.key),
        ),
      ListTile(
        leading: const Icon(Icons.bookmark_outline),
        title: const Text('None of these'),
        subtitle: const Text('Keep it as a plain save'),
        onTap: () => Navigator.pop(context, 'none'),
      ),
    ],
  );
  if (section != null && context.mounted) {
    await fileUnder(context, save, section);
  }
}

Widget _pad(Widget child) =>
    Padding(padding: const EdgeInsets.all(16), child: child);

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

String _platform(String? p) => switch (p) {
      'tiktok' => 'TikTok',
      'instagram' => 'Instagram',
      'youtube' => 'YouTube',
      'facebook' => 'Facebook',
      null => 'the web',
      _ => p,
    };

/// "From TikTok · chef · Saved 12 Apr".
String sourceLine(Map<String, dynamic> save) {
  final at = save['created_at'] as num?;
  final d = at == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch((at * 1000).round());
  return [
    'From ${_platform(save['platform'] as String?)}',
    if (save['creator'] != null) save['creator'] as String,
    if (d != null) 'Saved ${d.day} ${_months[d.month - 1]}',
  ].join(' · ');
}

/// The memory's own facts as chips: time, difficulty, impact (design v4 §5.1).
List<(IconData, String)> metaChips(Map<String, dynamic> save) => [
      if (save['effort_min'] != null)
        (Icons.schedule, '${save['effort_min']} min'),
      if (save['difficulty'] != null)
        (Icons.signal_cellular_alt, _cap(save['difficulty'] as String)),
      if (save['impact'] != null)
        (Icons.bolt_outlined, '${_cap(save['impact'] as String)} impact'),
    ];

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// The body, separate from Firestore so it can be tested with plain data.
class SaveDetail extends StatelessWidget {
  const SaveDetail(
      {super.key,
      required this.save,
      required this.items,
      this.related = const [],
      this.heroTag,
      this.onMore,
      this.onEditWhy});
  final Object? heroTag;
  final Map<String, dynamic> save;
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> related;
  final VoidCallback? onMore, onEditWhy;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = RbColors.of(context);
    final source = save['source_url'] as String? ?? '';
    final primary = items.isEmpty ? null : items.first;
    final section = primary?['section'] as String?;
    final data =
        (primary?['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    final summary =
        save['summary'] as String? ?? save['step_text'] as String? ?? '';
    final title = switch (section) {
      'recipe' => data['title'] as String? ?? summary,
      _ => summary,
    };
    final note = save['note'] as String?;
    final why = note ?? save['good_for'] as String?;
    final chips = metaChips(save);
    final top = MediaQuery.paddingOf(context).top;
    Widget round(IconData icon, String tip, VoidCallback? onTap) => Semantics(
          button: true,
          label: tip,
          child: Pressable(
            onTap: onTap,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
          ),
        );
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // The frame, edge to edge, with back and More on it and the kind at its foot.
        SizedBox(
          height: 360 + top,
          child: Stack(fit: StackFit.expand, children: [
            Hero(
              tag: heroTag ?? 'frame-${save['save_id']}',
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(RbSpace.cardRadius)),
                child: FrameImage(save: save),
              ),
            ),
            PositionedDirectional(
              top: top + 8,
              start: 12,
              child: round(Icons.arrow_back, 'Back',
                  () => Navigator.of(context).maybePop()),
            ),
            if (onMore != null)
              PositionedDirectional(
                  top: top + 8,
                  end: 12,
                  child: round(Icons.more_horiz, 'More', onMore)),
            if (section != null)
              PositionedDirectional(
                start: RbSpace.side,
                bottom: 14,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(RbSpace.pill),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(sectionIcons[section],
                        size: 14, color: c.section(section)),
                    const SizedBox(width: 6),
                    Text(kindLabels[section] ?? '',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                  ]),
                ),
              ),
          ]),
        ),
        Padding(
          padding:
              const EdgeInsets.fromLTRB(RbSpace.side, 16, RbSpace.side, 24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: t.headlineSmall
                    ?.copyWith(fontSize: 24, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(sourceLine(save), style: t.bodySmall),
            if (chips.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final (icon, label) in chips) _MetaChip(icon, label),
              ]),
            ],
            if (title != summary && summary.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(summary, style: t.bodyMedium?.copyWith(color: c.muted)),
            ],
            // Each section's own content and action; a heading only when there are several.
            for (final item in items) ...[
              const SizedBox(height: 20),
              if (items.length > 1) ...[
                Row(children: [
                  Icon(sectionIcons[item['section']],
                      size: 16, color: c.section(item['section'] as String?)),
                  const SizedBox(width: 8),
                  Text(sectionLabels[item['section']] ?? '${item['section']}',
                      style: t.titleSmall),
                ]),
                const SizedBox(height: 8),
              ],
              _content(context, item, showTitle: item != primary),
            ],
            if (why != null || onEditWhy != null) ...[
              const SizedBox(height: 24),
              Text('Why you saved this', style: t.titleSmall),
              const SizedBox(height: 6),
              Pressable(
                onTap: onEditWhy,
                child: Text(
                    why == null
                        ? 'Add why you saved it'
                        : note == null
                            ? '“$why” · tap to put it in your words'
                            : '“$why”',
                    style: t.bodyMedium?.copyWith(color: c.muted)),
              ),
            ],
            if (source.isNotEmpty)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: () => openUrl(context, source),
                  child: Text('View original',
                      style: TextStyle(
                          color: c.accent,
                          decoration: TextDecoration.underline)),
                ),
              ),
            if (related.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Related', style: t.titleSmall),
              const SizedBox(height: 10),
              SizedBox(
                height: 150,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: related.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) => _RelatedCard(save: related[i]),
                ),
              ),
            ],
          ]),
        ),
      ],
    );
  }

  Widget _content(BuildContext context, Map<String, dynamic> item,
      {required bool showTitle}) {
    final data = (item['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    return switch (item['section']) {
      'places' => PlacesView(data: data),
      'workout' => WorkoutView(item: item),
      'recipe' => RecipeView(data: data, showTitle: showTitle),
      'fact_check' =>
        FactCheckView(saveId: save['save_id'] as String?, data: data),
      'tools' => ToolsView(data: data),
      _ => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final l in itemLines(item))
            Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(l)),
        ]),
    };
  }

  static String _at(Object? t) {
    final s = (t as num?)?.round();
    return s == null
        ? ''
        : '  (${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')})';
  }

  /// One readable line per extracted thing, with the second it appears in the reel.
  static List<String> itemLines(Map<String, dynamic> item) {
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

class _MetaChip extends StatelessWidget {
  const _MetaChip(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(RbSpace.pill),
        border: Border.all(color: c.line),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: c.muted),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 13, color: c.text)),
      ]),
    );
  }
}

/// Tools: each one with what it is, what the reel showed, the snippet, and Open.
class ToolsView extends StatelessWidget {
  const ToolsView({super.key, required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = RbColors.of(context);
    final tools = [
      for (final x in (data['items'] as List?) ?? const [])
        (x as Map).cast<String, dynamic>()
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final x in tools)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${x['name']}', style: t.titleMedium),
            if (x['kind'] != null)
              Text(toolKinds[x['kind']] ?? '${x['kind']}', style: t.bodySmall),
            if (x['use_shown'] != null) ...[
              const SizedBox(height: 6),
              Text('${x['use_shown']}', style: t.bodyMedium),
            ],
            if (x['snippet'] != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: c.raised, borderRadius: BorderRadius.circular(12)),
                child: SelectableText('${x['snippet']}',
                    style: TextStyle(
                        fontFamily: 'monospace', fontSize: 13, color: c.text)),
              ),
            ],
            if (x['url_guess'] != null) ...[
              const SizedBox(height: 10),
              PillButton(
                  small: true,
                  icon: Icons.open_in_new,
                  label: 'Try now',
                  onPressed: () => openUrl(context, '${x['url_guess']}')),
            ],
          ]),
        ),
    ]);
  }
}

class _RelatedCard extends StatelessWidget {
  const _RelatedCard({required this.save});
  final Map<String, dynamic> save;

  @override
  Widget build(BuildContext context) {
    final id = save['save_id'] as String?, space = save['space_id'] as String?;
    return Pressable(
      onTap: id == null || space == null
          ? null
          : () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) =>
                  SaveScreen(spaceId: space, saveId: id, initial: save))),
      child: SizedBox(
        width: 104,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(RbSpace.photoRadius),
            child: SizedBox(
                width: 104, height: 104, child: FrameImage(save: save)),
          ),
          const SizedBox(height: 6),
          Text(save['summary'] as String? ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall),
        ]),
      ),
    );
  }
}

/// Memory DNA: the memory's profile as plain rows.
class MemoryDna extends StatelessWidget {
  const MemoryDna({super.key, required this.save, required this.items});
  final Map<String, dynamic> save;
  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final rows = [
      (
        'Kind',
        items.map((i) => sectionLabels[i['section']] ?? i['section']).join(', ')
      ),
      if (save['effort_min'] != null) ('Time', '${save['effort_min']} minutes'),
      if (save['difficulty'] != null)
        ('Difficulty', _cap(save['difficulty'] as String)),
      if (save['impact'] != null) ('Impact', _cap(save['impact'] as String)),
      if (save['good_for'] != null) ('Good for', save['good_for'] as String),
      if (save['language'] != null) ('Language', save['language'] as String),
      ('Source', sourceLine(save)),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          RbSpace.side, 0, RbSpace.side, RbSpace.side),
      child: Column(children: [
        for (final (k, v) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 110, child: Text(k, style: t.bodySmall)),
              Expanded(child: Text(v, style: t.bodyMedium)),
            ]),
          ),
      ]),
    );
  }
}

/// The bar at the foot of a memory: Share sends the link; Done marks the main item tried, cooked,
/// visited, done or read (tap again to undo). More sits on the frame.
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.save, required this.items});
  final Map<String, dynamic> save;
  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final primary = items.isEmpty ? null : items.first;
    final choices = statusChoices[primary?['section']] ?? const {};
    final doneState =
        choices.keys.firstWhere((k) => k != 'to_try', orElse: () => '');
    final done = primary != null &&
        doneState.isNotEmpty &&
        primary['user_state'] == doneState;
    Widget action(IconData icon, String label, VoidCallback? onTap) => Expanded(
          child: Semantics(
            button: true,
            label: label,
            excludeSemantics: true,
            child: Pressable(
              onTap: onTap,
              child: Opacity(
                opacity: onTap == null ? 0.4 : 1,
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 22, color: c.text),
                      const SizedBox(height: 4),
                      Text(label,
                          style: TextStyle(fontSize: 11, color: c.muted)),
                    ]),
              ),
            ),
          ),
        );
    final source = save['source_url'] as String?;
    return DecoratedBox(
      decoration: BoxDecoration(
          color: c.ground, border: Border(top: BorderSide(color: c.line))),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(children: [
            action(
                Icons.ios_share,
                'Share',
                source == null
                    ? null
                    : () =>
                        shareText('${save['summary'] ?? ''}\n$source'.trim())),
            action(
                done ? Icons.check_circle : Icons.check_circle_outline,
                doneState.isEmpty ? 'Done' : choices[doneState]!,
                doneState.isEmpty
                    ? null
                    : () =>
                        setItemState(primary!, done ? 'to_try' : doneState)),
          ]),
        ),
      ),
    );
  }
}
