import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/anim/entrance.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_state.dart';
import '../../core/widgets/pressable.dart';
import '../../data/models/entities.dart';
import '../../data/models/enums.dart';
import '../../data/seed/catalog_seed.dart';
import '../../state/providers.dart';
import 'widgets/brand_tile.dart';

/// Every vehicle this customer keeps, with the one thing they do from here:
/// book it in.
class GaragePage extends ConsumerWidget {
  const GaragePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final vehicles = ref.watch(vehiclesProvider);

    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Gap.page, Gap.md, Gap.page, Gap.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('My Vehicles', style: AppType.d2.c(p.ink)),
                        Text('Manage your vehicles and service schedules',
                            style: AppType.bodyS.c(p.inkMuted)),
                      ],
                    ),
                  ),
                  const SizedBox(width: Gap.sm),
                  GButton.accent(
                    label: 'Add Vehicle',
                    size: GButtonSize.sm,
                    icon: Icons.add_rounded,
                    expand: false,
                    onPressed: () => context.push('/vehicle/add'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: vehicles.isEmpty
                  ? GEmptyState(
                      icon: Icons.directions_car_outlined,
                      title: 'No vehicles yet',
                      message: 'Add a vehicle and the workshop can open a job '
                          'card against it.',
                      actionLabel: 'Add vehicle',
                      onAction: () => context.push('/vehicle/add'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                          Gap.page, 0, Gap.page, Gap.h2),
                      itemCount: vehicles.length,
                      itemBuilder: (context, i) => Entrance(
                        index: i.clamp(0, 8),
                        child: _VehicleRow(vehicle: vehicles[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleRow extends StatelessWidget {
  const _VehicleRow({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final brand = Seed.brandByName(vehicle.brand);
    return Pressable(
      onTap: () => context.push('/vehicle/${vehicle.id}'),
      scale: 0.985,
      child: Container(
        margin: const EdgeInsets.only(bottom: Gap.sm),
        padding: const EdgeInsets.all(Gap.lg),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: R.all(R.md),
          border: Border.all(color: p.line),
          boxShadow: Shadows.soft(p),
        ),
        child: Row(
          children: [
            // The car's own mark. BrandBadge falls back to a tinted
            // monogram, so a brand we ship no logo for still looks
            // deliberate rather than unfinished.
            if (brand != null)
              BrandBadge(brand: brand, size: 48)
            else
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: p.surfaceSunken,
                  borderRadius: R.all(R.sm),
                ),
                child: Icon(Icons.directions_car_rounded,
                    size: 24, color: p.inkMuted),
              ),
            const SizedBox(width: Gap.md),
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
                  const SizedBox(height: Gap.sm),
                  GTag(
                    label: vehicle.body.label.toUpperCase(),
                    outlined: true,
                    tone: GTone.neutral,
                  ),
                ],
              ),
            ),
            const SizedBox(width: Gap.sm),
            GButton(
              label: 'Book',
              kind: GButtonKind.outline,
              size: GButtonSize.sm,
              icon: Icons.calendar_month_rounded,
              expand: false,
              onPressed: () => context.push('/book?vehicle=${vehicle.id}'),
            ),
          ],
        ),
      ),
    );
  }
}
