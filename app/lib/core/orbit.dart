import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'brain_mark.dart';
import 'theme/tokens.dart';

/// Design v4 revision 2's one luminous motif (onboarding; later Threads and Year in Brain): the
/// brain glowing softly in the centre, two thin tilted orbits, and memory nodes in the four
/// accents travelling slowly along them, each tied to the centre by a fine line.
/// Still under reduced motion.
class OrbitBrain extends StatefulWidget {
  const OrbitBrain({super.key, this.size = 280});
  final double size;

  @override
  State<OrbitBrain> createState() => _OrbitBrainState();
}

class _OrbitBrainState extends State<OrbitBrain>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 40));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (RbMotion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final s = widget.size;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: s,
        child: Stack(alignment: Alignment.center, children: [
          // The glow behind the brain: the one place light comes from.
          Container(
            width: s * 0.62,
            height: s * 0.62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                c.brand.withValues(alpha: 0.35),
                c.brand.withValues(alpha: 0),
              ]),
            ),
          ),
          CustomPaint(
            size: Size.square(s),
            painter: _OrbitPainter(_c, c),
          ),
          BrainMark(size: s * 0.36),
        ]),
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  _OrbitPainter(this.t, this.c) : super(repaint: t);
  final Animation<double> t;
  final RbColors c;

  /// (orbit, start angle): where each memory node rides.
  static const _nodes = [(0, 0.2), (0, 2.4), (0, 4.3), (1, 1.1), (1, 3.6)];

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final orbits = [
      (rx: size.width * 0.46, ry: size.width * 0.17, tilt: -0.35),
      (rx: size.width * 0.40, ry: size.width * 0.14, tilt: 0.55),
    ];
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = c.text.withValues(alpha: 0.14);
    for (final o in orbits) {
      canvas.save();
      canvas.translate(centre.dx, centre.dy);
      canvas.rotate(o.tilt);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset.zero, width: o.rx * 2, height: o.ry * 2),
          ring);
      canvas.restore();
    }
    final accents = [
      c.section('fact_check'), // violet
      c.section('tools'), // blue
      c.section('places'), // teal
      c.section('recipe'), // amber
      c.section('tools'),
    ];
    final tie = Paint()
      ..strokeWidth = 1
      ..color = c.text.withValues(alpha: 0.08);
    for (final (n, (orbit, start)) in _nodes.indexed) {
      final o = orbits[orbit];
      // The inner orbit runs the other way, a little faster.
      final a = start + (orbit == 0 ? 1 : -1.3) * t.value * 2 * math.pi;
      final local = Offset(o.rx * math.cos(a), o.ry * math.sin(a));
      final p = centre +
          Offset(local.dx * math.cos(o.tilt) - local.dy * math.sin(o.tilt),
              local.dx * math.sin(o.tilt) + local.dy * math.cos(o.tilt));
      canvas.drawLine(centre, p, tie);
      final colour = accents[n];
      final r = 4.0 + (n % 3);
      canvas.drawCircle(
          p,
          r * 2.6,
          Paint()
            ..color = colour.withValues(alpha: 0.28)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      canvas.drawCircle(p, r, Paint()..color = colour);
    }
  }

  @override
  bool shouldRepaint(_OrbitPainter old) => old.c != c;
}
