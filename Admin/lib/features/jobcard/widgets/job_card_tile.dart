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
import '../../../data/models/enums.dart';
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
                    Text('${stamp.year}',
                        style: AppType.labelS.s(11).c(p.inkFaint)),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: p.surfaceSunken,
                        borderRadius: R.all(R.pill),
                      ),
                      child: Text(Fmt.time(stamp),
                          style: AppType.labelS.s(9.5).c(p.inkMuted)),
                    ),
                    if (card.paid > 0) ...[
                      const SizedBox(height: 5),
                      Text('Paid ${Fmt.money(card.paid)}',
                          style: AppType.labelS.s(10).c(p.success)),
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
                              Gap.md, Gap.md, Gap.md, Gap.md),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                children: [
                                  GAvatar(
                                    initials:
                                        Fmt.initials(customer?.name ?? '?'),
                                    size: 38,
                                    tone: GTone.neutral,
                                  ),
                                  const SizedBox(height: 5),
                                  Text(card.number,
                                      style:
                                          AppType.labelS.s(9).c(p.inkFaint)),
                                ],
                              ),
                              const SizedBox(width: Gap.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      customer?.name ?? 'Unknown',
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
                                        label:
                                            'Overdue • promised ${Fmt.friendlyDay(card.promisedAt!)}',
                                        tone: GTone.warning,
                                        compact: true,
                                        icon: Icons.schedule_rounded,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: Gap.sm),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('Total',
                                      style: AppType.labelS
                                          .s(10)
                                          .c(p.inkFaint)),
                                  const SizedBox(height: 3),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: Gap.sm, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: p.surfaceSunken,
                                      borderRadius: R.all(R.pill),
                                    ),
                                    child: Text(Fmt.money(card.total),
                                        style: AppType.money.s(15).c(p.ink)),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    card.items.isEmpty
                                        ? 'Not billed'
                                        : 'Due ${Fmt.money(card.balance)}',
                                    style: AppType.labelS.s(10.5).c(
                                        card.settled && card.items.isNotEmpty
                                            ? p.success
                                            : p.danger),
                                  ),
                                ],
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
              child: Text('IND',
                  style: AppType.labelS.s(7.5).c(Colors.white)),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              child: Text(Fmt.plate(reg),
                  style: AppType.labelM.s(12).c(p.ink)),
            ),
          ],
        ),
      ),
    );
  }
}
