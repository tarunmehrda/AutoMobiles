import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/i18n/strings.dart';
import '../../data/models/enums.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_type.dart';
import 'vehicle_art.dart';

/// The vehicle, as one object on the screen.
///
/// Before this, a vehicle was three lines of text with a generic car glyph
/// beside them, repeated slightly differently on the job card header, the
/// customer page and the create form. A workshop identifies a vehicle by its
/// plate and by looking at it, in that order, so the card leads with the
/// picture and puts the plate on top of it at a size that can be read across
/// a counter.
///
/// Two shapes, because there are two jobs:
///
/// * [GVehicleCard] — the full card. The picture is the card, the plate and
///   the model sit on it, and the marque's badge sits in the corner. This is
///   what goes above a job card and what the create form shows the moment
///   there is enough typed to draw something.
/// * [GVehicleCard.compact] — a list row. The same picture as a thumbnail at
///   the left, details beside it. This is what a customer's vehicle list and
///   any other list of vehicles is made of.
///
/// Both take plain values rather than a `Vehicle`, so the create form — which
/// has no saved vehicle yet, only four half-filled text controllers — can
/// show exactly the same card as the screens that do.
class GVehicleCard extends StatelessWidget {
  const GVehicleCard({
    super.key,
    required this.plate,
    required this.title,
    required this.shape,
    this.photo,
    this.logo,
    this.subtitle,
    this.badge,
    this.trailing,
    this.onTap,
    this.height = 158,
    this.animate = true,
  }) : compact = false;

  const GVehicleCard.compact({
    super.key,
    required this.plate,
    required this.title,
    required this.shape,
    this.photo,
    this.logo,
    this.subtitle,
    this.badge,
    this.trailing,
    this.onTap,
    this.animate = true,
  }) : compact = true,
       height = 78;

  /// The registration, already formatted. Shown as given.
  final String plate;

  /// `Maruti Suzuki Swift VXi` — make, model and trim on one line.
  final String title;

  final VehicleShape shape;

  /// A bundled photograph of the model, or null to draw the body instead.
  final String? photo;

  /// The marque's mark, `.svg` or a raster. Null where none is bundled.
  final String? logo;

  /// Under the title: the fuel, the year, whatever the screen wants there.
  final String? subtitle;

  /// A short word over the picture, top right — a status, a count of visits.
  final Widget? badge;

  /// The action at the right of a compact row.
  final Widget? trailing;

  final VoidCallback? onTap;

  final double height;
  final bool compact;

  /// Off for print and for goldens.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final card = compact ? _compact(context) : _full(context);
    if (onTap == null) return card;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: card,
    );
  }

  // --- the full card -------------------------------------------------------

  Widget _full(BuildContext context) {
    final p = context.c;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: R.rLg,
        border: Border.all(color: p.line),
        boxShadow: Shadows.soft(p),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              // A drawing needs something to sit on or it floats in white; a
              // photograph fills the box and covers this entirely.
              Container(
                height: height,
                color: photo == null ? p.surfaceSunken : p.surfaceAlt,
              ),
              Positioned.fill(
                child: VehicleArt(
                  shape: shape,
                  photo: photo,
                  height: height,
                  animate: animate,
                  tint: p.inkMuted,
                ),
              ),
              if (logo != null)
                Positioned(
                  top: Gap.md,
                  left: Gap.md,
                  child: _LogoChip(asset: logo!),
                ),
              if (badge != null)
                Positioned(top: Gap.md, right: Gap.md, child: badge!),
              // The plate goes on the picture rather than under it. On a
              // photograph it is the only thing that says which car this is.
              Positioned(
                left: Gap.lg,
                right: Gap.lg,
                bottom: Gap.md,
                child: _Plate(plate: plate, onPhoto: photo != null),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.md),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.trim().isEmpty ? 'Vehicle'.tr : title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.labelL.c(p.ink),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty)
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.bodyS.c(p.inkMuted),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: Gap.md),
                  trailing!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- the list row --------------------------------------------------------

  Widget _compact(BuildContext context) {
    final p = context.c;

    return Container(
      padding: const EdgeInsets.all(Gap.sm),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: R.rMd,
        border: Border.all(color: p.line),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: R.all(R.sm),
            child: Container(
              width: 86,
              height: 62,
              color: photo == null ? p.surfaceSunken : p.surfaceAlt,
              child: VehicleArt(
                shape: shape,
                photo: photo,
                height: 62,
                animate: animate,
                tint: p.inkMuted,
              ),
            ),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        plate,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.labelL.c(p.ink),
                      ),
                    ),
                    if (logo != null) ...[
                      const SizedBox(width: Gap.sm),
                      GMarqueLogo(asset: logo!, size: 15),
                    ],
                  ],
                ),
                Text(
                  title.trim().isEmpty ? 'Vehicle'.tr : title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.bodyS.c(p.inkSoft),
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.labelS.c(p.inkFaint),
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: Gap.sm), trailing!],
        ],
      ),
    );
  }
}

/// The registration, set the way a plate is set.
///
/// Over a photograph it needs its own ground — white type on an unknown
/// picture is a gamble — so it gets a dark slab. Over a drawing the card's
/// own surface is already the right colour and a slab would only add a box
/// inside a box.
class _Plate extends StatelessWidget {
  const _Plate({required this.plate, required this.onPhoto});

  final String plate;
  final bool onPhoto;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    if (plate.trim().isEmpty) return const SizedBox.shrink();

    final text = Text(
      plate,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppType.h3
          .s(17)
          .c(onPhoto ? Colors.white : p.ink)
          .copyWith(letterSpacing: 1.1),
    );

    if (!onPhoto) return text;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: R.all(R.xs),
          border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
        ),
        child: text,
      ),
    );
  }
}

/// The marque's mark on a light disc, so a dark logo still reads on a dark
/// photograph and a light one still reads on a pale drawing.
class _LogoChip extends StatelessWidget {
  const _LogoChip({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: GMarqueLogo(
        asset: asset,
        size: 20,
        color: const Color(0xFF14181F),
      ),
    );
  }
}

/// One marque mark, vector or raster. Public because the catalogue picker
/// puts the same badge beside every row it offers.
///
/// The set is mostly single-colour SVG, which is why [color] can tint them;
/// the one raster in it ignores the tint, which is correct — it is a full
/// colour badge and recolouring it would ruin it.
class GMarqueLogo extends StatelessWidget {
  const GMarqueLogo({
    super.key,
    required this.asset,
    required this.size,
    this.color,
  });

  final String asset;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final tint = color ?? p.inkSoft;

    if (!asset.endsWith('.svg')) {
      return Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => SizedBox(width: size, height: size),
      );
    }

    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
      placeholderBuilder: (_) => SizedBox(width: size, height: size),
    );
  }
}
