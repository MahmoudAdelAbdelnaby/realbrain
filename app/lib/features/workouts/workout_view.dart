import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/native.dart';
import '../recipes/cook_timers.dart' show clock;
import 'workout_plan.dart';

List<Map<String, dynamic>> exercisesOf(Map<String, dynamic> item) => [
      for (final e
          in (((item['data'] as Map?)?['exercises'] as List?) ?? const []))
        (e as Map).cast<String, dynamic>(),
    ];

/// Key for one exercise inside a routine's overrides: `save/item#index`.
String exerciseKey(Map<String, dynamic> item, int n) =>
    '${item['save_id']}/${item['item_id']}#$n';

/// Exercises of several workout items, with a routine's overrides applied.
List<Map<String, dynamic>> routineExercises(
        List<Map<String, dynamic>> items, Map<String, dynamic> overrides) =>
    [
      for (final item in items)
        for (final (n, e) in exercisesOf(item).indexed)
          {
            ...e,
            ...((overrides[exerciseKey(item, n)] as Map?)
                    ?.cast<String, dynamic>() ??
                const {})
          },
    ];

String exerciseLine(Map<String, dynamic> e) {
  final what = e['duration_s'] != null
      ? '${e['duration_s']} s'
      : '${e['reps'] ?? '?'} reps';
  final sets = (e['sets'] as num?) != null && (e['sets'] as num) > 1
      ? ' × ${e['sets']}'
      : '';
  return '${e['name']}: $what$sets${e['estimated'] == true ? ' (≈)' : ''}';
}

/// Workout card (P1-13): each exercise with its pose frame from the reel, and Start.
class WorkoutView extends StatelessWidget {
  const WorkoutView({super.key, required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final exercises = exercisesOf(item);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in exercises)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: _Pose(frameUrl(e['frame'] as String?), size: 48),
            title: Text(exerciseLine(e)),
            subtitle: e['cues'] != null ? Text('${e['cues']}') : null,
          ),
        if (exercises.isNotEmpty)
          FilledButton.icon(
            onPressed: () => startWorkout(context, exercises, [item]),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start workout'),
          ),
      ],
    );
  }
}

void startWorkout(BuildContext context, List<Map<String, dynamic>> exercises,
    List<Map<String, dynamic>> items) {
  Navigator.of(context).push(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => WorkoutMode(phases: buildPhases(exercises), items: items),
  ));
}

class _Pose extends StatelessWidget {
  const _Pose(this.url, {required this.size});
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final box = SizedBox.square(
      dimension: size,
      child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest),
    );
    return ClipOval(
      child: url == null
          ? box
          : Image.network(url!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => box),
    );
  }
}

/// Workout mode (P1-14): ring timer around the pose, 3-2-1 beep + haptic, auto rest and next,
/// pause/skip, Done for reps; marks the workouts done at the end. Screen stays on.
class WorkoutMode extends StatefulWidget {
  const WorkoutMode({super.key, required this.phases, required this.items});
  final List<Phase> phases;
  final List<Map<String, dynamic>> items;

  @override
  State<WorkoutMode> createState() => _WorkoutModeState();
}

class _WorkoutModeState extends State<WorkoutMode> {
  late final _run = WorkoutRunner(widget.phases)..start(DateTime.now());
  Timer? _tick;
  int? _lastBeep;
  bool _logged = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable().ignore();
    _tick = Timer.periodic(const Duration(milliseconds: 250), (_) => _onTick());
  }

  void _onTick() {
    final now = DateTime.now();
    final beep = _run.countdown(now);
    if (beep != null && beep != _lastBeep) {
      SystemSound.play(SystemSoundType.click);
      HapticFeedback.mediumImpact();
    }
    _lastBeep = beep;
    if (_run.tick(now)) {
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.heavyImpact();
    }
    if (_run.finished) _finish();
    if (mounted) setState(() {});
  }

  void _finish() {
    if (_logged) return;
    _logged = true;
    _tick?.cancel();
    for (final i in widget.items) {
      if (i['item_id'] == null) continue;
      FirebaseFirestore.instance
          .doc(
              'spaces/${i['space_id']}/saves/${i['save_id']}/items/${i['item_id']}')
          .update({'user_state': 'done'}).ignore();
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    WakelockPlus.disable().ignore();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final t = Theme.of(context).textTheme;
    if (_run.finished) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Workout complete', style: t.headlineMedium),
            const SizedBox(height: 16),
            FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done')),
          ]),
        ),
      );
    }
    final p = _run.current;
    final left = _run.left(now);
    final next = _run.index + 1 < widget.phases.length
        ? widget.phases[_run.index + 1].name
        : null;
    return Scaffold(
      appBar:
          AppBar(title: Text('${_run.index + 1} / ${widget.phases.length}')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Text(p.name, style: t.headlineSmall, textAlign: TextAlign.center),
            if (p.cues != null)
              Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(p.cues!, textAlign: TextAlign.center)),
            const Spacer(),
            SizedBox.square(
              dimension: 280,
              child: Stack(alignment: Alignment.center, children: [
                if (!p.rest)
                  Opacity(
                      opacity: 0.35,
                      child: _Pose(frameUrl(p.frame), size: 240)),
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: p.seconds == null ? null : _run.progress(now),
                    strokeWidth: 10,
                  ),
                ),
                Text(
                  left == null
                      ? '${p.reps ?? ''}'
                      : '${left.inSeconds + (left.inMilliseconds % 1000 > 0 ? 1 : 0)}',
                  style: const TextStyle(
                      fontSize: 96,
                      fontWeight: FontWeight.w600,
                      fontFeatures: [FontFeature.tabularFigures()]),
                ),
              ]),
            ),
            if (left == null && p.reps != null)
              Text('reps', style: t.titleMedium),
            const Spacer(),
            if (next != null) Text('Next: $next', style: t.bodyLarge),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (p.seconds != null)
                IconButton.filledTonal(
                  iconSize: 32,
                  tooltip: _run.paused ? 'Resume' : 'Pause',
                  onPressed: () => setState(() => _run.paused
                      ? _run.resume(DateTime.now())
                      : _run.pause(DateTime.now())),
                  icon: Icon(_run.paused ? Icons.play_arrow : Icons.pause),
                )
              else
                FilledButton(
                    onPressed: () => setState(() => _run.done(DateTime.now())),
                    child: const Text('Done')),
              const SizedBox(width: 16),
              IconButton.outlined(
                iconSize: 32,
                tooltip: 'Skip',
                onPressed: () => setState(() => _run.skip(DateTime.now())),
                icon: const Icon(Icons.skip_next),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// Routines (P1-13): lists of workouts in your spaces, with per-exercise edits.
class RoutinesBar extends StatelessWidget {
  const RoutinesBar({super.key, required this.spaceIds, required this.items});
  final List<String> spaceIds;
  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final id in spaceIds)
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('spaces/$id/lists')
              .where('section', isEqualTo: 'workout')
              .snapshots(),
          builder: (context, snap) => Wrap(spacing: 8, children: [
            for (final d in snap.data?.docs ?? const [])
              ActionChip(
                avatar: const Icon(Icons.fitness_center, size: 18),
                label: Text('${d.data()['name']}'),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => RoutineScreen(ref: d.reference, items: items),
                )),
              ),
          ]),
        ),
    ]);
  }
}

class RoutineScreen extends StatelessWidget {
  const RoutineScreen({super.key, required this.ref, required this.items});
  final DocumentReference<Map<String, dynamic>> ref;
  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snap) {
        final list = snap.data?.data() ?? const {};
        final refs = ((list['item_refs'] as List?) ?? const []).cast<String>();
        final overrides =
            (list['overrides'] as Map?)?.cast<String, dynamic>() ?? const {};
        final chosen = [
          for (final r in refs)
            ...items.where((i) => '${i['save_id']}/${i['item_id']}' == r),
        ];
        return Scaffold(
          appBar: AppBar(title: Text('${list['name'] ?? 'Routine'}')),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            for (final item in chosen)
              for (final (n, e) in exercisesOf(item).indexed)
                _EditableExercise(
                  exercise: {
                    ...e,
                    ...((overrides[exerciseKey(item, n)] as Map?)
                            ?.cast<String, dynamic>() ??
                        const {})
                  },
                  onSeconds: (s) => ref.update({
                    FieldPath(
                        ['overrides', exerciseKey(item, n), 'duration_s']): s
                  }),
                ),
            const SizedBox(height: 16),
            if (chosen.isNotEmpty)
              FilledButton.icon(
                onPressed: () => startWorkout(
                    context, routineExercises(chosen, overrides), chosen),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start routine'),
              ),
          ]),
        );
      },
    );
  }
}

class _EditableExercise extends StatelessWidget {
  const _EditableExercise({required this.exercise, required this.onSeconds});
  final Map<String, dynamic> exercise;
  final void Function(int seconds) onSeconds;

  @override
  Widget build(BuildContext context) {
    final s = (exercise['duration_s'] as num?)?.toInt();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text('${exercise['name']}'),
      subtitle: Text(s == null
          ? '${exercise['reps'] ?? '?'} reps'
          : clock(Duration(seconds: s))),
      trailing: s == null
          ? null
          : Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                  tooltip: '5 s less',
                  onPressed: s > 5 ? () => onSeconds(s - 5) : null,
                  icon: const Icon(Icons.remove)),
              IconButton(
                  tooltip: '5 s more',
                  onPressed: () => onSeconds(s + 5),
                  icon: const Icon(Icons.add)),
            ]),
    );
  }
}
