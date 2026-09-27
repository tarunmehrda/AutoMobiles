import 'package:flutter/material.dart';

/// Balaji Automobiles palette — "Pit Lane".
///
/// Carbon base, signal-orange accent, volt highlight reserved for the
/// live-tracking surfaces. Two hand-tuned palettes instead of a generated
/// Material scheme so light and dark both read intentionally.
@immutable
class AppPalette {
  const AppPalette({
    required this.brightness,
    required this.canvas,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceSunken,
    required this.inverse,
    required this.onInverse,
    required this.ink,
    required this.inkSoft,
    required this.inkMuted,
    required this.inkFaint,
    required this.line,
    required this.lineSoft,
    required this.accent,
    required this.accentSoft,
    required this.accentInk,
    required this.onAccent,
    required this.volt,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    required this.info,
    required this.infoSoft,
    required this.shimmerBase,
    required this.shimmerHighlight,
    required this.scrim,
  });

  final Brightness brightness;

  /// App background.
  final Color canvas;

  /// Default card / sheet background.
  final Color surface;

  /// Slightly raised or tinted card background.
  final Color surfaceAlt;

  /// Recessed wells, inputs, track backgrounds.
  final Color surfaceSunken;

  /// Dark hero surfaces (tracking card, CTA bars) + its foreground.
  final Color inverse;
  final Color onInverse;

  final Color ink;
  final Color inkSoft;
  final Color inkMuted;
  final Color inkFaint;

  final Color line;
  final Color lineSoft;

  final Color accent;
  final Color accentSoft;

  /// Accent tuned for text on light backgrounds (passes contrast).
  final Color accentInk;
  final Color onAccent;

  /// High-energy highlight, only legible on [inverse].
  final Color volt;

  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;
  final Color info;
  final Color infoSoft;

  final Color shimmerBase;
  final Color shimmerHighlight;
  final Color scrim;

  bool get isDark => brightness == Brightness.dark;

  LinearGradient get accentGradient => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF7A3D), Color(0xFFF2481B)],
  );

  LinearGradient get inverseGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: isDark
        ? const [Color(0xFF1C2430), Color(0xFF0E141C)]
        : const [Color(0xFF1B2430), Color(0xFF090D13)],
  );

  /// Health ramp used by inspection reports and the condition gauge.
  Color health(double score) {
    if (score >= 0.75) return success;
    if (score >= 0.45) return warning;
    return danger;
  }
}

class AppColors {
  const AppColors._();

  static const AppPalette light = AppPalette(
    brightness: Brightness.light,
    canvas: Color(0xFFF4F5F8),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFFAFAFC),
    surfaceSunken: Color(0xFFEFF1F5),
    inverse: Color(0xFF0D1117),
    onInverse: Color(0xFFF4F5F8),
    ink: Color(0xFF0D1117),
    inkSoft: Color(0xFF39434F),
    inkMuted: Color(0xFF6B7684),
    inkFaint: Color(0xFF9AA4B1),
    line: Color(0xFFE2E6EC),
    lineSoft: Color(0xFFEDF0F4),
    accent: Color(0xFFFF5F2E),
    accentSoft: Color(0xFFFFEDE5),
    accentInk: Color(0xFFD9410F),
    onAccent: Color(0xFFFFFFFF),
    volt: Color(0xFFC6F24E),
    success: Color(0xFF0FA968),
    successSoft: Color(0xFFE4F7EE),
    warning: Color(0xFFE08A00),
    warningSoft: Color(0xFFFFF3DE),
    danger: Color(0xFFE02A2A),
    dangerSoft: Color(0xFFFDE8E8),
    info: Color(0xFF2F6FED),
    infoSoft: Color(0xFFE8F0FE),
    shimmerBase: Color(0xFFE7EAEF),
    shimmerHighlight: Color(0xFFF6F8FA),
    scrim: Color(0x660D1117),
  );

  static const AppPalette dark = AppPalette(
    brightness: Brightness.dark,
    canvas: Color(0xFF0A0E13),
    surface: Color(0xFF141A22),
    surfaceAlt: Color(0xFF1A222C),
    surfaceSunken: Color(0xFF0F151C),
    inverse: Color(0xFF1A222C),
    onInverse: Color(0xFFF1F4F8),
    ink: Color(0xFFF1F4F8),
    inkSoft: Color(0xFFC3CBD6),
    inkMuted: Color(0xFF8A96A5),
    inkFaint: Color(0xFF5E6B7B),
    line: Color(0xFF242D38),
    lineSoft: Color(0xFF1C242E),
    accent: Color(0xFFFF6B3D),
    accentSoft: Color(0xFF2A1810),
    accentInk: Color(0xFFFF8A5F),
    onAccent: Color(0xFF160800),
    volt: Color(0xFFC6F24E),
    success: Color(0xFF2ECC87),
    successSoft: Color(0xFF0F2620),
    warning: Color(0xFFF5B32B),
    warningSoft: Color(0xFF2A2110),
    danger: Color(0xFFFF5A5A),
    dangerSoft: Color(0xFF2C1315),
    info: Color(0xFF5B92FF),
    infoSoft: Color(0xFF111D33),
    shimmerBase: Color(0xFF1A222C),
    shimmerHighlight: Color(0xFF232D39),
    scrim: Color(0x99000000),
  );

  static AppPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

extension PaletteContextX on BuildContext {
  /// Shorthand: `context.c.accent`
  AppPalette get c => AppColors.of(this);
}
