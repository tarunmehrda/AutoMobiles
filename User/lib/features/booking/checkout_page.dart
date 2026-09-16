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
import '../../core/widgets/g_state.dart';
import '../../core/widgets/g_surface.dart';
import '../../core/widgets/pressable.dart';
import '../../data/models/enums.dart';
import '../../data/seed/catalog_seed.dart';
import '../../state/app_state.dart';
import '../../state/draft_state.dart';
import '../../state/providers.dart';
import 'widgets/address_sheet.dart';
import 'widgets/bill_summary.dart';

class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  final _notes = TextEditingController();
  bool _placing = false;

  late final List<DateTime> _days = List.generate(14, (i) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).add(Duration(days: i));
  });

  @override
  void initState() {
    super.initState();
    final draft = ref.read(draftProvider);
    _notes.text = draft.notes ?? '';
    if (draft.slotDate == null) {
      // Default to the first day with a usable slot.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final first = _days.firstWhere((d) => _slotsFor(d).isNotEmpty,
            orElse: () => _days.first);
        ref.read(draftProvider.notifier).setSlot(date: first);
      });
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  /// Past times are dropped from today's list so a slot is never impossible.
  List<String> _slotsFor(DateTime day) {
    final now = DateTime.now();
    final isToday = day.year == now.year &&
        day.month == now.month &&
        day.day == now.day;
    if (!isToday) return Seed.slotTimes;
    return Seed.slotTimes.where((t) {
      final parts = t.split(RegExp(r'[: ]'));
      var hour = int.parse(parts[0]);
      if (parts[2] == 'PM' && hour != 12) hour += 12;
      if (parts[2] == 'AM' && hour == 12) hour = 0;
      return hour > now.hour + 1;
    }).toList();
  }

  bool _slotBusy(DateTime day, String time) {
    // Deterministic "already booked" pattern so the grid feels like a real
    // diary instead of every slot always being free.
    return (day.day + time.hashCode) % 7 == 0;
  }

  Future<void> _confirm() async {
    final draft = ref.read(draftProvider);
    final vehicle = ref.read(activeVehicleProvider);

    if (vehicle == null) {
      GFeedback.error(context, 'Add a vehicle before booking');
      return;
    }
    if (!draft.addressReady) {
      GFeedback.error(context, 'Add a pickup address to continue');
      return;
    }
    if (!draft.slotReady) {
      GFeedback.error(context, 'Pick a date and time slot');
      return;
    }

    setState(() => _placing = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    final booking = ref.read(appControllerProvider.notifier).createBooking(
          vehicleId: vehicle.id,
          lines: draft.lines,
          mode: draft.mode,
          slot: draft.slot!,
          addressId: draft.addressId,
          couponCode: draft.couponCode,
          discount: draft.discount,
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        );

    ref.read(draftProvider.notifier).clear();
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    context.pushReplacement('/booking-success/${booking.id}');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final draft = ref.watch(draftProvider);
    final vehicle = ref.watch(activeVehicleProvider);
    final addresses = ref.watch(addressesProvider);
    final address = draft.addressId == null
        ? null
        : addresses.where((a) => a.id == draft.addressId).firstOrNull;

    if (draft.isEmpty) {
      return Scaffold(
        backgroundColor: p.canvas,
        appBar: const GHeader(title: 'Checkout'),
        body: GEmptyState(
          icon: Icons.shopping_bag_outlined,
          title: 'Your cart is empty',
          message: 'Add a service to continue with the booking.',
          actionLabel: 'Browse services',
          onAction: () => context.go('/book'),
        ),
      );
    }

    final slots = draft.slotDate == null
        ? const <String>[]
        : _slotsFor(draft.slotDate!);
    final ready = draft.slotReady && draft.addressReady && vehicle != null;

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Slot & handover',
        subtitle: '${draft.count} service${draft.count == 1 ? '' : 's'} • '
            '${Fmt.money(draft.total)}',
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.h2),
        children: [
          // --- handover mode -------------------------------------------
          Entrance(child: _label(context, 'How should we collect it?')),
          const SizedBox(height: Gap.md),
          Entrance(
            child: Row(
              children: [
                for (final m in ServiceMode.values) ...[
                  Expanded(
                    child: _ModeCard(
                      mode: m,
                      selected: draft.mode == m,
                      fee: m == ServiceMode.pickup ? Seed.pickupFee : 0,
                      onTap: () {
                        ref.read(draftProvider.notifier).setMode(m);
                        if (m == ServiceMode.pickup &&
                            draft.addressId == null &&
                            addresses.isNotEmpty) {
                          ref
                              .read(draftProvider.notifier)
                              .setAddress(addresses.first.id);
                        }
                      },
                    ),
                  ),
                  if (m != ServiceMode.values.last)
                    const SizedBox(width: Gap.md),
                ],
              ],
            ),
          ),

          // --- address --------------------------------------------------
          if (draft.mode == ServiceMode.pickup) ...[
            const SizedBox(height: Gap.xxl),
            _label(context, 'Pickup address'),
            const SizedBox(height: Gap.md),
            if (addresses.isEmpty)
              Pressable(
                onTap: () async {
                  final a = await showAddressEditor(context);
                  if (a != null) {
                    ref.read(draftProvider.notifier).setAddress(a.id);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(Gap.lg),
                  decoration: BoxDecoration(
                    color: p.accentSoft,
                    borderRadius: R.all(R.lg),
                    border:
                        Border.all(color: p.accent.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.add_location_alt_rounded,
                          color: p.accentInk, size: 22),
                      const SizedBox(width: Gap.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Add a pickup address',
                                style: AppType.labelL.c(p.accentInk)),
                            Text(
                              'Free pickup within ${Seed.garage.address.contains('Mohali') ? 12 : 12} km',
                              style: AppType.bodyS.c(
                                  p.accentInk.withValues(alpha: 0.75)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              for (final a in addresses)
                Padding(
                  padding: const EdgeInsets.only(bottom: Gap.sm),
                  child: GOptionRow(
                    label: a.label,
                    subtitle: a.oneLine,
                    icon: a.icon,
                    selected: draft.addressId == a.id,
                    onTap: () =>
                        ref.read(draftProvider.notifier).setAddress(a.id),
                  ),
                ),
              GButton.ghost(
                label: 'Add another address',
                icon: Icons.add_rounded,
                size: GButtonSize.md,
                expand: true,
                onPressed: () async {
                  final a = await showAddressEditor(context);
                  if (a != null) {
                    ref.read(draftProvider.notifier).setAddress(a.id);
                  }
                },
              ),
            ],
          ] else ...[
            const SizedBox(height: Gap.lg),
            GCard(
              padding: const EdgeInsets.all(Gap.md),
              child: Row(
                children: [
                  Icon(Icons.place_rounded, size: 19, color: p.inkMuted),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(Seed.garage.name,
                            style: AppType.labelL.c(p.ink)),
                        Text(Seed.garage.address,
                            style: AppType.bodyS.c(p.inkMuted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // --- date -----------------------------------------------------
          const SizedBox(height: Gap.xxl),
          _label(context, 'Pick a date'),
          const SizedBox(height: Gap.md),
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _days.length,
              separatorBuilder: (_, _) => const SizedBox(width: Gap.sm),
              itemBuilder: (context, i) {
                final d = _days[i];
                final selected = draft.slotDate != null &&
                    draft.slotDate!.day == d.day &&
                    draft.slotDate!.month == d.month;
                final available = _slotsFor(d).isNotEmpty;
                return Pressable(
                  onTap: available
                      ? () {
                          // Keep the chosen time only if the new date really
                          // offers it and it is not already taken.
                          final time = draft.slotTime;
                          final stillOk = time != null &&
                              _slotsFor(d).contains(time) &&
                              !_slotBusy(d, time);
                          ref
                              .read(draftProvider.notifier)
                              .setSlot(date: d, clearTime: !stillOk);
                        }
                      : null,
                  enabled: available,
                  scale: 0.93,
                  child: AnimatedContainer(
                    duration: Motion.fast,
                    width: 60,
                    decoration: BoxDecoration(
                      color: selected ? p.ink : p.surface,
                      borderRadius: R.all(R.md),
                      border:
                          Border.all(color: selected ? p.ink : p.line),
                      boxShadow: selected ? Shadows.soft(p) : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          Fmt.dayName(d).toUpperCase(),
                          style: AppType.over.s(9).c(selected
                              ? (p.isDark ? p.canvas : Colors.white)
                                  .withValues(alpha: 0.65)
                              : p.inkFaint),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${d.day}',
                          style: AppType.h1.s(18).c(selected
                              ? (p.isDark ? p.canvas : Colors.white)
                              : p.ink),
                        ),
                        Text(
                          Fmt.dateShort(d).split(' ').last,
                          style: AppType.labelS.s(9.5).c(selected
                              ? (p.isDark ? p.canvas : Colors.white)
                                  .withValues(alpha: 0.65)
                              : p.inkMuted),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // --- time -----------------------------------------------------
          const SizedBox(height: Gap.xxl),
          Row(
            children: [
              _label(context, 'Pick a time'),
              const Spacer(),
              if (draft.slotDate != null)
                Text(Fmt.friendlyDay(draft.slotDate!),
                    style: AppType.labelM.c(p.inkMuted)),
            ],
          ),
          const SizedBox(height: Gap.md),
          if (slots.isEmpty)
            Container(
              padding: const EdgeInsets.all(Gap.lg),
              decoration: BoxDecoration(
                color: p.warningSoft,
                borderRadius: R.all(R.md),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 18, color: p.warning),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Text(
                      'No slots left today. Pick another date above.',
                      style: AppType.labelM.c(p.warning),
                    ),
                  ),
                ],
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: Gap.sm,
                crossAxisSpacing: Gap.sm,
                mainAxisExtent: 48,
              ),
              itemCount: slots.length,
              itemBuilder: (context, i) {
                final t = slots[i];
                final busy = _slotBusy(draft.slotDate!, t);
                final selected = draft.slotTime == t;
                return Pressable(
                  onTap: busy
                      ? null
                      : () =>
                          ref.read(draftProvider.notifier).setSlot(time: t),
                  enabled: !busy,
                  scale: 0.94,
                  child: AnimatedContainer(
                    duration: Motion.fast,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? p.accent
                          : (busy ? p.surfaceSunken : p.surface),
                      borderRadius: R.all(R.md),
                      border: Border.all(
                          color: selected ? p.accent : p.line),
                    ),
                    child: Text(
                      t,
                      style: AppType.labelM.c(selected
                          ? p.onAccent
                          : (busy ? p.inkFaint : p.ink)),
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: Gap.sm),
          Row(
            children: [
              _legendDot(p.surface, p.line),
              Text(' Available   ', style: AppType.labelS.c(p.inkMuted)),
              _legendDot(p.surfaceSunken, p.line),
              Text(' Full   ', style: AppType.labelS.c(p.inkMuted)),
              _legendDot(p.accent, p.accent),
              Text(' Selected', style: AppType.labelS.c(p.inkMuted)),
            ],
          ),

          // --- notes -----------------------------------------------------
          const SizedBox(height: Gap.xxl),
          _label(context, 'Anything we should know?'),
          const SizedBox(height: Gap.md),
          GField(
            hint: 'e.g. rattling sound over speed breakers, AC weak after 20 mins',
            controller: _notes,
            maxLines: 4,
            onChanged: (v) => ref.read(draftProvider.notifier).setNotes(v),
          ),

          // --- summary ----------------------------------------------------
          const SizedBox(height: Gap.xxl),
          _label(context, 'Booking summary'),
          const SizedBox(height: Gap.md),
          GCard(
            child: Column(
              children: [
                _summaryRow(context, Icons.directions_car_rounded, 'Vehicle',
                    vehicle == null
                        ? '—'
                        : '${vehicle.title} • ${vehicle.regNumber}'),
                _summaryRow(
                    context,
                    draft.mode.icon,
                    'Handover',
                    draft.mode == ServiceMode.garage
                        ? 'Garage visit'
                        : 'Pickup from ${address?.shortLine ?? 'your address'}'),
                _summaryRow(
                  context,
                  Icons.event_rounded,
                  'Slot',
                  draft.slot == null
                      ? 'Not selected'
                      : '${Fmt.friendlyDay(draft.slot!)}, ${draft.slotTime}',
                ),
                _summaryRow(context, Icons.timelapse_rounded, 'Estimated time',
                    Fmt.duration(draft.hours)),
                const SizedBox(height: Gap.sm),
                const GDashedLine(),
                const SizedBox(height: Gap.md),
                for (final l in draft.lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(Icons.check_rounded, size: 14, color: p.success),
                        const SizedBox(width: Gap.sm),
                        Expanded(
                          child: Text(l.name,
                              style: AppType.bodyM.c(p.inkSoft),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        Text(Fmt.money(l.price),
                            style: AppType.moneyS.c(p.inkSoft)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Gap.lg),
          BillSummary(draft: draft),
          const SizedBox(height: Gap.lg),
          Container(
            padding: const EdgeInsets.all(Gap.md),
            decoration: BoxDecoration(
              color: p.surfaceSunken,
              borderRadius: R.all(R.md),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: p.inkMuted),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Text(
                    'Nothing is charged now. You pay after the work is done and '
                    'the invoice is generated.',
                    style: AppType.bodyS.c(p.inkMuted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: GBottomBar(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!ready)
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.sm),
                child: Row(
                  children: [
                    Icon(Icons.info_rounded, size: 14, color: p.warning),
                    const SizedBox(width: 5),
                    Text(
                      !draft.addressReady
                          ? 'Pick a pickup address to continue'
                          : 'Pick a date and time slot',
                      style: AppType.labelS.c(p.warning),
                    ),
                  ],
                ),
              ),
            GButton.accent(
              label: 'Confirm booking',
              badge: Fmt.money(draft.total),
              loading: _placing,
              onPressed: ready ? _confirm : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(BuildContext context, String text) =>
      Text(text, style: AppType.h1.c(context.c.ink));

  Widget _legendDot(Color fill, Color border) => Container(
        height: 10,
        width: 10,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: Border.all(color: border),
        ),
      );

  Widget _summaryRow(
      BuildContext context, IconData icon, String label, String value) {
    final p = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: p.inkMuted),
          const SizedBox(width: Gap.md),
          Text(label, style: AppType.bodyM.c(p.inkMuted)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppType.labelM.c(p.ink),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.mode,
    required this.selected,
    required this.onTap,
    required this.fee,
  });

  final ServiceMode mode;
  final bool selected;
  final VoidCallback onTap;
  final int fee;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Pressable(
      onTap: onTap,
      scale: 0.97,
      child: AnimatedContainer(
        duration: Motion.fast,
        padding: const EdgeInsets.all(Gap.lg),
        decoration: BoxDecoration(
          color: selected ? p.accentSoft : p.surface,
          borderRadius: R.all(R.lg),
          border: Border.all(
              color: selected ? p.accent : p.line,
              width: selected ? 1.6 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(mode.icon,
                    size: 22, color: selected ? p.accentInk : p.inkMuted),
                const Spacer(),
                AnimatedOpacity(
                  opacity: selected ? 1 : 0,
                  duration: Motion.fast,
                  child: Icon(Icons.check_circle_rounded,
                      size: 18, color: p.accent),
                ),
              ],
            ),
            const SizedBox(height: Gap.md),
            Text(mode.label,
                style: AppType.h3.c(selected ? p.accentInk : p.ink)),
            const SizedBox(height: 2),
            Text(mode.blurb,
                style: AppType.bodyS.s(11.5).c(p.inkMuted),
                maxLines: 2),
            const SizedBox(height: Gap.sm),
            GPill(
              label: fee == 0 ? 'No extra charge' : '+ ${Fmt.money(fee)}',
              tone: fee == 0 ? GTone.success : GTone.neutral,
              compact: true,
            ),
          ],
        ),
      ),
    );
  }
}
