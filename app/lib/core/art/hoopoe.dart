import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'mark.dart' show MarkPaths;
import 'svg_path.dart';

/// Hudhud, Realbrain's scout (docs/DESIGN_V5.md §2.2): a hoopoe drawn as a natural-history plate.
/// In the Qur'anic story of Solomon and in Attar's *Conference of the Birds* the hoopoe flies out
/// and comes back with knowledge, which is what Realbrain does with the things you find.
/// 120 × 100 grid, facing right (mirrored in RTL).
enum HudhudPose {
  /// Standing on the rule: default, onboarding.
  perched,

  /// Head up, crest raised: empty states ("nothing here yet").
  curious,

  /// The saffron piece in its beak: success, achievements.
  carrying,

  /// Head down over the line: loading ("reading the reel").
  reading,
}

abstract final class _Parts {
  static const tail =
      'M45 57.5C37 60.5 28 64.6 19.5 69.6C18.4 70.3 19 71.8 20.3 71.5C29 69.4 38 66.8 46.6 62.8Z';
  static const tailBand = 'M28.4 65C29.6 66.6 30.1 67.9 30 69.1';
  static const body =
      'M72.5 39.6C79.4 41.4 81.6 47.4 78.8 53.2C75.8 59.6 67.4 63.2 58.6 63.2C50.6 63.2 44.8 60.8 42 57.6C41 55.2 43.8 52.4 47.6 51C55.4 47.6 63 40.6 72.5 39.6Z';
  static const belly =
      'M78.2 50.6C75.6 57.4 67.8 61.6 59.4 62C66.2 59 71.8 55 74.2 49.4Z';
  static const wing =
      'M70 44.4C64.2 46.4 56.4 49.8 50.4 52.2C45.6 54.2 41.8 56.6 39.4 59C46.8 59.4 56.4 58.4 63.2 56C68.2 54 71 50.2 70 44.4Z';
  static const bands =
      'M66.8 45.8C67.7 48.6 66.8 51.9 64.2 54.4M61 48.1C61.8 50.6 61 53.5 58.5 56.2M55.2 50.4C55.9 52.7 55.1 55.2 52.9 57.4M49.4 52.8C49.9 54.5 49.2 56.4 47.3 58.2';
  static const head =
      'M71 34.6C71.4 29.6 75.3 26.8 79.7 27.4C84.4 28.1 86.9 32 85.8 36.1C84.9 39.6 81.4 41.4 77.5 41.1C73.8 40.8 70.8 38.3 71 34.6Z';
  static const beak =
      'M85.2 33.4C93.6 34 102 37.8 109.2 44.6C101.4 40.6 93.4 38.1 85.7 37.9Z';
  static const legs =
      'M60.4 62.8L59 70.8M66.2 61.8L65.8 70.8M56.2 71.2H62.4M62.8 71.2H69';
  static const perch = 'M26 71.4H98';

  /// Crest feathers: base x, base y, angle (degrees, 0 = right, -90 = up), length.
  static const crest = [
    (83.2, 29.4, -62.0, 15.0),
    (80.6, 28.3, -78.0, 16.5),
    (77.6, 28.1, -95.0, 16.5),
    (74.8, 28.9, -112.0, 15.5),
    (72.6, 30.6, -130.0, 14.0),
    (71.4, 33.0, -148.0, 11.5),
  ];
}

typedef _Feather = ({Path body, Path band, Path cap});

/// One spatulate crest feather: a narrow base, a wider tip with a white band and a black cap.
_Feather _feather(double x, double y, double angle, double len) {
  final r = deg(angle);
  final ux = math.cos(r), uy = math.sin(r), nx = -uy, ny = ux;
  Offset p(double t, double w) =>
      Offset(x + ux * len * t + nx * w, y + uy * len * t + ny * w);
  Path curve(List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i + 2 < pts.length; i += 3) {
      path.cubicTo(pts[i].dx, pts[i].dy, pts[i + 1].dx, pts[i + 1].dy,
          pts[i + 2].dx, pts[i + 2].dy);
    }
    return path..close();
  }

  final body = curve([
    p(0, -1.1),
    p(.3, -1.2), p(.45, -1.6), p(.55, -1.5), //
    p(.7, -1.6), p(.85, -1.9), p(.92, -1.8),
    p(1, -1.8), p(1.07, -.9), p(1.06, 0),
    p(1.07, .9), p(1, 1.8), p(.92, 1.8),
    p(.85, 1.9), p(.7, 1.6), p(.55, 1.5),
    p(.45, 1.6), p(.3, 1.2), p(0, 1.1),
  ]);
  final cap = curve([
    p(.84, -1.85),
    p(.92, -1.85), p(1, -1.8), p(1.03, -1.1), //
    p(1.07, -.6), p(1.07, .6), p(1.03, 1.1),
    p(1, 1.8), p(.92, 1.85), p(.84, 1.85),
  ]);
  final band = Path()
    ..moveTo(p(.72, -1.75).dx, p(.72, -1.75).dy)
    ..lineTo(p(.84, -1.85).dx, p(.84, -1.85).dy)
    ..lineTo(p(.84, 1.85).dx, p(.84, 1.85).dy)
    ..lineTo(p(.72, 1.75).dx, p(.72, 1.75).dy)
    ..close();
  return (body: body, band: band, cap: cap);
}

final _feathers = [
  for (final f in _Parts.crest) _feather(f.$1, f.$2, f.$3, f.$4)
];

/// Hudhud at [width] (height is 5/6 of it). [motion] animates gently: the crest breathes and,
/// while [working], the head bobs as if reading. Still under reduced motion.
class Hudhud extends StatefulWidget {
  const Hudhud({
    super.key,
    this.width = 160,
    this.pose = HudhudPose.perched,
    this.motion = false,
    this.working = false,
    this.perch = true,
    this.semanticLabel,
  });

  final double width;
  final HudhudPose pose;
  final bool motion, working, perch;
  final String? semanticLabel;

  @override
  State<Hudhud> createState() => _HudhudState();
}

class _HudhudState extends State<Hudhud> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(Hudhud old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final run = (widget.motion || widget.working) && !RbMotion.reduced(context);
    if (run && !_c.isAnimating) _c.repeat();
    if (!run && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    Widget art = CustomPaint(
      size: Size(widget.width, widget.width * 100 / 120),
      painter: _HudhudPainter(
        _c,
        pose: widget.pose,
        working: widget.working,
        animate: widget.motion || widget.working,
        perch: widget.perch,
        // Always ink on paper: Hudhud lives on a plate (see Plate), in both themes.
        ink: const Color(0xFF1A1714),
        plumage: RbColors.light.cinnamon,
        cream: const Color(0xFFF2CFA0),
        paper: const Color(0xFFF7F2E9),
        piece: c.brand,
      ),
    );
    if (rtl) {
      art = Transform.flip(flipX: true, child: art);
    }
    return Semantics(
      label: widget.semanticLabel ?? 'Hudhud the hoopoe',
      image: true,
      child: RepaintBoundary(child: art),
    );
  }
}

class _HudhudPainter extends CustomPainter {
  _HudhudPainter(
    this.t, {
    required this.pose,
    required this.working,
    required this.animate,
    required this.perch,
    required this.ink,
    required this.plumage,
    required this.cream,
    required this.paper,
    required this.piece,
  }) : super(repaint: t);

  final Animation<double> t;
  final HudhudPose pose;
  final bool working, animate, perch;
  final Color ink, plumage, cream, paper, piece;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 120;
    canvas.save();
    canvas.scale(s);
    final outline = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    Paint fill(Color c) => Paint()..color = c;

    final v = animate ? t.value : 0.0;
    final breathe = animate ? 0.5 - 0.5 * math.cos(v * 2 * math.pi) : 0.0;
    var headRot = switch (pose) {
      HudhudPose.curious => -14.0,
      HudhudPose.reading => 16.0,
      _ => 0.0,
    };
    var crestScale = switch (pose) {
      HudhudPose.curious => 1.08,
      HudhudPose.reading => 0.82,
      _ => 1.0,
    };
    if (animate) crestScale *= 0.94 + 0.08 * breathe;
    if (working) headRot += 8 * math.sin(v * 2 * math.pi * 2).abs();

    if (perch) {
      canvas.drawPath(
          svgPath(_Parts.perch),
          Paint()
            ..color = ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.1
            ..strokeCap = StrokeCap.round);
    }
    final tail = svgPath(_Parts.tail);
    canvas.drawPath(tail, fill(ink));
    canvas.drawPath(
        svgPath(_Parts.tailBand),
        Paint()
          ..color = paper
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round);
    final body = svgPath(_Parts.body);
    canvas.drawPath(body, fill(plumage));
    canvas.drawPath(svgPath(_Parts.belly), fill(cream));
    canvas.drawPath(body, outline);
    final wing = svgPath(_Parts.wing);
    canvas.drawPath(wing, fill(paper));
    canvas.drawPath(
        svgPath(_Parts.bands),
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round);
    canvas.drawPath(wing, outline);

    // Head group: crest, head, beak, piece, eye; rotates about the neck.
    canvas.save();
    canvas.translate(74, 40);
    canvas.rotate(deg(headRot));
    canvas.translate(-74, -40);
    canvas.save();
    canvas.translate(77, 30);
    canvas.scale(1, crestScale);
    canvas.translate(-77, -30);
    for (final f in _feathers) {
      canvas.drawPath(f.body, fill(plumage));
      canvas.drawPath(f.band, fill(paper));
      canvas.drawPath(f.cap, fill(ink));
      canvas.drawPath(f.body, outline);
    }
    canvas.restore();
    final head = svgPath(_Parts.head);
    canvas.drawPath(head, fill(plumage));
    canvas.drawPath(head, outline);
    canvas.drawPath(svgPath(_Parts.beak), fill(ink));
    if (pose == HudhudPose.carrying) {
      canvas.save();
      canvas.translate(104, 39.5);
      canvas.rotate(deg(18));
      canvas.scale(0.24);
      canvas.translate(-66, -32);
      final p = svgPath(MarkPaths.piece);
      canvas.drawPath(p, fill(piece));
      canvas.drawPath(
          p,
          Paint()
            ..color = ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.6
            ..strokeJoin = StrokeJoin.round);
      canvas.restore();
    }
    canvas.drawCircle(const Offset(80.6, 33.2), 1.15, fill(ink));
    canvas.drawCircle(const Offset(80.95, 32.85), 0.35, fill(paper));
    canvas.restore();

    canvas.drawPath(
        svgPath(_Parts.legs),
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..strokeCap = StrokeCap.round);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HudhudPainter old) =>
      old.pose != pose ||
      old.ink != ink ||
      old.plumage != plumage ||
      old.working != working ||
      old.perch != perch;
}
