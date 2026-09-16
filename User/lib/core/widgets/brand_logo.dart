import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// Where the Balaji Automobiles artwork lives.
///
/// The same lockup is shipped in two cuts — the original ink for paper
/// coloured surfaces and a white-ink recolour for carbon ones — so the mark
/// never has to sit inside a white box to stay legible. [badge] is the square
/// cut used for launcher icons: the tagline rule is dropped from it because it
/// turns to mush below about 64px.
class BrandArt {
  const BrandArt._();

  static const String lockup = 'assets/logo/logo.png';
  static const String lockupOnDark = 'assets/logo/logo_on_dark.png';
  static const String badge = 'assets/logo/icon.png';

  /// The carbon the badge is cut on. Matches the native launch background so
  /// the handoff from the OS splash to the Flutter one is seamless.
  static const Color carbon = Color(0xFF101215);

  /// Aspect ratio of [lockup], so a width is enough to lay it out.
  static const double lockupAspect = 1142 / 490;
}

/// The full horizontal lockup — car, wordmark, "AUTOMOBILES" and the rule.
///
/// Picks its own cut from the surface it is on: pass [onDark] for inverse
/// surfaces, otherwise it follows the theme's brightness.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, required this.width, this.onDark});

  final double width;
  final bool? onDark;

  @override
  Widget build(BuildContext context) {
    final dark = onDark ?? (context.c.brightness == Brightness.dark);
    return Image.asset(
      dark ? BrandArt.lockupOnDark : BrandArt.lockup,
      width: width,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
  }
}

/// The square badge — the app icon, for app bars, sheets and list rows.
class BrandBadge extends StatelessWidget {
  const BrandBadge({super.key, this.size = 44, this.onDark = false});

  final double size;

  /// Adds a hairline rim so the carbon badge still has an edge when it sits
  /// on an inverse surface that is nearly the same colour.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: BrandArt.carbon,
        borderRadius: R.all(size * 0.28),
        border: onDark
            ? Border.all(color: p.onInverse.withValues(alpha: 0.14), width: 1)
            : null,
        boxShadow: onDark
            ? null
            : [
                BoxShadow(
                  color: BrandArt.carbon.withValues(alpha: 0.22),
                  blurRadius: size * 0.34,
                  offset: Offset(0, size * 0.12),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        BrandArt.badge,
        height: size,
        width: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}
