import 'package:flutter/material.dart';

import 'theme/tokens.dart';

/// The Glow mark (docs/BRAND.md): a pale brain shining seven rays on a safelight glow. The same
/// drawing as the launcher icon (android res/drawable/ic_launcher_*). With [animate], the rays
/// breathe: used wherever something is processing.
class BrainMark extends StatefulWidget {
  const BrainMark(
      {super.key, this.size = 32, this.animate = false, this.glow = true});
  final double size;
  final bool animate;

  /// The red glow disc behind the brain; off for the bare mark on a coloured ground.
  final bool glow;

  @override
  State<BrainMark> createState() => _BrainMarkState();
}

class _BrainMarkState extends State<BrainMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400));

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
    if (run && !_c.isAnimating) _c.repeat(reverse: true);
    if (!run) _c.value = 1; // still: rays at full length
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        label: widget.animate ? 'Working' : 'Reelbrain',
        child: SizedBox.square(
          dimension: widget.size,
          child: CustomPaint(painter: _MarkPainter(_c, widget.glow)),
        ),
      );
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.t, this.glow) : super(repaint: t);
  final Animation<double> t;
  final bool glow;

  static const _paper = Color(0xFFFFF4EC);
  static const _red = Color(0xFFFF4F3A);
  static const _lobes = [
    (42.0, 44.0, 15.0),
    (57.0, 38.0, 16.0),
    (68.0, 51.0, 13.0),
    (55.0, 60.0, 15.0),
    (39.0, 59.0, 12.0),
    (64.0, 64.0, 10.0),
  ];
  static const _ends = [
    Offset(50, 6),
    Offset(88, 18),
    Offset(95, 52),
    Offset(86, 86),
    Offset(12, 86),
    Offset(6, 50),
    Offset(12, 16),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100);
    const centre = Offset(50, 50);
    if (glow) {
      canvas.drawCircle(
        centre,
        50,
        Paint()
          ..shader = const RadialGradient(
            colors: [Color(0xFFFFB547), _red, Color(0xFF3A0D0B)],
            stops: [0, 0.45, 1],
          ).createShader(Rect.fromCircle(center: centre, radius: 50)),
      );
    }
    // Rays: grow and fade with the breath.
    final v = Curves.easeInOut.transform(t.value);
    final ray = Paint()
      ..color = _paper.withValues(alpha: 0.55 + 0.4 * v)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final e in _ends) {
      final len = 0.7 + 0.3 * v;
      canvas.drawLine(centre, centre + (e - centre) * len, ray);
    }
    // Brain: the lobes swell a little on the in-breath.
    canvas.save();
    canvas.translate(53, 51);
    canvas.scale(0.96 + 0.04 * v);
    canvas.translate(-53, -51);
    final fill = Paint()..color = _paper;
    for (final (x, y, r) in _lobes) {
      canvas.drawCircle(Offset(x, y), r, fill);
    }
    final fold = Paint()
      ..color = _red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
        Path()
          ..moveTo(54, 25)
          ..cubicTo(49, 36, 58, 44, 52, 54)
          ..cubicTo(48, 62, 56, 68, 54, 74),
        fold);
    canvas.drawPath(
        Path()
          ..moveTo(38, 44)
          ..cubicTo(43, 42, 46, 47, 44, 51),
        fold);
    canvas.drawPath(
        Path()
          ..moveTo(63, 42)
          ..cubicTo(67, 44, 66, 49, 70, 50),
        fold);
    canvas.drawPath(
        Path()
          ..moveTo(60, 62)
          ..cubicTo(63, 58, 67, 60, 68, 57),
        fold);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.glow != glow;
}
