import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// Network image that degrades gracefully: a tinted gradient with a glyph
/// while loading and if the fetch fails, so the layout never collapses or
/// shows a broken-image box when the device is offline.
class GImage extends StatelessWidget {
  const GImage({
    super.key,
    required this.url,
    this.height,
    this.width,
    this.radius = R.md,
    this.fit = BoxFit.cover,
    this.fallbackIcon = Icons.directions_car_rounded,
    this.tint,
  });

  final String? url;
  final double? height;
  final double? width;
  final double radius;
  final BoxFit fit;
  final IconData fallbackIcon;
  final Color? tint;

  Widget _fallback(BuildContext context, {bool shimmer = false}) {
    final p = context.c;
    final base = tint ?? p.accent;
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        borderRadius: R.all(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            base.withValues(alpha: p.isDark ? 0.22 : 0.13),
            base.withValues(alpha: p.isDark ? 0.06 : 0.04),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          fallbackIcon,
          color: base.withValues(alpha: shimmer ? 0.25 : 0.45),
          size: ((height ?? 60) * 0.34).clamp(16, 44),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) return _fallback(context);

    // Bundled photography goes through the same widget so every image in the
    // app shares one radius, fade and fallback behaviour.
    if (url!.startsWith('assets/')) {
      return ClipRRect(
        borderRadius: R.all(radius),
        child: Image.asset(
          url!,
          height: height,
          width: width,
          fit: fit,
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, _, _) => _fallback(context),
        ),
      );
    }

    return ClipRRect(
      borderRadius: R.all(radius),
      child: CachedNetworkImage(
        imageUrl: url!,
        height: height,
        width: width,
        fit: fit,
        fadeInDuration: Motion.base,
        placeholder: (context, _) => _fallback(context, shimmer: true),
        errorWidget: (context, _, _) => _fallback(context),
      ),
    );
  }
}
