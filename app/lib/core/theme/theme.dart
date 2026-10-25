import 'package:flutter/material.dart';

import 'tokens.dart';

export 'tokens.dart';

/// Material 3 theme built only from Design system tokens. Widgets keep using Theme/colorScheme;
/// verdict and accent colours come from `RbColors.of(context)`.
ThemeData rbTheme(Brightness b) {
  final c = b == Brightness.dark ? RbColors.dark : RbColors.light;
  final scheme = ColorScheme(
    brightness: b,
    primary: c.primaryFill,
    onPrimary: c.primaryLabel,
    secondary: c.accent,
    onSecondary: c.primaryLabel,
    error: c.falseFg,
    onError: c.falseBg,
    surface: c.surface,
    onSurface: c.text,
    onSurfaceVariant: c.muted,
    surfaceContainerLowest: c.ground,
    surfaceContainerLow: c.surface,
    surfaceContainer: c.surface,
    surfaceContainerHigh: c.raised,
    surfaceContainerHighest: c.raised,
    outline: c.faint,
    outlineVariant: c.line,
    secondaryContainer: c.raised,
    onSecondaryContainer: c.text,
  );
  // Design v4 scale 12/13/15/16/19/28, weights 400-700, tabular figures on every number.
  TextStyle t(double size, FontWeight w, [Color? color]) => TextStyle(
      fontSize: size,
      fontWeight: w,
      color: color ?? c.text,
      fontFeatures: RbType.tabular,
      fontFamily: RbType.family,
      fontFamilyFallback: RbType.fallback);
  // Large text is bold with slightly tight tracking.
  TextStyle d(double size, FontWeight w) =>
      t(size, w).copyWith(letterSpacing: -0.02 * size, height: 1.15);
  final text = TextTheme(
    displayLarge: d(28, FontWeight.w700),
    displayMedium: d(28, FontWeight.w700),
    displaySmall: d(28, FontWeight.w700),
    headlineLarge: d(28, FontWeight.w700),
    headlineMedium: d(28, FontWeight.w700),
    headlineSmall: d(19, FontWeight.w600),
    titleLarge: d(19, FontWeight.w600),
    titleMedium: t(16, FontWeight.w600),
    titleSmall: t(15, FontWeight.w600),
    bodyLarge: t(16, FontWeight.w400),
    bodyMedium: t(15, FontWeight.w400),
    bodySmall: t(13, FontWeight.w400, c.muted),
    labelLarge: t(15, FontWeight.w500),
    labelMedium: t(13, FontWeight.w500),
    labelSmall: t(12, FontWeight.w500, c.faint),
  );
  const round = StadiumBorder();
  final panel = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(RbSpace.panelRadius));
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: scheme,
    extensions: [c],
    fontFamily: RbType.family,
    fontFamilyFallback: RbType.fallback,
    textTheme: text,
    scaffoldBackgroundColor: c.ground,
    canvasColor: c.ground,
    dividerColor: c.line,
    dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: c.ground,
      foregroundColor: c.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: text.titleLarge,
    ),
    // Separation by a lightness step and a 1 px line; no shadow on cards.
    cardTheme: CardThemeData(
      color: c.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RbSpace.cardRadius),
        side: BorderSide(color: c.line),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: StadiumBorder(side: BorderSide(color: c.line)),
      side: BorderSide(color: c.line),
      backgroundColor: c.surface,
      selectedColor: c.raised,
      checkmarkColor: c.accent,
      labelStyle: text.labelLarge,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? c.text.withValues(alpha: 0.12)
                : Colors.transparent),
        foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? c.text : c.muted),
        side: WidgetStatePropertyAll(BorderSide(color: c.line)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            shape: round, minimumSize: const Size(64, RbSpace.touch))),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
            shape: round,
            side: BorderSide(color: c.line),
            minimumSize: const Size(64, RbSpace.touch))),
    textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
            shape: round,
            foregroundColor: c.text,
            minimumSize: const Size(48, RbSpace.touch))),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.raised,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RbSpace.pill),
          borderSide: BorderSide.none),
    ),
    // Shadows only on what floats: sheets, menus, the toast.
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      showDragHandle: true,
      dragHandleColor: c.faint,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(RbSpace.cardRadius))),
    ),
    popupMenuTheme: PopupMenuThemeData(
        color: c.raised, surfaceTintColor: Colors.transparent, shape: panel),
    dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RbSpace.cardRadius))),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.primaryFill,
      contentTextStyle: text.bodyMedium?.copyWith(color: c.primaryLabel),
      shape: round,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.accent,
        linearTrackColor: c.raised,
        circularTrackColor: c.raised),
    navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        indicatorColor: c.raised,
        surfaceTintColor: Colors.transparent),
    listTileTheme:
        ListTileThemeData(iconColor: c.muted, minVerticalPadding: 12),
    iconTheme: IconThemeData(color: c.muted, size: 20),
    pageTransitionsTheme: const PageTransitionsTheme(),
  );
}

/// WCAG contrast ratio between two opaque colours.
double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}
