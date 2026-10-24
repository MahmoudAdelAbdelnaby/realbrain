import 'package:flutter_test/flutter_test.dart';
import 'package:reelbrain/features/workouts/workout_plan.dart';

void main() {
  final t0 = DateTime(2026, 10, 24, 7);
  DateTime at(int s) => t0.add(Duration(seconds: s));

  test('sets repeat, rest between, none after the last', () {
    final p = buildPhases([
      {'name': 'Plank', 'duration_s': 30, 'sets': 2, 'rest_s': 10},
      {'name': 'Squats', 'reps': 12},
    ]);
    expect([
      for (final x in p) '${x.name}:${x.seconds}'
    ], [
      'Plank · set 1/2:30',
      'Rest:10',
      'Plank · set 2/2:30',
      'Rest:10',
      'Squats:null',
    ]);
    expect(p.last.reps, 12);
  });

  test('a timed exercise without a duration gets the default', () {
    expect(
        buildPhases([
          {'name': 'Jog'}
        ]).single.seconds,
        defaultWorkS);
  });

  test('runner auto-advances, beeps 3-2-1, waits for Done on reps', () {
    final r = WorkoutRunner(buildPhases([
      {'name': 'Plank', 'duration_s': 5, 'rest_s': 2},
      {'name': 'Push-ups', 'reps': 10},
    ]))
      ..start(t0);
    expect(r.countdown(at(1)), isNull);
    expect([r.countdown(at(2)), r.countdown(at(3)), r.countdown(at(4))],
        [3, 2, 1]);
    expect(r.tick(at(4)), isFalse);
    expect(r.tick(at(5)), isTrue);
    expect(r.current.rest, isTrue);
    r.tick(at(7));
    expect(r.current.name, 'Push-ups');
    expect(r.tick(at(500)), isFalse, reason: 'reps wait for Done');
    r.done(at(500));
    expect(r.finished, isTrue);
  });

  test('pause freezes the clock; skip moves on', () {
    final r = WorkoutRunner(buildPhases([
      {'name': 'Plank', 'duration_s': 30, 'rest_s': 10},
      {'name': 'Bridge', 'duration_s': 30},
    ]))
      ..start(t0);
    r.pause(at(10));
    expect(r.tick(at(100)), isFalse);
    expect(r.left(at(100)), const Duration(seconds: 20));
    r.resume(at(100));
    expect(r.progress(at(110)), closeTo(2 / 3, 0.01),
        reason: '10 of 30 s left');
    r.skip(at(111));
    expect(r.current.rest, isTrue);
  });
}
