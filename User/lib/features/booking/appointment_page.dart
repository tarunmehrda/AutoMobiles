import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/anim/entrance.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_field.dart';
import '../../core/widgets/g_state.dart';
import '../../core/widgets/pressable.dart';
import '../../data/models/entities.dart';
import '../../data/models/enums.dart';
import '../../data/models/workshop.dart';
import '../../data/seed/catalog_seed.dart';
import '../../state/app_state.dart';
import '../../state/providers.dart';
import '../vehicle/widgets/brand_tile.dart';
import '../../data/models/directory.dart';
import '../../data/repo/directory_gateway.dart';

/// The slots a workshop takes a car in on. Whole hours, with the lunch hour
/// left out, because that is how a counter actually books.
const _slots = <({int hour, String label})>[
  (hour: 9, label: '09:00 AM'),
  (hour: 10, label: '10:00 AM'),
  (hour: 11, label: '11:00 AM'),
  (hour: 12, label: '12:00 PM'),
  (hour: 14, label: '02:00 PM'),
  (hour: 15, label: '03:00 PM'),
  (hour: 16, label: '04:00 PM'),
  (hour: 17, label: '05:00 PM'),
];

/// Booking a slot, in the four steps the reference walks: which car, which
/// workshop, what for, and when.
class AppointmentPage extends ConsumerStatefulWidget {
  const AppointmentPage({super.key, this.vehicleId, this.garageId});

  /// Set when the flow was started from a particular vehicle's Book button.
  final String? vehicleId;

  /// Set when the flow was started from a workshop's page in the directory,
  /// which is the ordinary way in: the customer found a garage, tapped Book,
  /// and the slot they are about to pick is at that garage.
  final String? garageId;

  @override
  ConsumerState<AppointmentPage> createState() => _AppointmentPageState();
}

class _AppointmentPageState extends ConsumerState<AppointmentPage> {
  static const _labels = ['Vehicle', 'Workshop', 'Services', 'Details'];

  final _pager = PageController();
  final _notes = TextEditingController();
  int _step = 0;

  String? _vehicleId;

  /// The workshop this booking is for, and what it has published.
  ///
  /// Null until one is chosen. There is no longer any such thing as "the"
  /// workshop for a customer — they pick one out of the directory, and the
  /// booking is what puts them on its books.
  GarageCard? _shop;
  bool _loadingShop = false;
  final _services = <String>{};
  ServiceMode _mode = ServiceMode.garage;
  late DateTime _date = _firstBookableDay();
  int _hour = 10;

  static DateTime _firstBookableDay() {
    final now = DateTime.now();
    // Anything booked today would have to be dropped off in the next hour,
    // so the picker opens on tomorrow.
    return DateTime(now.year, now.month, now.day + 1);
  }

  @override
  void initState() {
    super.initState();
    _vehicleId = widget.vehicleId;
    final gid = widget.garageId;
    if (gid != null && gid.isNotEmpty) _loadShop(gid);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vehicles = ref.read(vehiclesProvider);
      if (_vehicleId == null && vehicles.length == 1) {
        setState(() => _vehicleId = vehicles.first.id);
      }
    });
  }

  @override
  void dispose() {
    _pager.dispose();
    _notes.dispose();
    super.dispose();
  }

  /// Reads one workshop's public page, which a customer may do before they
  /// have any dealings with it at all — that is what `garage_card()` is for.
  Future<void> _loadShop(String garageId) async {
    setState(() => _loadingShop = true);
    final card = await ref.read(directoryGatewayProvider).card(garageId);
    if (!mounted) return;
    setState(() {
      _shop = card;
      _loadingShop = false;
      // A menu the customer had ticked at another workshop means nothing
      // here; the service ids belong to the shop that published them.
      _services.clear();
    });
  }

  /// Sends the customer to the directory and picks up whatever they choose.
  Future<void> _pickShop() async {
    final picked = await context.push<NearbyGarage>('/search?pick=1');
    if (!mounted || picked == null) return;
    await _loadShop(picked.id);
  }

  void _go(int step) {
    final clamped = step.clamp(0, 3);
    setState(() => _step = clamped);
    _pager.animateToPage(clamped,
        duration: Motion.base, curve: Motion.emphasized);
  }

  List<WorkshopService> get _chosen =>
      (_shop?.services ?? const <WorkshopService>[])
          .where((s) => _services.contains(s.id))
          .toList();

  /// What the chosen services come to, before anything is added.
  double get _cost =>
      _chosen.fold<double>(0, (s, e) => s + e.price);

  /// The three numbers below are the ones [Booking] itself will use, kept
  /// deliberately in the same shape (`subtotal`, `pickupFee`, `gst`,
  /// `total`) so the quote on this page and the estimate on the booking
  /// cannot drift apart again.
  ///
  /// They did drift. "Total Cost" used to show [_cost] alone, so a Pick &
  /// Drop booking of an 800 rupee service was quoted at 800 on the last
  /// screen before Confirm and then listed at 1,297 on the very next one —
  /// a 62% jump, made of a pickup fee and a tax rate the customer had not
  /// been shown anywhere. Quoting a price and then charging a different one
  /// is the kind of thing a customer only notices at the counter.
  double get _pickupFee =>
      _mode == ServiceMode.pickup ? Seed.pickupFee.toDouble() : 0;

  double get _taxable => _cost + _pickupFee;

  double get _gst => (_taxable * AppConfig.gstRate).roundToDouble();

  double get _total => _taxable + _gst;

  DateTime get _slot =>
      DateTime(_date.year, _date.month, _date.day, _hour);

  /// The hours still ahead of us on [_date]. Every one of them on a later
  /// day; on today only those that have not gone by — the picker allows
  /// today, and an 09:00 slot picked at noon used to go to the counter as a
  /// visit in the past.
  List<({int hour, String label})> get _openSlots {
    final now = DateTime.now();
    return [
      for (final s in _slots)
        if (DateTime(_date.year, _date.month, _date.day, s.hour).isAfter(now))
          s,
    ];
  }

  /// Takes a newly picked day, and moves the hour on to the first one still
  /// open if the one they had has already passed on it.
  void _setDate(DateTime day) {
    setState(() {
      _date = day;
      final open = _openSlots;
      if (open.isNotEmpty && !open.any((s) => s.hour == _hour)) {
        _hour = open.first.hour;
      }
    });
  }

  bool get _canLeaveStep => switch (_step) {
        0 => _vehicleId != null,
        1 => _shop != null,
        // Services are optional: a workshop with nothing published still has
        // to be bookable, which is exactly what the reference shows.
        2 => true,
        _ => true,
      };

  /// True while the request is on its way to the workshop, so a second tap
  /// cannot book the same slot twice.
  bool _sending = false;

  Future<void> _confirm() async {
    if (_sending) return;
    if (_vehicleId == null) {
      _go(0);
      return;
    }
    final shop = _shop;
    if (shop == null) {
      _go(1);
      return;
    }
    // The page may have sat open past the hour that was picked.
    if (!_slot.isAfter(DateTime.now())) {
      GFeedback.error(context, 'That time has passed. Pick a later slot.');
      return;
    }
    final controller = ref.read(appControllerProvider.notifier);
    final booking = controller.createBooking(
          vehicleId: _vehicleId!,
          garageId: shop.garage.id,
          workshopName: shop.garage.name,
          lines: [
            for (final s in _chosen)
              CartLine(
                id: s.id,
                name: s.name,
                price: s.price.round(),
                mrp: s.price.round(),
                isAddOn: false,
                durationHours: s.durationMins / 60,
              ),
          ],
          mode: _mode,
          slot: _slot,
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        );

    // Said only once it is true. This used to announce "sent" before the
    // request had left the phone, so a booking made with no signal looked
    // delivered and never reached the counter.
    setState(() => _sending = true);
    final sent = await controller.tellTheWorkshop(booking);
    if (!mounted) return;
    setState(() => _sending = false);
    if (sent) {
      GFeedback.success(
        context,
        'Booking ${booking.code} sent to ${shop.garage.label}',
      );
    } else {
      GFeedback.info(
        context,
        'Booking ${booking.code} is saved. It could not reach '
        '${shop.garage.label} just now — the app will send it again '
        'automatically when you are back online.',
      );
    }
    context.go('/bookings');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return PopScope(
      // Android back on step one as the only route would close the app.
      canPop: _step == 0 && context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_step > 0) {
          _go(_step - 1);
        } else {
          context.go('/home');
        }
      },
      child: Scaffold(
        backgroundColor: p.canvas,
        appBar: GHeader(
          title: 'Book Appointment',
          subtitle: 'Schedule your vehicle service',
          centered: true,
          // Booking can be the only route on the stack (a notification or
          // an old deep link opens it with `go`), and popping the only route
          // throws. Home is where that customer meant to go back to.
          onBack: () => _step > 0
              ? _go(_step - 1)
              : (context.canPop() ? context.pop() : context.go('/home')),
        ),
        // The stepper lives in the body rather than under the bar, so its
        // labels have room to breathe on a short phone.
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Gap.page, Gap.lg, Gap.page, Gap.lg),
              child: _Stepper(step: _step, labels: _labels),
            ),
            Expanded(
              child: PageView(
                controller: _pager,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _step = i),
                children: [
                  _vehicleStep(),
                  _workshopStep(),
                  _servicesStep(),
                  _detailsStep(),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: GBottomBar(
          child: Row(
            children: [
              if (_step > 0) ...[
                Expanded(
                  child: GButton(
                    label: 'Back',
                    kind: GButtonKind.outline,
                    icon: Icons.arrow_back_rounded,
                    onPressed: () => _go(_step - 1),
                  ),
                ),
                const SizedBox(width: Gap.md),
              ],
              Expanded(
                flex: _step == 0 ? 1 : 2,
                child: _step == 3
                    ? GButton.accent(
                        label: 'Confirm Booking',
                        icon: Icons.check_circle_rounded,
                        loading: _sending,
                        onPressed: _sending ? null : _confirm,
                      )
                    : GButton.accent(
                        label: 'Next',
                        trailingIcon: Icons.arrow_forward_rounded,
                        onPressed:
                            _canLeaveStep ? () => _go(_step + 1) : null,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- step 1 -------------------------------------------------------------

  Widget _vehicleStep() {
    final vehicles = ref.watch(vehiclesProvider);
    if (vehicles.isEmpty) {
      return GEmptyState(
        icon: Icons.directions_car_outlined,
        title: 'No vehicle yet',
        message: 'Add the vehicle you want serviced first.',
        actionLabel: 'Add vehicle',
        onAction: () => context.push('/vehicle/add'),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.h2),
      itemCount: vehicles.length,
      itemBuilder: (context, i) {
        final v = vehicles[i];
        return Entrance(
          index: i.clamp(0, 8),
          child: _PickRow(
            title: v.title,
            subtitle: Fmt.plate(v.regNumber),
            icon: Icons.directions_car_rounded,
            leading: switch (Seed.brandByName(v.brand)) {
              final b? => BrandBadge(brand: b, size: 44),
              _ => null,
            },
            selected: _vehicleId == v.id,
            onTap: () => setState(() => _vehicleId = v.id),
          ),
        );
      },
    );
  }

  // --- step 2 -------------------------------------------------------------

  Widget _workshopStep() {
    if (_loadingShop) {
      return const Center(child: CircularProgressIndicator());
    }
    final shop = _shop;
    if (shop == null) {
      return GEmptyState(
        icon: Icons.storefront_outlined,
        title: 'Pick a workshop',
        message: 'Search the garages near you and choose where this car is '
            'going. They see the request the moment you confirm it.',
        actionLabel: 'Find a workshop',
        onAction: _pickShop,
      );
    }
    final g = shop.garage;
    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.h2),
      children: [
        Entrance(
          child: _PickRow(
            title: g.label,
            subtitle: [
              if (g.where.isNotEmpty) g.where,
              if (g.distanceLabel.isNotEmpty) '${g.distanceLabel} away',
            ].join('  •  '),
            icon: Icons.storefront_rounded,
            selected: true,
            onTap: _pickShop,
          ),
        ),
        const SizedBox(height: Gap.md),
        GButton(
          label: 'Choose a different workshop',
          kind: GButtonKind.ghost,
          icon: Icons.search_rounded,
          onPressed: _pickShop,
        ),
      ],
    );
  }

  // --- step 3 -------------------------------------------------------------

  Widget _servicesStep() {
    final p = context.c;
    final services = _shop?.services ?? const <WorkshopService>[];
    if (services.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Gap.page),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.build_outlined, size: 62, color: p.inkFaint),
              const SizedBox(height: Gap.lg),
              Text('No services available',
                  style: AppType.h1.c(p.ink)),
              const SizedBox(height: Gap.sm),
              Text("This workshop hasn't added any services yet",
                  textAlign: TextAlign.center,
                  style: AppType.bodyM.c(p.inkMuted)),
              const SizedBox(height: Gap.lg),
              Text(
                'Carry on — the counter will write the work up when you drop '
                'the vehicle off.',
                textAlign: TextAlign.center,
                style: AppType.bodyS.c(p.inkFaint),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.h2),
      itemCount: services.length,
      itemBuilder: (context, i) {
        final s = services[i];
        return Entrance(
          index: i.clamp(0, 8),
          child: _PickRow(
            title: s.name,
            subtitle: [
              if (s.blurb.isNotEmpty) s.blurb,
              '${s.durationMins} min',
            ].join('  ·  '),
            icon: Icons.build_rounded,
            trailing: Fmt.money(s.price),
            selected: _services.contains(s.id),
            onTap: () => setState(() {
              if (!_services.remove(s.id)) _services.add(s.id);
            }),
          ),
        );
      },
    );
  }

  // --- step 4 -------------------------------------------------------------

  Widget _detailsStep() {
    final p = context.c;
    final vehicles = ref.watch(vehiclesProvider);
    Vehicle? vehicle;
    for (final v in vehicles) {
      if (v.id == _vehicleId) vehicle = v;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.h2),
      children: [
        Row(
          children: [
            Icon(Icons.event_rounded, size: 18, color: p.accent),
            const SizedBox(width: Gap.sm),
            Text('Appointment Type', style: AppType.h2.c(p.ink)),
          ],
        ),
        const SizedBox(height: Gap.md),
        _ModeRow(
          mode: ServiceMode.garage,
          selected: _mode == ServiceMode.garage,
          title: 'Direct Visit',
          blurb: 'Bring your vehicle to the workshop',
          icon: Icons.home_rounded,
          onTap: () => setState(() => _mode = ServiceMode.garage),
        ),
        const SizedBox(height: Gap.sm),
        _ModeRow(
          mode: ServiceMode.pickup,
          selected: _mode == ServiceMode.pickup,
          title: 'Pick & Drop',
          blurb: "We'll pick up and deliver your vehicle",
          icon: Icons.local_shipping_rounded,
          onTap: () => setState(() => _mode = ServiceMode.pickup),
        ),

        const SizedBox(height: Gap.xl),
        Text('Date & Time', style: AppType.h2.c(p.ink)),
        const SizedBox(height: Gap.md),
        Text('Select Date', style: AppType.labelM.c(p.inkMuted)),
        const SizedBox(height: Gap.sm),
        Pressable(
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: _date,
              firstDate: DateTime(now.year, now.month, now.day),
              lastDate: now.add(const Duration(days: 90)),
            );
            if (picked != null) _setDate(picked);
          },
          scale: 0.98,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: Gap.lg, vertical: Gap.lg),
            decoration: BoxDecoration(
              color: p.surfaceSunken,
              borderRadius: R.all(R.sm),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 17, color: p.accent),
                const SizedBox(width: Gap.md),
                Text(Fmt.fullDateTime(_date).split(',').first,
                    style: AppType.labelL.c(p.ink)),
              ],
            ),
          ),
        ),

        const SizedBox(height: Gap.lg),
        Text('Select Time', style: AppType.labelM.c(p.inkMuted)),
        const SizedBox(height: Gap.sm),
        if (_openSlots.isEmpty)
          Container(
            padding: const EdgeInsets.all(Gap.lg),
            decoration: BoxDecoration(
              color: p.surfaceSunken,
              borderRadius: R.all(R.sm),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'No slots left today — the last one is at ${_slots.last.label}.',
                    style: AppType.bodyS.c(p.inkMuted),
                  ),
                ),
                const SizedBox(width: Gap.md),
                GButton.outline(
                  label: 'Tomorrow',
                  size: GButtonSize.sm,
                  onPressed: () => _setDate(
                      DateTime(_date.year, _date.month, _date.day + 1)),
                ),
              ],
            ),
          )
        else
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: Gap.sm,
            crossAxisSpacing: Gap.sm,
            childAspectRatio: 2.4,
            children: [
              for (final s in _openSlots)
                Pressable(
                  onTap: () => setState(() => _hour = s.hour),
                  scale: 0.95,
                  child: AnimatedContainer(
                    duration: Motion.fast,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _hour == s.hour ? p.accent : p.surfaceSunken,
                      borderRadius: R.all(R.sm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time_rounded,
                            size: 14,
                            color: _hour == s.hour ? p.onAccent : p.inkMuted),
                        const SizedBox(width: 5),
                        Text(
                          s.label,
                          style: AppType.labelM
                              .c(_hour == s.hour ? p.onAccent : p.inkSoft),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),

        const SizedBox(height: Gap.xl),
        GField(
          label: 'Additional Notes (Optional)',
          hint: 'Any specific requirements or concerns?',
          controller: _notes,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
        ),

        const SizedBox(height: Gap.xl),
        Container(
          padding: const EdgeInsets.all(Gap.lg),
          decoration: BoxDecoration(
            gradient: p.inverseGradient,
            borderRadius: R.all(R.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Booking Summary', style: AppType.h2.c(p.onInverse)),
              const SizedBox(height: Gap.md),
              _SummaryRow(
                label: 'Vehicle',
                value: vehicle == null
                    ? '—'
                    : '${vehicle.title} (${Fmt.plate(vehicle.regNumber)})',
              ),
              _SummaryRow(
                label: 'Services',
                value: '${_services.length} selected',
              ),
              _SummaryRow(
                label: 'Type',
                value: _mode == ServiceMode.pickup
                    ? 'Pick & Drop'
                    : 'Direct Visit',
              ),
              Divider(
                  height: Gap.xl,
                  color: p.onInverse.withValues(alpha: 0.18)),
              _SummaryRow(label: 'Services', value: Fmt.money(_cost)),
              // Only when it is being charged. A zero row on a Direct Visit
              // reads as a fee that might yet appear.
              if (_pickupFee > 0)
                _SummaryRow(
                  label: 'Pick & drop',
                  value: Fmt.money(_pickupFee),
                ),
              _SummaryRow(
                label: 'GST at '
                    '${(AppConfig.gstRate * 100).toStringAsFixed(0)}%',
                value: Fmt.money(_gst),
              ),
              Divider(
                  height: Gap.xl,
                  color: p.onInverse.withValues(alpha: 0.18)),
              Row(
                children: [
                  Expanded(
                    child:
                        Text('Total Cost', style: AppType.h2.c(p.onInverse)),
                  ),
                  Text(Fmt.money(_total),
                      style: AppType.money.c(p.accent)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Numbered circles with the rail between them.
class _Stepper extends StatelessWidget {
  const _Stepper({required this.step, required this.labels});

  final int step;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          Column(
            children: [
              AnimatedContainer(
                duration: Motion.base,
                curve: Motion.spring,
                height: 30,
                width: 30,
                decoration: BoxDecoration(
                  color: i <= step ? p.accent : p.surfaceSunken,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: i < step
                      ? Icon(Icons.check_rounded,
                          size: 17, color: p.onAccent)
                      : Text('${i + 1}',
                          style: AppType.labelM.c(
                              i == step ? p.onAccent : p.inkFaint)),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                labels[i],
                style: AppType.labelS
                    .s(10)
                    .c(i == step ? p.accent : p.inkFaint)
                    .w(i == step ? FontWeight.w700 : FontWeight.w500),
              ),
            ],
          ),
          if (i != labels.length - 1)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: AnimatedContainer(
                  duration: Motion.base,
                  height: 2,
                  color: i < step ? p.accent : p.line,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// A selectable row with a tick, used for vehicle, workshop and service.
class _PickRow extends StatelessWidget {
  const _PickRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.trailing,
    this.leading,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final String? trailing;

  /// Shown instead of [icon] where there is something better to show —
  /// the car's own brand mark, as the rest of the app draws it.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Pressable(
      onTap: onTap,
      scale: 0.985,
      child: AnimatedContainer(
        duration: Motion.fast,
        margin: const EdgeInsets.only(bottom: Gap.sm),
        padding: const EdgeInsets.all(Gap.lg),
        decoration: BoxDecoration(
          color: selected ? p.accentSoft : p.surface,
          borderRadius: R.all(R.md),
          border: Border.all(
              color: selected ? p.accent : p.line,
              width: selected ? 1.6 : 1),
        ),
        child: Row(
          children: [
            leading ??
                Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: selected
                        ? p.accent.withValues(alpha: 0.16)
                        : p.surfaceSunken,
                    borderRadius: R.all(R.sm),
                  ),
                  child: Icon(icon,
                      size: 21, color: selected ? p.accent : p.inkMuted),
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
                    style: AppType.labelL.c(selected ? p.accentInk : p.ink),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.bodyS.c(p.inkMuted),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: Gap.sm),
              Text(trailing!, style: AppType.money.s(15).c(p.ink)),
              const SizedBox(width: Gap.sm),
            ],
            AnimatedScale(
              duration: Motion.base,
              curve: Motion.spring,
              scale: selected ? 1 : 0.6,
              child: AnimatedOpacity(
                duration: Motion.fast,
                opacity: selected ? 1 : 0.25,
                child: Container(
                  height: 26,
                  width: 26,
                  decoration: BoxDecoration(
                    color: selected ? p.accent : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: selected ? p.accent : p.inkFaint, width: 1.6),
                  ),
                  child: Icon(Icons.check_rounded,
                      size: 16,
                      color: selected ? p.onAccent : Colors.transparent),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeRow extends StatelessWidget {
  const _ModeRow({
    required this.mode,
    required this.selected,
    required this.title,
    required this.blurb,
    required this.icon,
    required this.onTap,
  });

  final ServiceMode mode;
  final bool selected;
  final String title;
  final String blurb;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Pressable(
      onTap: onTap,
      scale: 0.985,
      child: AnimatedContainer(
        duration: Motion.fast,
        padding: const EdgeInsets.all(Gap.lg),
        decoration: BoxDecoration(
          color: selected ? p.accentSoft : p.surface,
          borderRadius: R.all(R.md),
          border: Border.all(color: selected ? p.accent : p.line),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: Motion.fast,
              height: 20,
              width: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: selected ? p.accent : p.inkFaint, width: 2),
              ),
              child: Center(
                child: AnimatedScale(
                  duration: Motion.base,
                  curve: Motion.spring,
                  scale: selected ? 1 : 0,
                  child: Container(
                    height: 10,
                    width: 10,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle, color: p.accent),
                  ),
                ),
              ),
            ),
            const SizedBox(width: Gap.md),
            Icon(icon, size: 20, color: selected ? p.accent : p.inkMuted),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppType.labelL
                          .c(selected ? p.accentInk : p.ink)),
                  Text(blurb, style: AppType.bodyS.c(p.inkMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style:
                    AppType.bodyM.c(p.onInverse.withValues(alpha: 0.65))),
          ),
          Flexible(
            child: Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: AppType.labelL.c(p.onInverse)),
          ),
        ],
      ),
    );
  }
}
