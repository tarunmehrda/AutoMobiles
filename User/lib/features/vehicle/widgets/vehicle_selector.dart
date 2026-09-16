import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/g_badge.dart';
import '../../../core/widgets/g_button.dart';
import '../../../core/widgets/g_feedback.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/models/entities.dart';
import '../../../data/models/enums.dart';
import '../../../data/seed/catalog_seed.dart';
import '../../../state/app_state.dart';
import '../../../state/draft_state.dart';
import '../../../state/providers.dart';
import 'brand_tile.dart';

/// Compact vehicle pill used in the Home header and booking flows.
class VehiclePill extends ConsumerWidget {
  const VehiclePill({super.key, this.onInverse = false});

  final bool onInverse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final vehicle = ref.watch(activeVehicleProvider);
    if (vehicle == null) {
      return GButton.ghost(
        label: 'Add vehicle',
        icon: Icons.add_rounded,
        size: GButtonSize.sm,
        onPressed: () => context.push('/vehicle/add'),
      );
    }

    final brand = Seed.brandByName(vehicle.brand);
    final fg = onInverse ? p.onInverse : p.ink;

    return Pressable(
      onTap: () => showVehicleSelector(context, ref),
      scale: 0.95,
      child: Container(
        padding: const EdgeInsets.fromLTRB(5, 5, Gap.md, 5),
        decoration: BoxDecoration(
          color: onInverse
              ? p.onInverse.withValues(alpha: 0.08)
              : p.surface,
          borderRadius: R.all(R.pill),
          border: Border.all(
              color: onInverse
                  ? p.onInverse.withValues(alpha: 0.12)
                  : p.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (brand != null)
              BrandBadge(brand: brand, size: 26)
            else
              Icon(Icons.directions_car_rounded, size: 20, color: fg),
            const SizedBox(width: Gap.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 130),
              child: Text(
                vehicle.model,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.labelM.c(fg),
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.expand_more_rounded, size: 17, color: fg),
          ],
        ),
      ),
    );
  }
}

Future<void> showVehicleSelector(BuildContext context, WidgetRef ref) {
  return GFeedback.sheet<void>(
    context,
    title: 'Your vehicles',
    subtitle: 'Prices and parts are matched to the selected car',
    child: Consumer(
      builder: (context, ref, _) {
        final p = context.c;
        final vehicles = ref.watch(vehiclesProvider);
        final active = ref.watch(activeVehicleProvider);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
              Gap.page, Gap.lg, Gap.page, Gap.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final v in vehicles) ...[
                VehicleRow(
                  vehicle: v,
                  selected: v.id == active?.id,
                  onTap: () {
                    ref.read(appControllerProvider.notifier).setActiveVehicle(v.id);
                    ref.read(draftProvider.notifier).setVehicle(v.id);
                    Navigator.of(context).pop();
                  },
                ),
                const SizedBox(height: Gap.sm),
              ],
              const SizedBox(height: Gap.sm),
              Pressable(
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/vehicle/add');
                },
                child: Container(
                  padding: const EdgeInsets.all(Gap.lg),
                  decoration: BoxDecoration(
                    borderRadius: R.all(R.lg),
                    border: Border.all(
                        color: p.accent.withValues(alpha: 0.4),
                        style: BorderStyle.solid),
                    color: p.accentSoft,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.add_circle_rounded,
                          color: p.accentInk, size: 22),
                      const SizedBox(width: Gap.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Add another vehicle',
                                style: AppType.labelL.c(p.accentInk)),
                            Text('Keep every car in one garage',
                                style: AppType.bodyS.c(p.accentInk
                                    .withValues(alpha: 0.75))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class VehicleRow extends StatelessWidget {
  const VehicleRow({
    super.key,
    required this.vehicle,
    required this.selected,
    this.onTap,
    this.trailing,
  });

  final Vehicle vehicle;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final brand = Seed.brandByName(vehicle.brand);

    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: AnimatedContainer(
        duration: Motion.fast,
        padding: const EdgeInsets.all(Gap.md),
        decoration: BoxDecoration(
          color: selected ? p.surfaceSunken : p.surface,
          borderRadius: R.all(R.lg),
          border: Border.all(color: selected ? p.ink : p.line),
        ),
        child: Row(
          children: [
            if (brand != null)
              BrandBadge(brand: brand, size: 44)
            else
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                    color: p.surfaceSunken, borderRadius: R.all(R.sm)),
                child: Icon(Icons.directions_car_rounded,
                    color: p.inkMuted, size: 22),
              ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(vehicle.title,
                            style: AppType.h3.c(p.ink),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (vehicle.isPrimary) ...[
                        const SizedBox(width: Gap.sm),
                        const GPill(
                            label: 'PRIMARY', tone: GTone.neutral, compact: true),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      _plate(context, vehicle.regNumber),
                      const SizedBox(width: Gap.sm),
                      Flexible(
                        child: Text(
                          '${vehicle.fuel.label} • ${Fmt.km(vehicle.odometerKm)}',
                          style: AppType.labelS.c(p.inkMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (selected)
              Icon(Icons.check_circle_rounded, color: p.accent, size: 22)
            else
              Icon(Icons.radio_button_unchecked_rounded,
                  color: p.line, size: 22),
          ],
        ),
      ),
    );
  }

  static Widget _plate(BuildContext context, String reg) {
    final p = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: p.surfaceSunken,
        borderRadius: R.all(4),
        border: Border.all(color: p.line),
      ),
      child: Text(reg.toUpperCase(),
          style: AppType.labelS.s(10).c(p.inkSoft).copyWith(letterSpacing: 0.4)),
    );
  }
}
