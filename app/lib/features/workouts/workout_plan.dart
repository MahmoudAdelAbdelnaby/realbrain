/// Workout plan and runner (P1-13/P1-14). Pure: time is passed in, unit tested.
library;

class Phase {
  const Phase(
      {required this.name,
      required this.seconds,
      required this.rest,
      this.reps,
      this.frame,
      this.cues});
  final String name;
  final int? seconds; // null: reps-based, the user taps Done
  final bool rest;
  final int? reps;
  final String? frame;
  final String? cues;
}

const defaultWorkS = 40; // a timed exercise with no duration in the video
const defaultRestS = 20;

/// Exercises (from one or more saves, with the user's overrides) -> work/rest phases.
/// Sets repeat the exercise; rest comes after each set except the very last.
List<Phase> buildPhases(List<Map<String, dynamic>> exercises) {
  final phases = <Phase>[];
  for (final (n, e) in exercises.indexed) {
    final sets = ((e['sets'] as num?)?.toInt() ?? 1).clamp(1, 10);
    final reps = (e['reps'] as num?)?.toInt();
    final work = (e['duration_s'] as num?)?.toInt() ??
        (reps == null ? defaultWorkS : null);
    final rest = (e['rest_s'] as num?)?.toInt() ?? defaultRestS;
    for (var s = 0; s < sets; s++) {
      phases.add(Phase(
        name: sets > 1 ? '${e['name']} · set ${s + 1}/$sets' : '${e['name']}',
        seconds: work,
        rest: false,
        reps: reps,
        frame: e['frame'] as String?,
        cues: e['cues'] as String?,
      ));
      final last = n == exercises.length - 1 && s == sets - 1;
      if (!last && rest > 0) {
        phases.add(Phase(name: 'Rest', seconds: rest, rest: true));
      }
    }
  }
  return phases;
}

/// Steps through phases: timed ones end on their own, reps ones on done(); pause/skip.
class WorkoutRunner {
  WorkoutRunner(this.phases);
  final List<Phase> phases;
  int index = 0;
  DateTime? _endsAt;
  Duration? _pausedLeft;
  bool finished = false;

  Phase get current => phases[index];
  bool get paused => _pausedLeft != null;

  void start(DateTime now) => _enter(0, now);

  void _enter(int i, DateTime now) {
    if (i >= phases.length) {
      finished = true;
      _endsAt = null;
      return;
    }
    index = i;
    _pausedLeft = null;
    final s = phases[i].seconds;
    _endsAt = s == null ? null : now.add(Duration(seconds: s));
  }

  Duration? left(DateTime now) {
    if (_pausedLeft != null) return _pausedLeft;
    if (_endsAt == null) return null;
    final d = _endsAt!.difference(now);
    return d.isNegative ? Duration.zero : d;
  }

  /// Seconds left to beep on (3, 2, 1), or null. Call once per second.
  int? countdown(DateTime now) {
    final l = left(now);
    if (l == null || paused) return null;
    final s = (l.inMilliseconds / 1000).ceil();
    return s >= 1 && s <= 3 ? s : null;
  }

  /// Advances when the timed phase ran out; returns true when it moved on.
  bool tick(DateTime now) {
    if (finished || paused || _endsAt == null || now.isBefore(_endsAt!)) {
      return false;
    }
    _enter(index + 1, now);
    return true;
  }

  void done(DateTime now) =>
      _enter(index + 1, now); // reps exercise finished, or skip
  void skip(DateTime now) => _enter(index + 1, now);

  void pause(DateTime now) {
    if (paused || _endsAt == null) return;
    _pausedLeft = left(now);
    _endsAt = null;
  }

  void resume(DateTime now) {
    final l = _pausedLeft;
    if (l == null) return;
    _pausedLeft = null;
    _endsAt = now.add(l);
  }

  /// Fraction of the current timed phase elapsed (0..1), for the ring.
  double progress(DateTime now) {
    final s = current.seconds;
    final l = left(now);
    if (s == null || l == null || s == 0) return 0;
    return (1 - l.inMilliseconds / (s * 1000)).clamp(0.0, 1.0);
  }
}
