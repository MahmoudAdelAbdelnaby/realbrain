import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/art/mark.dart';
import '../../core/data/repo.dart';
import '../../core/theme/theme.dart';
import '../../core/ui/art_frames.dart';
import '../../core/ui/components.dart';
import 'workout_plan.dart';

/// Workout mode (P1-14, restyled): the pose frame inside a saffron ring, digits you can read
/// from the floor, 3-2-1 beep and haptic, rest and next on their own, pause and skip; finishing
/// stamps the workouts done. The screen stays on.
class WorkoutMode extends StatefulWidget {
  const WorkoutMode({super.key, required this.phases, required this.items});
  final List<Phase> phases;
  final List<Discovery> items;

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
    for (final d in widget.items) {
      if (!d.isDone) {
        Repo.instance.setStamp(d, d.category.finished.state).ignore();
      }
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
    return Theme(
      data: rbTheme(Brightness.dark),
      child: Builder(builder: (context) {
        final c = RbColors.of(context);
        final now = DateTime.now();
        if (_run.finished) {
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(RbSpace.side),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const BrainMark(size: 120, motion: MarkMotion.arriving),
                    const SizedBox(height: 18),
                    Text('Workout done',
                        style: RbType.serif(32, color: c.text)),
                    const SizedBox(height: 6),
                    MonoLabel(
                        widget.items.length == 1
                            ? 'Piece placed'
                            : '${widget.items.length} pieces placed',
                        color: c.brandText),
                    const SizedBox(height: 24),
                    RbButton('Finish', onPressed: () => Navigator.pop(context)),
                  ]),
                ),
              ),
            ),
          );
        }
        final p = _run.current;
        final left = _run.left(now);
        final next = _run.index + 1 < widget.phases.length
            ? widget.phases[_run.index + 1].name
            : null;
        final ring = math.min(MediaQuery.sizeOf(context).width - 72, 300.0);
        return Scaffold(
          appBar: AppBar(
            backgroundColor: c.ground,
            leading: IconButton(
                tooltip: 'End workout',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context)),
            title: MonoLabel('${_run.index + 1} of ${widget.phases.length}',
                color: c.muted, size: 12),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: RbSpace.side),
              child: Column(children: [
                MonoLabel(p.rest ? 'Rest' : 'Now',
                    color: p.rest ? c.muted : c.brandText, size: 12),
                const SizedBox(height: 6),
                Text(p.name,
                    textAlign: TextAlign.center,
                    style: RbType.serif(28, color: c.text)),
                if (p.cues != null && !p.rest)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(p.cues!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: c.muted)),
                  ),
                const Spacer(),
                SizedBox.square(
                  dimension: ring,
                  child: Stack(alignment: Alignment.center, children: [
                    if (!p.rest && p.frame != null)
                      ClipOval(
                        child: SizedBox.square(
                          dimension: ring - 28,
                          child: Opacity(
                              opacity: 0.4,
                              child: FrameImage(
                                  stored: p.frame,
                                  fallback: ColoredBox(color: c.raised))),
                        ),
                      ),
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: p.seconds == null ? null : _run.progress(now),
                        strokeWidth: 8,
                        strokeCap: StrokeCap.round,
                        color: p.rest ? c.muted : c.brand,
                        backgroundColor: c.raised,
                      ),
                    ),
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(
                        left == null
                            ? '${p.reps ?? ''}'
                            : '${left.inSeconds + (left.inMilliseconds % 1000 > 0 ? 1 : 0)}',
                        style: RbType.monoNumber(RbType.timerDigits,
                            color: c.text, weight: FontWeight.w600),
                      ),
                      if (left == null && p.reps != null)
                        MonoLabel('reps', color: c.muted, size: 13),
                      if (_run.paused)
                        MonoLabel('Paused', color: c.brandText, size: 13),
                    ]),
                  ]),
                ),
                const Spacer(),
                if (next != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const MonoLabel('Next'),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(next,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: c.muted)),
                          ),
                        ]),
                  ),
              ]),
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(RbSpace.side, 4, RbSpace.side, 10),
              child: Row(children: [
                Expanded(
                  child: p.seconds != null
                      ? RbButton(_run.paused ? 'Resume' : 'Pause',
                          expand: true,
                          icon: _run.paused
                              ? Icons.play_arrow_rounded
                              : Icons.pause_rounded,
                          onPressed: () => setState(() => _run.paused
                              ? _run.resume(DateTime.now())
                              : _run.pause(DateTime.now())))
                      : RbButton('Done',
                          expand: true,
                          icon: Icons.check,
                          onPressed: () =>
                              setState(() => _run.done(DateTime.now()))),
                ),
                const SizedBox(width: 10),
                RbButton.secondary('Skip',
                    icon: Icons.skip_next_rounded,
                    onPressed: () => setState(() => _run.skip(DateTime.now()))),
              ]),
            ),
          ),
        );
      }),
    );
  }
}
