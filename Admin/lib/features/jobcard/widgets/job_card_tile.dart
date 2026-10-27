import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/g_badge.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/vehicle_art.dart';
import '../../../data/models/entities.dart';
import '../../../data/models/enums.dart';
import '../../../data/seed/vehicle_media.dart';
import '../../../state/providers.dart';

/// A job card as it reads in a list: when it happened down the left, who and
/// what in the middle, and where the money stands on the right.
class JobCardTile extends ConsumerWidget {
  const JobCardTile({
    super.key,
    required this.card,
    this.stampStatus,
    this.showDateColumn = true,
  });

  final JobCard card;

  /// Which timestamp to show — defaults to the card's own status.
  final JobStatus? stampStatus;
  final bool showDateColumn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final customer = ref.watch(customerProvider(card.customerId));
    final vehicle = ref.watch(vehicleProvider(card.vehicleId));
    final stamp = card.stampFor(stampStatus ?? card.status);
    // A mechanic's list is the work, not the takings.
    final cost = ref.watch(accessProvider).seesCost;

    // The rail reads at a glance: red means money is still owed, amber means
    // it is running late, green means done and settled.
    final rail = card.items.isNotEmpty && !card.settled
        ? p.danger
        : card.overdue
        ? p.warning
        : card.isOpen
        ? p.accent
        : p.success;

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showDateColumn) ...[
            SizedBox(
              width: 66,
              child: Padding(
                padding: const EdgeInsets.only(top: Gap.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(Fmt.dateShort(stamp), style: AppType.h3.c(p.ink)),
                    Text(
                      '${stamp.year}',
                      style: AppType.labelS.s(11).c(p.inkFaint),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: p.surfaceSunken,
                        borderRadius: R.all(R.pill),
                      ),
                      child: Text(
                        Fmt.time(stamp),
                        style: AppType.labelS.s(9.5).c(p.inkMuted),
                      ),
                    ),
                    if (cost && card.paid > 0) ...[
                      const SizedBox(height: 5),
                      Text(
                        'Paid {0}'.trf([Fmt.money(card.paid)]),
                        style: AppType.labelS.s(10).c(p.success),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: Gap.sm),
          ],
          Expanded(
            child: Pressable(
              onTap: () => context.push('/job/${card.id}'),
              scale: 0.985,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: R.all(R.md),
                  border: Border.all(color: p.line),
                  boxShadow: Shadows.soft(p),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(width: 4, color: rail),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            Gap.md,
                            Gap.md,
                            Gap.md,
                            Gap.md,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Who over what: the owner's initials, then
                              // the vehicle, then the card number. Scanning a
                              // day's list for "the silver Swift" is how the
                              // counter actually looks for a card, and the
                              // plate two columns over only helps once you
                              // are already reading the right row.
                              // Held to the picture's width: a long card
                              // number used to widen this column to a third
                              // of the card and squeeze the name.
                              SizedBox(
                                width: 56,
                                child: Column(
                                  children: [
                                    GAvatar(
                                      initials: Fmt.initials(
                                        customer?.name ?? '?',
                                      ),
                                      size: 38,
                                      tone: GTone.neutral,
                                    ),
                                    const SizedBox(height: 4),
                                    ClipRRect(
                                      borderRadius: R.all(R.xs),
                                      child: Container(
                                        width: 44,
                                        height: 28,
                                        color: p.surfaceSunken,
                                        child: VehicleArt(
                                          shape:
                                              vehicle?.shape ??
                                              VehicleShape.fourWheeler,
                                          photo: VehicleMedia.photoFor(
                                            vehicle?.brand,
                                            vehicle?.model,
                                            vehicle?.shape ??
                                                VehicleShape.fourWheeler,
                                          ),
                                          height: 28,
                                          tint: p.inkFaint,
                                          // A list scrolls. Tracing a drawing
                                          // on every row that comes into view
                                          // is motion nobody asked for, and it
                                          // replays each time the row recycles.
                                          animate: false,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        card.number,
                                        maxLines: 1,
                                        style: AppType.labelS.s(9).c(p.inkFaint),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: Gap.md),
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      customer?.name ?? 'Unknown'.tr,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppType.h2.c(p.ink),
                                    ),
                                    Text(
                                      vehicle?.title ?? '—',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppType.bodyS.c(p.inkMuted),
                                    ),
                                    const SizedBox(height: Gap.sm),
                                    _Plate(reg: vehicle?.regNo ?? '—'),
                                    if (card.overdue) ...[
                                      const SizedBox(height: Gap.sm),
                                      GPill(
                                        label: 'Overdue • promised {0}'.trf([
                                          Fmt.friendlyDay(card.promisedAt!),
                                        ]),
                                        tone: GTone.warning,
                                        compact: true,
                                        icon: Icons.schedule_rounded,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (cost) const SizedBox(width: Gap.sm),
                              // Capped, and at most two fifths of the row, so
                              // a big bill shrinks its figures instead of
                              // squeezing the name to nothing.
                              if (cost)
                                Flexible(
                                  flex: 2,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 116,
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'Total'.tr,
                                          style: AppType.labelS.s(10).c(p.inkFaint),
                                        ),
                                        const SizedBox(height: 3),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: Gap.sm,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: p.surfaceSunken,
                                            borderRadius: R.all(R.pill),
                                          ),
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              Fmt.money(card.total),
                                              style: AppType.money.s(15).c(p.ink),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          card.items.isEmpty
                                              ? 'Not billed'.tr
                                              : 'Due {0}'.trf([
                                                  Fmt.money(card.balance),
                                                ]),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppType.labelS
                                              .s(10.5)
                                              .c(
                                                card.settled &&
                                                        card.items.isNotEmpty
                                                    ? p.success
                                                    : p.danger,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Indian number plate: blue country flash, then the registration.
class _Plate extends StatelessWidget {
  const _Plate({required this.reg});

  final String reg;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: R.all(R.xs),
        border: Border.all(color: p.line),
      ),
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: const Color(0xFF2F6FED),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              child: Text('IND', style: AppType.labelS.s(7.5).c(Colors.white)),
            ),
            // A long registration shortens rather than running off the
            // right edge of the card.
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Text(
                  Fmt.plate(reg),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.labelM.s(12).c(p.ink),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
