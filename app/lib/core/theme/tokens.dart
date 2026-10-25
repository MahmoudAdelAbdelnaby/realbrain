import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// Design tokens: design v4 (docs/DESIGN_V4_PROPOSAL.md §2): a navy ground under a soft haze,
/// lavender as the brand, pill and action gradients, and one hue per interest.
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
    required this.brand,
    required this.haze,
    required this.pill,
    required this.action,
    required this.sections,
  });

  final Color ground, surface, raised, line, text, muted, faint;
  final Color primaryFill, primaryLabel, accent;
  final Color trueFg, trueBg, mixedFg, mixedBg, falseFg, falseBg;

  /// Lavender: the mark, selection, links.
  final Color brand;

  /// The two glows behind every screen: top right, bottom left.
  final (Color, Color) haze;

  /// Pill buttons (Cook now, Try now, the + button): top to bottom.
  final (Color, Color) pill;

  /// The one main action on a screen (Start cooking): start to end.
  final (Color, Color) action;

  /// One hue per interest: chip dot, card wash, thread node.
  final Map<String, Color> sections;

  Color section(String? id) => sections[id] ?? accent;

  static const dark = RbColors(
    ground: Color(0xFF080A14),
    surface: Color(0xFF111528),
    raised: Color(0xFF1A1F38),
    line: Color(0xFF24294A),
    text: Color(0xFFFFFFFF),
    muted: Color(0xFFA7ACBF),
    faint: Color(0xFF8A8FA3),
    primaryFill: Color(0xFFECE9FF),
    primaryLabel: Color(0xFF12142A),
    accent: Color(0xFF9C8CFF),
    trueFg: Color(0xFF3FC07A),
    trueBg: Color(0xFF172A1D),
    mixedFg: Color(0xFFE9B44C),
    mixedBg: Color(0xFF2D2516),
    falseFg: Color(0xFFE5566F),
    falseBg: Color(0xFF2C1A20),
    brand: Color(0xFF9C8CFF),
    haze: (Color(0xFF1B1F3D), Color(0xFF141A33)),
    pill: (Color(0xFFFFFFFF), Color(0xFFE6E2FF)),
    action: (Color(0xFFFF9A5A), Color(0xFFFF6B8B)),
    sections: {
      'fact_check': Color(0xFFFF6B8B),
      'tools': Color(0xFF8FB8FF),
      'recipe': Color(0xFFFFB27A),
      'places': Color(0xFF6FE0C8),
      'workout': Color(0xFF9BE38A),
      'learning': Color(0xFF9C8CFF),
      'ideas': Color(0xFFFFD66B),
    },
  );

  static const light = RbColors(
    ground: Color(0xFFF4F4FA),
    surface: Color(0xFFFFFFFF),
    raised: Color(0xFFECEBF6),
    line: Color(0xFFDAD9E8),
    text: Color(0xFF0E1024),
    muted: Color(0xFF5B5F75),
    faint: Color(0xFF63677D),
    primaryFill: Color(0xFF0E1024),
    primaryLabel: Color(0xFFFFFFFF),
    accent: Color(0xFF5B4FD6),
    trueFg: Color(0xFF247B50),
    trueBg: Color(0xFFDCFAE5),
    mixedFg: Color(0xFF92400E),
    mixedBg: Color(0xFFFFFBEB),
    falseFg: Color(0xFF831C1E),
    falseBg: Color(0xFFFFEDEA),
    brand: Color(0xFF5B4FD6),
    haze: (Color(0xFFE4E1FA), Color(0xFFE9EDFA)),
    pill: (Color(0xFF1B1E3A), Color(0xFF0E1024)),
    action: (Color(0xFFE0641F), Color(0xFFD62C5A)),
    sections: {
      'fact_check': Color(0xFFC2264B),
      'tools': Color(0xFF2D63C8),
      'recipe': Color(0xFFA2520C),
      'places': Color(0xFF0F7A68),
      'workout': Color(0xFF3F7A1E),
      'learning': Color(0xFF5B4FD6),
      'ideas': Color(0xFF7F6200),
    },
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
        'brand': brand,
        'haze top': haze.$1,
        'haze bottom': haze.$2,
        'pill top': pill.$1,
        'pill bottom': pill.$2,
        'action start': action.$1,
        'action end': action.$2,
        for (final e in sections.entries) 'section ${e.key}': e.value,
      };

  @override
  RbColors copyWith() => this;

  @override
  RbColors lerp(RbColors? other, double t) =>
      t < 0.5 || other == null ? this : other;
}

/// Type (design v4): Inter, with IBM Plex Sans Arabic for Arabic; 12/13/15/16/19/28; weights
/// 400/500/600/700. Two justified exceptions read from a distance: cooking step 28, workout
/// timer digits 96.
abstract final class RbType {
  static const family = 'Inter';
  static const fallback = ['IBMPlexSansArabic'];
  static const sizes = [12.0, 13.0, 15.0, 16.0, 19.0, 28.0];
  static const cookingStep = 28.0;
  static const timerDigits = 96.0;
  static const tabular = [FontFeature.tabularFigures()];
}

/// 4 pt grid, 20 side margins, 48 dp touch targets; radii 20 cards / 16 panels / 14 photos in a
/// card / round pills.
abstract final class RbSpace {
  static const unit = 4.0;
  static const side = 20.0;
  static const touch = 48.0;
  static const cardRadius = 20.0;
  static const panelRadius = 16.0;
  static const photoRadius = 14.0;
  static const pill = 999.0;
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

/// Motion: springs that answer an action; nothing moves on its own. Under reduced motion
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
