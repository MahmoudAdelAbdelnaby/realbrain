import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'svg_path.dart';

/// Realbrain's line glyphs on a 24-unit grid, drawn with round caps (docs/DESIGN_V5.md §2.3).
/// Category symbols, sub-kinds, and the custom navigation icons. Generic controls (close, share,
/// more) stay Material so they read as system controls.
abstract final class Glyphs {
  static const recipe =
      'M4.5 10.5H19.5V12.5C19.5 16.4 16.3 19.5 12.5 19.5H11.5C7.7 19.5 4.5 16.4 4.5 12.5ZM2.5 11.5H4.5M19.5 11.5H21.5M7 8.5H17M10.5 8.5V7.6C10.5 6.7 11.2 6 12 6C12.8 6 13.5 6.7 13.5 7.6V8.5M9 4.8C8.4 4.1 8.4 3.4 9 2.7M15 4.8C14.4 4.1 14.4 3.4 15 2.7';
  static const workout =
      'M8.2 10C7 7.8 7.4 5 9.6 4.4C11 4.1 13 4.1 14.4 4.4C16.6 5 17 7.8 15.8 10M7.2 10.6C5.6 12 5 13.6 5 15.4C5 17.6 6.1 19.3 7.6 20.5H16.4C17.9 19.3 19 17.6 19 15.4C19 13.6 18.4 12 16.8 10.6C15.4 9.5 13.8 9 12 9C10.2 9 8.6 9.5 7.2 10.6ZM9.2 14.2C9.6 13 10.6 12.2 11.8 12';
  static const places =
      'M3.5 6.5L8.5 4.5L15.5 6.8L20.5 4.8V17.5L15.5 19.5L8.5 17.2L3.5 19.2ZM8.5 4.5V17.2M15.5 6.8V19.5M11.2 11.6C11.2 10.4 12.2 9.4 13.4 9.4';
  static const tools =
      'M3.5 6C3.5 5.2 4.2 4.5 5 4.5H19C19.8 4.5 20.5 5.2 20.5 6V18C20.5 18.8 19.8 19.5 19 19.5H5C4.2 19.5 3.5 18.8 3.5 18ZM3.5 8.5H20.5M7.5 12L10 14L7.5 16M12 16.2H16';
  static const factCheck =
      'M12 3.5V20M7 20.5H17M5 6.5H19M12 5.2V6.5M5 6.5L2.5 13C2.5 14.4 3.6 15.4 5 15.4C6.4 15.4 7.5 14.4 7.5 13ZM19 6.5L16.5 13C16.5 14.4 17.6 15.4 19 15.4C20.4 15.4 21.5 14.4 21.5 13ZM2.5 13H7.5M16.5 13H21.5';
  static const ideas =
      'M9 17.5H15M9.8 20.5H14.2M12 2.5C8.4 2.5 5.8 5.2 5.8 8.6C5.8 10.9 7 12.6 8.4 13.9C9 14.5 9.3 15.2 9.3 16V17.5M12 2.5C15.6 2.5 18.2 5.2 18.2 8.6C18.2 10.9 17 12.6 15.6 13.9C15 14.5 14.7 15.2 14.7 16V17.5M10.4 12.5L12 9.6L13.6 12.5';
  static const entertainment =
      'M3.5 8.2V6.5C3.5 5.4 4.4 4.5 5.5 4.5H18.5C19.6 4.5 20.5 5.4 20.5 6.5V8.2C19.3 8.2 18.3 9.2 18.3 10.4C18.3 11.6 19.3 12.6 20.5 12.6V17.5C20.5 18.6 19.6 19.5 18.5 19.5H5.5C4.4 19.5 3.5 18.6 3.5 17.5V12.6C4.7 12.6 5.7 11.6 5.7 10.4C5.7 9.2 4.7 8.2 3.5 8.2ZM14.5 4.5V6.4M14.5 8.6V10.4M14.5 12.6V14.4M14.5 16.6V19.5M7.5 10H11M7.5 13H10';
  static const products =
      'M11.8 3.5H19C19.8 3.5 20.5 4.2 20.5 5V12.2C20.5 12.6 20.3 13 20 13.3L12.6 20.7C12 21.3 11.1 21.3 10.5 20.7L3.3 13.5C2.7 12.9 2.7 12 3.3 11.4L10.7 4C11 3.7 11.4 3.5 11.8 3.5ZM16.3 6.4A1.3 1.3 0 1 0 16.3 9A1.3 1.3 0 1 0 16.3 6.4Z';
  static const movie =
      'M3.5 9.5H20.5V18.5C20.5 19.1 20.1 19.5 19.5 19.5H4.5C3.9 19.5 3.5 19.1 3.5 18.5ZM3.2 9.2L2.6 6.4C2.5 5.8 2.8 5.3 3.4 5.2L17.6 2.6C18.2 2.5 18.7 2.8 18.8 3.4L19.3 6.2ZM7.3 4.6L9.5 8.2M11.8 3.8L14 7.4M3.5 13H20.5';
  static const series =
      'M3.5 8.5C3.5 7.4 4.4 6.5 5.5 6.5H18.5C19.6 6.5 20.5 7.4 20.5 8.5V17.5C20.5 18.6 19.6 19.5 18.5 19.5H5.5C4.4 19.5 3.5 18.6 3.5 17.5ZM8.5 2.5L12 6.5L15.5 2.5M8 21.5H16M10.5 10.5V15.5L14.5 13Z';
  static const book =
      'M12 6.6C10.2 5.2 7.4 4.5 3.5 4.6V17.6C7.4 17.5 10.2 18.2 12 19.6C13.8 18.2 16.6 17.5 20.5 17.6V4.6C16.6 4.5 13.8 5.2 12 6.6ZM12 6.6V19.6M6 8.4C7.6 8.4 8.9 8.7 9.9 9.2M6 11.4C7.6 11.4 8.9 11.7 9.9 12.2';
  static const bookmark = 'M6.5 3.5H17.5V20.5L12 16.6L6.5 20.5Z';

  // Navigation.
  static const today =
      'M3 18H21M6.6 18C6.6 15 9 12.6 12 12.6C15 12.6 17.4 15 17.4 18M12 5.2V8.2M5.4 9.4L7.4 11.2M18.6 9.4L16.6 11.2M2.8 13.8H5.2M18.8 13.8H21.2M8 21H16';
  static const library =
      'M4.5 5.5H8V19.5H4.5ZM8 8H11.5V19.5H8ZM13 6.6L16.3 5.6L19.9 18.6L16.6 19.5ZM3 19.5H21M5.8 8.5V10M9.3 10.5V12';
  static const groups =
      'M9 11.4C10.8 11.4 12.2 10 12.2 8.2C12.2 6.4 10.8 5 9 5C7.2 5 5.8 6.4 5.8 8.2C5.8 10 7.2 11.4 9 11.4ZM3.5 19.5C3.5 16.4 6 14.2 9 14.2C12 14.2 14.5 16.4 14.5 19.5M15.4 5.3C16.9 5.6 18 6.9 18 8.4C18 9.9 16.9 11.2 15.4 11.5M16.6 14.4C18.9 14.9 20.5 16.9 20.5 19.4';
  static const search =
      'M10.8 17.6C14.6 17.6 17.6 14.6 17.6 10.8C17.6 7 14.6 4 10.8 4C7 4 4 7 4 10.8C4 14.6 7 17.6 10.8 17.6ZM15.6 15.6L20 20';
  static const piece =
      'M5 9H8.2C8 8.6 7.9 8.2 7.9 7.8C7.9 6.5 8.9 5.5 10.2 5.5C11.5 5.5 12.5 6.5 12.5 7.8C12.5 8.2 12.4 8.6 12.2 9H15.5V12.3C15.9 12.1 16.3 12 16.7 12C18 12 19 13 19 14.3C19 15.6 18 16.6 16.7 16.6C16.3 16.6 15.9 16.5 15.5 16.3V19.5H5Z';
  static const arriving =
      'M4 13.5L6.2 5.6C6.4 4.9 7 4.5 7.7 4.5H16.3C17 4.5 17.6 4.9 17.8 5.6L20 13.5V18C20 18.8 19.3 19.5 18.5 19.5H5.5C4.7 19.5 4 18.8 4 18ZM4 13.5H8.5C8.5 15.2 10 16.5 12 16.5C14 16.5 15.5 15.2 15.5 13.5H20';
  static const map =
      'M12 21C12 21 18.5 14.8 18.5 9.8C18.5 6.2 15.6 3.5 12 3.5C8.4 3.5 5.5 6.2 5.5 9.8C5.5 14.8 12 21 12 21ZM12 12.3C13.4 12.3 14.5 11.2 14.5 9.8C14.5 8.4 13.4 7.3 12 7.3C10.6 7.3 9.5 8.4 9.5 9.8C9.5 11.2 10.6 12.3 12 12.3Z';
  static const collection =
      'M5.5 7.5H18.5V19.5H5.5ZM7.5 5H16.5M9.5 2.8H14.5M9 11.5H15';
  static const browse =
      'M6.5 3.5H17.5C18.3 3.5 19 4.2 19 5V19C19 19.8 18.3 20.5 17.5 20.5H6.5C5.7 20.5 5 19.8 5 19V5C5 4.2 5.7 3.5 6.5 3.5ZM10.2 9L14.2 12L10.2 15Z';
  static const quote =
      'M5 17.5C5 13.2 6.6 9.6 10 7.5M14 17.5C14 13.2 15.6 9.6 19 7.5M5 17.5H9V13.5H5ZM14 17.5H18V13.5H14Z';

  /// Every glyph by name (gallery, tests).
  static const all = {
    'recipe': recipe,
    'workout': workout,
    'places': places,
    'tools': tools,
    'fact_check': factCheck,
    'ideas': ideas,
    'entertainment': entertainment,
    'products': products,
    'movie': movie,
    'series': series,
    'book': book,
    'bookmark': bookmark,
    'today': today,
    'library': library,
    'groups': groups,
    'search': search,
    'piece': piece,
    'arriving': arriving,
    'map': map,
    'collection': collection,
    'browse': browse,
    'quote': quote,
  };
}

/// A glyph drawn in [color] at [size] (the 24-unit grid scaled), stroke [weight] in grid units.
/// [fill] fills closed shapes too (the selected piece in the tab bar).
class Glyph extends StatelessWidget {
  const Glyph(this.data,
      {super.key,
      this.size = 24,
      this.color,
      this.weight = 1.6,
      this.fill,
      this.semanticLabel});

  /// Path data on the 24 grid, usually a [Glyphs] constant.
  final String data;
  final double size, weight;
  final Color? color, fill;
  final String? semanticLabel;

  /// The glyph for a category or sub-kind id (falls back to the bookmark).
  factory Glyph.of(String? id,
          {Key? key,
          double size = 24,
          Color? color,
          double weight = 1.6,
          String? semanticLabel}) =>
      Glyph(Glyphs.all[id] ?? Glyphs.bookmark,
          key: key,
          size: size,
          color: color,
          weight: weight,
          semanticLabel: semanticLabel);

  /// Path data for [data]: a glyph name ("recipe", "map") or raw path data; unknown names fall
  /// back to the bookmark so a new category never crashes the UI.
  static String resolve(String data) {
    final named = Glyphs.all[data];
    if (named != null) return named;
    final first = data.isEmpty ? '' : data[0];
    return first == 'M' || first == 'm' ? data : Glyphs.bookmark;
  }

  @override
  Widget build(BuildContext context) {
    final paint = CustomPaint(
      size: Size.square(size),
      painter: _GlyphPainter(
          resolve(data), color ?? RbColors.of(context).text, weight,
          fill: fill),
    );
    return semanticLabel == null
        ? ExcludeSemantics(child: paint)
        : Semantics(label: semanticLabel, image: true, child: paint);
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.data, this.color, this.weight, {this.fill});
  final String data;
  final Color color;
  final double weight;
  final Color? fill;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    canvas.scale(s);
    final path = svgPath(data);
    if (fill != null) {
      canvas.drawPath(path, Paint()..color = fill!);
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = weight
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.data != data ||
      old.color != color ||
      old.weight != weight ||
      old.fill != fill;
}
