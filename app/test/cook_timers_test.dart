import 'package:flutter_test/flutter_test.dart';
import 'package:reelbrain/features/recipes/cook_timers.dart';

void main() {
  final t0 = DateTime(2026, 10, 24, 20);

  test('timers count down, ring once, and run side by side', () {
    final timers = CookTimers()
      ..start(1, const Duration(minutes: 10), t0)
      ..start(3, const Duration(minutes: 2), t0);
    final later = t0.add(const Duration(minutes: 1));
    expect([for (final a in timers.active(later)) (a.$1, a.$2.inSeconds)],
        [(3, 60), (1, 540)]);
    final ring = t0.add(const Duration(minutes: 2));
    expect(timers.takeFinished(ring), [3]);
    expect(timers.takeFinished(ring), isEmpty, reason: 'rings once');
    expect(timers.isRunning(1), isTrue);
  });

  test('pause keeps the remaining time; resume continues from it', () {
    final timers = CookTimers()..start(0, const Duration(minutes: 5), t0);
    timers.pause(0, t0.add(const Duration(minutes: 2)));
    expect(timers.isPaused(0), isTrue);
    expect(timers.takeFinished(t0.add(const Duration(hours: 1))), isEmpty,
        reason: 'paused never rings');
    final back = t0.add(const Duration(minutes: 30));
    timers.resume(0, back);
    expect(timers.active(back).single.$2, const Duration(minutes: 3));
  });

  test('clock text', () {
    expect(clock(const Duration(seconds: 65)), '1:05');
    expect(clock(const Duration(minutes: 90)), '1:30:00');
    expect(clock(Duration.zero), '0:00');
  });
}
