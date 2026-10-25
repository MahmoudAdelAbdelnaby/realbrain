import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/brain_mark.dart';
import '../../core/surface.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets.dart';
import '../feed/feed_screen.dart' show sectionLabels;
import '../feed/lanes.dart' show FrameImage, cardFace;
import '../recall/recall.dart' show Memory;
import '../save/save_screen.dart';

/// Interests by the names people use for them (the concept's Cooking, AI, Fitness...).
const interestNames = {
  'recipe': 'Cooking',
  'tools': 'AI & Tools',
  'places': 'Travel',
  'workout': 'Fitness',
  'fact_check': 'Learning',
  'ideas': 'Ideas',
};

/// What a memory is about, for connecting it: the save's topics (design v4 step 5), plus what
/// older saves already carry (recipe tags, a place's city).
Set<String> topicsOf(Map<String, dynamic> item, Map<String, dynamic> save) {
  final data = (item['data'] as Map?) ?? const {};
  return {
    for (final t in (save['topics'] as List?) ?? const []) '$t'.toLowerCase(),
    if (item['section'] == 'recipe')
      for (final t in (data['tags'] as List?) ?? const []) '$t'.toLowerCase(),
    if (item['section'] == 'places')
      for (final p in (data['items'] as List?) ?? const [])
        if (p is Map && p['city'] != null) '${p['city']}'.toLowerCase(),
  };
}

typedef Interest = ({
  String section,
  List<Memory> memories,
  Map<String, int> topics
});

/// Two interests joined by the topics they share: the reason for the line between them.
typedef Thread = ({String a, String b, List<String> shared});

class ThreadsModel {
  ThreadsModel(this.interests, this.threads);

  /// Most memories first.
  final List<Interest> interests;
  final List<Thread> threads;

  List<Thread> of(String section) => [
        for (final t in threads)
          if (t.a == section || t.b == section) t
      ];
}

ThreadsModel threadsOf(Iterable<Map<String, dynamic>> items,
    Iterable<Map<String, dynamic>> saves) {
  final byId = {for (final s in saves) s['save_id']: s};
  final memories = <String, List<Memory>>{};
  final topics = <String, Map<String, int>>{};
  for (final item in items) {
    final s = item['section'] as String?;
    final save = byId[item['save_id']];
    if (save == null || !interestNames.containsKey(s)) continue;
    (memories[s!] ??= []).add((item: item, save: save));
    for (final t in topicsOf(item, save)) {
      final m = topics[s] ??= {};
      m[t] = (m[t] ?? 0) + 1;
    }
  }
  final interests = [
    for (final e in memories.entries)
      (
        section: e.key,
        memories: e.value,
        topics: topics[e.key] ?? const <String, int>{}
      )
  ]..sort((a, b) => b.memories.length.compareTo(a.memories.length));
  final threads = <Thread>[];
  for (var i = 0; i < interests.length; i++) {
    for (var j = i + 1; j < interests.length; j++) {
      final shared = interests[i]
          .topics
          .keys
          .where(interests[j].topics.containsKey)
          .toList()
        ..sort();
      if (shared.isNotEmpty) {
        threads.add(
            (a: interests[i].section, b: interests[j].section, shared: shared));
      }
    }
  }
  return ThreadsModel(interests, threads);
}

/// Threads (design v4 step 5): the signature screen. You in the centre, your interests around
/// you as softly glowing nodes sized by how much you save, a line between two interests when
/// they share topics. Tap one to see its topics, its memories and why it connects.
class ThreadsView extends StatefulWidget {
  const ThreadsView(
      {super.key,
      required this.model,
      required this.onSection,
      this.padding = EdgeInsets.zero});
  final ThreadsModel model;
  final void Function(String section) onSection;
  final EdgeInsets padding;

  @override
  State<ThreadsView> createState() => _ThreadsViewState();
}

class _ThreadsViewState extends State<ThreadsView> {
  String? _picked, _topic;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = RbColors.of(context);
    final model = widget.model;
    final picked =
        model.interests.where((i) => i.section == _picked).firstOrNull ??
            model.interests.firstOrNull;
    return Haze(
      child: ListView(
        padding: widget.padding,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: RbSpace.side),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Brain Threads', style: t.headlineMedium),
              const SizedBox(height: 6),
              Text('Your interests, connected.',
                  style: t.bodyMedium?.copyWith(color: c.muted)),
            ]),
          ),
          if (model.interests.isEmpty)
            const EmptyState(
                icon: Icons.hub_outlined,
                title: 'No threads yet',
                body: 'Your interests show up here as you save.')
          else ...[
            Constellation(
              model: model,
              picked: picked!.section,
              onPick: (s) => setState(() {
                _picked = s;
                _topic = null;
              }),
            ),
            _Detail(
              interest: picked,
              threads: model.of(picked.section),
              topic: _topic,
              onTopic: (x) => setState(() => _topic = _topic == x ? null : x),
              onPick: (s) => setState(() {
                _picked = s;
                _topic = null;
              }),
              onSeeAll: () => widget.onSection(picked.section),
            ),
          ],
        ],
      ),
    );
  }
}

/// The constellation: lines painted underneath, the nodes as real buttons on top.
class Constellation extends StatelessWidget {
  const Constellation(
      {super.key,
      required this.model,
      required this.picked,
      required this.onPick});
  final ThreadsModel model;
  final String picked;
  final ValueChanged<String> onPick;

  static const height = 340.0;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final reduced = RbMotion.reduced(context);
    return LayoutBuilder(builder: (context, box) {
      final size = Size(box.maxWidth, height);
      final centre = size.center(Offset.zero);
      final ring = math.min(size.width, size.height) / 2 - 56;
      final n = model.interests.length;
      final most = model.interests.first.memories.length;
      final at = <String, Offset>{
        for (final (k, i) in model.interests.indexed)
          i.section: centre +
              Offset(math.cos(-math.pi / 2 + 2 * math.pi * k / n),
                      math.sin(-math.pi / 2 + 2 * math.pi * k / n)) *
                  ring,
      };
      double radius(Interest i) => 22 + 14 * i.memories.length / most;
      return TweenAnimationBuilder<double>(
        // Nodes gently appear; no particles.
        tween: Tween(begin: reduced ? 1 : 0, end: 1),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => SizedBox(
          height: height,
          child: Stack(children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _Lines(
                    centre: centre,
                    at: at,
                    threads: model.threads,
                    picked: picked,
                    c: c,
                    v: v),
              ),
            ),
            Positioned(
              left: centre.dx - 32,
              top: centre.dy - 32,
              child: Opacity(
                opacity: v,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.surface,
                    border: Border.all(color: c.line),
                    boxShadow: [
                      BoxShadow(
                          color: c.brand.withValues(alpha: 0.35),
                          blurRadius: 28)
                    ],
                  ),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const BrainMark(size: 26),
                        Text('You',
                            style: TextStyle(
                                fontSize: 11, color: c.text, height: 1.2)),
                      ]),
                ),
              ),
            ),
            for (final (k, i) in model.interests.indexed)
              _Node(
                interest: i,
                centre: Offset.lerp(
                    centre,
                    at[i.section]!,
                    Curves.easeOutBack
                        .transform(((v * (n + 2) - k) / 3).clamp(0.0, 1.0)))!,
                radius: radius(i),
                selected: i.section == picked,
                visible: ((v * (n + 2) - k) / 3).clamp(0.0, 1.0),
                onTap: () => onPick(i.section),
              ),
          ]),
        ),
      );
    });
  }
}

class _Lines extends CustomPainter {
  _Lines(
      {required this.centre,
      required this.at,
      required this.threads,
      required this.picked,
      required this.c,
      required this.v});
  final Offset centre;
  final Map<String, Offset> at;
  final List<Thread> threads;
  final String picked;
  final RbColors c;
  final double v;

  @override
  void paint(Canvas canvas, Size size) {
    final spoke = Paint()
      ..strokeWidth = 1
      ..color = c.text.withValues(alpha: 0.12 * v);
    for (final p in at.values) {
      canvas.drawLine(centre, Offset.lerp(centre, p, v)!, spoke);
    }
    // Interest to interest, only where they share topics; thicker for more shared topics,
    // brighter when it touches the picked one.
    for (final t in threads) {
      final lit = t.a == picked || t.b == picked;
      canvas.drawLine(
          at[t.a]!,
          at[t.b]!,
          Paint()
            ..strokeWidth = (1 + t.shared.length * 0.6).clamp(1, 3)
            ..shader = LinearGradient(colors: [
              c.section(t.a).withValues(alpha: (lit ? 0.7 : 0.25) * v),
              c.section(t.b).withValues(alpha: (lit ? 0.7 : 0.25) * v),
            ]).createShader(Rect.fromPoints(at[t.a]!, at[t.b]!)));
    }
  }

  @override
  bool shouldRepaint(_Lines old) => old.v != v || old.picked != picked;
}

class _Node extends StatelessWidget {
  const _Node(
      {required this.interest,
      required this.centre,
      required this.radius,
      required this.selected,
      required this.visible,
      required this.onTap});
  final Interest interest;
  final Offset centre;
  final double radius, visible;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final hue = c.section(interest.section);
    final name = interestNames[interest.section]!;
    const label = 22.0;
    return Positioned(
      left: centre.dx - 60,
      top: centre.dy - radius,
      width: 120,
      height: radius * 2 + label,
      child: Opacity(
        opacity: visible,
        child: Semantics(
          button: true,
          selected: selected,
          label: '$name, ${interest.memories.length} memories',
          excludeSemantics: true,
          child: Pressable(
            onTap: onTap,
            child: Column(children: [
              AnimatedContainer(
                duration: RbMotion.base,
                curve: RbMotion.curve,
                width: radius * 2,
                height: radius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color.alphaBlend(
                      hue.withValues(alpha: selected ? 0.30 : 0.16), c.surface),
                  border: Border.all(
                      color: hue.withValues(alpha: selected ? 1 : 0.6),
                      width: selected ? 2 : 1),
                  boxShadow: [
                    BoxShadow(
                        color: hue.withValues(alpha: selected ? 0.55 : 0.28),
                        blurRadius: selected ? 26 : 16)
                  ],
                ),
                child: Icon(sectionIcons[interest.section],
                    color: hue, size: radius * 0.8),
              ),
              const SizedBox(height: 4),
              Text(name,
                  maxLines: 1,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? c.text : c.muted)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// The picked interest: its topics, why it connects to the others, and its memories.
class _Detail extends StatelessWidget {
  const _Detail(
      {required this.interest,
      required this.threads,
      required this.topic,
      required this.onTopic,
      required this.onPick,
      required this.onSeeAll});
  final Interest interest;
  final List<Thread> threads;
  final String? topic;
  final ValueChanged<String> onTopic, onPick;
  final VoidCallback onSeeAll;

  static const _shown = 8;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = RbColors.of(context);
    final hue = c.section(interest.section);
    final topics = interest.topics.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final memories = [
      for (final m in interest.memories)
        if (topic == null || topicsOf(m.item, m.save).contains(topic)) m
    ]..sort((a, b) => ((b.save['created_at'] ?? 0) as num)
        .compareTo((a.save['created_at'] ?? 0) as num));
    return Container(
      margin: const EdgeInsets.fromLTRB(RbSpace.side, 8, RbSpace.side, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(RbSpace.cardRadius),
        border: Border.all(color: c.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(sectionIcons[interest.section], color: hue, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child:
                  Text(interestNames[interest.section]!, style: t.titleLarge)),
          Text('${interest.memories.length} memories', style: t.bodySmall),
        ]),
        if (topics.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in topics.take(10))
              ChoiceChip(
                label: Text('${e.key} · ${e.value}'),
                selected: topic == e.key,
                showCheckmark: false,
                onSelected: (_) => onTopic(e.key),
              ),
          ]),
        ],
        if (threads.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Connected to', style: t.titleSmall),
          const SizedBox(height: 6),
          for (final th in threads)
            Builder(builder: (context) {
              final other = th.a == interest.section ? th.b : th.a;
              return Pressable(
                onTap: () => onPick(other),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: c.section(other), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text.rich(TextSpan(children: [
                        TextSpan(
                            text: interestNames[other], style: t.titleSmall),
                        TextSpan(
                            text: '  through ${th.shared.take(3).join(', ')}',
                            style: t.bodySmall),
                      ])),
                    ),
                    Icon(Icons.chevron_right, size: 18, color: c.faint),
                  ]),
                ),
              );
            }),
        ],
        const SizedBox(height: 12),
        for (final m in memories.take(_shown)) _MemoryRow(memory: m),
        if (memories.length > _shown || topic == null)
          TextButton(
              onPressed: onSeeAll,
              child: Text('See all in ${sectionLabels[interest.section]}')),
      ]),
    );
  }
}

class _MemoryRow extends StatelessWidget {
  const _MemoryRow({required this.memory});
  final Memory memory;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final (title, detail) = cardFace(memory.item, memory.save);
    final id = memory.save['save_id'] as String?,
        space = memory.save['space_id'] as String?;
    return Pressable(
      onTap: id == null || space == null
          ? null
          : () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SaveScreen(
                  spaceId: space, saveId: id, initial: memory.save))),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox.square(
                dimension: 44, child: FrameImage(save: memory.save)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleSmall),
              if (detail.isNotEmpty)
                Text(detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodySmall),
            ]),
          ),
        ]),
      ),
    );
  }
}
