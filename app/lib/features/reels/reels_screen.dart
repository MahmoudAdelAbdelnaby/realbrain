import 'package:flutter/material.dart';

import '../../core/glass.dart';
import '../../core/native.dart';
import '../../core/theme/tokens.dart';
import '../factcheck/fact_check_view.dart' show VerdictPill, openUrl;
import '../feed/feed_screen.dart' show sectionLabels;
import '../save/save_screen.dart';

/// One extracted moment in a reel, ready to show over its frame.
typedef ReelMoment = ({
  double t,
  String? frame,
  String section,
  String title,
  String? detail,
  String? verdict,
});

String _clock(double t) =>
    '${t ~/ 60}:${(t % 60).floor().toString().padLeft(2, '0')}';

/// Every moment in a save across its sections, in reel order: claims (with verdicts), recipe
/// steps (with timers), tools (what they're for), places (why go), exercises (reps or time).
List<ReelMoment> reelMoments(List<Map<String, dynamic>> items) {
  final out = <ReelMoment>[];
  for (final item in items) {
    final section = item['section'] as String? ?? '';
    final data = (item['data'] as Map?) ?? const {};
    List<Map<String, dynamic>> list(String key) => [
          for (final e in (data[key] as List?) ?? const [])
            if (e is Map && e['t'] is num) e.cast<String, dynamic>()
        ];
    ReelMoment m(Map<String, dynamic> e, String title, String? detail,
            [String? verdict]) =>
        (
          t: (e['t'] as num).toDouble(),
          frame: e['frame'] as String?,
          section: section,
          title: title,
          detail: detail == null || detail.isEmpty ? null : detail,
          verdict: verdict,
        );
    switch (section) {
      case 'fact_check':
        for (final c in list('claims')) {
          out.add(m(c, '${c['text']}', c['correction'] as String?,
              c['verdict'] as String? ?? 'unverifiable'));
        }
      case 'recipe':
        for (final s in list('steps')) {
          final timer = (s['timer_s'] as num?)?.toInt();
          out.add(m(s, '${s['text']}',
              timer == null ? null : 'Timer ${_clock(timer.toDouble())}'));
        }
      case 'tools':
        for (final tool in list('items')) {
          out.add(m(tool, '${tool['name']}',
              tool['use_shown'] as String? ?? tool['snippet'] as String?));
        }
      case 'places':
        for (final p in list('items')) {
          out.add(m(
              p,
              '${p['name']}',
              [p['why_go'], p['what_to_order']]
                  .whereType<String>()
                  .join('. ')));
        }
      case 'workout':
        for (final e in list('exercises')) {
          final how = [
            if (e['sets'] != null) '${e['sets']} sets',
            if (e['reps'] != null) '${e['reps']} reps',
            if (e['duration_s'] != null) '${e['duration_s']} s',
          ].join(', ');
          out.add(m(
              e,
              '${e['name']}',
              [how, e['cues']]
                  .whereType<String>()
                  .where((s) => s.isNotEmpty)
                  .join('. ')));
        }
    }
  }
  return out..sort((a, b) => a.t.compareTo(b.t));
}

/// Reels (design: docs/BRAND.md): your saves full screen, swiped up and down like the apps they
/// came from. Swiping sideways steps through what Reelbrain pulled out of each one, each moment
/// over its own frame. Play original opens the reel in its app; nothing is re-hosted.
class ReelsView extends StatefulWidget {
  const ReelsView({super.key, required this.saves, required this.items});
  final List<Map<String, dynamic>> saves;
  final List<Map<String, dynamic>> items;

  @override
  State<ReelsView> createState() => _ReelsViewState();
}

class _ReelsViewState extends State<ReelsView> {
  final _pages = PageController();

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = [
      for (final s in widget.saves)
        if ((s['status'] == 'ready' || s['status'] == 'partial') &&
            s['save_id'] != null)
          s
    ];
    if (ready.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('Your reels show up here once they are read.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium),
        ),
      );
    }
    final bySave = <String, List<Map<String, dynamic>>>{};
    for (final i in widget.items) {
      (bySave[i['save_id'] as String? ?? ''] ??= []).add(i);
    }
    return PageView.builder(
      controller: _pages,
      scrollDirection: Axis.vertical,
      itemCount: ready.length,
      itemBuilder: (context, i) {
        final save = ready[i];
        return _Reel(
          key: ValueKey(save['save_id']),
          save: save,
          moments: reelMoments(bySave[save['save_id']] ?? const []),
        );
      },
    );
  }
}

class _Reel extends StatefulWidget {
  const _Reel({super.key, required this.save, required this.moments});
  final Map<String, dynamic> save;
  final List<ReelMoment> moments;

  @override
  State<_Reel> createState() => _ReelState();
}

class _ReelState extends State<_Reel> {
  final _steps = PageController();
  int _at = 0; // 0: the reel itself; 1..n: its moments

  @override
  void dispose() {
    _steps.dispose();
    super.dispose();
  }

  void _go(int page) => _steps.animateToPage(page,
      duration: RbMotion.base, curve: RbMotion.curve);

  @override
  Widget build(BuildContext context) {
    final save = widget.save;
    final moments = widget.moments;
    final c = RbColors.of(context);
    final t = Theme.of(context).textTheme;
    final key = save['key_frame_url'] as String?;
    final current = _at == 0 ? null : moments[_at - 1];
    final duration = (save['duration_s'] as num?)?.toDouble() ??
        (moments.isEmpty ? 0 : moments.last.t / 0.9);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Stack(fit: StackFit.expand, children: [
      // The frame of the moment on screen, slowly drifting closer (the reel's motion, not a video).
      AnimatedSwitcher(
        duration: RbMotion.base,
        child: _Frame(
            key: ValueKey(current?.frame ?? key),
            stored: current?.frame ?? key),
      ),
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0x99000000),
              Color(0x00000000),
              Color(0x00000000),
              Color(0xE6000000)
            ],
            stops: [0, 0.2, 0.45, 1],
          ),
        ),
      ),
      // Sideways: the reel, then each moment. The page view only catches the gesture.
      PageView.builder(
        controller: _steps,
        itemCount: moments.length + 1,
        onPageChanged: (p) => setState(() => _at = p),
        itemBuilder: (_, __) => const SizedBox.expand(),
      ),
      Positioned(
        top: MediaQuery.paddingOf(context).top + 12,
        left: RbSpace.side,
        right: RbSpace.side,
        child: Text(
          [save['creator'], save['platform']].whereType<String>().join('  ·  '),
          style: t.labelLarge?.copyWith(color: Colors.white),
        ),
      ),
      Positioned(
        left: RbSpace.side,
        right: 72,
        bottom: bottom + 112,
        child: IgnorePointer(
          child: AnimatedSwitcher(
            duration: RbMotion.base,
            switchInCurve: RbMotion.curve,
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(
                  position:
                      Tween(begin: const Offset(0, 0.15), end: Offset.zero)
                          .animate(a),
                  child: child),
            ),
            child: current == null
                ? _Overview(
                    key: const ValueKey(-1), save: save, count: moments.length)
                : _MomentCard(key: ValueKey(_at), moment: current),
          ),
        ),
      ),
      // Right rail: play the original, open the save.
      Positioned(
        right: 12,
        bottom: bottom + 120,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _RailButton(
            icon: Icons.play_arrow_rounded,
            label: 'Play original',
            onTap: save['source_url'] == null
                ? null
                : () => openUrl(context, save['source_url'] as String),
          ),
          const SizedBox(height: 16),
          _RailButton(
            icon: Icons.notes_rounded,
            label: 'Open save',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => SaveScreen(
                    spaceId: save['space_id'] as String,
                    saveId: save['save_id'] as String,
                    initial: save))),
          ),
        ]),
      ),
      // The moment strip, full width: a tick per moment in its section's hue; tap one to jump.
      if (moments.isNotEmpty && duration > 0)
        Positioned(
          left: RbSpace.side,
          right: RbSpace.side,
          bottom: bottom + 96,
          height: 24,
          child: LayoutBuilder(builder: (context, box) {
            return Stack(clipBehavior: Clip.none, children: [
              Positioned(
                left: 0,
                right: 0,
                top: 11,
                height: 2,
                child: ColoredBox(color: Colors.white.withValues(alpha: 0.3)),
              ),
              for (final (n, m) in moments.indexed)
                Positioned(
                  left: (m.t / duration).clamp(0.0, 1.0) * (box.maxWidth - 24),
                  top: 0,
                  width: 24,
                  height: 24,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _go(n + 1),
                    child: Center(
                      child: AnimatedContainer(
                        duration: RbMotion.fast,
                        width: _at == n + 1 ? 6 : 4,
                        height: _at == n + 1 ? 18 : 10,
                        decoration: BoxDecoration(
                          color: m.verdict != null
                              ? _verdictColor(c, m.verdict!)
                              : c.section(m.section),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
            ]);
          }),
        ),
    ]);
  }

  static Color _verdictColor(RbColors c, String v) => switch (v) {
        'true' || 'mostly_true' => c.trueFg,
        'mixed' => c.mixedFg,
        'false' || 'mostly_false' => c.falseFg,
        _ => c.muted,
      };
}

class _Overview extends StatelessWidget {
  const _Overview({super.key, required this.save, required this.count});
  final Map<String, dynamic> save;
  final int count;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = RbColors.of(context);
    final sections = (save['sections'] as List?)?.cast<String>() ?? const [];
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in sections)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: c.section(s).withValues(alpha: 0.22),
                  border: Border.all(color: c.section(s)),
                  borderRadius: BorderRadius.circular(RbSpace.pill),
                ),
                child: Text(sectionLabels[s] ?? s,
                    style: t.labelMedium?.copyWith(color: Colors.white)),
              ),
            if (save['verdict'] != null) VerdictPill(save['verdict'] as String),
          ]),
          const SizedBox(height: 10),
          Text(save['summary'] as String? ?? '',
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: t.titleMedium?.copyWith(color: Colors.white, height: 1.3)),
          if (count > 0) ...[
            const SizedBox(height: 8),
            Text(
                count == 1
                    ? 'Swipe for the 1 moment found'
                    : 'Swipe through $count moments',
                style: t.bodySmall?.copyWith(color: Colors.white70)),
          ],
        ]);
  }
}

class _MomentCard extends StatelessWidget {
  const _MomentCard({super.key, required this.moment});
  final ReelMoment moment;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = RbColors.of(context);
    return Glass(
      radius: RbSpace.cardRadius,
      padding: const EdgeInsets.all(16),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    color: c.section(moment.section), shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                  '${sectionLabels[moment.section] ?? moment.section}  ·  ${_clock(moment.t)}',
                  style: t.labelMedium?.copyWith(color: c.text)),
              const Spacer(),
              if (moment.verdict != null) VerdictPill(moment.verdict!),
            ]),
            const SizedBox(height: 10),
            Text(moment.title,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: t.titleMedium?.copyWith(color: c.text)),
            if (moment.detail != null) ...[
              const SizedBox(height: 6),
              Text(moment.detail!,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodyMedium?.copyWith(color: c.text)),
            ],
          ]),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: Pressable(
          onTap: onTap,
          child: Column(children: [
            Glass(
              padding: const EdgeInsets.all(12),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 4),
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: Colors.white)),
          ]),
        ),
      );
}

/// A frame full bleed, drifting slowly closer while it's on screen; still under reduced motion.
class _Frame extends StatelessWidget {
  const _Frame({super.key, this.stored});
  final String? stored;

  @override
  Widget build(BuildContext context) {
    final ground = ColoredBox(color: RbColors.of(context).raised);
    return ValueListenableBuilder<String?>(
      valueListenable: backendUrl,
      builder: (context, _, __) {
        final url = frameUrl(stored);
        if (url == null) return ground;
        final image = Image.network(url,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) => ground);
        if (RbMotion.reduced(context)) return image;
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 1, end: 1.08),
          duration: const Duration(seconds: 8),
          curve: Curves.easeOut,
          builder: (_, s, child) => Transform.scale(scale: s, child: child),
          child: image,
        );
      },
    );
  }
}
