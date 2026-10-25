import 'package:flutter/material.dart';

import 'theme/tokens.dart';

/// A solid floating panel (design v4: no frosted glass): surface fill, a 1 px line and one soft
/// shadow. Used on what floats: the tab bar's status row, sheets, map cards, timer controls.
class Panel extends StatelessWidget {
  const Panel({
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

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: c.line),
        boxShadow: shadow
            ? [
                BoxShadow(
                    color: Colors.black.withValues(alpha: dark ? 0.45 : 0.08),
                    blurRadius: 28,
                    offset: const Offset(0, 10))
              ]
            : null,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// The haze: the ground with two soft glows, top right and bottom left. Only on the expressive
/// screens (sign-in, onboarding, Threads, Year in Brain); everyday screens stay plain.
class Haze extends StatelessWidget {
  const Haze({super.key, this.child});
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(color: c.ground),
      child: DecoratedBox(
        decoration: BoxDecoration(
            gradient: RadialGradient(
                center: const Alignment(0.8, -1.1),
                radius: 1.2,
                colors: [c.haze.$1, c.haze.$1.withValues(alpha: 0)])),
        child: DecoratedBox(
          decoration: BoxDecoration(
              gradient: RadialGradient(
                  center: const Alignment(-1, 1.1),
                  radius: 1.0,
                  colors: [c.haze.$2, c.haze.$2.withValues(alpha: 0)])),
          child: child ?? const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// The action pill (revision 2): soft white on charcoal, ink on light. [action] makes it the
/// screen's main action: taller, full width, with an optional [icon].
class PillButton extends StatelessWidget {
  const PillButton(
      {super.key,
      required this.label,
      required this.onPressed,
      this.icon,
      this.action = false,
      this.small = false});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool action, small;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final height = small ? 34.0 : (action ? 52.0 : RbSpace.touch);
    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: Pressable(
        onTap: onPressed,
        child: Opacity(
          opacity: onPressed == null ? 0.5 : 1,
          child: Container(
            height: height,
            // Small pills keep a 48 dp touch target through the card around them.
            padding: EdgeInsets.symmetric(horizontal: small ? 16 : 22),
            decoration: BoxDecoration(
              color: c.primaryFill,
              borderRadius: BorderRadius.circular(RbSpace.pill),
            ),
            child: Row(
                mainAxisSize: action ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: small ? 16 : 20, color: c.primaryLabel),
                    const SizedBox(width: 8),
                  ],
                  Text(label,
                      maxLines: 1,
                      style: TextStyle(
                          fontFamily: RbType.family,
                          fontFamilyFallback: RbType.fallback,
                          fontSize: small ? 13 : 16,
                          fontWeight: FontWeight.w600,
                          color: c.primaryLabel)),
                ]),
          ),
        ),
      ),
    );
  }
}

/// Scales to 0.97 under the finger and springs back.
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
