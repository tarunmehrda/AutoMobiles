import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// Where the Balaji Automobiles artwork lives.
///
/// Kept in step with the console's `Admin/lib/core/widgets/brand_logo.dart`:
/// the two apps are one product to the person holding the phone, so they wear
/// the same mark cut from the same master.
///
/// The mark is the full Balaji Automobiles emblem — gear, car and wordmark in
/// one piece — and is used exactly as supplied, never recoloured. It was drawn
/// for a dark ground, so [markLight] and [markDark] are the same file; the two
/// slots stay so a future cut per theme needs no code change.
///
/// [badge] is the same mark pre-composited on its carbon tile, for the places
/// that need one flat file — the store listings and generated PDFs.
class BrandArt {
  const BrandArt._();

  static const String markLight = 'assets/logo/mark_light.png';
  static const String markDark = 'assets/logo/mark_dark.png';
  static const String badge = 'assets/logo/icon.png';

  /// The carbon the mark is cut on. Matches the native launch background so
  /// the handoff from the OS splash to the Flutter one is seamless.
  static const Color carbon = Color(0xFF101215);

  /// The old mark's two inks, still the accent chrome is built around.
  static const Color amber = Color(0xFFFCBB01);
  static const Color ink = Color(0xFF171919);

  /// Which cut belongs on a surface of the given brightness.
  static String markFor({required bool onDark}) =>
      onDark ? markDark : markLight;

  /// The artwork ships well above the size it is usually painted at, so it
  /// stays crisp on a 3x panel. Every use asks the codec for the pixels it
  /// will actually paint and no more, rather than decoding the master.
  static int decodeWidth(BuildContext context, double width) =>
      (width * MediaQuery.devicePixelRatioOf(context)).round();
}

/// The bare mark on whatever is behind it.
///
/// Picks its own cut from the surface it sits on: pass [onDark] for inverse
/// surfaces, otherwise it follows the theme's brightness.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 44, this.onDark});

  final double size;
  final bool? onDark;

  @override
  Widget build(BuildContext context) {
    final dark = onDark ?? (context.c.brightness == Brightness.dark);
    return Image.asset(
      BrandArt.markFor(onDark: dark),
      height: size,
      width: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      cacheWidth: BrandArt.decodeWidth(context, size),
    );
  }
}

/// The lockup the splash and the sign-in sheet wear.
///
/// The artwork carries the name itself, so this is the mark at the full
/// [width] — no wordmark set in type underneath, which would say it twice.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, required this.width, this.onDark});

  final double width;
  final bool? onDark;

  @override
  Widget build(BuildContext context) => BrandMark(size: width, onDark: onDark);
}

/// The mark on its own tile — for app bars, sheets and list rows.
///
/// The tile is always the carbon plate, in either theme: the mark's white
/// wordmark and car line vanish on a paper well. The artwork is laid in with
/// [BoxFit.contain] and an inset, not cropped to fill: the whole mark is the
/// point.
class BrandBadge extends StatelessWidget {
  const BrandBadge({super.key, this.size = 44, this.onDark});

  final double size;

  /// For badges sitting on an inverse surface: adds a hairline rim so the
  /// tile still has an edge against it.
  final bool? onDark;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final inverse = onDark ?? false;
    final dark = inverse || p.isDark;

    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: BrandArt.carbon,
        borderRadius: R.all(size * 0.28),
        border: inverse
            ? Border.all(color: p.onInverse.withValues(alpha: 0.14), width: 1)
            : Border.all(color: p.line, width: 1),
        boxShadow: inverse
            ? null
            : [
                BoxShadow(
                  color: BrandArt.carbon.withValues(alpha: dark ? 0.34 : 0.10),
                  blurRadius: size * 0.34,
                  offset: Offset(0, size * 0.12),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(size * 0.15),
        child: BrandMark(size: size * 0.70, onDark: true),
      ),
    );
  }
}
