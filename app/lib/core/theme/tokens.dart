import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// Design system v2 tokens (docs/BUILD_PLAN.md "Design system"). Locked: change the doc first.
/// One accent (signal blue) on data only; sections have no colours; true neutrals.
@immutable
class RbColors extends ThemeExtension<RbColors> {
  const RbColors({
    required this.ground,
    required this.surface,
    required this.raised,
    required this.line,
    required this.text,
    required this.muted,
    required this.faint,
    required this.primaryFill,
    required this.primaryLabel,
    required this.accent,
    required this.trueFg,
    required this.trueBg,
    required this.mixedFg,
    required this.mixedBg,
    required this.falseFg,
    required this.falseBg,
  });

  final Color ground, surface, raised, line, text, muted, faint;
  final Color primaryFill, primaryLabel, accent;
  final Color trueFg, trueBg, mixedFg, mixedBg, falseFg, falseBg;

  static const dark = RbColors(
    ground: Color(0xFF0E0E0F),
    surface: Color(0xFF18181A),
    raised: Color(0xFF222225),
    line: Color(0xFF2A2A2D),
    text: Color(0xFFFFFFFF),
    muted: Color(0xFFB4B4B4),
    faint: Color(0xFF949494),
    primaryFill: Color(0xFFFFFFFF),
    primaryLabel: Color(0xFF000000),
    accent: Color(0xFF6CB8FF),
    trueFg: Color(0xFF3FC07A),
    trueBg: Color(0xFF172A1D),
    mixedFg: Color(0xFFE9B44C),
    mixedBg: Color(0xFF2D2516),
    falseFg: Color(0xFFE5566F),
    falseBg: Color(0xFF2C1A20),
  );

  static const light = RbColors(
    ground: Color(0xFFF7F7F5),
    surface: Color(0xFFFFFFFF),
    raised: Color(0xFFF0F0EE),
    line: Color(0xFFE6E6E3),
    text: Color(0xFF111111),
    muted: Color(0xFF5F6368),
    faint: Color(0xFF6B6B6B),
    primaryFill: Color(0xFF111111),
    primaryLabel: Color(0xFFFFFFFF),
    accent: Color(0xFF1F6FD1),
    trueFg: Color(0xFF247B50),
    trueBg: Color(0xFFDCFAE5),
    mixedFg: Color(0xFF92400E),
    mixedBg: Color(0xFFFFFBEB),
    falseFg: Color(0xFF831C1E),
    falseBg: Color(0xFFFFEDEA),
  );

  static RbColors of(BuildContext context) =>
      Theme.of(context).extension<RbColors>() ??
      (Theme.of(context).brightness == Brightness.dark ? dark : light);

  /// Every token by name, for the design gallery.
  Map<String, Color> get all => {
        'ground': ground,
        'surface': surface,
        'raised': raised,
        'line': line,
        'text': text,
        'muted': muted,
        'faint': faint,
        'primary fill': primaryFill,
        'primary label': primaryLabel,
        'accent': accent,
        'true': trueFg,
        'true bg': trueBg,
        'mixed': mixedFg,
        'mixed bg': mixedBg,
        'false': falseFg,
        'false bg': falseBg,
      };

  @override
  RbColors copyWith() => this;

  @override
  RbColors lerp(RbColors? other, double t) =>
      t < 0.5 || other == null ? this : other;
}

/// Type: IBM Plex Sans + IBM Plex Sans Arabic, one family; 12/14/16/20/28; weights 400/500/600.
/// Two justified exceptions read from a distance: cooking step 28, workout timer digits 96.
abstract final class RbType {
  static const family = 'IBMPlexSans';
  static const fallback = ['IBMPlexSansArabic'];
  static const sizes = [12.0, 14.0, 16.0, 20.0, 28.0];
  static const cookingStep = 28.0;
  static const timerDigits = 96.0;
  static const tabular = [FontFeature.tabularFigures()];
}

/// 4 pt grid, 16 side margins, 48 dp touch targets; radii 24 / 16 / round (design v3: corners
/// nest evenly inside 8 px of glass padding).
abstract final class RbSpace {
  static const unit = 4.0;
  static const side = 16.0;
  static const touch = 48.0;
  static const cardRadius = 24.0;
  static const panelRadius = 16.0;
  static const pill = 999.0;
  static const glassPad = 8.0;
}

/// A spring as a Curve over a fixed duration, so implicit animations (AnimatedContainer,
/// AnimatedSize, AnimatedScale) move on springs. Overshoots past 1 when under-damped: use it on
/// size, position and scale, never on opacity.
class SpringCurve extends Curve {
  const SpringCurve(
      {this.stiffness = 180, this.dampingRatio = 1, this.settle = 1.0});
  final double stiffness, dampingRatio;

  /// Seconds of spring time mapped onto the animation's 0..1.
  final double settle;

  @override
  double transformInternal(double t) {
    final sim = SpringSimulation(
      SpringDescription.withDampingRatio(
          mass: 1, stiffness: stiffness, ratio: dampingRatio),
      0,
      1,
      0,
    );
    return sim.x(t * settle);
  }
}

/// Design v3 motion: springs that answer an action; nothing moves on its own. Under reduced motion
/// everything becomes a 150 ms fade-speed ease (see [RbMotion.of]).
abstract final class RbMotion {
  static const fast = Duration(milliseconds: 150);
  static const base = Duration(milliseconds: 350);
  static const slow = Duration(milliseconds: 500);

  /// Content: critically damped, no bounce, settles in about 350 ms.
  static const curve =
      SpringCurve(stiffness: 180, dampingRatio: 1, settle: 0.6);

  /// The pill and sheets: a small overshoot.
  static const bouncy =
      SpringCurve(stiffness: 260, dampingRatio: 0.8, settle: 0.7);

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// (duration, curve) for a content move, or a quick ease when reduced motion is on.
  static (Duration, Curve) of(BuildContext context, {bool bounce = false}) =>
      reduced(context)
          ? (fast, Curves.easeOut)
          : (bounce ? slow : base, bounce ? bouncy : curve);
}
