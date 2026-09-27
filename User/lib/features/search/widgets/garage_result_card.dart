import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/models/directory.dart';

/// One garage in the search results.
///
/// The distance is the loudest thing on the row after the name, because it
/// is the only reason this list is ordered the way it is. When there is no
/// distance — a PIN search, or a workshop that has not dropped its pin — the
/// space is simply empty rather than filled with a dash the customer has to
/// decode.
class GarageResultCard extends StatelessWidget {
  const GarageResultCard({super.key, required this.garage, this.onTap});

  final NearbyGarage garage;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final km = garage.distanceLabel;

    return Pressable(
      onTap: onTap,
      borderRadius: R.rLg,
      child: Container(
        padding: const EdgeInsets.all(Gap.lg),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: R.rLg,
          border: Border.all(color: p.line),
          boxShadow: Shadows.soft(p),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Avatar(garage: garage),
            const SizedBox(width: Gap.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          garage.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.h3.c(p.ink),
                        ),
                      ),
                      if (garage.verified) ...[
                        const SizedBox(width: Gap.xs),
                        Icon(Icons.verified_rounded,
                            size: 16, color: p.accentInk),
                      ],
                    ],
                  ),
                  if (garage.where.isNotEmpty) ...[
                    const SizedBox(height: Gap.xxs),
                    Text(
                      garage.where,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.bodyS.c(p.inkMuted),
                    ),
                  ],
                ],
              ),
            ),
            if (km.isNotEmpty) ...[
              const SizedBox(width: Gap.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(km, style: AppType.labelL.c(p.accentInk)),
                  const SizedBox(height: Gap.xxs),
                  Text('away', style: AppType.labelS.c(p.inkFaint)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.garage});

  final NearbyGarage garage;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
      height: 46,
      width: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: p.accentSoft,
        borderRadius: R.rMd,
        border: Border.all(color: p.accent.withValues(alpha: 0.18)),
      ),
      child: Text(garage.initials, style: AppType.labelL.c(p.accentInk)),
    );
  }
}
