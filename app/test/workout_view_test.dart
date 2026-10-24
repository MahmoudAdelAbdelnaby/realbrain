import 'package:flutter_test/flutter_test.dart';
import 'package:reelbrain/features/workouts/workout_view.dart';

void main() {
  final item = {
    'save_id': 's1',
    'item_id': '0-workout',
    'data': {
      'exercises': [
        {'name': 'Plank', 'duration_s': 30},
        {'name': 'Squats', 'reps': 12, 'sets': 3},
      ],
    },
  };

  test('routine overrides replace an exercise duration by key', () {
    final list = routineExercises([
      item
    ], {
      's1/0-workout#0': {'duration_s': 45},
    });
    expect(list.first['duration_s'], 45);
    expect(list.last['reps'], 12);
  });

  test('exercise lines', () {
    expect(exerciseLine({'name': 'Plank', 'duration_s': 30}), 'Plank: 30 s');
    expect(exerciseLine({'name': 'Squats', 'reps': 12, 'sets': 3}),
        'Squats: 12 reps × 3');
    expect(exerciseLine({'name': 'Jog', 'estimated': true}), 'Jog: ? reps (≈)');
  });
}
