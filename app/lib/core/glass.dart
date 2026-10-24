import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'theme/tokens.dart';

/// Design v3 glass: a web-style approximation of Apple's Liquid Glass (Apple's own material only
/// exists in Apple's SDKs). Used on what floats: the pill, the scrolled top bar, sheets, menus,
/// map cards, timer controls. Never under text you read for long.
///
/// Blur 24 with saturation 1.6, a thin fill, a 1 px top highlight and a 1 px line, one shadow
/// tinted to the ground. High contrast or reduced motion turns it into a solid `raised` fill.
/// ponytail: each Glass is a BackdropFilter (a full re-blur per frame); keep 2 on screen at most.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.radius = RbSpace.pill,
    this.padding = EdgeInsets.zero,
    this.shadow = true,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final bool shadow;

  static bool solid(BuildContext context) =>
      MediaQuery.maybeHighContrastOf(context) == true ||
      RbMotion.reduced(context);

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final shape = BorderRadius.circular(radius);
    final opaque = solid(context);
    final box = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        color: opaque
            ? c.raised
            : (dark
                ? c.ground.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.14)),
        border: Border.all(
            color: dark
                ? Colors.white.withValues(alpha: 0.10)
                : c.line.withValues(alpha: 0.7)),
        gradient: opaque
            ? null
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, 0.04, 0.5, 1],
                colors: [
                  Colors.white.withValues(
                      alpha: dark ? 0.18 : 0.35), // top-edge highlight
                  Colors.white.withValues(alpha: dark ? 0.06 : 0.22),
                  Colors.white.withValues(alpha: dark ? 0.02 : 0.10),
                  Colors.white.withValues(alpha: dark ? 0.04 : 0.16),
                ],
              ),
      ),
      child: Padding(padding: padding, child: child),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: shadow
            ? [
                BoxShadow(
                    color: c.ground.withValues(alpha: dark ? 0.6 : 0.10),
                    blurRadius: 32,
                    offset: const Offset(0, 12))
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: opaque
            ? box
            : BackdropFilter(
                filter: ui.ImageFilter.compose(
                    outer: _saturate,
                    inner: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24)),
                child: box,
              ),
      ),
    );
  }

  // Saturation 1.6 (luma weights 0.2126 / 0.7152 / 0.0722): the colour behind reads through.
  static const _saturate = ColorFilter.matrix([
    1.4724, -0.4291, -0.0433, 0, 0, //
    -0.1276, 1.1709, -0.0433, 0, 0, //
    -0.1276, -0.4291, 1.5567, 0, 0, //
    0, 0, 0, 1, 0,
  ]);
}

/// Scales to 0.97 under the finger and springs back (design v3 press).
class Pressable extends StatefulWidget {
  const Pressable(
      {super.key, required this.child, this.onTap, this.onLongPress});
  final Widget child;
  final VoidCallback? onTap, onLongPress;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final (d, curve) = RbMotion.of(context, bounce: !_down);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down && !RbMotion.reduced(context) ? 0.97 : 1,
        duration: _down ? RbMotion.fast : d,
        curve: _down ? Curves.easeOut : curve,
        child: widget.child,
      ),
    );
  }
}
