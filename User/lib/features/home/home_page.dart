import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/anim/entrance.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_state.dart';
import '../../core/widgets/pressable.dart';
import '../../data/models/enums.dart';
import '../../data/models/workshop.dart';
import '../../state/app_state.dart';
import '../../state/providers.dart';
import '../vehicle/widgets/vehicle_health_row.dart';
import '../workshop/widgets/booking_details_sheet.dart';
import '../workshop/widgets/workshop_details_sheet.dart';

/// My Garage: the workshop this customer deals with, the car that is in it
/// right now, and the cars that are not. Nothing else — everything a customer
/// needs on any given day is one of those three.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final shop = ref.watch(workshopProvider);
    final live = ref.watch(liveWorkshopCardProvider);
    final vehicles = ref.watch(vehiclesProvider);
    final unread = ref.watch(unreadCountProvider);

    return Scaffold(
      backgroundColor: p.canvas,
      body: RefreshIndicator(
        color: p.accent,
        backgroundColor: p.surface,
        displacement: 70,
        // The spinner going away used to be the only answer, whether or not
        // the workshop was reached — an offline pull looked like "nothing
        // new". `refreshWorkshop` says which it was.
        onRefresh: () async {
          final reached =
              await ref.read(appControllerProvider.notifier).refreshWorkshop();
          if (!reached && context.mounted) {
            GFeedback.error(
                context, "Couldn't reach the workshop. Check your connection.");
          }
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Gap.page, Gap.md, Gap.page, Gap.lg),
                  child: Row(
                    children: [
                      const BrandBadge(size: 34),
                      const SizedBox(width: Gap.md),
                      Expanded(
                        child: Text('My Garage', style: AppType.h1.c(p.ink)),
                      ),
                      Pressable(
                        onTap: () => context.push('/notifications'),
                        scale: 0.9,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(Gap.sm),
                              child: Icon(Icons.notifications_none_rounded,
                                  size: 24, color: p.ink),
                            ),
                            // The count, not just a dot: "3 waiting" and
                            // "something happened" are different messages,
                            // and the app already knows which one it is.
                            if (unread > 0)
                              Positioned(
                                right: 0,
                                top: 1,
                                child: Container(
                                  constraints:
                                      const BoxConstraints(minWidth: 16),
                                  height: 16,
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4),
                                  decoration: BoxDecoration(
                                    color: p.accent,
                                    borderRadius: R.all(R.pill),
                                    border: Border.all(
                                        color: p.canvas, width: 1.6),
                                  ),
                                  child: Text(
                                    unread > 9 ? '9+' : '$unread',
                                    style: AppType.labelS
                                        .s(9)
                                        .c(p.onAccent),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // --- the workshop -----------------------------------------
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.page),
                child: Entrance(
                  child: shop.isLinked
                      ? _PreferredGarage(
                          onServices: () => showWorkshopDetailsSheet(context),
                        )
                      : _NotLinked(
                          onLink: () => context.push('/search'),
                        ),
                ),
              ),
            ),

            // --- what is happening right now --------------------------
            if (live != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Gap.page, Gap.lg, Gap.page, 0),
                  child: Entrance(index: 1, child: _CurrentService(card: live)),
                ),
              ),

            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, 0),
                child: Entrance(
                  index: 2,
                  child: Pressable(
                    // Books with the workshop on the card above. Without the
                    // garage the flow stopped at step 2 and sent the customer
                    // to the directory to find a shop they already have.
                    onTap: () => context.push(shop.isLinked
                        ? '/book?garage=${Uri.encodeComponent(shop.id)}'
                        : '/book'),
                    scale: 0.98,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: Gap.lg),
                      decoration: BoxDecoration(
                        gradient: p.inverseGradient,
                        borderRadius: R.all(R.lg),
                        boxShadow: Shadows.soft(p),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_rounded,
                              size: 20, color: p.onInverse),
                          const SizedBox(width: Gap.sm),
                          Text(
                            live == null
                                ? 'Book a Service'
                                : 'Book Another Service',
                            style: AppType.labelL.c(p.onInverse),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // --- finding a workshop -----------------------------------
            // Secondary to booking on purpose. A customer who already has a
            // workshop books with it; this is for the one who does not, or
            // who is somewhere else today.
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, 0),
                child: Entrance(
                  index: 3,
                  child: Pressable(
                    onTap: () => context.push('/search'),
                    scale: 0.98,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: Gap.lg, horizontal: Gap.lg),
                      decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius: R.all(R.lg),
                        border: Border.all(color: p.line),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.travel_explore_rounded,
                              size: 20, color: p.accentInk),
                          const SizedBox(width: Gap.md),
                          Expanded(
                            child: Text('Find a garage near me',
                                style: AppType.labelM.c(p.ink)),
                          ),
                          Icon(Icons.chevron_right_rounded,
                              size: 20, color: p.inkFaint),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // --- parts ------------------------------------------------
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, 0),
                child: Entrance(
                  index: 4,
                  child: Pressable(
                    onTap: () => context.push('/parts'),
                    scale: 0.98,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: Gap.lg, horizontal: Gap.lg),
                      decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius: R.all(R.lg),
                        border: Border.all(color: p.line),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.settings_outlined,
                              size: 20, color: p.accentInk),
                          const SizedBox(width: Gap.md),
                          Expanded(
                            child: Text('Buy or sell a part',
                                style: AppType.labelM.c(p.ink)),
                          ),
                          Icon(Icons.chevron_right_rounded,
                              size: 20, color: p.inkFaint),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // --- the cars ---------------------------------------------
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    Gap.page, Gap.xxl, Gap.page, Gap.md),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('My Vehicles', style: AppType.h1.c(p.ink)),
                    ),
                    GLink(
                      label: 'All',
                      icon: Icons.arrow_forward_rounded,
                      onTap: () => context.go('/garage'),
                    ),
                  ],
                ),
              ),
            ),
            if (vehicles.isEmpty)
              SliverToBoxAdapter(
                child: GEmptyState(
                  compact: true,
                  icon: Icons.directions_car_outlined,
                  title: 'No vehicle yet',
                  message: 'Add your vehicle and the workshop can open a job '
                      'card against it.',
                  actionLabel: 'Add vehicle',
                  onAction: () => context.push('/vehicle/add'),
                ),
              )
            else
              SliverList.builder(
                itemCount: vehicles.length,
                itemBuilder: (context, i) => Padding(
                  padding:
                      const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.sm),
                  child: Entrance(
                    index: (i + 3).clamp(0, 8),
                    child: VehicleHealthRow(vehicle: vehicles[i]),
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: Gap.h2)),
          ],
        ),
      ),
    );
  }
}

/// The dark card at the top: who looks after this customer's cars.
class _PreferredGarage extends ConsumerWidget {
  const _PreferredGarage({required this.onServices});

  final VoidCallback onServices;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final shop = ref.watch(workshopProvider);
    final vehicles = ref.watch(vehiclesProvider);
    final kinds = <String>{for (final v in vehicles) v.body.label};

    return Pressable(
      onTap: onServices,
      scale: 0.985,
      child: Container(
        padding: const EdgeInsets.all(Gap.lg),
        decoration: BoxDecoration(
          gradient: p.inverseGradient,
          borderRadius: R.all(R.lg),
          boxShadow: Shadows.lifted(p),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: 3),
              decoration:
                  BoxDecoration(color: p.accent, borderRadius: R.all(R.xs)),
              child: Text('MY PREFERRED GARAGE',
                  style: AppType.over.s(9).c(p.onAccent)),
            ),
            const SizedBox(height: Gap.md),
            Row(
              children: [
                Container(
                  height: 44,
                  width: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p.onInverse.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child:
                      Text(shop.initials, style: AppType.labelL.c(p.onInverse)),
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(shop.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.h1.c(p.onInverse)),
                      if (shop.address.isNotEmpty)
                        Row(
                          children: [
                            Icon(Icons.location_on_rounded,
                                size: 13, color: p.accent),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(shop.address,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppType.bodyS.c(
                                      p.onInverse.withValues(alpha: 0.7))),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                // Only claim a rating when the workshop actually has one.
                // A bare star reads as one and says nothing.
                if (shop.rating > 0) ...[
                  Icon(Icons.star_rounded, size: 18, color: p.volt),
                  const SizedBox(width: 3),
                  Text(shop.rating.toStringAsFixed(1),
                      style: AppType.labelM.c(p.onInverse)),
                ],
              ],
            ),
            if (kinds.isNotEmpty) ...[
              const SizedBox(height: Gap.md),
              Wrap(
                spacing: Gap.xs,
                runSpacing: Gap.xs,
                children: [
                  for (final k in kinds)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: Gap.md, vertical: 3),
                      decoration: BoxDecoration(
                        color: p.onInverse.withValues(alpha: 0.1),
                        borderRadius: R.all(R.pill),
                      ),
                      child: Text(k, style: AppType.labelS.c(p.onInverse)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: Gap.md),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('View offered services',
                      style: AppType.labelM
                          .c(p.onInverse.withValues(alpha: 0.75))),
                  Icon(Icons.chevron_right_rounded,
                      size: 18, color: p.onInverse.withValues(alpha: 0.75)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// No workshop linked yet — the one thing that has to happen first.
class _NotLinked extends StatelessWidget {
  const _NotLinked({required this.onLink});

  final VoidCallback onLink;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
      padding: const EdgeInsets.all(Gap.xl),
      decoration: BoxDecoration(
        gradient: p.inverseGradient,
        borderRadius: R.all(R.lg),
        boxShadow: Shadows.lifted(p),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.storefront_rounded, size: 28, color: p.volt),
          const SizedBox(height: Gap.md),
          Text('Find a workshop', style: AppType.h1.c(p.onInverse)),
          const SizedBox(height: 4),
          Text(
            'Search the garages near you and book a slot. From the moment '
            'they take it, every job card they open for your vehicle shows '
            'up here.',
            style: AppType.bodyM.c(p.onInverse.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: Gap.lg),
          GButton.accent(label: 'Find a workshop', onPressed: onLink),
        ],
      ),
    );
  }
}

/// The car that is in the workshop right now.
class _CurrentService extends StatelessWidget {
  const _CurrentService({required this.card});

  final WorkshopCard card;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: R.all(R.lg),
        border: Border.all(color: p.line),
        boxShadow: Shadows.soft(p),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.build_rounded, size: 18, color: p.accent),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text('Current Service', style: AppType.labelL.c(p.ink)),
              ),
              GPill(
                label: card.isComplete ? 'Ready for Delivery' : 'In Process',
                tone: card.isComplete ? GTone.success : GTone.warning,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          Row(
            children: [
              Icon(Icons.directions_car_rounded, size: 16, color: p.inkMuted),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(card.vehicleTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.labelM.c(p.ink)),
              ),
              Text('•  ${Fmt.plate(card.regNo)}',
                  style: AppType.labelM.c(p.accentInk)),
            ],
          ),
          const SizedBox(height: Gap.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.settled
                          ? 'Paid'
                          : (card.isComplete ? 'Amount due' : 'Estimate'),
                      style: AppType.labelS.c(p.inkMuted),
                    ),
                    // One line, shrunk if it has to be: a large bill at a
                    // large font used to break mid-number.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        Fmt.money(card.settled ? card.total : card.balance),
                        maxLines: 1,
                        style: AppType.moneyL.s(22).c(
                            card.settled ? p.success : p.accentInk),
                      ),
                    ),
                  ],
                ),
              ),
              GButton.accent(
                label: card.isComplete ? 'View Invoice' : 'View Details',
                size: GButtonSize.md,
                expand: false,
                onPressed: () => showBookingDetailsSheet(context, card),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
