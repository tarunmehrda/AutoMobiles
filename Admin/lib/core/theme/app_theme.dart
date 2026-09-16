import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_tokens.dart';
import 'app_type.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(AppColors.light);
  static ThemeData dark() => _build(AppColors.dark);

  static ThemeData _build(AppPalette p) {
    final scheme = ColorScheme(
      brightness: p.brightness,
      primary: p.accent,
      onPrimary: p.onAccent,
      primaryContainer: p.accentSoft,
      onPrimaryContainer: p.accentInk,
      secondary: p.ink,
      onSecondary: p.surface,
      secondaryContainer: p.surfaceSunken,
      onSecondaryContainer: p.ink,
      error: p.danger,
      onError: Colors.white,
      errorContainer: p.dangerSoft,
      onErrorContainer: p.danger,
      surface: p.surface,
      onSurface: p.ink,
      surfaceContainerLowest: p.surface,
      surfaceContainerLow: p.surfaceAlt,
      surfaceContainer: p.surfaceAlt,
      surfaceContainerHigh: p.surfaceSunken,
      surfaceContainerHighest: p.surfaceSunken,
      onSurfaceVariant: p.inkMuted,
      outline: p.line,
      outlineVariant: p.lineSoft,
      inverseSurface: p.inverse,
      onInverseSurface: p.onInverse,
      shadow: Colors.black,
      scrim: p.scrim,
    );

    final text = TextTheme(
      displayLarge: AppType.d1.c(p.ink),
      displayMedium: AppType.d2.c(p.ink),
      displaySmall: AppType.d3.c(p.ink),
      headlineMedium: AppType.h1.c(p.ink),
      headlineSmall: AppType.h2.c(p.ink),
      titleLarge: AppType.h1.c(p.ink),
      titleMedium: AppType.h2.c(p.ink),
      titleSmall: AppType.h3.c(p.ink),
      bodyLarge: AppType.bodyL.c(p.inkSoft),
      bodyMedium: AppType.bodyM.c(p.inkSoft),
      bodySmall: AppType.bodyS.c(p.inkMuted),
      labelLarge: AppType.labelL.c(p.ink),
      labelMedium: AppType.labelM.c(p.inkSoft),
      labelSmall: AppType.labelS.c(p.inkMuted),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.canvas,
      canvasColor: p.canvas,
      fontFamily: AppType.body,
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,
      highlightColor: Colors.transparent,
      visualDensity: VisualDensity.standard,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeThroughPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeThroughPageTransitionsBuilder(),
          TargetPlatform.linux: FadeThroughPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.canvas,
        surfaceTintColor: Colors.transparent,
        foregroundColor: p.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppType.h1.c(p.ink),
        systemOverlayStyle: p.isDark
            ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
            : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: R.rLg),
      ),
      dividerTheme: DividerThemeData(color: p.line, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: p.ink, size: 22),
      listTileTheme: ListTileThemeData(
        iconColor: p.inkMuted,
        textColor: p.ink,
        titleTextStyle: AppType.labelL.c(p.ink),
        subtitleTextStyle: AppType.bodyS.c(p.inkMuted),
        shape: RoundedRectangleBorder(borderRadius: R.rMd),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceSunken,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: Gap.lg, vertical: Gap.lg),
        hintStyle: AppType.bodyM.c(p.inkFaint),
        labelStyle: AppType.labelM.c(p.inkMuted),
        floatingLabelStyle: AppType.labelM.c(p.accent),
        errorStyle: AppType.labelS.c(p.danger),
        border: OutlineInputBorder(
            borderRadius: R.rMd, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: R.rMd, borderSide: BorderSide(color: p.line)),
        focusedBorder: OutlineInputBorder(
            borderRadius: R.rMd,
            borderSide: BorderSide(color: p.accent, width: 1.6)),
        errorBorder: OutlineInputBorder(
            borderRadius: R.rMd,
            borderSide: BorderSide(color: p.danger, width: 1.2)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: R.rMd,
            borderSide: BorderSide(color: p.danger, width: 1.6)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surfaceSunken,
        selectedColor: p.ink,
        side: BorderSide(color: p.line),
        labelStyle: AppType.labelM.c(p.inkSoft),
        secondaryLabelStyle: AppType.labelM.c(p.surface),
        padding: const EdgeInsets.symmetric(
            horizontal: Gap.md, vertical: Gap.sm),
        shape: const StadiumBorder(),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(R.xxl)),
        ),
        showDragHandle: false,
      ).copyWith(
        backgroundColor: p.surface,
        modalBackgroundColor: p.surface,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: R.all(R.xl)),
        titleTextStyle: AppType.h1.c(p.ink),
        contentTextStyle: AppType.bodyM.c(p.inkSoft),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.inverse,
        contentTextStyle: AppType.labelM.c(p.onInverse),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: R.rMd),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: p.ink,
        unselectedLabelColor: p.inkMuted,
        labelStyle: AppType.labelL,
        unselectedLabelStyle: AppType.labelL.w(FontWeight.w500),
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: p.accent, width: 2.5),
          insets: const EdgeInsets.symmetric(horizontal: 2),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.accent,
        linearTrackColor: p.surfaceSunken,
        circularTrackColor: Colors.transparent,
        strokeWidth: 2.6,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: p.accent,
        inactiveTrackColor: p.surfaceSunken,
        thumbColor: p.accent,
        overlayColor: p.accent.withValues(alpha: 0.12),
        trackHeight: 5,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? Colors.white : p.surface),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? p.accent : p.surfaceSunken),
        trackOutlineColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? Colors.transparent : p.line),
        trackOutlineWidth: const WidgetStatePropertyAll(1),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? p.accent : Colors.transparent),
        checkColor: WidgetStatePropertyAll(p.onAccent),
        side: BorderSide(color: p.inkFaint, width: 1.6),
        shape: RoundedRectangleBorder(borderRadius: R.all(7)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? p.accent : p.inkFaint),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: p.inverse, borderRadius: R.rSm),
        textStyle: AppType.labelS.c(p.onInverse),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.accent,
        selectionColor: p.accent.withValues(alpha: 0.24),
        selectionHandleColor: p.accent,
      ),
    );
  }
}

/// Shared-axis style fade-through used for full page pushes.
class FadeThroughPageTransitionsBuilder extends PageTransitionsBuilder {
  const FadeThroughPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved =
        CurvedAnimation(parent: animation, curve: Motion.emphasized);
    final out =
        CurvedAnimation(parent: secondaryAnimation, curve: Motion.emphasized);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.035), end: Offset.zero)
            .animate(curved),
        child: FadeTransition(
          opacity: Tween<double>(begin: 1, end: 0).animate(out),
          child: SlideTransition(
            position:
                Tween<Offset>(begin: Offset.zero, end: const Offset(0, -0.02))
                    .animate(out),
            child: child,
          ),
        ),
      ),
    );
  }
}
