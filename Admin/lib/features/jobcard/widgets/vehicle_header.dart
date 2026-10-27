import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/g_badge.dart';
import '../../../core/widgets/g_feedback.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/vehicle_art.dart';
import '../../../data/models/entities.dart';
import '../../../data/models/enums.dart';
import '../../../data/seed/vehicle_media.dart';
import '../../../state/providers.dart';
import '../../shared/support_sheet.dart';

/// Who and what, pinned above the document. Tapping the number opens the
/// three things the counter actually does with it.
class VehicleHeader extends ConsumerWidget {
  const VehicleHeader({super.key, required this.card, this.onEdit});

  final JobCard card;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final customer = ref.watch(customerProvider(card.customerId));
    final vehicle = ref.watch(vehicleProvider(card.vehicleId));
    final history = ref.watch(historyProvider(card.id));

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(bottom: BorderSide(color: p.line)),
      ),
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              // The vehicle, not a glyph of one. This strip is pinned above
              // everything on the card, so it is the picture the counter
              // works under all day; a generic car outline over a customer's
              // bike is the one thing it must not be.
              ClipRRect(
                borderRadius: R.all(R.sm),
                child: Container(
                  height: 54,
                  width: 76,
                  color: p.surfaceSunken,
                  child: VehicleArt(
                    shape: vehicle?.shape ?? VehicleShape.fourWheeler,
                    photo: VehicleMedia.photoFor(
                      vehicle?.brand,
                      vehicle?.model,
                      vehicle?.shape ?? VehicleShape.fourWheeler,
                    ),
                    height: 54,
                    tint: p.inkFaint,
                  ),
                ),
              ),
              if (history.isNotEmpty) ...[
                const SizedBox(height: 4),
                Pressable(
                  onTap: () => _showHistory(context, ref, history),
                  child: Text(
                    'Last history'.tr,
                    style: AppType.labelS.s(9.5).c(p.accentInk),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer?.name ?? 'Unknown'.tr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.d3.c(p.ink),
                ),
                Text(
                  Fmt.plate(vehicle?.regNo ?? '—'),
                  style: AppType.labelM.c(p.inkSoft),
                ),
                Text(
                  [
                    if (vehicle != null) ...[
                      vehicle.title,
                      vehicle.fuel.label,
                      if (vehicle.transmission != null)
                        vehicle.transmission!.label,
                    ],
                  ].where((e) => e.trim().isNotEmpty).join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.bodyS.c(p.inkMuted),
                ),
                const SizedBox(height: 2),
                Pressable(
                  onTap: customer == null
                      ? null
                      : () => _contactSheet(
                          context,
                          customer,
                          whatsapp: ref.read(adminDataProvider).whatsappEnabled,
                        ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          customer?.phone ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.labelM.c(p.accentInk),
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(
                        Icons.expand_more_rounded,
                        size: 15,
                        color: p.accentInk,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GPill(
                label: card.status.label,
                tone: switch (card.status.name) {
                  'open' => GTone.accent,
                  'complete' => GTone.info,
                  _ => GTone.success,
                },
                compact: true,
              ),
              const SizedBox(height: Gap.sm),
              if (onEdit != null)
                Pressable(
                  onTap: onEdit,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_rounded, size: 14, color: p.accentInk),
                      const SizedBox(width: 3),
                      Text('Edit'.tr, style: AppType.labelM.c(p.accentInk)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Call, WhatsApp or text the customer. WhatsApp is offered only while
  /// it is switched on under Settings → Options; that switch used to be
  /// saved and then read by nothing.
  void _contactSheet(
    BuildContext context,
    Customer customer, {
    required bool whatsapp,
  }) {
    GFeedback.sheet<void>(
      context,
      title: customer.name,
      subtitle: customer.phone,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.h1),
        child: Column(
          children: [
            GOptionRow(
              label: 'Call {0}'.trf([customer.phone]),
              icon: Icons.call_rounded,
              selected: false,
              onTap: () {
                Navigator.of(context).pop();
                launchDial(context, customer.phone);
              },
            ),
            if (whatsapp)
              GOptionRow(
                label: 'WhatsApp {0}'.trf([customer.phone]),
                icon: Icons.chat_rounded,
                selected: false,
                onTap: () {
                  Navigator.of(context).pop();
                  launchWhatsApp(context, customer.phone);
                },
              ),
            GOptionRow(
              label: 'Send an SMS'.tr,
              icon: Icons.sms_rounded,
              selected: false,
              onTap: () {
                Navigator.of(context).pop();
                launchSms(context, customer.phone);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showHistory(
    BuildContext context,
    WidgetRef ref,
    List<JobCard> history,
  ) {
    final cost = ref.read(accessProvider).seesCost;
    GFeedback.sheet<void>(
      context,
      title: 'Previous visits'.tr,
      subtitle: '{0} on this vehicle'.trf([history.length]),
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.h1),
        itemCount: history.length,
        itemBuilder: (context, i) {
          final h = history[i];
          final p = context.c;
          return Pressable(
            onTap: () {
              Navigator.of(context).pop();
              context.push('/job/${h.id}');
            },
            scale: 0.98,
            child: Container(
              margin: const EdgeInsets.only(bottom: Gap.sm),
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.lg,
                vertical: Gap.md,
              ),
              decoration: BoxDecoration(
                color: p.surfaceAlt,
                borderRadius: R.all(R.md),
                border: Border.all(color: p.line),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(h.number, style: AppType.labelL.c(p.ink)),
                        Text(
                          '${Fmt.date(h.createdAt)} • ${Fmt.km(h.odometerKm)}',
                          style: AppType.bodyS.c(p.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  if (cost)
                    Text(Fmt.money(h.total), style: AppType.money.c(p.ink)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
