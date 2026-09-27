import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/g_badge.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/models/entities.dart';
import '../../../data/seed/catalog_seed.dart';
import 'brand_tile.dart';

/// One vehicle as it reads on Home: what it is, whether it is due, and how
/// far it has run since the workshop last saw it.
class VehicleHealthRow extends ConsumerWidget {
  const VehicleHealthRow({super.key, required this.vehicle, this.onTap});

  final Vehicle vehicle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final brand = Seed.brandByName(vehicle.brand);
    // With no service on record `daysToService` counts from today, so every
    // such car read "On Track, due in 182 days" — a countdown to a date
    // nobody gave us. Say it is not set instead.
    final known = vehicle.lastServiceDate != null;
    final days = vehicle.daysToService;
    final overdue = known && days < 0;
    final soon = known && days >= 0 && days <= 14;

    return Pressable(
      onTap: onTap ?? () => context.push('/vehicle/${vehicle.id}'),
      scale: 0.985,
      child: Container(
        padding: const EdgeInsets.all(Gap.lg),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: R.all(R.md),
          border: Border.all(color: p.line),
          boxShadow: Shadows.soft(p),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // The car's own mark, rather than the same grey glyph on
                // every row: a garage list is read by shape first.
                if (brand != null) ...[
                  BrandBadge(brand: brand, size: 42),
                  const SizedBox(width: Gap.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(vehicle.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.labelL.c(p.ink)),
                      Text(Fmt.plate(vehicle.regNumber),
                          style: AppType.bodyS.c(p.inkMuted)),
                    ],
                  ),
                ),
                GPill(
                  label: !known
                      ? 'Not set'
                      : (overdue
                          ? 'Overdue'
                          : (soon ? 'Due soon' : 'On Track')),
                  tone: !known
                      ? GTone.neutral
                      : (overdue
                          ? GTone.danger
                          : (soon ? GTone.warning : GTone.success)),
                  compact: true,
                ),
              ],
            ),
            const SizedBox(height: Gap.md),
            Row(
              children: [
                Expanded(
                  child: _Stat(
                    label: 'Due In',
                    value: !known
                        ? 'Not set'
                        : (overdue ? '${-days} days ago' : '$days days'),
                    tint: !known
                        ? p.inkMuted
                        : (overdue ? p.danger : p.ink),
                  ),
                ),
                Expanded(
                  child: _Stat(
                    label: 'Kilometers',
                    value: vehicle.odometerKm == 0
                        ? '0 / No KM Reminder'
                        : Fmt.km(vehicle.odometerKm),
                    tint: p.ink,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.tint,
  });

  final String label;
  final String value;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppType.labelS.c(p.inkMuted)),
        const SizedBox(height: 2),
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.labelL.c(tint)),
      ],
    );
  }
}
