import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'theme/tokens.dart';

/// What drives the liquid: scroll deltas, a back wave, and heat while a save processes.
class LiquidController extends ChangeNotifier {
  double _scroll = 0, _impulse = 0;
  bool _wave = false;
  double heat = 0;

  void scrolled(double delta) {
    _scroll += delta;
    _impulse += delta;
    notifyListeners();
  }

  /// A wave rolls across (coming back to a screen, switching tabs).
  void wave() {
    _wave = true;
    notifyListeners();
  }

  void setHeat(bool processing) {
    final v = processing ? 1.0 : 0.0;
    if (v != heat) {
      heat = v;
      notifyListeners();
    }
  }
}

/// Darkroom liquid background (docs/BRAND.md): one fragment shader for the whole screen.
/// Lags behind the scroll and springs back, stretches with its speed, ripples on back, warms
/// while processing. Stops ticking 4 s after the last input; still under reduced motion; plain
/// ground if the shader can't load.
class LiquidBackground extends StatefulWidget {
  const LiquidBackground({super.key, required this.controller});
  final LiquidController controller;

  @override
  State<LiquidBackground> createState() => _LiquidBackgroundState();
}

class _LiquidBackgroundState extends State<LiquidBackground>
    with SingleTickerProviderStateMixin {
  static Future<ui.FragmentProgram?>? _program;
  ui.FragmentShader? _shader;
  late final Ticker _ticker = createTicker(_tick);
  final _frame = ValueNotifier(0);

  double _time = 0, _offset = 0, _vel = 0, _wave = -1, _heat = 0;
  Duration _last = Duration.zero, _idleSince = Duration.zero;
  double _seenScroll = 0;

  @override
  void initState() {
    super.initState();
    _program ??= ui.FragmentProgram.fromAsset('shaders/liquid.frag')
        .then<ui.FragmentProgram?>((p) => p)
        .catchError((Object _) => null);
    _program!.then((p) {
      if (mounted && p != null) setState(() => _shader = p.fragmentShader());
      _wake();
    });
    widget.controller.addListener(_wake);
  }

  void _wake() {
    if (!mounted || RbMotion.reduced(context)) {
      _frame.value++;
      return;
    }
    if (widget.controller._wave) {
      widget.controller._wave = false;
      _wave = 0;
    }
    _idleSince = _last;
    if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _tick(Duration now) {
    final dt = ((now - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = now;
    final c = widget.controller;
    _time += dt;
    // Speed (px per 16 ms frame), smoothed; offset lags the scroll and settles.
    final impulse = c._impulse;
    c._impulse = 0;
    _vel += (impulse / (dt == 0 ? 1 : dt / 0.016) - _vel) * 0.25;
    _seenScroll = c._scroll;
    _offset += (-_seenScroll * 0.35 - _offset) * 0.08;
    _heat += (c.heat - _heat) * 0.03;
    if (_wave >= 0) {
      _wave += dt / 0.9;
      if (_wave > 1) _wave = -1;
    }
    final busy = impulse != 0 || _wave >= 0 || _vel.abs() > 0.05;
    if (busy) _idleSince = now;
    _frame.value++;
    if (now - _idleSince > const Duration(seconds: 4)) _ticker.stop();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_wake);
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final shader = _shader;
    if (shader == null) return ColoredBox(color: c.ground);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return RepaintBoundary(
      child: CustomPaint(
        painter: _LiquidPainter(
          shader: shader,
          repaint: _frame,
          values: () => [
            _time,
            _offset,
            1 + (_vel.abs() / 18).clamp(0.0, 0.9),
            _wave < 0 ? 0 : _wave,
            _heat,
            dark ? 1 : 0,
          ],
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _LiquidPainter extends CustomPainter {
  _LiquidPainter(
      {required this.shader, required this.values, required Listenable repaint})
      : super(repaint: repaint);
  final ui.FragmentShader shader;
  final List<double> Function() values;

  @override
  void paint(Canvas canvas, Size size) {
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height);
    for (final (i, v) in values().indexed) {
      shader.setFloat(2 + i, v);
    }
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_LiquidPainter old) => old.shader != shader;
}
