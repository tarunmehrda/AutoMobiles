import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'g_state.dart';

/// A photograph fetched over the network, with somewhere to stand while it
/// loads and somewhere to stand if it never arrives.
///
/// Flutter's [Image.network] already caches decoded frames in memory and
/// already reports progress; what it does not do is have an opinion about
/// what the hole looks like in the meantime. Three states, and the screen is
/// the same size in all of them:
///
/// * **loading** — a shimmering block, the same one the rest of the app uses
///   for content that is on its way;
/// * **loaded** — the photograph, faded in rather than snapped in, because a
///   list where pictures pop in one by one reads as jitter;
/// * **failed or absent** — a tinted glyph on a soft wash, which is a
///   deliberate-looking tile rather than a broken one.
///
/// The failure path is not an edge case here. Catalogue photography is
/// fetched from the open web, so it is missing on a dead connection, missing
/// on a metered one the customer has throttled, and missing for every part
/// whose name nothing in the keyword map recognises. A caller passes
/// [url] as null for that last case and gets the same tile.
class GNetImage extends StatelessWidget {
  const GNetImage({
    super.key,
    required this.url,
    required this.fallbackIcon,
    this.fit = BoxFit.cover,
    this.radius = R.md,
    this.tint,
    this.height,
    this.width,
  });

  final String? url;

  /// Drawn when there is no picture. Give it the row's own icon — the kind's
  /// glyph, or the part family's — so the tile still says what it is.
  final IconData fallbackIcon;

  final BoxFit fit;
  final double radius;

  /// Colour of the fallback glyph, and of the wash behind it. Defaults to
  /// the page accent.
  final Color? tint;

  final double? height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final colour = tint ?? p.accent;

    Widget wrap(Widget child) => ClipRRect(
      borderRadius: R.all(radius),
      child: SizedBox(height: height, width: width, child: child),
    );

    if (url == null || url!.isEmpty) return wrap(_fallback(p, colour));

    return wrap(
      Image.network(
        url!,
        headers: AppConfig.imageHeaders,
        fit: fit,
        // Decode to roughly the box rather than to the source's own pixels.
        // A 500px catalogue thumbnail drawn into a 64pt tile is 60x the
        // bitmap the screen can show, and a gridful of them is what puts a
        // mid-range phone into an image-cache thrash.
        cacheHeight: height == null ? null : (height! * 3).round(),
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : GSkeletonGroup(child: Container(color: p.shimmerBase)),
        frameBuilder: (context, child, frame, wasSync) => wasSync
            ? child
            : AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: Motion.base,
                curve: Motion.enter,
                child: child,
              ),
        errorBuilder: (context, _, _) => _fallback(p, colour),
      ),
    );
  }

  Widget _fallback(AppPalette p, Color colour) => Container(
    color: colour.withValues(alpha: p.isDark ? 0.16 : 0.10),
    alignment: Alignment.center,
    child: LayoutBuilder(
      // The glyph is sized off the tile, so the same widget works as a
      // 40pt row thumbnail and as a 160pt grid cover.
      builder: (context, box) => Icon(
        fallbackIcon,
        size: (box.biggest.shortestSide * 0.38).clamp(14.0, 56.0),
        color: colour.withValues(alpha: 0.75),
      ),
    ),
  );
}
