import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/anim/entrance.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_field.dart';
import '../../core/widgets/g_state.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/vehicle_art.dart';
import '../../data/models/entities.dart';
import '../../data/models/enums.dart';
import '../../data/repo/admin_data.dart';
import '../../data/seed/vehicle_media.dart';
import '../../state/providers.dart';

/// Which slice of the customer list is on screen. Deleted is its own bucket
/// so a card pulled off the floor by mistake can still be found.
enum _Bucket { open, complete, close, deleted }

extension on _Bucket {
  String get label => switch (this) {
    _Bucket.open => 'Open'.tr,
    _Bucket.complete => 'Complete'.tr,
    _Bucket.close => 'Close'.tr,
    _Bucket.deleted => 'Deleted'.tr,
  };

  JobStatus? get status => switch (this) {
    _Bucket.open => JobStatus.open,
    _Bucket.complete => JobStatus.complete,
    _Bucket.close => JobStatus.closed,
    _Bucket.deleted => null,
  };
}

/// What is typed and what is stored, reduced to what identifies them. Plates
/// are written every way at a counter — `RJ14 4C 2626`, `rj-14-4c-2626`,
/// `RJ.14.4C.2626` — and all of them are the same car.
String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[\s\-./,_]'), '');

/// What a search for [query] turns up with [tab] on screen: job cards, and
/// vehicles that have never had one.
///
/// Typing searches every card, not only the tab on screen. It used to search
/// the tab alone — Open, by default — so a plate whose cards were complete
/// or closed came back as "No Customer Data Found" for a car the workshop
/// had seen a dozen times. The tab on screen still comes first.
@visibleForTesting
({List<JobCard> cards, List<Vehicle> vehicles}) searchWorkshop(
  AdminData data,
  String query,
  JobStatus? tab,
) {
  final q = _norm(query);
  if (q.isEmpty) {
    if (tab == null) return (cards: const [], vehicles: const []);
    return (
      cards: data.jobCards.where((j) => j.status == tab).toList()
        ..sort((a, b) => b.stampFor(tab).compareTo(a.stampFor(tab))),
      vehicles: const [],
    );
  }

  bool hit(Vehicle? v, Customer? c, [String extra = '']) => _norm(
    [c?.name, c?.phone, v?.regNo, v?.title, extra].whereType<String>().join(),
  ).contains(q);

  final cards =
      data.jobCards
          .where(
            (j) => hit(
              data.vehicleById(j.vehicleId),
              data.customerById(j.customerId),
              j.number,
            ),
          )
          .toList()
        ..sort((a, b) {
          final first = (a.status == tab ? 0 : 1) - (b.status == tab ? 0 : 1);
          if (first != 0) return first;
          return b.stampFor(b.status).compareTo(a.stampFor(a.status));
        });

  // A car the workshop has on its books but has never opened a card for is
  // still a car somebody will type the plate of.
  final carded = {for (final j in data.jobCards) j.vehicleId};
  final vehicles = [
    for (final v in data.vehicles)
      if (!carded.contains(v.id) && hit(v, data.customerById(v.customerId))) v,
  ];
  return (cards: cards, vehicles: vehicles);
}

/// The Search tab: one list of everybody who has a card in the chosen state,
/// searchable by name, mobile or registration.
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _search = TextEditingController();
  _Bucket _bucket = _Bucket.open;
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final data = ref.watch(adminDataProvider);
    final status = _bucket.status;
    final found = searchWorkshop(data, _query, status);
    final rows = found.cards;
    final loose = found.vehicles;

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Search'.tr,
        subtitle: 'Find a card, a customer or a vehicle'.tr,
        showBack: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.md),
            child: Row(
              children: [
                for (final b in _Bucket.values)
                  Expanded(
                    child: _Radio(
                      label: b.label,
                      selected: _bucket == b,
                      onTap: () => setState(() => _bucket = b),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.md),
            child: GSearchBar(
              hint: 'Search by Name, Mobile, Vehicle Number'.tr,
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              onClear: _query.isEmpty
                  ? null
                  : () {
                      _search.clear();
                      setState(() => _query = '');
                    },
            ),
          ),
          Divider(height: 1, color: p.line),
          Expanded(
            child: rows.isEmpty && loose.isEmpty
                ? GEmptyState(
                    icon: _bucket == _Bucket.deleted
                        ? Icons.delete_outline_rounded
                        : Icons.assignment_outlined,
                    title: 'No Customer Data Found'.tr,
                    message: _bucket == _Bucket.deleted
                        ? 'Nothing has been removed from the floor.'.tr
                        : "Looks like you haven't carded any job card\nlike this."
                              .tr,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      Gap.page,
                      Gap.lg,
                      Gap.page,
                      Gap.h2,
                    ),
                    itemCount: rows.length + loose.length,
                    itemBuilder: (context, i) => Entrance(
                      index: i.clamp(0, 8),
                      child: i < rows.length
                          ? _Row(
                              card: rows[i],
                              // Found outside the tab on screen: say where.
                              showStatus: rows[i].status != status,
                            )
                          : _VehicleRow(vehicle: loose[i - rows.length]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// A radio the way the counter reads it — a ring that fills, not a chip.
class _Radio extends StatelessWidget {
  const _Radio({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Pressable(
      onTap: onTap,
      scale: 0.94,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: Motion.fast,
              height: 19,
              width: 19,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? p.accent : p.inkFaint,
                  width: 2,
                ),
              ),
              child: Center(
                child: AnimatedScale(
                  duration: Motion.base,
                  curve: Motion.spring,
                  scale: selected ? 1 : 0,
                  child: Container(
                    height: 9,
                    width: 9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: p.accent,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.labelM
                    .c(selected ? p.ink : p.inkMuted)
                    .w(selected ? FontWeight.w700 : FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A car on the books that has never had a job card. Opens its owner.
class _VehicleRow extends ConsumerWidget {
  const _VehicleRow({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final customer = ref.watch(customerProvider(vehicle.customerId));

    return Pressable(
      onTap: () => context.push('/customer/${vehicle.customerId}'),
      scale: 0.985,
      child: Container(
        margin: EdgeInsets.only(bottom: Gap.sm),
        padding: const EdgeInsets.all(Gap.lg),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: R.all(R.md),
          border: Border.all(color: p.line),
          boxShadow: Shadows.soft(p),
        ),
        child: Row(
          children: [
            GAvatar(
              initials: Fmt.initials(customer?.name ?? '?'),
              size: 42,
              tone: GTone.neutral,
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer?.name ?? 'Walk-in'.tr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.labelL.c(p.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      Fmt.plate(vehicle.regNo),
                      vehicle.title,
                      if (customer != null && customer.phone.isNotEmpty)
                        customer.phone,
                    ].where((s) => s.trim().isNotEmpty).join('  ·  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.bodyS.c(p.inkMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Gap.sm),
            GPill(label: 'No job card'.tr, tone: GTone.neutral, compact: true),
          ],
        ),
      ),
    );
  }
}

class _Row extends ConsumerWidget {
  const _Row({required this.card, this.showStatus = false});

  final JobCard card;

  /// Whether to say which tab the card belongs to — for a search hit from
  /// outside the tab on screen.
  final bool showStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final customer = ref.watch(customerProvider(card.customerId));
    final vehicle = ref.watch(vehicleProvider(card.vehicleId));

    return Pressable(
      onTap: () => context.push('/job/${card.id}'),
      scale: 0.985,
      child: Container(
        margin: EdgeInsets.only(bottom: Gap.sm),
        padding: const EdgeInsets.all(Gap.lg),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: R.all(R.md),
          border: Border.all(color: p.line),
          boxShadow: Shadows.soft(p),
        ),
        child: Row(
          children: [
            GAvatar(
              initials: Fmt.initials(customer?.name ?? '?'),
              size: 42,
              tone: GTone.neutral,
            ),
            const SizedBox(width: Gap.sm),
            // Half of what is typed into this box is a plate or a model, so
            // the vehicle belongs in the result rather than only in the line
            // of grey text under the name. Still, no tracing: results replace
            // themselves on every keystroke.
            ClipRRect(
              borderRadius: R.all(R.xs),
              child: Container(
                width: 46,
                height: 30,
                color: p.surfaceSunken,
                child: VehicleArt(
                  shape: vehicle?.shape ?? VehicleShape.fourWheeler,
                  photo: VehicleMedia.photoFor(
                    vehicle?.brand,
                    vehicle?.model,
                    vehicle?.shape ?? VehicleShape.fourWheeler,
                  ),
                  height: 30,
                  tint: p.inkFaint,
                  animate: false,
                ),
              ),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer?.name ?? 'Walk-in'.tr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.labelL.c(p.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (vehicle != null) Fmt.plate(vehicle.regNo),
                      if (vehicle != null) vehicle.title,
                      if (customer != null && customer.phone.isNotEmpty)
                        customer.phone,
                    ].join('  ·  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.bodyS.c(p.inkMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Gap.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (showStatus) ...[
                  GPill(
                    label: card.status.label,
                    tone: GTone.info,
                    compact: true,
                  ),
                  const SizedBox(height: 3),
                ],
                Text(Fmt.money(card.total), style: AppType.money.c(p.ink)),
                const SizedBox(height: 3),
                if (card.balance > 0)
                  GPill(
                    label: 'Due {0}'.trf([Fmt.money(card.balance)]),
                    tone: GTone.danger,
                    compact: true,
                  )
                else
                  GPill(label: 'Paid'.tr, tone: GTone.success, compact: true),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
