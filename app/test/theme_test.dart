import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelbrain/core/theme/gallery.dart';
import 'package:reelbrain/core/theme/theme.dart';
import 'package:reelbrain/core/widgets.dart';

void main() {
  for (final (name, c) in [
    ('dark', RbColors.dark),
    ('light', RbColors.light)
  ]) {
    test(
        '$name: text, muted and faint reach 4.5:1 on ground, surface and raised',
        () {
      for (final fg in [c.text, c.muted, c.faint]) {
        for (final bg in [c.ground, c.surface, c.raised]) {
          expect(contrast(fg, bg), greaterThanOrEqualTo(4.5),
              reason: '$fg on $bg');
        }
      }
    });

    test('$name: verdict pills and the primary button reach 4.5:1', () {
      expect(contrast(c.trueFg, c.trueBg), greaterThanOrEqualTo(4.5));
      expect(contrast(c.mixedFg, c.mixedBg), greaterThanOrEqualTo(4.5));
      expect(contrast(c.falseFg, c.falseBg), greaterThanOrEqualTo(4.5));
      expect(
          contrast(c.primaryLabel, c.primaryFill), greaterThanOrEqualTo(4.5));
    });
  }

  test(
      'theme uses Plex Sans with Plex Sans Arabic, the type scale and tabular figures',
      () {
    final t = rbTheme(Brightness.dark).textTheme;
    final sizes = {
      for (final s in [
        t.headlineLarge,
        t.titleLarge,
        t.titleMedium,
        t.bodyLarge,
        t.bodyMedium,
        t.bodySmall
      ])
        s!.fontSize
    };
    expect(sizes.every(RbType.sizes.contains), isTrue);
    expect(t.bodyMedium!.fontFamily, RbType.family);
    expect(t.bodyMedium!.fontFamilyFallback, contains('IBMPlexSansArabic'));
    expect(t.bodyMedium!.fontFeatures, RbType.tabular);
    expect(rbTheme(Brightness.light).extension<RbColors>(), RbColors.light);
  });

  testWidgets(
      'gallery shows every token and component, flips theme and direction',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: rbTheme(Brightness.light), home: const DesignGallery()));
    expect(find.text('ground'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Cooked'), 300);
    expect(find.byType(SectionChip), findsNWidgets(5));
    expect(find.byType(StatusPill), findsNWidgets(2));
    await tester.scrollUntilVisible(find.byType(EmptyState), 300);

    await tester.tap(find.text('RTL'));
    await tester.pump();
    expect(Directionality.of(tester.element(find.byType(EmptyState))),
        TextDirection.rtl);

    await tester.tap(find.byTooltip('Theme'));
    await tester.pump();
    expect(Theme.of(tester.element(find.byType(EmptyState))).brightness,
        Brightness.dark);

    await tester.scrollUntilVisible(find.text('Open bottom sheet'), 300);
    await tester.tap(find.text('Open bottom sheet'));
    await tester.pumpAndSettle();
    expect(find.text('Bottom sheet'), findsOneWidget);
  });
}
