import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'mark.dart' show MarkPaths;
import 'svg_path.dart';

/// The brain cut into jigsaw pieces (My Brain, docs/DESIGN_V5.md §2.5). A level's puzzle has
/// exactly [count] pieces: a grid laid over the brain outline, interlocking knobs on every inner
/// edge, clipped to the outline; slivers at the rim are merged into a neighbour so the count is
/// exact and the brain has no holes. Pieces are ordered from the core outward (fill order).
class PuzzleLayout {
  PuzzleLayout._(this.pieces, this.centres);

  /// Piece outlines on the mark's 100-unit grid, in fill order.
  final List<Path> pieces;
  final List<Offset> centres;

  int get count => pieces.length;

  static final _cache = <int, PuzzleLayout>{};

  static PuzzleLayout of(int count) =>
      _cache.putIfAbsent(count, () => _build(count.clamp(4, 120)));

  static PuzzleLayout _build(int target) {
    final outline = svgPath(MarkPaths.outline);
    final b = outline.getBounds();
    // Smallest grid (about 4:3 cells, like the brain) whose covered cells reach the target.
    for (var rows = 2; rows < 16; rows++) {
      final cols = (rows * b.width / b.height * 0.92).round().clamp(2, 20);
      final cells = _cells(outline, b, cols, rows);
      if (cells.length >= target) {
        return _merge(cells, target, b.center);
      }
    }
    return _merge(_cells(outline, b, 20, 16), target, b.center);
  }

  static List<_Cell> _cells(Path outline, Rect b, int cols, int rows) {
    final w = b.width / cols, h = b.height / rows;
    // Knob direction per inner edge, from a fixed hash so the puzzle never reshuffles.
    int sign(int a, int bb, int k) =>
        ((a * 73856093) ^ (bb * 19349663) ^ (k * 83492791)) & 1 == 0 ? 1 : -1;
    final out = <_Cell>[];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final x0 = b.left + c * w, y0 = b.top + r * h;
        // Coverage: how much of the cell lies inside the brain (5 × 5 samples).
        var inside = 0;
        for (var i = 0; i < 5; i++) {
          for (var j = 0; j < 5; j++) {
            if (outline.contains(
                Offset(x0 + (i + 0.5) * w / 5, y0 + (j + 0.5) * h / 5))) {
              inside++;
            }
          }
        }
        if (inside == 0) continue;
        final p = Path()..moveTo(x0, y0);
        // Top edge (left to right): knob shared with the cell above.
        _edge(
            p, Offset(x0, y0), Offset(x0 + w, y0), r == 0 ? 0 : sign(c, r, 1));
        // Right edge (top to bottom).
        _edge(p, Offset(x0 + w, y0), Offset(x0 + w, y0 + h),
            c == cols - 1 ? 0 : sign(c + 1, r, 2));
        // Bottom edge (right to left): the cell below's top edge, reversed.
        _edge(p, Offset(x0 + w, y0 + h), Offset(x0, y0 + h),
            r == rows - 1 ? 0 : -sign(c, r + 1, 1));
        // Left edge (bottom to top): the left cell's right edge, reversed.
        _edge(
            p, Offset(x0, y0 + h), Offset(x0, y0), c == 0 ? 0 : -sign(c, r, 2));
        p.close();
        final clipped = Path.combine(PathOperation.intersect, p, outline);
        out.add(
            _Cell(c, r, clipped, inside / 25, Offset(x0 + w / 2, y0 + h / 2)));
      }
    }
    return out;
  }

  /// A jigsaw edge from a to b with a knob bulging to the left of the direction of travel
  /// (sign 1), right (-1), or a straight edge (0).
  static void _edge(Path p, Offset a, Offset b, int sign) {
    if (sign == 0) {
      p.lineTo(b.dx, b.dy);
      return;
    }
    final d = b - a;
    final n = Offset(d.dy, -d.dx) *
        sign.toDouble(); // normal, same length as the edge
    Offset at(double u, double v) => a + d * u + n * v;
    void line(double u, double v) => p.lineTo(at(u, v).dx, at(u, v).dy);
    void cubic(double u1, double v1, double u2, double v2, double u, double v) {
      final p1 = at(u1, v1), p2 = at(u2, v2), e = at(u, v);
      p.cubicTo(p1.dx, p1.dy, p2.dx, p2.dy, e.dx, e.dy);
    }

    line(0.37, 0);
    cubic(0.43, 0, 0.40, 0.10, 0.38, 0.14);
    cubic(0.34, 0.22, 0.42, 0.30, 0.50, 0.30);
    cubic(0.58, 0.30, 0.66, 0.22, 0.62, 0.14);
    cubic(0.60, 0.10, 0.57, 0, 0.63, 0);
    line(1, 0);
  }

  /// Merges the smallest rim slivers into their best-covered neighbour until [target] remain,
  /// then orders pieces from the brain's core outward.
  static PuzzleLayout _merge(List<_Cell> cells, int target, Offset core) {
    final live = [...cells];
    while (live.length > target) {
      live.sort((a, b) => a.cover.compareTo(b.cover));
      final small = live.first;
      _Cell? best;
      for (final o in live) {
        if (identical(o, small)) continue;
        final adj = (o.c - small.c).abs() + (o.r - small.r).abs() == 1;
        if (adj && (best == null || o.cover > best.cover)) best = o;
      }
      // An isolated sliver (no live neighbour) joins the nearest piece.
      best ??= (live.skip(1).toList()
            ..sort((a, b) => (a.centre - small.centre)
                .distance
                .compareTo((b.centre - small.centre).distance)))
          .first;
      best.path = Path.combine(PathOperation.union, best.path, small.path);
      best.cover += small.cover;
      live.remove(small);
    }
    live.sort((a, b) =>
        (a.centre - core).distance.compareTo((b.centre - core).distance));
    return PuzzleLayout._(
        [for (final c in live) c.path], [for (final c in live) c.centre]);
  }
}

class _Cell {
  _Cell(this.c, this.r, this.path, this.cover, this.centre);
  final int c, r;
  Path path;
  double cover;
  final Offset centre;
}

/// The puzzle brain: [placed] colours fill the first pieces (a placed discovery takes its
/// category's pigment), the next [found] pieces show as explored (tinted, not filled), the rest
/// wait as outlines. [fresh] marks the newest placed piece, which settles in with a spring.
class PuzzleBrain extends StatelessWidget {
  const PuzzleBrain({
    super.key,
    required this.count,
    this.placed = const [],
    this.found = 0,
    this.size = 240,
    this.fresh,
  });

  final int count;
  final List<Color> placed;
  final int found;
  final double size;
  final int? fresh;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final layout = PuzzleLayout.of(count);
    final painter = _PuzzlePainter(layout,
        placed: placed,
        found: found,
        line: c.text,
        rule: c.faint,
        ground: c.ground,
        foundTint: c.brand);
    final label =
        '${math.min(placed.length, layout.count)} of ${layout.count} pieces placed';
    final art = CustomPaint(size: Size.square(size), painter: painter);
    if (fresh == null || RbMotion.reduced(context)) {
      return Semantics(label: label, image: true, child: art);
    }
    return Semantics(
      label: label,
      image: true,
      child: TweenAnimationBuilder<double>(
        key: ValueKey(fresh),
        tween: Tween(begin: 0, end: 1),
        duration: RbMotion.slow,
        curve: RbMotion.bouncy,
        builder: (context, v, _) => CustomPaint(
            size: Size.square(size), painter: painter.withFresh(fresh!, v)),
      ),
    );
  }
}

class _PuzzlePainter extends CustomPainter {
  _PuzzlePainter(this.layout,
      {required this.placed,
      required this.found,
      required this.line,
      required this.rule,
      required this.ground,
      required this.foundTint,
      this.fresh,
      this.freshT = 1});

  final PuzzleLayout layout;
  final List<Color> placed;
  final int found;
  final Color line, rule, ground, foundTint;
  final int? fresh;
  final double freshT;

  _PuzzlePainter withFresh(int index, double t) => _PuzzlePainter(layout,
      placed: placed,
      found: found,
      line: line,
      rule: rule,
      ground: ground,
      foundTint: foundTint,
      fresh: index,
      freshT: t);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    canvas.save();
    canvas.scale(s);
    canvas.translate(MarkPaths.centreShift.dx, MarkPaths.centreShift.dy);
    final seam = Paint()
      ..color = rule.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.55
      ..strokeJoin = StrokeJoin.round;
    for (var i = 0; i < layout.count; i++) {
      final p = layout.pieces[i];
      if (i < placed.length) {
        if (i == fresh && freshT < 1) {
          // The newest piece drops in: scaled up from its centre, then settles.
          final k = 1.25 - 0.25 * freshT;
          final ctr = layout.centres[i];
          canvas.save();
          canvas.translate(ctr.dx, ctr.dy);
          canvas.scale(k);
          canvas.translate(-ctr.dx, -ctr.dy);
          canvas.drawPath(p, Paint()..color = placed[i]);
          canvas.drawPath(
              p,
              Paint()
                ..color = ground
                ..style = PaintingStyle.stroke
                ..strokeWidth = 0.9);
          canvas.restore();
          continue;
        }
        canvas.drawPath(p, Paint()..color = placed[i]);
        canvas.drawPath(
            p,
            Paint()
              ..color = ground
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.9
              ..strokeJoin = StrokeJoin.round);
      } else if (i < placed.length + found) {
        // Opened, not finished: engraved hatching, like an unfinished plate.
        canvas.save();
        canvas.clipPath(p);
        final b = p.getBounds();
        final hatch = Paint()
          ..color = foundTint.withValues(alpha: 0.75)
          ..strokeWidth = 0.55;
        for (var x = b.left - b.height; x < b.right; x += 2.4) {
          canvas.drawLine(
              Offset(x, b.bottom), Offset(x + b.height, b.top), hatch);
        }
        canvas.restore();
        canvas.drawPath(p, seam);
      } else {
        canvas.drawPath(p, seam);
      }
    }
    canvas.drawPath(
        svgPath(MarkPaths.outline),
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeJoin = StrokeJoin.round);
    canvas.drawPath(
        svgPath(MarkPaths.stem),
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PuzzlePainter old) =>
      old.layout != layout ||
      old.placed.length != placed.length ||
      old.found != found ||
      old.line != line ||
      old.freshT != freshT ||
      !_sameColors(old.placed, placed);

  static bool _sameColors(List<Color> a, List<Color> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
