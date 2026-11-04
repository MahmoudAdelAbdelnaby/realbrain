import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/data/brain.dart';
import '../../core/format.dart';
import '../../core/theme/theme.dart';
import '../../core/ui/art_frames.dart';
import '../../core/ui/components.dart';
import 'cook_timers.dart';

/// Cooking mode (P1-11, restyled): one step per page in large type, always light (a bright
/// kitchen), the screen stays on, swipe between steps, timers pinned at the bottom, the reel's
/// frame at that step.
class CookingMode extends StatefulWidget {
  const CookingMode({super.key, required this.title, required this.steps});
  final String title;
  final List<Json> steps;

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
          toast(
              context, 'Step ${rang.map((s) => s + 1).join(', ')}: time’s up');
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
      data: rbTheme(Brightness.light),
      child: Builder(builder: (context) {
        final c = RbColors.of(context);
        final n = widget.steps.length;
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context)),
            title: Text(widget.title,
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          body: Column(children: [
            // Progress: one tick per step.
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(RbSpace.side, 0, RbSpace.side, 8),
              child: Row(children: [
                for (var i = 0; i < n; i++)
                  Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                          color: i <= _page ? c.brand : c.line,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
              ]),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: n,
                onPageChanged: (p) => setState(() => _page = p),
                itemBuilder: (context, i) {
                  final s = widget.steps[i];
                  final secs = (s['timer_s'] as num?)?.toInt();
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(
                        RbSpace.side, 12, RbSpace.side, 24),
                    children: [
                      MonoLabel('Step ${i + 1} of $n',
                          color: c.brandText, size: 12),
                      const SizedBox(height: 10),
                      Text('${s['text']}',
                          style: RbType.serif(RbType.cookingStep,
                              color: c.text, height: 1.25)),
                      const SizedBox(height: 20),
                      if (secs != null &&
                          !_timers.isRunning(i) &&
                          !_timers.isPaused(i))
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: RbButton(
                              'Start ${clock(Duration(seconds: secs))}',
                              icon: Icons.timer_outlined,
                              onPressed: () => setState(() => _timers.start(
                                  i, Duration(seconds: secs), DateTime.now()))),
                        ),
                      if (s['frame'] != null) ...[
                        const SizedBox(height: 20),
                        if (s['t'] != null)
                          MonoLabel('In the reel at ${mmss(s['t'] as num)}'),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius:
                              BorderRadius.circular(RbSpace.cardRadius),
                          child: SizedBox(
                            height: 300,
                            child: FrameImage(
                                stored: s['frame'] as String?,
                                fallback: ColoredBox(color: c.raised)),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ]),
          // Running timers stay pinned while you swipe.
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(RbSpace.side, 6, RbSpace.side, 8),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (active.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final (step, left, paused) in active)
                        InputChip(
                          avatar: Icon(paused ? Icons.play_arrow : Icons.pause,
                              size: 18),
                          label: Text('Step ${step + 1} · ${clock(left)}',
                              style: RbType.monoNumber(17, color: c.text)),
                          onPressed: () => setState(() => paused
                              ? _timers.resume(step, DateTime.now())
                              : _timers.pause(step, DateTime.now())),
                          onDeleted: () => setState(() => _timers.cancel(step)),
                        ),
                    ]),
                  ),
                Row(children: [
                  RbButton.secondary('Back',
                      icon: Icons.arrow_back,
                      onPressed: _page == 0
                          ? null
                          : () => _pages.previousPage(
                              duration: RbMotion.base, curve: RbMotion.curve)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RbButton(
                        _page == n - 1 ? 'Done cooking' : 'Next step',
                        expand: true,
                        onPressed: () => _page == n - 1
                            ? Navigator.pop(context, true)
                            : _pages.nextPage(
                                duration: RbMotion.base,
                                curve: RbMotion.curve)),
                  ),
                ]),
              ]),
            ),
          ),
        );
      }),
    );
  }
}
