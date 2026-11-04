import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'tokens.dart';

export 'tokens.dart';

/// Material 3 theme built only from V5 tokens. Screens use the text theme and RbColors; the
/// Material component themes here make stock widgets (dialogs, pickers, switches, snack bars)
/// look like they belong to the archive.
ThemeData rbTheme(Brightness b) {
  final c = b == Brightness.dark ? RbColors.dark : RbColors.light;
  final scheme = ColorScheme(
    brightness: b,
    primary: c.brand,
    onPrimary: c.onBrand,
    primaryContainer: c.raised,
    onPrimaryContainer: c.text,
    secondary: c.text,
    onSecondary: c.ground,
    secondaryContainer: c.raised,
    onSecondaryContainer: c.text,
    tertiary: c.brandText,
    onTertiary: c.ground,
    error: c.falseFg,
    onError: c.ground,
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
    inverseSurface: c.text,
    onInverseSurface: c.ground,
    inversePrimary: c.brandText,
    shadow: Colors.black,
    scrim: Colors.black,
    surfaceTint: Colors.transparent,
  );

  TextStyle sans(double size, FontWeight w, {Color? color, double h = 1.4}) =>
      TextStyle(
          fontFamily: RbType.sans,
          fontFamilyFallback: RbType.textFallback,
          fontSize: size,
          fontWeight: w,
          height: h,
          color: color ?? c.text,
          fontFeatures: RbType.tabular);

  final text = TextTheme(
    displayLarge: RbType.serif(RbType.hero, color: c.text),
    displayMedium: RbType.serif(RbType.title, color: c.text),
    displaySmall: RbType.serif(RbType.card, color: c.text),
    headlineLarge: RbType.serif(RbType.hero, color: c.text),
    headlineMedium: RbType.serif(RbType.title, color: c.text),
    headlineSmall: RbType.serif(RbType.card, color: c.text),
    titleLarge: RbType.serif(20, color: c.text),
    titleMedium: sans(16, FontWeight.w600, h: 1.3),
    titleSmall: sans(15, FontWeight.w600, h: 1.3),
    bodyLarge: sans(16, FontWeight.w400, h: 1.5),
    bodyMedium: sans(15, FontWeight.w400, h: 1.45),
    bodySmall: sans(13, FontWeight.w400, color: c.muted, h: 1.4),
    labelLarge: sans(15, FontWeight.w500, h: 1.2),
    labelMedium: sans(13, FontWeight.w500, h: 1.2),
    labelSmall: RbType.label(color: c.faint),
  );

  const pill = StadiumBorder();
  final card = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(RbSpace.cardRadius),
      side: BorderSide(color: c.line));
  final sheet = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(RbSpace.sheetRadius));

  return ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: scheme,
    extensions: [c],
    fontFamily: RbType.sans,
    fontFamilyFallback: RbType.textFallback,
    textTheme: text,
    primaryTextTheme: text,
    scaffoldBackgroundColor: c.ground,
    canvasColor: c.ground,
    dividerColor: c.line,
    splashFactory: InkSparkle.constantTurbulenceSeedSplashFactory,
    highlightColor: c.text.withValues(alpha: 0.04),
    splashColor: c.text.withValues(alpha: 0.06),
    dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: c.ground,
      foregroundColor: c.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: RbType.serif(20, color: c.text),
      iconTheme: IconThemeData(color: c.text, size: 22),
    ),
    cardTheme: CardThemeData(
      color: c.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shape: card,
    ),
    chipTheme: ChipThemeData(
      shape: StadiumBorder(side: BorderSide(color: c.line)),
      side: BorderSide(color: c.line),
      backgroundColor: Colors.transparent,
      selectedColor: c.text,
      secondarySelectedColor: c.text,
      checkmarkColor: c.ground,
      labelStyle: text.labelMedium,
      secondaryLabelStyle: text.labelMedium?.copyWith(color: c.ground),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    ),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            backgroundColor: c.brand,
            foregroundColor: c.onBrand,
            shape: pill,
            textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
            minimumSize: const Size(64, RbSpace.touch))),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
            foregroundColor: c.text,
            shape: pill,
            side: BorderSide(color: c.line),
            textStyle: text.labelLarge,
            minimumSize: const Size(64, RbSpace.touch))),
    textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
            foregroundColor: c.text,
            shape: pill,
            textStyle: text.labelLarge,
            minimumSize: const Size(48, RbSpace.touch))),
    iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
            foregroundColor: c.text,
            minimumSize: const Size(RbSpace.touch, RbSpace.touch))),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.raised,
      hintStyle: text.bodyMedium?.copyWith(color: c.faint),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RbSpace.cardRadius),
          borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RbSpace.cardRadius),
          borderSide: BorderSide(color: c.text, width: 1.2)),
    ),
    textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.brand,
        selectionColor: c.brand.withValues(alpha: 0.35),
        selectionHandleColor: c.brand),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.onBrand : c.muted),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.brand : c.raised),
      trackOutlineColor: WidgetStatePropertyAll(c.line),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? c.text : Colors.transparent),
      checkColor: WidgetStatePropertyAll(c.ground),
      side: BorderSide(color: c.faint, width: 1.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
    ),
    radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? c.brand : c.faint)),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? c.text : Colors.transparent),
        foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? c.ground : c.muted),
        side: WidgetStatePropertyAll(BorderSide(color: c.line)),
        textStyle: WidgetStatePropertyAll(text.labelMedium),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: c.surface,
      elevation: 0,
      showDragHandle: false,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(RbSpace.sheetRadius))),
    ),
    popupMenuTheme: PopupMenuThemeData(
        color: c.raised,
        surfaceTintColor: Colors.transparent,
        textStyle: text.bodyMedium,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RbSpace.cardRadius),
            side: BorderSide(color: c.line))),
    dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: RbType.serif(22, color: c.text),
        contentTextStyle: text.bodyMedium,
        shape: sheet),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: c.raised,
      headerForegroundColor: c.text,
      headerHeadlineStyle: RbType.serif(26, color: c.text),
      shape: sheet,
      todayBorder: BorderSide(color: c.brand),
      dayForegroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.onBrand : c.text),
      dayBackgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.brand : null),
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: c.surface,
      hourMinuteColor: c.raised,
      hourMinuteTextColor: c.text,
      dialHandColor: c.brand,
      dialBackgroundColor: c.raised,
      dayPeriodColor: c.raised,
      shape: sheet,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.text,
      contentTextStyle: text.bodyMedium?.copyWith(color: c.ground),
      actionTextColor: c.brand,
      elevation: 6,
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 92),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RbSpace.cardRadius)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration:
          BoxDecoration(color: c.text, borderRadius: BorderRadius.circular(6)),
      textStyle: text.labelMedium?.copyWith(color: c.ground),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.brand,
        linearTrackColor: c.raised,
        circularTrackColor: c.raised),
    listTileTheme: ListTileThemeData(
        iconColor: c.muted,
        textColor: c.text,
        titleTextStyle: text.bodyLarge,
        subtitleTextStyle: text.bodySmall,
        minVerticalPadding: 12),
    iconTheme: IconThemeData(color: c.muted, size: 22),
    badgeTheme: BadgeThemeData(backgroundColor: c.brand, textColor: c.onBrand),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
  );
}

/// WCAG contrast ratio between two opaque colours.
double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}
