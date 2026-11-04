import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// Design tokens: Realbrain V5, "The Curiosity Archive" (docs/DESIGN_V5.md §2.7).
///
/// Ink and paper carry the interface; saffron is the one brand colour (the puzzle piece, the
/// main action, progress); each category has a pigment used only as a small mark. Every text pair
/// here is at least 4.5:1 (checked in test/theme_test.dart).
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
    required this.brand,
    required this.onBrand,
    required this.brandText,
    required this.trueFg,
    required this.trueBg,
    required this.mixedFg,
    required this.mixedBg,
    required this.falseFg,
    required this.falseBg,
    required this.cinnamon,
    required this.pigments,
  });

  /// Behind everything; the cards' paper; inputs and nested panels; hairline rules.
  final Color ground, surface, raised, line;

  /// Primary text, secondary text, labels and meta.
  final Color text, muted, faint;

  /// Saffron: fills (main action, the piece, progress), the ink on top of it, and saffron used as
  /// text (darkened on paper so it stays readable).
  final Color brand, onBrand, brandText;

  /// Verdict pills (Fact Check) only.
  final Color trueFg, trueBg, mixedFg, mixedBg, falseFg, falseBg;

  /// The mascot's plumage (a warmer saffron), illustration only.
  final Color cinnamon;

  /// One pigment per category id (and sub-kind), shown as glyph tint, label or dot.
  final Map<String, Color> pigments;

  Color pigment(String? id) => pigments[id] ?? muted;

  /// Text drawn over photos sits on this scrim.
  Color get scrim => const Color(0xFF0B0A09);

  static const dark = RbColors(
    ground: Color(0xFF121110),
    surface: Color(0xFF1B1917),
    raised: Color(0xFF25221F),
    line: Color(0xFF35312C),
    text: Color(0xFFF2ECE1),
    muted: Color(0xFFB3AA9C),
    faint: Color(0xFF958C7F),
    brand: Color(0xFFF0A53A),
    onBrand: Color(0xFF1A1206),
    brandText: Color(0xFFF0A53A),
    trueFg: Color(0xFF7BCB8E),
    trueBg: Color(0xFF17281C),
    mixedFg: Color(0xFFE9B44C),
    mixedBg: Color(0xFF2D2516),
    falseFg: Color(0xFFF07A6E),
    falseBg: Color(0xFF2E1A18),
    cinnamon: Color(0xFFE39A4F),
    pigments: {
      'recipe': Color(0xFFE57B45),
      'workout': Color(0xFF9BBE5C),
      'places': Color(0xFF46B8A8),
      'tools': Color(0xFF68A8F0),
      'fact_check': Color(0xFFA991FF),
      'ideas': Color(0xFFE2D35E),
      'entertainment': Color(0xFFCF86D9),
      'products': Color(0xFFE88AA0),
    },
  );

  static const light = RbColors(
    ground: Color(0xFFF3EEE5),
    surface: Color(0xFFFBF8F2),
    raised: Color(0xFFEAE3D6),
    line: Color(0xFFD9D0C1),
    text: Color(0xFF1A1714),
    muted: Color(0xFF5D564C),
    faint: Color(0xFF6B6358),
    brand: Color(0xFFE39B2C),
    onBrand: Color(0xFF1A1206),
    brandText: Color(0xFF8F5A00),
    trueFg: Color(0xFF1F6B3A),
    trueBg: Color(0xFFDDEFD9),
    mixedFg: Color(0xFF7A4A00),
    mixedBg: Color(0xFFF7E8C6),
    falseFg: Color(0xFF9B2A1E),
    falseBg: Color(0xFFF7DED8),
    cinnamon: Color(0xFFD98A3D),
    pigments: {
      'recipe': Color(0xFFA6481C),
      'workout': Color(0xFF4D6E1C),
      'places': Color(0xFF12766A),
      'tools': Color(0xFF2462B0),
      'fact_check': Color(0xFF5B47C4),
      'ideas': Color(0xFF786800),
      'entertainment': Color(0xFF84368F),
      'products': Color(0xFFA23A5A),
    },
  );

  static RbColors of(BuildContext context) =>
      Theme.of(context).extension<RbColors>() ??
      (Theme.of(context).brightness == Brightness.dark ? dark : light);

  /// Every token by name, for the design gallery and the contrast test.
  Map<String, Color> get all => {
        'ground': ground,
        'surface': surface,
        'raised': raised,
        'line': line,
        'text': text,
        'muted': muted,
        'faint': faint,
        'brand': brand,
        'on brand': onBrand,
        'brand text': brandText,
        'true': trueFg,
        'true bg': trueBg,
        'mixed': mixedFg,
        'mixed bg': mixedBg,
        'false': falseFg,
        'false bg': falseBg,
        'cinnamon': cinnamon,
        for (final e in pigments.entries) e.key: e.value,
      };

  @override
  RbColors copyWith() => this;

  @override
  RbColors lerp(RbColors? other, double t) =>
      t < 0.5 || other == null ? this : other;
}

/// Type (V5): Fraunces for display (the archive's voice; italic for the human one), IBM Plex Sans
/// for everything you read and tap, IBM Plex Mono for catalogue labels, numbers and timers.
/// Arabic falls back to Markazi Text (display) and IBM Plex Sans Arabic (text).
abstract final class RbType {
  static const display = 'Fraunces';
  static const sans = 'IBMPlexSans';
  static const mono = 'IBMPlexMono';
  static const arabicDisplay = 'MarkaziText';
  static const arabicText = 'IBMPlexSansArabic';
  static const displayFallback = [arabicDisplay, arabicText];
  static const textFallback = [arabicText];
  static const tabular = [FontFeature.tabularFigures()];

  /// Display scale: hero, screen title, card title, small heading.
  static const hero = 34.0, title = 28.0, card = 22.0, heading = 18.0;

  /// Read from a distance: cooking-mode step and workout timer digits.
  static const cookingStep = 30.0;
  static const timerDigits = 88.0;

  static TextStyle serif(double size,
          {Color? color,
          FontWeight weight = FontWeight.w600,
          bool italic = false,
          double? height}) =>
      TextStyle(
        fontFamily: display,
        fontFamilyFallback: displayFallback,
        fontSize: size,
        fontWeight: italic ? FontWeight.w400 : weight,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        letterSpacing: -0.015 * size,
        height: height ?? (size >= 26 ? 1.08 : 1.18),
        color: color,
      );

  /// Catalogue label: mono, small caps-like (callers upper-case the text), tracked.
  static TextStyle label(
          {Color? color, double size = 11, FontWeight? weight}) =>
      TextStyle(
        fontFamily: mono,
        fontFamilyFallback: textFallback,
        fontSize: size,
        fontWeight: weight ?? FontWeight.w500,
        letterSpacing: 0.08 * size,
        height: 1.3,
        color: color,
        fontFeatures: tabular,
      );

  static TextStyle monoNumber(double size,
          {Color? color, FontWeight? weight}) =>
      TextStyle(
        fontFamily: mono,
        fontFamilyFallback: textFallback,
        fontSize: size,
        fontWeight: weight ?? FontWeight.w500,
        height: 1,
        color: color,
        fontFeatures: tabular,
      );
}

/// 4 pt grid, a 20 dp side gutter, 48 dp touch targets. Editorial radii: small and precise.
abstract final class RbSpace {
  static const unit = 4.0;
  static const side = 20.0;
  static const touch = 48.0;
  static const tagRadius = 4.0;
  static const photoRadius = 6.0;
  static const cardRadius = 10.0;
  static const sheetRadius = 16.0;
  static const pill = 999.0;

  /// The widest a reading column gets on tablets and desktop.
  static const column = 640.0;
}

/// A spring as a Curve over a fixed duration, so implicit animations move on springs. Overshoots
/// past 1 when under-damped: use it on size, position and scale, never on opacity.
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

/// Motion (V5): quick and purposeful, 150-400 ms; springs only on things that answer a touch.
/// Under reduced motion everything becomes a short ease (see [RbMotion.of]).
abstract final class RbMotion {
  static const fast = Duration(milliseconds: 150);
  static const base = Duration(milliseconds: 260);
  static const slow = Duration(milliseconds: 420);

  /// Content: critically damped, no bounce.
  static const curve =
      SpringCurve(stiffness: 210, dampingRatio: 1, settle: 0.55);

  /// The piece snapping in, sheets: a small overshoot.
  static const bouncy =
      SpringCurve(stiffness: 280, dampingRatio: 0.72, settle: 0.7);

  /// Entrances (fade + rise).
  static const enter = Curves.easeOutCubic;

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// (duration, curve) for a content move, or a quick ease when reduced motion is on.
  static (Duration, Curve) of(BuildContext context, {bool bounce = false}) =>
      reduced(context)
          ? (fast, Curves.easeOut)
          : (bounce ? slow : base, bounce ? bouncy : curve);
}
