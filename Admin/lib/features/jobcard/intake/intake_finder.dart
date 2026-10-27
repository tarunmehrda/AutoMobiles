import 'package:flutter/material.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/models/entities.dart';
import '../../../data/repo/admin_data.dart';

/// One row the intake search turned up: a vehicle on record (which brings
/// its owner with it), or a customer on their own.
typedef IntakeHit = ({Vehicle? vehicle, Customer? customer});

/// The most rows the search shows. Past this the counter should be typing
/// one more character, not scrolling.
const _kMaxHits = 6;

String _squash(String s) =>
    s.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();

/// Customers and vehicles on record that match what the counter typed.
///
/// One box for all three, because at the counter the customer offers
/// whichever they have to hand — a name, a number, or the plate on the key
/// fob — and making the counter first decide which kind of search this is
/// was a decision that slowed every card.
///
/// Vehicles come first: a plate is the most specific thing anyone can type,
/// and picking one fills the customer as well.
List<IntakeHit> findIntake(AdminData data, String query) {
  final q = query.trim().toLowerCase();
  if (q.length < 2) return const [];
  final plate = _squash(q);
  final digits = q.replaceAll(RegExp(r'[^0-9]'), '');
  final hits = <IntakeHit>[];

  if (plate.length >= 2) {
    for (final v in data.vehicles) {
      if (_squash(v.regNo).contains(plate)) {
        hits.add((vehicle: v, customer: data.customerById(v.customerId)));
      }
    }
  }
  for (final c in data.customers) {
    final byName = c.name.toLowerCase().contains(q);
    // Three digits before a number counts: fewer matches half the book.
    final byPhone = digits.length >= 3 && c.phone.contains(digits);
    if (byName || byPhone) hits.add((vehicle: null, customer: c));
  }
  return hits.take(_kMaxHits).toList();
}

/// Whether what was typed could be a registration number — letters and
/// digits both, long enough to be one — so the search can offer to carry it
/// to the vehicle step even when nothing on record matches.
bool looksLikePlate(String query) {
  final s = _squash(query);
  return s.length >= 4 &&
      s.contains(RegExp(r'[A-Z]')) &&
      s.contains(RegExp(r'[0-9]'));
}

/// The results under the search box.
class IntakeResults extends StatelessWidget {
  const IntakeResults({
    super.key,
    required this.data,
    required this.query,
    required this.onVehicle,
    required this.onCustomer,
    required this.onPlate,
  });

  final AdminData data;
  final String query;
  final ValueChanged<Vehicle> onVehicle;
  final ValueChanged<Customer> onCustomer;

  /// A plate nobody has on record, carried to the vehicle step as typed.
  final ValueChanged<String> onPlate;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final hits = findIntake(data, query);
    final exactPlate = data.vehicleByReg(query) != null;
    final offerPlate = !exactPlate && looksLikePlate(query);

    if (hits.isEmpty && !offerPlate) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.sm),
        child: Row(
          children: [
            Icon(Icons.person_add_alt_1_rounded, size: 16, color: p.inkFaint),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Text(
                'Nobody on record matches. Fill in the details below — a new customer is saved with the card.'
                    .tr,
                style: AppType.bodyS.c(p.inkMuted),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: R.all(R.md),
        border: Border.all(color: p.line),
        boxShadow: Shadows.soft(p),
      ),
      child: Column(
        children: [
          for (final h in hits)
            if (h.vehicle case final v?)
              _Row(
                icon: Icons.directions_car_filled_rounded,
                tint: p.accent,
                title: Fmt.plate(v.regNo),
                subtitle: [
                  h.customer?.name ?? '',
                  '${v.brand} ${v.model}'.trim(),
                ].where((e) => e.isNotEmpty).join(' · '),
                onTap: () => onVehicle(v),
              )
            else if (h.customer case final c?)
              _Row(
                icon: Icons.person_rounded,
                tint: p.success,
                title: c.name.isEmpty ? 'Customer'.tr : c.name,
                subtitle: [
                  c.phone,
                  Tr.plural(
                    data.vehiclesOf(c.id).length,
                    '{0} vehicle',
                    '{0} vehicles',
                  ),
                ].where((e) => e.isNotEmpty).join(' · '),
                onTap: () => onCustomer(c),
              ),
          if (offerPlate)
            _Row(
              icon: Icons.pin_rounded,
              tint: p.info,
              title: Fmt.plate(query.trim()),
              subtitle: 'New vehicle — use this number'.tr,
              onTap: () => onPlate(query.trim()),
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.md,
          vertical: Gap.sm + 2,
        ),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: p.lineSoft)),
        ),
        child: Row(
          children: [
            Container(
              height: 32,
              width: 32,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: tint),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.labelL.c(p.ink),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.bodyS.s(11).c(p.inkMuted),
                    ),
                ],
              ),
            ),
            Icon(Icons.north_west_rounded, size: 15, color: p.inkFaint),
          ],
        ),
      ),
    );
  }
}
