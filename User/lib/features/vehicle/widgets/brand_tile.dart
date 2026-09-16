import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/models/entities.dart';
import '../../../data/seed/media.dart';

/// Brand mark on a tinted plate. Uses the real logo where we ship one and
/// falls back to a monogram, so an unknown brand still looks deliberate.
class BrandBadge extends StatelessWidget {
  const BrandBadge({
    super.key,
    required this.brand,
    this.size = 48,
    this.inverted = false,
  });

  final VehicleBrand brand;
  final double size;

  /// Solid brand-coloured plate with a white mark, for dark surfaces.
  final bool inverted;

  String get _initials {
    final words = brand.name.split(RegExp(r'[\s-]+'));
    if (words.length == 1) {
      return brand.name.substring(0, brand.name.length >= 2 ? 2 : 1);
    }
    return '${words[0][0]}${words[1][0]}';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final tint =
        p.isDark ? Color.lerp(brand.color, Colors.white, 0.35)! : brand.color;
    final markColor = inverted ? Colors.white : tint;
    final logo = Media.logoFor(brand.id);

    Widget mark;
    if (logo == null) {
      mark = Text(
        _initials.toUpperCase(),
        style: AppType.h3.s(size * 0.34).c(markColor).w(FontWeight.w700),
      );
    } else if (Media.isVector(logo)) {
      mark = SvgPicture.asset(
        logo,
        width: size * 0.52,
        height: size * 0.52,
        colorFilter: ColorFilter.mode(markColor, BlendMode.srcIn),
        placeholderBuilder: (_) => const SizedBox.shrink(),
      );
    } else {
      mark = ClipRRect(
        borderRadius: R.all(4),
        child: Image.asset(
          logo,
          width: size * 0.56,
          height: size * 0.56,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, _, _) => Text(
            _initials.toUpperCase(),
            style: AppType.h3.s(size * 0.34).c(markColor),
          ),
        ),
      );
    }

    return Container(
      height: size,
      width: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: inverted
            ? tint
            : tint.withValues(alpha: p.isDark ? 0.16 : 0.09),
        borderRadius: R.all(size * 0.3),
        border: Border.all(color: tint.withValues(alpha: 0.22)),
      ),
      child: mark,
    );
  }
}

class BrandTile extends StatelessWidget {
  const BrandTile({
    super.key,
    required this.brand,
    required this.onTap,
    this.selected = false,
  });

  final VehicleBrand brand;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Pressable(
      onTap: onTap,
      scale: 0.95,
      child: AnimatedContainer(
        duration: Motion.fast,
        curve: Motion.enter,
        padding: const EdgeInsets.all(Gap.md),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: R.all(R.lg),
          border: Border.all(
              color: selected ? p.accent : p.line,
              width: selected ? 1.6 : 1),
          boxShadow: Shadows.soft(p),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            BrandBadge(brand: brand, size: 46),
            const SizedBox(height: Gap.sm),
            Text(
              brand.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppType.labelS.s(11).c(p.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}
