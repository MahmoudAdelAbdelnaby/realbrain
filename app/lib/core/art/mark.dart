import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'svg_path.dart';

/// The Realbrain mark (docs/DESIGN_V5.md §2.3): a line-drawn brain whose parietal lobe is a jigsaw
/// piece in saffron. Every discovery you use is a piece; the brain is the bigger picture.
/// Drawn on a 100-unit grid. The launcher icon and web icons are rendered from these same paths.
abstract final class MarkPaths {
  static const outline =
      'M23 66C13 64 8 54 11 44C13 31 24 20 38 17C42 13.89 47.38 11.96 53 11.22C60.03 10.3 67.44 11.22 73 14C85 18 93 30 91 43C90 52 86 58 79 60C79 67 73 73 65 71C60 75 55 76 50 73C40 74 30 71 23 66Z';
  static const stem = 'M59 73.5C59.5 78 58.5 82 56 86';
  static const sulci =
      'M21 56.5C31 55 40 51.5 49.5 46.5M33 21.5C25 26.5 21.5 34 24 42.5M29 64.5C37 62.5 45 62.5 52 60.5M66 61C71 63.5 75.5 63 79 60M36 38C33 41 32.5 45 34.5 49';
  static const sulciSimple =
      'M21 56.5C31 55 40 51.5 49.5 46.5M33 21.5C25 26.5 21.5 34 24 42.5';
  static const piece =
      'M53 11.22C60.03 10.3 67.44 11.22 73 14C85 18 93 30 91 43L76 43.4C76.8 45.6 75.2 46.6 74.6 47.2C77.6 50.4 74.6 54 71 54C67.4 54 64.4 50.4 67.4 47.2C66.8 46.6 65.2 45.6 66 43.4L53.4 43L53.2 34C51 35 49.6 33 48.9 32.4C45.6 35.4 41.8 32.2 41.8 28.4C41.8 24.6 45.6 21.4 48.9 24.4C49.6 23.8 51 21.8 53.2 22.8Z';

  /// The brain's visual centre on the grid (it spans y 10..86).
  static const centreShift = Offset(0, 2);
}

enum MarkMotion {
  /// Drawn once, no movement.
  still,

  /// The piece lifts and settles in a loop: something is being understood.
  thinking,

  /// One shot: the outline draws itself, then the piece drops into place (splash, success).
  arriving,
}

/// The mark at [size]. Detail follows size: full (≥ 56), simple (≥ 30), tiny. [color] is the line
/// colour (text by default); [piece] the piece fill (saffron by default); [lifted] shows the piece
/// hovering above its dashed socket (onboarding, the empty puzzle).
class BrainMark extends StatefulWidget {
  const BrainMark({
    super.key,
    this.size = 32,
    this.color,
    this.piece,
    this.motion = MarkMotion.still,
    this.lifted = false,
    this.showPiece = true,
    this.onDone,
  });

  final double size;
  final Color? color, piece;
  final MarkMotion motion;
  final bool lifted, showPiece;

  /// Called when an [MarkMotion.arriving] animation finishes.
  final VoidCallback? onDone;

  @override
  State<BrainMark> createState() => _BrainMarkState();
}

class _BrainMarkState extends State<BrainMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(BrainMark old) {
    super.didUpdateWidget(old);
    if (old.motion != widget.motion) _sync();
  }

  void _sync() {
    if (RbMotion.reduced(context) || widget.motion == MarkMotion.still) {
      _c.stop();
      _c.value = 1;
      return;
    }
    if (widget.motion == MarkMotion.thinking) {
      _c.duration = const Duration(milliseconds: 1400);
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.duration = const Duration(milliseconds: 1100);
      _c.forward(from: 0).whenComplete(() {
        if (mounted) widget.onDone?.call();
      });
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
    return Semantics(
      label: widget.motion == MarkMotion.thinking ? 'Working' : 'Realbrain',
      image: true,
      child: SizedBox.square(
        dimension: widget.size,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: MarkPainter(
              _c,
              line: widget.color ?? c.text,
              piece: widget.piece ?? c.brand,
              seam: c.ground,
              motion: widget.motion,
              lifted: widget.lifted,
              showPiece: widget.showPiece,
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the mark; public so the share cards and icon renderer can draw it onto any canvas.
class MarkPainter extends CustomPainter {
  MarkPainter(this.t,
      {required this.line,
      required this.piece,
      required this.seam,
      this.motion = MarkMotion.still,
      this.lifted = false,
      this.showPiece = true})
      : super(repaint: t);

  final Animation<double> t;
  final Color line, piece, seam;
  final MarkMotion motion;
  final bool lifted, showPiece;

  @override
  void paint(Canvas canvas, Size size) {
    final px = size.width / 100;
    canvas.save();
    canvas.scale(px);
    canvas.translate(MarkPaths.centreShift.dx, MarkPaths.centreShift.dy);
    final full = size.width >= 56, simple = size.width >= 30;
    // Thicker lines as the mark gets smaller, so it never goes hairline.
    final w = full
        ? math.max(1.9, 2.6 * 64 / size.width.clamp(64, 400))
        : simple
            ? 5.0
            : 7.5;
    final stroke = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final v = t.value;
    // Outline progress (arriving draws it in the first 60%), piece offset.
    var draw = 1.0;
    var lift = lifted ? 1.0 : 0.0;
    if (motion == MarkMotion.arriving) {
      draw = (v / 0.6).clamp(0.0, 1.0);
      final drop = ((v - 0.55) / 0.45).clamp(0.0, 1.0);
      lift = 1 - RbMotion.bouncy.transform(drop);
      if (v < 0.55) lift = 1.0;
    } else if (motion == MarkMotion.thinking) {
      lift = 0.5 - 0.5 * math.cos(v * 2 * math.pi);
    }

    final outline = svgPath(MarkPaths.outline);
    final details = Path()
      ..addPath(svgPath(MarkPaths.stem), Offset.zero)
      ..addPath(
          svgPath(full ? MarkPaths.sulci : MarkPaths.sulciSimple), Offset.zero);
    final piecePath = svgPath(MarkPaths.piece);

    // The socket shows while the piece is away from it.
    if (showPiece && lift > 0.02) {
      canvas.drawPath(
          _dashed(piecePath, 1.6, 2.2),
          Paint()
            ..color = line.withValues(alpha: 0.55 * lift.clamp(0, 1))
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.0, w * 0.55)
            ..strokeCap = StrokeCap.round);
    }

    if (draw >= 1) {
      canvas.drawPath(outline, stroke);
      if (simple) canvas.drawPath(details, stroke);
    } else {
      canvas.drawPath(_partial(outline, draw), stroke);
      if (simple && draw > 0.5) {
        canvas.drawPath(_partial(details, (draw - 0.5) * 2), stroke);
      }
    }

    if (showPiece && (motion != MarkMotion.arriving || v > 0.45)) {
      canvas.save();
      if (lift > 0) {
        canvas.translate(3.2 * lift, -3.8 * lift);
        canvas.translate(72, 30);
        canvas.rotate(deg(5) * lift);
        canvas.translate(-72, -30);
      }
      final fade = motion == MarkMotion.arriving
          ? ((v - 0.45) / 0.15).clamp(0.0, 1.0)
          : 1.0;
      canvas.drawPath(
          piecePath, Paint()..color = piece.withValues(alpha: fade));
      // The seam: the piece's jigsaw edge, in the ground colour, so the cut reads at every size.
      if (simple) {
        canvas.drawPath(
            piecePath,
            Paint()
              ..color = (lift > 0.02 ? seam : seam).withValues(alpha: fade)
              ..style = PaintingStyle.stroke
              ..strokeWidth = full ? w * 0.75 : 2.6
              ..strokeJoin = StrokeJoin.round);
      }
      canvas.restore();
      // Lines on top of a placed piece keep the outline crisp.
      if (lift <= 0.02) canvas.drawPath(outline, stroke);
    }
    canvas.restore();
  }

  static Path _partial(Path p, double f) {
    final out = Path();
    for (final m in p.computeMetrics()) {
      out.addPath(m.extractPath(0, m.length * f), Offset.zero);
    }
    return out;
  }

  static Path _dashed(Path p, double on, double off) {
    final out = Path();
    for (final m in p.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        out.addPath(m.extractPath(d, math.min(d + on, m.length)), Offset.zero);
        d += on + off;
      }
    }
    return out;
  }

  @override
  bool shouldRepaint(MarkPainter old) =>
      old.line != line ||
      old.piece != piece ||
      old.lifted != lifted ||
      old.motion != motion ||
      old.showPiece != showPiece;
}

/// The wordmark: the mark and *Realbrain* in Fraunces SemiBold.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 24, this.color});
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? RbColors.of(context).text;
    return Semantics(
      label: 'Realbrain',
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        BrainMark(size: size * 1.5, color: c),
        SizedBox(width: size * 0.3),
        ExcludeSemantics(
          child:
              Text('Realbrain', style: RbType.serif(size, color: c, height: 1)),
        ),
      ]),
    );
  }
}
