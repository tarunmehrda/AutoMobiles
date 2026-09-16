import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/anim/entrance.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/g_badge.dart';
import '../../../core/widgets/g_surface.dart';
import '../../../data/models/entities.dart';
import '../../../data/models/enums.dart';
import '../../../state/app_state.dart';
import '../../../state/providers.dart';

class BookingCard extends ConsumerWidget {
  const BookingCard({
    super.key,
    required this.booking,
    this.index = 0,
    this.showVehicle = true,
  });

  final Booking booking;
  final int index;
  final bool showVehicle;

  GTone get _tone => switch (booking.status) {
        BookingStatus.upcoming => GTone.info,
        BookingStatus.active => GTone.accent,
        BookingStatus.completed => GTone.success,
        BookingStatus.cancelled => GTone.danger,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final vehicle = ref.watch(appControllerProvider).vehicleById(booking.vehicleId);
    final invoice = ref.watch(invoiceProvider(booking.id));
    final cancelled = booking.status == BookingStatus.cancelled;

    return Entrance(
      index: index,
      stagger: const Duration(milliseconds: 45),
      child: GCard(
        padding: EdgeInsets.zero,
        onTap: () => context.push('/booking/${booking.id}'),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.md),
              child: Row(
                children: [
                  Flexible(
                    child: GPill(
                      label: booking.status == BookingStatus.active
                          ? booking.stage.label
                          : booking.status.label,
                      tone: _tone,
                      compact: true,
                      dot: booking.status == BookingStatus.active,
                      pulse: booking.status == BookingStatus.active,
                    ),
                  ),
                  const SizedBox(width: Gap.sm),
                  Flexible(
                    child: Text(booking.code,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: AppType.labelS.c(p.inkFaint)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 44,
                        width: 44,
                        decoration: BoxDecoration(
                          color: p.surfaceSunken,
                          borderRadius: R.all(R.sm),
                        ),
                        child: Icon(
                          cancelled
                              ? Icons.cancel_rounded
                              : booking.stage.icon,
                          size: 21,
                          color: cancelled ? p.danger : p.inkSoft,
                        ),
                      ),
                      const SizedBox(width: Gap.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              booking.lines.isEmpty
                                  ? 'Service'
                                  : booking.lines.first.name,
                              style: AppType.h3.c(p.ink),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (booking.lines.length > 1)
                              Text(
                                '+ ${booking.lines.length - 1} more service${booking.lines.length == 2 ? '' : 's'}',
                                style: AppType.bodyS.c(p.inkMuted),
                              ),
                            if (showVehicle && vehicle != null) ...[
                              const SizedBox(height: 3),
                              Text(
                                '${vehicle.title} • ${vehicle.regNumber}',
                                style: AppType.labelS.c(p.inkFaint),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            Fmt.money(invoice?.total ?? booking.total),
                            style: AppType.money.c(p.ink),
                          ),
                          if (invoice != null)
                            Text(
                              invoice.paid ? 'Paid' : 'Due',
                              style: AppType.labelS.c(
                                  invoice.paid ? p.success : p.warning),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: Gap.md),
                  Divider(height: 1, color: p.lineSoft),
                  const SizedBox(height: Gap.md),
                  Row(
                    children: [
                      Icon(Icons.event_rounded, size: 14, color: p.inkFaint),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          '${Fmt.dateShort(booking.slot)} • ${Fmt.time(booking.slot)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.labelS.c(p.inkMuted),
                        ),
                      ),
                      const SizedBox(width: Gap.md),
                      Icon(booking.mode.icon, size: 14, color: p.inkFaint),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          booking.mode.label,
                          style: AppType.labelS.c(p.inkMuted),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Spacer(),
                      if (booking.rating != null) ...[
                        Icon(Icons.star_rounded, size: 14, color: p.warning),
                        const SizedBox(width: 2),
                        Text('${booking.rating}',
                            style: AppType.labelS.c(p.inkSoft)),
                      ] else
                        Icon(Icons.chevron_right_rounded,
                            size: 18, color: p.inkFaint),
                    ],
                  ),
                ],
              ),
            ),
            if (booking.needsApproval)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: Gap.lg, vertical: Gap.sm),
                color: p.accent.withValues(alpha: p.isDark ? 0.14 : 0.08),
                child: Row(
                  children: [
                    Icon(Icons.pan_tool_alt_rounded,
                        size: 14, color: p.accentInk),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('Estimate waiting for your approval',
                          style: AppType.labelS.c(p.accentInk)),
                    ),
                    Text('Review', style: AppType.labelS.c(p.accentInk)),
                  ],
                ),
              ),
            if (invoice != null && !invoice.paid)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: Gap.lg, vertical: Gap.sm),
                color: p.warning.withValues(alpha: p.isDark ? 0.14 : 0.1),
                child: Row(
                  children: [
                    Icon(Icons.account_balance_wallet_rounded,
                        size: 14, color: p.warning),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                          '${Fmt.money(invoice.total)} pending payment',
                          style: AppType.labelS.c(p.warning)),
                    ),
                    Text('Pay now', style: AppType.labelS.c(p.warning)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
