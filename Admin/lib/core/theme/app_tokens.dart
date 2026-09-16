import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Spacing scale (4pt base).
class Gap {
  const Gap._();
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double h1 = 32;
  static const double h2 = 40;
  static const double h3 = 56;

  /// Standard horizontal page padding.
  static const double page = 20;
}

/// Corner radii.
class R {
  const R._();
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 26;
  static const double xxl = 34;
  static const double pill = 999;

  static BorderRadius all(double v) => BorderRadius.circular(v);
  static const BorderRadius rSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius rMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius rLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius rXl = BorderRadius.all(Radius.circular(xl));
}

/// Motion tokens. Everything in the app animates on one of these.
class Motion {
  const Motion._();
  static const Duration instant = Duration(milliseconds: 120);
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration base = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 520);
  static const Duration lazy = Duration(milliseconds: 800);

  /// Crisp deceleration used for most entrances.
  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve spring = Cubic(0.22, 1.10, 0.36, 1.0);
  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
}

/// Layered, low-opacity elevation. Never the default Material drop shadow.
class Shadows {
  const Shadows._();

  static List<BoxShadow> soft(AppPalette p) => p.isDark
      ? const [
          BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 6)),
        ]
      : const [
          BoxShadow(color: Color(0x0A0D1117), blurRadius: 2, offset: Offset(0, 1)),
          BoxShadow(color: Color(0x0F0D1117), blurRadius: 14, offset: Offset(0, 6)),
        ];

  static List<BoxShadow> lifted(AppPalette p) => p.isDark
      ? const [
          BoxShadow(color: Color(0x4D000000), blurRadius: 28, offset: Offset(0, 12)),
        ]
      : const [
          BoxShadow(color: Color(0x0D0D1117), blurRadius: 4, offset: Offset(0, 2)),
          BoxShadow(color: Color(0x140D1117), blurRadius: 28, offset: Offset(0, 14)),
        ];

  static List<BoxShadow> accent(AppPalette p) => [
        BoxShadow(
          color: p.accent.withValues(alpha: p.isDark ? 0.28 : 0.32),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
      ];
}
