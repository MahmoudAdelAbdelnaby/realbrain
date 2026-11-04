import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:reelbrain/core/art/glyphs.dart';
import 'package:reelbrain/core/art/mark.dart';
import 'package:reelbrain/core/art/puzzle.dart';
import 'package:reelbrain/core/art/svg_path.dart';

void main() {
  test('every glyph parses and stays on its 24-unit grid', () {
    for (final e in Glyphs.all.entries) {
      final b = svgBounds(e.value);
      expect(b.isEmpty, isFalse, reason: e.key);
      expect(
          b.left >= 0 && b.top >= 0 && b.right <= 24 && b.bottom <= 24, isTrue,
          reason: '${e.key} $b');
    }
  });

  test('the mark parses, and the piece sits inside the brain', () {
    final outline = svgBounds(MarkPaths.outline);
    final piece = svgBounds(MarkPaths.piece);
    expect(outline.width, greaterThan(70));
    expect(outline.inflate(0.5).contains(piece.topLeft), isTrue);
    expect(outline.inflate(0.5).contains(piece.bottomRight), isTrue);
    for (final d in [MarkPaths.stem, MarkPaths.sulci, MarkPaths.sulciSimple]) {
      expect(svgBounds(d).isEmpty, isFalse);
    }
  });

  test(
      'the parser handles relative commands, arcs, smooth curves and tight numbers',
      () {
    expect(svgBounds('M0 0h10v10h-10z'), const Rect.fromLTRB(0, 0, 10, 10));
    expect(svgBounds('M2 2l3-1.5.5.5').right, closeTo(5.5, 0.001));
    final arc = svgBounds('M10 5A5 5 0 1 0 0 5A5 5 0 1 0 10 5Z');
    expect(arc.width, closeTo(10, 0.1));
    expect(svgBounds('M0 0C1 1 2 1 3 0S5-1 6 0Q7 1 8 0T10 0').right,
        closeTo(10, 0.01));
    expect(() => svgPath('L1 1'), throwsFormatException);
    expect(() => svgPath('M0 0 X5 5'), throwsFormatException);
  });

  test(
      'a glyph name resolves to its path; unknown names fall back to the bookmark',
      () {
    expect(Glyph.resolve('recipe'), Glyphs.recipe);
    expect(Glyph.resolve(Glyphs.map), Glyphs.map);
    expect(Glyph.resolve('horoscope'), Glyphs.bookmark);
  });

  test('a level puzzle has exactly the pieces asked for, all inside the brain',
      () {
    final outline = svgBounds(MarkPaths.outline).inflate(1);
    for (final n in [9, 12, 16, 25, 36, 56]) {
      final layout = PuzzleLayout.of(n);
      expect(layout.count, n, reason: 'level with $n pieces');
      for (final p in layout.pieces) {
        final b = p.getBounds();
        expect(b.isEmpty, isFalse);
        expect(outline.contains(b.center), isTrue);
      }
    }
    // Cached: the same layout object every time.
    expect(identical(PuzzleLayout.of(16), PuzzleLayout.of(16)), isTrue);
  });
}
