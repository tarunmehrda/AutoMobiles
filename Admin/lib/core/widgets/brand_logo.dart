import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_type.dart';

/// Where the Balaji Automobiles artwork lives.
///
/// The mark — the gear with the B inside it — is shipped in two inks cut from
/// one master, so they register pixel-for-pixel and the swap when the theme
/// flips is invisible. [markLight] is the near-black cut for paper coloured
/// surfaces; [markDark] is the amber cut for carbon ones. Nothing ever has to
/// sit inside a white box to stay legible.
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

  /// The two inks the mark ships in, for chrome that has to match it.
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

/// The mark over the wordmark — what the splash and the sign-in sheet wear.
///
/// The artwork is square, so the old horizontal lockup's typography is set
/// here rather than baked into the file: it stays sharp at any size and
/// picks up the Devanagari fallback along with the rest of the app.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, required this.width, this.onDark});

  /// The width of the whole lockup. The mark takes the middle of it, which
  /// keeps the wordmark — the longer of the two — the thing that sets the
  /// overall measure.
  final double width;
  final bool? onDark;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final dark = onDark ?? (p.brightness == Brightness.dark);
    final foreground = dark ? p.onInverse : p.ink;

    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BrandMark(size: width * 0.52, onDark: dark),
          SizedBox(height: width * 0.072),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              AppConfig.appName.toUpperCase(),
              maxLines: 1,
              style: AppType.h1
                  .c(foreground)
                  .copyWith(
                    fontSize: width * 0.108,
                    fontWeight: FontWeight.w800,
                    letterSpacing: width * 0.0125,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The mark on its own tile — for app bars, sheets and list rows.
///
/// The tile follows the theme rather than always being carbon: on paper the
/// mark is inked on a sunken well, on carbon it is amber on the plate. The
/// artwork is laid in with [BoxFit.contain] and an inset, not cropped to
/// fill: the whole mark is the point, and a cover fit ate its teeth.
class BrandBadge extends StatelessWidget {
  const BrandBadge({super.key, this.size = 44, this.onDark});

  final double size;

  /// Forces the carbon cut for badges sitting on an inverse surface, and
  /// adds a hairline rim so the tile still has an edge against it.
  final bool? onDark;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final inverse = onDark ?? false;
    final dark = inverse || p.isDark;
    final tile = dark ? BrandArt.carbon : p.surfaceSunken;

    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: tile,
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
        child: BrandMark(size: size * 0.70, onDark: dark),
      ),
    );
  }
}
