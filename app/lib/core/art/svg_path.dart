import 'dart:math' as math;
import 'dart:ui';

/// Parses SVG path data (M L H V C S Q T A Z, absolute and relative) into a [Path].
///
/// Realbrain's artwork (the mark, the category glyphs, Hudhud the hoopoe) is authored as SVG path
/// strings, previewed in a browser, and painted here at any size: one source, no image assets.
/// Results are cached by string.
Path svgPath(String d) => _cache.putIfAbsent(d, () => _parse(d));

final _cache = <String, Path>{};

Path _parse(String d) {
  final path = Path();
  final t = _Tokens(d);
  var cmd = '';
  var cx = 0.0, cy = 0.0; // current point
  var sx = 0.0, sy = 0.0; // subpath start
  var lcx = 0.0, lcy = 0.0; // last control point (for S/T)
  var lastCmd = '';
  while (t.more) {
    if (t.isCommand) cmd = t.command();
    if (cmd.isEmpty || (lastCmd.isEmpty && cmd != 'M' && cmd != 'm')) {
      throw FormatException('path must start with a move (M) command', d);
    }
    final rel = cmd == cmd.toLowerCase();
    final c = cmd.toUpperCase();
    double x(double v) => rel ? cx + v : v;
    double y(double v) => rel ? cy + v : v;
    switch (c) {
      case 'M':
        cx = x(t.number());
        cy = y(t.number());
        sx = cx;
        sy = cy;
        path.moveTo(cx, cy);
        // Extra pairs after M are implicit L (l after m).
        cmd = rel ? 'l' : 'L';
      case 'L':
        cx = x(t.number());
        cy = y(t.number());
        path.lineTo(cx, cy);
      case 'H':
        cx = rel ? cx + t.number() : t.number();
        path.lineTo(cx, cy);
      case 'V':
        cy = rel ? cy + t.number() : t.number();
        path.lineTo(cx, cy);
      case 'C':
        final x1 = x(t.number()), y1 = y(t.number());
        final x2 = x(t.number()), y2 = y(t.number());
        final ex = x(t.number()), ey = y(t.number());
        path.cubicTo(x1, y1, x2, y2, ex, ey);
        lcx = x2;
        lcy = y2;
        cx = ex;
        cy = ey;
      case 'S':
        final reflect = 'CS'.contains(lastCmd);
        final x1 = reflect ? 2 * cx - lcx : cx;
        final y1 = reflect ? 2 * cy - lcy : cy;
        final x2 = x(t.number()), y2 = y(t.number());
        final ex = x(t.number()), ey = y(t.number());
        path.cubicTo(x1, y1, x2, y2, ex, ey);
        lcx = x2;
        lcy = y2;
        cx = ex;
        cy = ey;
      case 'Q':
        final x1 = x(t.number()), y1 = y(t.number());
        final ex = x(t.number()), ey = y(t.number());
        path.quadraticBezierTo(x1, y1, ex, ey);
        lcx = x1;
        lcy = y1;
        cx = ex;
        cy = ey;
      case 'T':
        final reflect = 'QT'.contains(lastCmd);
        final x1 = reflect ? 2 * cx - lcx : cx;
        final y1 = reflect ? 2 * cy - lcy : cy;
        final ex = x(t.number()), ey = y(t.number());
        path.quadraticBezierTo(x1, y1, ex, ey);
        lcx = x1;
        lcy = y1;
        cx = ex;
        cy = ey;
      case 'A':
        final rx = t.number(), ry = t.number(), rot = t.number();
        final large = t.flag(), sweep = t.flag();
        final ex = x(t.number()), ey = y(t.number());
        if (rx == 0 || ry == 0) {
          path.lineTo(ex, ey);
        } else {
          path.arcToPoint(Offset(ex, ey),
              radius: Radius.elliptical(rx.abs(), ry.abs()),
              rotation: rot,
              largeArc: large,
              clockwise: sweep);
        }
        cx = ex;
        cy = ey;
      case 'Z':
        path.close();
        cx = sx;
        cy = sy;
      default:
        throw FormatException('unsupported path command $cmd', d);
    }
    lastCmd = c;
    // Z takes no numbers: a following number means a new implicit command is invalid, so stop
    // the loop from spinning on it.
    if (c == 'Z' && t.more && !t.isCommand) {
      throw FormatException('numbers after Z', d);
    }
  }
  return path;
}

class _Tokens {
  _Tokens(this.s);
  final String s;
  int i = 0;

  void _skip() {
    while (i < s.length) {
      final ch = s.codeUnitAt(i);
      if (ch == 0x20 || ch == 0x2C || ch == 0x0A || ch == 0x0D || ch == 0x09) {
        i++;
      } else {
        break;
      }
    }
  }

  bool get more {
    _skip();
    return i < s.length;
  }

  bool get isCommand {
    _skip();
    if (i >= s.length) return false;
    final ch = s[i];
    return 'MmLlHhVvCcSsQqTtAaZz'.contains(ch);
  }

  String command() {
    _skip();
    return s[i++];
  }

  /// Arc flags may be written without separators ("a1 1 0 104 0").
  bool flag() {
    _skip();
    final ch = s[i++];
    if (ch != '0' && ch != '1') throw FormatException('bad arc flag', s, i);
    return ch == '1';
  }

  double number() {
    _skip();
    final start = i;
    if (i < s.length && (s[i] == '-' || s[i] == '+')) i++;
    var dot = false, digits = false;
    while (i < s.length) {
      final ch = s[i];
      if (ch.codeUnitAt(0) >= 0x30 && ch.codeUnitAt(0) <= 0x39) {
        digits = true;
        i++;
      } else if (ch == '.' && !dot) {
        dot = true;
        i++;
      } else {
        break;
      }
    }
    if (i < s.length && (s[i] == 'e' || s[i] == 'E')) {
      i++;
      if (i < s.length && (s[i] == '-' || s[i] == '+')) i++;
      while (
          i < s.length && s.codeUnitAt(i) >= 0x30 && s.codeUnitAt(i) <= 0x39) {
        i++;
      }
    }
    if (!digits) throw FormatException('expected a number', s, start);
    return double.parse(s.substring(start, i));
  }
}

/// Bounds helper for tests and layout.
Rect svgBounds(String d) => svgPath(d).getBounds();

/// Degrees to radians, for artwork transforms.
double deg(double d) => d * math.pi / 180;
