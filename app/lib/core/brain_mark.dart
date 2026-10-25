import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme/tokens.dart';

/// The polygonal brain (docs/DESIGN_V4_PROPOSAL.md §3): a side-view brain drawn as a low-poly
/// mesh, on a 100 × 100 grid. The launcher icon and splash (android res/drawable) are drawn from
/// the same points by tool/brain_mesh.py; change both together.
abstract final class BrainMesh {
  /// The outline, clockwise from the front of the brain.
  static const outline = [
    Offset(14, 52), Offset(12, 40), Offset(18, 29), Offset(28, 21), //
    Offset(41, 16), Offset(55, 15), Offset(68, 18), Offset(79, 25),
    Offset(87, 35), Offset(89, 47), Offset(85, 58), Offset(76, 64),
    Offset(68, 72), Offset(60, 80), Offset(54, 70), Offset(44, 66),
    Offset(32, 64), Offset(22, 60),
  ];

  static const inner = [
    Offset(25, 42), Offset(36, 32), Offset(50, 27), Offset(63, 28), //
    Offset(75, 36), Offset(40, 47), Offset(55, 41), Offset(68, 48),
    Offset(80, 47), Offset(30, 54), Offset(47, 57), Offset(62, 58),
    Offset(74, 56),
  ];

  /// Outline point to inner point.
  static const spokes = [
    (1, 0), (0, 0), (2, 0), (2, 1), (3, 1), (4, 1), (4, 2), (5, 2), //
    (5, 3), (6, 3), (7, 3), (7, 4), (8, 4), (9, 8), (8, 8), (10, 8),
    (10, 12), (11, 12), (12, 11), (12, 12), (13, 11), (14, 11), (14, 10),
    (15, 10), (16, 9), (16, 10), (17, 9), (0, 9),
  ];

  /// Inner point to inner point.
  static const mesh = [
    (0, 1), (1, 2), (2, 3), (3, 4), (4, 8), (0, 5), (1, 5), (2, 5), //
    (2, 6), (3, 6), (3, 7), (4, 7), (6, 5), (6, 7), (7, 8), (7, 12),
    (8, 12), (0, 9), (5, 9), (5, 10), (9, 10), (6, 10), (6, 11),
    (10, 11), (7, 11), (11, 12),
  ];

  /// The larger nodes of the full mesh (inner indexes).
  static const big = [2, 5, 7, 11, 9];

  /// Small sizes: the outline, these inner nodes and the lines between them.
  static const simpleNodes = [1, 3, 5, 7, 9, 11];
  static const simple = [
    (1, 3), (1, 5), (3, 7), (5, 7), (5, 9), (5, 11), (7, 11), (9, 11), //
  ];
}

/// The mark. Below 80 px it draws the simplified mesh so it stays sharp (§3). With [animate] a
/// light runs through the nodes: used wherever something is processing.
class BrainMark extends StatefulWidget {
  const BrainMark(
      {super.key, this.size = 32, this.animate = false, this.color});
  final double size;
  final bool animate;

  /// Defaults to the text colour.
  final Color? color;

  @override
  State<BrainMark> createState() => _BrainMarkState();
}

class _BrainMarkState extends State<BrainMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(BrainMark old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final run = widget.animate && !RbMotion.reduced(context);
    if (run && !_c.isAnimating) _c.repeat();
    if (!run) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        label: widget.animate ? 'Working' : 'Realbrain',
        child: SizedBox.square(
          dimension: widget.size,
          child: CustomPaint(
              painter: _MeshPainter(
                  _c, widget.color ?? RbColors.of(context).text, widget.animate,
                  full: widget.size >= 80)),
        ),
      );
}

class _MeshPainter extends CustomPainter {
  _MeshPainter(this.t, this.color, this.animate, {required this.full})
      : super(repaint: t);
  final Animation<double> t;
  final Color color;
  final bool animate, full;

  @override
  void paint(Canvas canvas, Size size) {
    final px = size.width / 100; // one grid unit in pixels
    canvas.scale(px);
    canvas.translate(0, 2.5); // the brain spans y 15..80: centre it
    const o = BrainMesh.outline, i = BrainMesh.inner;
    final lineW = (full
            ? math.max(0.8, size.width / 110)
            : math.max(1.5, size.width * 0.045)) /
        px;
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineW
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final edges = Path()..addPolygon(o, true);
    if (full) {
      for (final (a, b) in BrainMesh.spokes) {
        edges
          ..moveTo(o[a].dx, o[a].dy)
          ..lineTo(i[b].dx, i[b].dy);
      }
    }
    for (final (a, b) in full ? BrainMesh.mesh : BrainMesh.simple) {
      edges
        ..moveTo(i[a].dx, i[a].dy)
        ..lineTo(i[b].dx, i[b].dy);
    }
    canvas.drawPath(
        edges, full ? (line..color = color.withValues(alpha: 0.85)) : line);
    // Nodes; while animating a light travels through them in turn.
    final nodes =
        full ? [...o, ...i] : [for (final k in BrainMesh.simpleNodes) i[k]];
    final bigs = full ? {for (final k in BrainMesh.big) i[k]} : nodes.toSet();
    final r = (full ? size.width * 0.012 : size.width * 0.05) / px;
    final rBig = (full ? size.width * 0.022 : size.width * 0.05) / px;
    final dot = Paint();
    for (final (n, p) in nodes.indexed) {
      var alpha = 1.0;
      if (animate) {
        final d = (t.value - n / nodes.length).abs();
        alpha = 0.35 + 0.65 * math.max(0, 1 - math.min(d, 1 - d) * 5);
      }
      canvas.drawCircle(p, bigs.contains(p) ? rBig : r,
          dot..color = color.withValues(alpha: alpha));
    }
  }

  @override
  bool shouldRepaint(_MeshPainter old) =>
      old.color != color || old.full != full || old.animate != animate;
}

/// The wordmark: the mark and "Realbrain" in Inter Bold, tight, in the text colour.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 22});
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Realbrain',
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          BrainMark(size: size * 1.4),
          SizedBox(width: size * 0.35),
          ExcludeSemantics(
            child: Text('Realbrain',
                style: TextStyle(
                    fontFamily: RbType.family,
                    fontSize: size,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.03 * size,
                    color: RbColors.of(context).text)),
          ),
        ]),
      );
}
