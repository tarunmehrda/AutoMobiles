import 'package:flutter/material.dart';

/// Typography — Sora for display/numerals, Inter for reading text.
class AppType {
  const AppType._();

  static const String display = 'Sora';
  static const String body = 'Inter';

  /// Sora's subset has no rupee sign, so every display/numeral style falls
  /// back to Inter for glyphs it is missing.
  static const List<String> _fallback = [body];

  static const TextStyle d1 = TextStyle(
      fontFamily: display,
      fontFamilyFallback: _fallback, fontSize: 34, fontWeight: FontWeight.w800, height: 1.12, letterSpacing: -1.0);
  static const TextStyle d2 = TextStyle(
      fontFamily: display,
      fontFamilyFallback: _fallback, fontSize: 28, fontWeight: FontWeight.w700, height: 1.16, letterSpacing: -0.7);
  static const TextStyle d3 = TextStyle(
      fontFamily: display,
      fontFamilyFallback: _fallback, fontSize: 23, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: -0.5);
  static const TextStyle h1 = TextStyle(
      fontFamily: display,
      fontFamilyFallback: _fallback, fontSize: 19, fontWeight: FontWeight.w700, height: 1.25, letterSpacing: -0.35);
  static const TextStyle h2 = TextStyle(
      fontFamily: display,
      fontFamilyFallback: _fallback, fontSize: 16, fontWeight: FontWeight.w600, height: 1.3, letterSpacing: -0.2);
  static const TextStyle h3 = TextStyle(
      fontFamily: display,
      fontFamilyFallback: _fallback, fontSize: 14, fontWeight: FontWeight.w600, height: 1.3, letterSpacing: -0.1);

  static const TextStyle bodyL = TextStyle(
      fontFamily: body, fontSize: 15.5, fontWeight: FontWeight.w400, height: 1.5, letterSpacing: -0.1);
  static const TextStyle bodyM = TextStyle(
      fontFamily: body, fontSize: 14, fontWeight: FontWeight.w400, height: 1.48, letterSpacing: -0.05);
  static const TextStyle bodyS = TextStyle(
      fontFamily: body, fontSize: 12.5, fontWeight: FontWeight.w400, height: 1.42);

  static const TextStyle labelL = TextStyle(
      fontFamily: body, fontSize: 14.5, fontWeight: FontWeight.w600, height: 1.2, letterSpacing: -0.1);
  static const TextStyle labelM = TextStyle(
      fontFamily: body, fontSize: 13, fontWeight: FontWeight.w600, height: 1.2);
  static const TextStyle labelS = TextStyle(
      fontFamily: body, fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.2);

  /// Small all-caps eyebrow used above sections.
  static const TextStyle over = TextStyle(
      fontFamily: body, fontSize: 10.5, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: 1.1);

  /// Tabular numerals for money and counters.
  static const TextStyle money = TextStyle(
      fontFamily: display,
      fontFamilyFallback: _fallback,
      fontSize: 17,
      fontWeight: FontWeight.w700,
      height: 1.2,
      letterSpacing: -0.4,
      fontFeatures: [FontFeature.tabularFigures()]);
  static const TextStyle moneyL = TextStyle(
      fontFamily: display,
      fontFamilyFallback: _fallback,
      fontSize: 26,
      fontWeight: FontWeight.w800,
      height: 1.1,
      letterSpacing: -0.9,
      fontFeatures: [FontFeature.tabularFigures()]);
  static const TextStyle moneyS = TextStyle(
      fontFamily: display,
      fontFamilyFallback: _fallback,
      fontSize: 13.5,
      fontWeight: FontWeight.w600,
      height: 1.2,
      fontFeatures: [FontFeature.tabularFigures()]);
}

extension TextStyleX on TextStyle {
  TextStyle c(Color color) => copyWith(color: color);
  TextStyle w(FontWeight weight) => copyWith(fontWeight: weight);
  TextStyle s(double size) => copyWith(fontSize: size);
}
