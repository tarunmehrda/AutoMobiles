import 'package:flutter/material.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_badge.dart';
import '../../data/models/entities.dart';
import '../../data/models/enums.dart';
import '../../data/seed/vehicle_catalog.dart';

/// The car and the visit, as the customer described them in their app.
///
/// This used to be one line — "Maruti Suzuki Swift" and the plate — because
/// that was all a booking carried. The gearbox, fuel, year and odometer the
/// customer had typed never reached the counter. Each now gets its own
/// place, and whatever a booking does not carry (one from an older app) is
/// simply left out rather than shown as a blank.
///
/// Shared by the Bookings list and the new-card form, so the counter reads
/// the same booking the same way on both.
class BookingDetails extends StatelessWidget {
  const BookingDetails({super.key, required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final b = booking;
    final named = b.brandModel(VehicleCatalog.models.keys);
    final title = [
      named.brand,
      named.model,
      b.variant,
    ].where((e) => e.trim().isNotEmpty).join(' ');
    final specs = [
      if (b.fuel != null) b.fuel!.label,
      if (b.transmission != null) b.transmission!.label,
      if (b.year != null && b.year! > 0) '${b.year}',
      if (b.odometerKm != null && b.odometerKm! > 0) Fmt.km(b.odometerKm!),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty || b.regNo.isNotEmpty)
          Text(
            [
              if (title.isNotEmpty) title,
              if (b.regNo.isNotEmpty) Fmt.plate(b.regNo),
            ].join('  •  '),
            style: AppType.labelM.c(p.ink),
          ),
        if (specs.isNotEmpty) ...[
          const SizedBox(height: Gap.xs),
          Wrap(
            spacing: Gap.xs,
            runSpacing: Gap.xs,
            children: [
              for (final s in specs)
                GPill(label: s, tone: GTone.neutral, compact: true),
            ],
          ),
        ],
        const SizedBox(height: Gap.xs),
        Text(
          [
            'Slot: {0}'.trf([Fmt.fullDateTime(b.at)]),
            if (b.pickup) 'Pick & drop'.tr,
          ].join('  •  '),
          style: AppType.bodyS.c(b.pickup ? p.accentInk : p.inkMuted),
        ),
        if (b.note.isNotEmpty)
          Text(
            'Services: {0}'.trf([b.note]),
            style: AppType.bodyS.c(p.inkSoft),
          ),
        if (b.customerNote.isNotEmpty)
          Text(
            '“${b.customerNote}”',
            style: AppType.bodyS.c(p.inkSoft).copyWith(
              fontStyle: FontStyle.italic,
            ),
          ),
      ],
    );
  }
}
