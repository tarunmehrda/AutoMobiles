import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/anim/entrance.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_field.dart';
import '../../core/widgets/g_image.dart';
import '../../core/widgets/g_state.dart';
import '../../core/widgets/g_surface.dart';
import '../../data/models/enums.dart';
import '../../data/seed/catalog_seed.dart';
import '../../data/seed/media.dart';
import '../../data/models/workshop.dart';
import '../../state/app_state.dart';
import '../../state/providers.dart';
import '../../core/widgets/pressable.dart';
import '../workshop/widgets/booking_details_sheet.dart';
import 'widgets/brand_tile.dart';

class VehicleDetailPage extends ConsumerWidget {
  const VehicleDetailPage({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final data = ref.watch(appControllerProvider);
    final vehicle = data.vehicleById(vehicleId);

    if (vehicle == null) {
      return Scaffold(
        backgroundColor: p.canvas,
        appBar: const GHeader(title: 'Vehicle'),
        body: GEmptyState(
          icon: Icons.directions_car_rounded,
          title: 'Vehicle removed',
          message: 'This vehicle is no longer in your garage.',
          actionLabel: 'My garage',
          onAction: () => context.go('/garage'),
        ),
      );
    }

    final brand = Seed.brandByName(vehicle.brand);
    // History is what the workshop actually did to this car, not what the
    // customer once asked for, so it reads off the job cards.
    final history = ref
        .watch(workshopCardsProvider)
        .where((c) =>
            c.regNo.replaceAll(' ', '').toUpperCase() ==
            vehicle.regNumber.replaceAll(' ', '').toUpperCase())
        .toList();
    final days = vehicle.daysToService;
    // No service on record means no due date either — `daysToService` would
    // count from today and promise one "in 182 days" out of nothing.
    final serviceKnown = vehicle.lastServiceDate != null;
    final overdue = serviceKnown && days <= 0;

    return Scaffold(
      backgroundColor: p.canvas,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 216,
            pinned: true,
            backgroundColor: p.canvas,
            surfaceTintColor: Colors.transparent,
            leading: Padding(
              padding: const EdgeInsets.all(Gap.sm),
              child: GIconButton(
                icon: Icons.arrow_back_rounded,
                size: 40,
                background: p.surface.withValues(alpha: 0.92),
                onTap: () => context.pop(),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.all(Gap.sm),
                child: GIconButton(
                  icon: Icons.more_vert_rounded,
                  size: 40,
                  background: p.surface.withValues(alpha: 0.92),
                  onTap: () => _menu(context, ref, vehicle.id, vehicle.isPrimary),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  GImage(
                    url: Media.carPhoto(
                      Seed.modelByName(vehicle.brand, vehicle.model)?.id,
                      body: vehicle.body,
                    ),
                    radius: 0,
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.25),
                          Colors.black.withValues(alpha: 0.8),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: Gap.page,
                    right: Gap.page,
                    bottom: Gap.xl,
                    child: Row(
                      children: [
                        if (brand != null)
                          BrandBadge(brand: brand, size: 48, inverted: true),
                        const SizedBox(width: Gap.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(vehicle.title,
                                  style: AppType.d3.c(Colors.white),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 3),
                              Text(
                                '${vehicle.regNumber}  •  ${vehicle.specLine}',
                                style: AppType.labelM.c(
                                    Colors.white.withValues(alpha: 0.8)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // --- next service -----------------------------------
                Entrance(
                  child: GCard(
                    child: Row(
                      children: [
                        Container(
                          height: 44,
                          width: 44,
                          decoration: BoxDecoration(
                            color: overdue ? p.dangerSoft : p.accentSoft,
                            borderRadius: R.all(R.sm),
                          ),
                          child: Icon(Icons.build_circle_rounded,
                              size: 22,
                              color: overdue ? p.danger : p.accentInk),
                        ),
                        const SizedBox(width: Gap.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                !serviceKnown
                                    ? 'Next service: not set'
                                    : (overdue
                                        ? 'Service overdue by ${-days} days'
                                        : 'Next service in $days days'),
                                style: AppType.labelL.c(p.ink),
                              ),
                              Text(
                                vehicle.lastServiceDate == null
                                    ? 'No service recorded yet'
                                    : 'Last done ${Fmt.date(vehicle.lastServiceDate!)}'
                                        '${vehicle.lastServiceKm == null ? '' : ' at ${Fmt.km(vehicle.lastServiceKm!)}'}',
                                style: AppType.bodyS.c(p.inkMuted),
                              ),
                            ],
                          ),
                        ),
                        GButton.accent(
                          label: 'Book',
                          size: GButtonSize.sm,
                          expand: false,
                          // Pushed, not gone to: `go` would leave booking
                          // as the only route, so its back arrow would have
                          // nothing to pop and Android back would quit the
                          // app. The car is passed along because the
                          // customer already chose it by opening this page.
                          onPressed: () =>
                              context.push('/book?vehicle=${vehicle.id}'),
                        ),
                      ],
                    ),
                  ),
                ),

                // --- specs -------------------------------------------
                const SizedBox(height: Gap.xl),
                Text('Specification', style: AppType.h1.c(p.ink)),
                const SizedBox(height: Gap.md),
                Entrance(
                  index: 1,
                  child: GCard(
                    child: Column(
                      children: [
                        _spec(context, 'Brand', vehicle.brand),
                        _spec(context, 'Model', vehicle.model),
                        if (vehicle.variant != null)
                          _spec(context, 'Variant', vehicle.variant!),
                        _spec(context, 'Body type', vehicle.body.label),
                        _spec(context, 'Fuel', vehicle.fuel.label),
                        _spec(
                            context, 'Transmission', vehicle.transmission.label),
                        _spec(context, 'Year', '${vehicle.year}'),
                        _spec(context, 'Registration', vehicle.regNumber),
                        if (vehicle.vin != null)
                          _spec(context, 'VIN / chassis', vehicle.vin!),
                      ],
                    ),
                  ),
                ),

                // --- odometer ----------------------------------------
                const SizedBox(height: Gap.xl),
                Entrance(
                  index: 2,
                  child: GCard(
                    onTap: () => _updateOdometer(context, ref, vehicle.id,
                        vehicle.odometerKm),
                    child: Row(
                      children: [
                        Icon(Icons.speed_rounded, size: 20, color: p.inkMuted),
                        const SizedBox(width: Gap.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Odometer',
                                  style: AppType.labelM.c(p.inkMuted)),
                              Text(Fmt.km(vehicle.odometerKm),
                                  style: AppType.money.c(p.ink)),
                            ],
                          ),
                        ),
                        Text('Update', style: AppType.labelM.c(p.accentInk)),
                      ],
                    ),
                  ),
                ),

                // --- documents ---------------------------------------
                const SizedBox(height: Gap.xl),
                Text('Documents', style: AppType.h1.c(p.ink)),
                const SizedBox(height: Gap.md),
                Entrance(
                  index: 3,
                  child: Row(
                    children: [
                      Expanded(
                        child: _DocCard(
                          label: 'Insurance',
                          icon: Icons.verified_user_rounded,
                          expiry: vehicle.insuranceExpiry,
                        ),
                      ),
                      const SizedBox(width: Gap.md),
                      Expanded(
                        child: _DocCard(
                          label: 'PUC',
                          icon: Icons.eco_rounded,
                          expiry: vehicle.pucExpiry,
                        ),
                      ),
                    ],
                  ),
                ),

                // --- history -----------------------------------------
                const SizedBox(height: Gap.xl),
                Row(
                  children: [
                    Text('Service history', style: AppType.h1.c(p.ink)),
                    const Spacer(),
                    Text('${history.length} visits',
                        style: AppType.labelM.c(p.inkMuted)),
                  ],
                ),
                const SizedBox(height: Gap.md),
                if (history.isEmpty)
                  const GEmptyState(
                    icon: Icons.history_rounded,
                    title: 'No history yet',
                    message: 'Completed services will be listed here.',
                    compact: true,
                  )
                else
                  for (var i = 0; i < history.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Gap.md),
                      child: Entrance(
                        index: i.clamp(0, 8),
                        child: _HistoryRow(card: history[i]),
                      ),
                    ),
                const SizedBox(height: Gap.h2),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _spec(BuildContext context, String label, String value) {
    final p = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label, style: AppType.bodyM.c(p.inkMuted)),
          const Spacer(),
          Text(value, style: AppType.labelM.c(p.ink)),
        ],
      ),
    );
  }

  void _menu(
      BuildContext context, WidgetRef ref, String id, bool isPrimary) {
    GFeedback.sheet<void>(
      context,
      title: 'Vehicle options',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.h1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GTile(
              title: 'Edit details',
              subtitle: 'Registration, fuel, variant and more',
              icon: Icons.edit_rounded,
              onTap: () {
                Navigator.of(context).pop();
                context.push('/vehicle/add?edit=$id');
              },
            ),
            if (!isPrimary)
              GTile(
                title: 'Set as primary',
                subtitle: 'Used by default when booking',
                icon: Icons.star_rounded,
                onTap: () {
                  ref.read(appControllerProvider.notifier).setPrimaryVehicle(id);
                  Navigator.of(context).pop();
                  GFeedback.success(context, 'Primary vehicle updated');
                },
              ),
            GTile(
              title: 'Remove vehicle',
              subtitle: 'Service history is kept for your records',
              icon: Icons.delete_outline_rounded,
              iconColor: context.c.danger,
              onTap: () async {
                Navigator.of(context).pop();
                final ok = await GFeedback.confirm(
                  context,
                  title: 'Remove this vehicle?',
                  message:
                      'It disappears from your garage, but completed jobs and '
                      'invoices stay in your history.',
                  confirmLabel: 'Remove',
                  destructive: true,
                  icon: Icons.delete_outline_rounded,
                );
                if (!ok || !context.mounted) return;
                ref.read(appControllerProvider.notifier).removeVehicle(id);
                context.go('/garage');
                GFeedback.info(context, 'Vehicle removed');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateOdometer(
      BuildContext context, WidgetRef ref, String id, int current) async {
    final controller = TextEditingController(text: '$current');
    final value = await GFeedback.sheet<int>(
      context,
      title: 'Update odometer',
      subtitle: 'Keeps your service reminders accurate',
      child: Padding(
        padding: EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page,
            Gap.h1 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GField(
              label: 'Current reading',
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              suffix: Text('km',
                  style: AppType.labelM.c(context.c.inkMuted)),
            ),
            const SizedBox(height: Gap.xl),
            GButton.accent(
              label: 'Save',
              onPressed: () => Navigator.of(context)
                  .pop(int.tryParse(controller.text) ?? current),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (value == null || !context.mounted) return;
    ref.read(appControllerProvider.notifier).updateOdometer(id, value);
    GFeedback.success(context, 'Odometer updated');
  }
}

class _DocCard extends StatelessWidget {
  const _DocCard({
    required this.label,
    required this.icon,
    required this.expiry,
  });

  final String label;
  final IconData icon;
  final DateTime? expiry;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final days = expiry?.difference(DateTime.now()).inDays;
    final tone = days == null
        ? GTone.neutral
        : (days < 0
            ? GTone.danger
            : (days < 30 ? GTone.warning : GTone.success));
    final t = toneOf(context, tone);

    return GCard(
      padding: const EdgeInsets.all(Gap.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: t.fg),
              const Spacer(),
              GPill(
                label: days == null
                    ? 'Not set'
                    : (days < 0 ? 'Expired' : '$days days'),
                tone: tone,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          Text(label, style: AppType.labelL.c(p.ink)),
          Text(
            expiry == null ? 'Add the expiry date' : Fmt.date(expiry!),
            style: AppType.bodyS.c(p.inkMuted),
          ),
        ],
      ),
    );
  }
}

/// One past visit, as the workshop wrote it up.
class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.card});

  final WorkshopCard card;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Pressable(
      onTap: () => showBookingDetailsSheet(context, card),
      scale: 0.985,
      child: Container(
        padding: const EdgeInsets.all(Gap.lg),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: R.all(R.md),
          border: Border.all(color: p.line),
          boxShadow: Shadows.soft(p),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.items.isEmpty
                        ? (card.voices.isEmpty
                            ? card.number
                            : card.voices.first)
                        : card.items.first.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.labelL.c(p.ink),
                  ),
                  Text('${card.number}  ·  ${Fmt.date(card.openedAt)}',
                      style: AppType.bodyS.c(p.inkMuted)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(Fmt.money(card.total), style: AppType.money.c(p.ink)),
                const SizedBox(height: 4),
                GPill(
                  label: card.isClosed ? 'Completed' : 'In workshop',
                  tone: card.isClosed ? GTone.success : GTone.warning,
                  compact: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
