/// Kitchen timers for cooking mode (P1-11): several can run at once, one per step.
/// Pure (time is passed in), unit tested.
class CookTimers {
  final _ends = <int, DateTime>{}; // step index -> when it rings
  final _paused = <int, Duration>{}; // step index -> remaining while paused

  void start(int step, Duration length, DateTime now) {
    _paused.remove(step);
    _ends[step] = now.add(length);
  }

  void pause(int step, DateTime now) {
    final end = _ends.remove(step);
    if (end != null) {
      _paused[step] =
          end.difference(now).isNegative ? Duration.zero : end.difference(now);
    }
  }

  void resume(int step, DateTime now) {
    final left = _paused.remove(step);
    if (left != null) _ends[step] = now.add(left);
  }

  void cancel(int step) {
    _ends.remove(step);
    _paused.remove(step);
  }

  bool isRunning(int step) => _ends.containsKey(step);
  bool isPaused(int step) => _paused.containsKey(step);

  /// Remaining time per active timer (running or paused), soonest first.
  List<(int step, Duration left, bool paused)> active(DateTime now) {
    final list = [
      for (final e in _ends.entries) (e.key, _left(e.value, now), false),
      for (final e in _paused.entries) (e.key, e.value, true),
    ];
    list.sort((a, b) => a.$2.compareTo(b.$2));
    return list;
  }

  /// Steps whose timers reached zero; they are removed so each rings once.
  List<int> takeFinished(DateTime now) {
    final done = [
      for (final e in _ends.entries)
        if (!e.value.isAfter(now)) e.key
    ];
    for (final s in done) {
      _ends.remove(s);
    }
    return done;
  }

  static Duration _left(DateTime end, DateTime now) {
    final d = end.difference(now);
    return d.isNegative ? Duration.zero : d;
  }
}

String clock(Duration d) {
  final s = d.inSeconds;
  final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
  final mm = m.toString().padLeft(h > 0 ? 2 : 1, '0'),
      ss = sec.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}
