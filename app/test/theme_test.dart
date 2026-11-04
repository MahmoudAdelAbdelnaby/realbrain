import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelbrain/core/theme/theme.dart';

void main() {
  for (final (name, c) in [('ink', RbColors.dark), ('paper', RbColors.light)]) {
    test('$name: every text colour reads at 4.5:1 or better on every surface',
        () {
      for (final bg in [c.ground, c.surface, c.raised]) {
        for (final fg in [c.text, c.muted, c.faint]) {
          expect(contrast(fg, bg), greaterThanOrEqualTo(4.5),
              reason: '$fg on $bg');
        }
      }
      for (final bg in [c.ground, c.surface]) {
        expect(contrast(c.brandText, bg), greaterThanOrEqualTo(4.5),
            reason: 'saffron text');
        // Pigments are used as label text (catalogue lines, category names).
        for (final e in c.pigments.entries) {
          expect(contrast(e.value, bg), greaterThanOrEqualTo(4.5),
              reason: '${e.key} on $bg');
        }
      }
      expect(contrast(c.onBrand, c.brand), greaterThanOrEqualTo(4.5),
          reason: 'ink on saffron');
      for (final (fg, bg) in [
        (c.trueFg, c.trueBg),
        (c.mixedFg, c.mixedBg),
        (c.falseFg, c.falseBg)
      ]) {
        expect(contrast(fg, bg), greaterThanOrEqualTo(4.5),
            reason: 'verdict pill');
      }
    });
  }

  test('every category has a pigment in both themes', () {
    expect(RbColors.dark.pigments.keys.toSet(),
        RbColors.light.pigments.keys.toSet());
    expect(RbColors.dark.pigments.length, 8);
  });

  test('springs end exactly at 1; the bouncy one overshoots, content does not',
      () {
    expect(RbMotion.curve.transform(1), closeTo(1, 0.02));
    expect(RbMotion.bouncy.transform(1), closeTo(1, 0.03));
    final bouncyPeak = [
      for (var i = 0; i <= 100; i++) RbMotion.bouncy.transform(i / 100)
    ].reduce((a, b) => a > b ? a : b);
    final contentPeak = [
      for (var i = 0; i <= 100; i++) RbMotion.curve.transform(i / 100)
    ].reduce((a, b) => a > b ? a : b);
    expect(bouncyPeak, greaterThan(1.0));
    expect(contentPeak, lessThanOrEqualTo(1.01));
  });

  test('the theme uses the V5 type and saffron for the main action', () {
    final t = rbTheme(Brightness.dark);
    expect(t.textTheme.displayLarge!.fontFamily, RbType.display);
    expect(t.textTheme.bodyMedium!.fontFamily, RbType.sans);
    expect(t.textTheme.labelSmall!.fontFamily, RbType.mono);
    expect(t.colorScheme.primary, RbColors.dark.brand);
    expect(t.textTheme.displayLarge!.fontFamilyFallback,
        contains(RbType.arabicDisplay));
  });
}
