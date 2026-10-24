import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/native.dart';
import '../../main.dart' show lightTheme;
import 'cook_timers.dart';
import 'recipe_math.dart';

List<Map<String, dynamic>> _list(Map<String, dynamic> d, String k) => [
      for (final x in (d[k] as List?) ?? const [])
        (x as Map).cast<String, dynamic>()
    ];

String _at(Object? t) {
  final s = (t as num?)?.round();
  return s == null ? '' : '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// Recipe card (P1-10): servings scaler, ingredients with "≈" for estimates, steps, tags, Cook.
class RecipeView extends StatefulWidget {
  const RecipeView({super.key, required this.data});
  final Map<String, dynamic> data;

  @override
  State<RecipeView> createState() => _RecipeViewState();
}

class _RecipeViewState extends State<RecipeView> {
  late int _servings = (widget.data['servings'] as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final base = (d['servings'] as num?)?.toInt();
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final tags = ((d['tags'] as List?) ?? const []).cast<String>();
    final steps = _list(d, 'steps');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (d['title'] != null)
          Text('${d['title']}', style: Theme.of(context).textTheme.titleMedium),
        if (tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
                spacing: 6,
                children: [for (final t in tags) Chip(label: Text(t))]),
          ),
        const SizedBox(height: 8),
        Row(children: [
          if (base != null) ...[
            const Text('Serves'),
            IconButton(
              tooltip: 'Fewer servings',
              onPressed:
                  _servings > 1 ? () => setState(() => _servings--) : null,
              icon: const Icon(Icons.remove),
            ),
            Text('$_servings',
                style: const TextStyle(
                    fontFeatures: [FontFeature.tabularFigures()])),
            IconButton(
              tooltip: 'More servings',
              onPressed: () => setState(() => _servings++),
              icon: const Icon(Icons.add),
            ),
          ],
          if (d['total_min'] != null)
            Text('  ${d['total_min']} min', style: TextStyle(color: muted)),
        ]),
        for (final i in _list(d, 'ingredients'))
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
                '• ${ingredientLine(i, from: base, to: base == null ? null : _servings)}'),
          ),
        if (_list(d, 'ingredients').any((i) => i['estimated'] == true))
          Text('≈ estimated: not said in the video',
              style: TextStyle(color: muted, fontSize: 12)),
        const SizedBox(height: 8),
        for (final (n, s) in steps.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('${n + 1}. ${s['text']}'
                '${s['timer_s'] != null ? '  ⏱ ${clock(Duration(seconds: (s['timer_s'] as num).toInt()))}' : ''}'),
          ),
        if (steps.isNotEmpty)
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => CookingMode(
                  title: '${d['title'] ?? 'Cooking'}', steps: steps),
            )),
            icon: const Icon(Icons.soup_kitchen_outlined),
            label: const Text('Cook'),
          ),
      ],
    );
  }
}

/// Cooking mode (P1-11): one step per page, big type, always light (bright kitchen), screen on,
/// swipe between steps, timers pinned at the bottom, the reel's frame at that step.
class CookingMode extends StatefulWidget {
  const CookingMode({super.key, required this.title, required this.steps});
  final String title;
  final List<Map<String, dynamic>> steps;

  @override
  State<CookingMode> createState() => _CookingModeState();
}

class _CookingModeState extends State<CookingMode> {
  final _timers = CookTimers();
  final _pages = PageController();
  Timer? _tick;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable().ignore();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      final rang = _timers.takeFinished(DateTime.now());
      if (rang.isNotEmpty) {
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.alert);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Step ${rang.map((s) => s + 1).join(', ')} timer done')),
          );
        }
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _pages.dispose();
    WakelockPlus.disable().ignore();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final active = _timers.active(now);
    return Theme(
      data: lightTheme,
      child: Builder(builder: (context) {
        final muted = Theme.of(context).colorScheme.onSurfaceVariant;
        return Scaffold(
          appBar: AppBar(
              title: Text(
                  '${widget.title} · ${_page + 1}/${widget.steps.length}')),
          body: SafeArea(
            child: Column(children: [
              Expanded(
                child: PageView.builder(
                  controller: _pages,
                  itemCount: widget.steps.length,
                  onPageChanged: (p) => setState(() => _page = p),
                  itemBuilder: (context, i) {
                    final s = widget.steps[i];
                    final frame = frameUrl(s['frame'] as String?);
                    final secs = (s['timer_s'] as num?)?.toInt();
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text('${s['text']}',
                            style: const TextStyle(
                                fontSize: 28,
                                height: 1.3,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 16),
                        if (secs != null &&
                            !_timers.isRunning(i) &&
                            !_timers.isPaused(i))
                          FilledButton.icon(
                            onPressed: () => setState(() => _timers.start(
                                i, Duration(seconds: secs), DateTime.now())),
                            icon: const Icon(Icons.timer_outlined),
                            label:
                                Text('Start ${clock(Duration(seconds: secs))}'),
                          ),
                        if (frame != null) ...[
                          const SizedBox(height: 16),
                          Text('In the reel at ${_at(s['t'])}',
                              style: TextStyle(color: muted)),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(frame,
                                height: 320,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const SizedBox()),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
              if (active.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final (step, left, paused) in active)
                      InputChip(
                        avatar: Icon(paused ? Icons.play_arrow : Icons.pause,
                            size: 18),
                        label: Text('Step ${step + 1} · ${clock(left)}',
                            style: const TextStyle(
                                fontSize: 18,
                                fontFeatures: [FontFeature.tabularFigures()])),
                        onPressed: () => setState(() => paused
                            ? _timers.resume(step, DateTime.now())
                            : _timers.pause(step, DateTime.now())),
                        onDeleted: () => setState(() => _timers.cancel(step)),
                      ),
                  ]),
                ),
            ]),
          ),
        );
      }),
    );
  }
}
