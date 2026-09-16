import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/anim/entrance.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/decor.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_image.dart';
import '../../core/widgets/g_state.dart';
import '../../core/widgets/g_surface.dart';
import '../../data/models/entities.dart';
import '../../data/models/enums.dart';
import '../../data/seed/catalog_seed.dart';
import '../../data/seed/media.dart';
import '../../state/providers.dart';
import '../history/widgets/booking_card.dart';

class GaragePage extends ConsumerWidget {
  const GaragePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final vehicles = ref.watch(vehiclesProvider);
    final stats = ref.watch(garageStatsProvider);
    final bookings = ref.watch(bookingsProvider);
    final live = bookings.where((b) => b.isLive).toList()
      ..sort((a, b) => a.slot.compareTo(b.slot));
    final past = bookings
        .where((b) => b.status == BookingStatus.completed)
        .toList()
      ..sort((a, b) => b.slot.compareTo(a.slot));

    return Scaffold(
      backgroundColor: p.canvas,
      body: CustomScrollView(
        slivers: [
          GSliverHeader(
            eyebrow: 'Your vehicles & history',
            title: 'My garage',
            actions: [
              GIconButton(
                icon: Icons.add_rounded,
                onTap: () => context.push('/vehicle/add'),
                tooltip: 'Add vehicle',
              ),
            ],
          ),

          // --- lifetime stats ------------------------------------------
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.lg),
              child: Entrance(child: _StatStrip(stats: stats)),
            ),
          ),

          // --- vehicles -------------------------------------------------
          if (vehicles.isEmpty)
            SliverToBoxAdapter(
              child: GEmptyState(
                icon: Icons.directions_car_rounded,
                title: 'No vehicles yet',
                message:
                    'Add your car to get prices matched to its exact engine, '
                    'fuel and gearbox.',
                actionLabel: 'Add a vehicle',
                onAction: () => context.push('/vehicle/add'),
                compact: true,
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: GSectionHeader(
                title: 'Vehicles',
                subtitle: '${vehicles.length} in your garage',
                padding: const EdgeInsets.fromLTRB(
                    Gap.page, Gap.sm, Gap.page, Gap.md),
                actionLabel: 'Add',
                onAction: () => context.push('/vehicle/add'),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.sm),
              sliver: SliverList.separated(
                itemCount: vehicles.length,
                separatorBuilder: (_, _) => const SizedBox(height: Gap.md),
                itemBuilder: (context, i) =>
                    VehicleCard(vehicle: vehicles[i], index: i),
              ),
            ),
          ],

          // --- live jobs ------------------------------------------------
          if (live.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: GSectionHeader(
                eyebrow: 'Happening now',
                title: 'Active bookings',
                actionLabel: 'All bookings',
                onAction: () => context.push('/bookings'),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.page),
              sliver: SliverList.separated(
                itemCount: live.length,
                separatorBuilder: (_, _) => const SizedBox(height: Gap.md),
                itemBuilder: (context, i) =>
                    BookingCard(booking: live[i], index: i),
              ),
            ),
          ],

          // --- history --------------------------------------------------
          SliverToBoxAdapter(
            child: GSectionHeader(
              eyebrow: 'Everything we have done',
              title: 'Service history',
              actionLabel: past.isEmpty ? null : 'See all',
              onAction: () => context.push('/history'),
            ),
          ),
          if (past.isEmpty)
            const SliverToBoxAdapter(
              child: GEmptyState(
                icon: Icons.history_rounded,
                title: 'No completed services yet',
                message:
                    'Once a job is finished it lands here with its invoice, '
                    'parts fitted and warranty.',
                compact: true,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.h3),
              sliver: SliverList.separated(
                itemCount: past.length > 3 ? 3 : past.length,
                separatorBuilder: (_, _) => const SizedBox(height: Gap.md),
                itemBuilder: (context, i) =>
                    BookingCard(booking: past[i], index: i),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatStrip extends StatelessWidget {
  const _StatStrip({required this.stats});

  final GarageStats stats;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
      decoration: BoxDecoration(
        gradient: p.inverseGradient,
        borderRadius: R.all(R.xl),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: BlueprintPainter(
                  color: p.onInverse, spacing: 22, opacity: 0.05),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: Gap.lg, vertical: Gap.xl),
            child: Row(
              children: [
                _stat(context, '${stats.services}', 'Services'),
                _divider(p),
                _stat(context, Fmt.money(stats.spend), 'Spent'),
                _divider(p),
                _stat(context, Fmt.money(stats.saved), 'Saved',
                    highlight: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(AppPalette p) => Container(
        height: 34,
        width: 1,
        color: p.onInverse.withValues(alpha: 0.12),
      );

  Widget _stat(BuildContext context, String value, String label,
      {bool highlight = false}) {
    final p = context.c;
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: AppType.moneyL
                .s(19)
                .c(highlight ? p.volt : p.onInverse),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(label.toUpperCase(),
              style: AppType.over
                  .s(9)
                  .c(p.onInverse.withValues(alpha: 0.5))),
        ],
      ),
    );
  }
}

class VehicleCard extends ConsumerWidget {
  const VehicleCard({super.key, required this.vehicle, this.index = 0});

  final Vehicle vehicle;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final days = vehicle.daysToService;
    final overdue = days <= 0;

    return Entrance(
      index: index,
      stagger: const Duration(milliseconds: 50),
      child: GCard(
        padding: EdgeInsets.zero,
        clip: true,
        onTap: () => context.push('/vehicle/${vehicle.id}'),
        child: Column(
          children: [
            // The car photo sits beside the text rather than behind it — a
            // white car under a scrim made the registration unreadable.
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.md),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // The photo already says which car this is, so the
                            // title gets the full width instead of a badge.
                            Flexible(
                              child: Text(vehicle.title,
                                  style: AppType.h2.c(p.ink),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            if (vehicle.isPrimary) ...[
                              const SizedBox(width: Gap.sm),
                              const GPill(
                                  label: 'PRIMARY',
                                  tone: GTone.neutral,
                                  compact: true),
                            ],
                          ],
                        ),
                        const SizedBox(height: Gap.sm),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: p.surfaceSunken,
                                borderRadius: R.all(4),
                                border: Border.all(color: p.line),
                              ),
                              child: Text(
                                vehicle.regNumber,
                                style: AppType.labelS
                                    .s(10)
                                    .c(p.inkSoft)
                                    .copyWith(letterSpacing: 0.5),
                              ),
                            ),
                            const SizedBox(width: Gap.sm),
                            Flexible(
                              child: Text(
                                '${vehicle.fuel.label} • ${vehicle.year}',
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
                  const SizedBox(width: Gap.md),
                  GImage(
                    url: Media.carPhoto(
                      Seed.modelByName(vehicle.brand, vehicle.model)?.id,
                      body: vehicle.body,
                    ),
                    height: 62,
                    width: 92,
                    radius: R.sm,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _meta(context, Icons.speed_rounded,
                            Fmt.km(vehicle.odometerKm), 'Odometer'),
                      ),
                      Expanded(
                        child: _meta(
                          context,
                          Icons.build_circle_rounded,
                          overdue ? 'Overdue' : 'In $days days',
                          'Next service',
                          tone: overdue ? p.danger : null,
                        ),
                      ),
                      Expanded(
                        child: _meta(
                          context,
                          Icons.verified_user_rounded,
                          vehicle.insuranceExpiry == null
                              ? '—'
                              : Fmt.dateShort(vehicle.insuranceExpiry!),
                          'Insurance',
                          tone: vehicle.insuranceExpiry != null &&
                                  vehicle.insuranceExpiry!
                                      .difference(DateTime.now())
                                      .inDays <
                                      15
                              ? p.warning
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Gap.md),
                  Row(
                    children: [
                      Expanded(
                        child: GButton.accent(
                          label: 'Book service',
                          size: GButtonSize.sm,
                          expand: true,
                          onPressed: () => context.go('/book'),
                        ),
                      ),
                      const SizedBox(width: Gap.sm),
                      Expanded(
                        child: GButton.outline(
                          label: 'History',
                          size: GButtonSize.sm,
                          expand: true,
                          onPressed: () => context.push('/vehicle/${vehicle.id}'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _meta(BuildContext context, IconData icon, String value, String label,
      {Color? tone}) {
    final p = context.c;
    return Column(
      children: [
        Icon(icon, size: 16, color: tone ?? p.inkMuted),
        const SizedBox(height: 4),
        Text(value,
            style: AppType.labelM.s(12).c(tone ?? p.ink),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        Text(label.toUpperCase(), style: AppType.over.s(8.5).c(p.inkFaint)),
      ],
    );
  }
}
