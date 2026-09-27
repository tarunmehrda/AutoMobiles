import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/anim/entrance.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_state.dart';
import '../../core/widgets/pressable.dart';
import '../../data/models/entities.dart';
import '../../data/models/enums.dart';
import '../../data/models/workshop.dart';
import '../../state/app_state.dart';
import '../../state/providers.dart';
import '../workshop/widgets/booking_details_sheet.dart';
import '../workshop/widgets/rate_sheet.dart';

/// Two lists that answer two different questions: what have I asked for, and
/// what has the workshop actually done.
class BookingsPage extends ConsumerStatefulWidget {
  const BookingsPage({super.key, this.focusId});

  /// The booking a tapped notification is about: shown first and outlined.
  final String? focusId;

  @override
  ConsumerState<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends ConsumerState<BookingsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final upcoming = ref.watch(upcomingBookingsProvider);
    final past = ref.watch(pastBookingsProvider);
    final cards = ref.watch(workshopCardsProvider);

    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Gap.page, Gap.md, Gap.page, Gap.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('My Bookings', style: AppType.d2.c(p.ink)),
                  Text('View and manage your service appointments',
                      style: AppType.bodyS.c(p.inkMuted)),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.page),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: p.surfaceSunken,
                  borderRadius: R.all(R.md),
                ),
                child: TabBar(
                  controller: _tabs,
                  dividerHeight: 0,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: p.surface,
                    borderRadius: R.all(R.sm),
                    boxShadow: Shadows.soft(p),
                  ),
                  labelColor: p.ink,
                  unselectedLabelColor: p.inkMuted,
                  labelStyle: AppType.labelL,
                  unselectedLabelStyle: AppType.labelL,
                  tabs: const [
                    Tab(text: 'My Bookings'),
                    Tab(text: 'Jobcard History'),
                  ],
                ),
              ),
            ),

            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _BookingList(
                    upcoming: upcoming,
                    past: past,
                    focusId: widget.focusId,
                  ),
                  _JobcardList(cards: cards),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingList extends ConsumerWidget {
  const _BookingList({
    required this.upcoming,
    required this.past,
    this.focusId,
  });

  final List<Booking> upcoming;
  final List<Booking> past;
  final String? focusId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    if (upcoming.isEmpty && past.isEmpty) {
      return GEmptyState(
        icon: Icons.calendar_month_rounded,
        title: 'No past bookings',
        message:
            'Book a service and it shows up here with its slot and estimate.',
        actionLabel: 'Book a service',
        onAction: () => context.push('/book'),
      );
    }
    // A tapped notification's booking goes first, wherever it would sit.
    final focused = [
      ...upcoming,
      ...past,
    ].where((b) => b.id == focusId).firstOrNull;
    final rest = [
      for (final b in upcoming)
        if (b.id != focusId) b,
    ];
    final earlier = [
      for (final b in past)
        if (b.id != focusId) b,
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.h2),
      children: [
        if (focused != null) _BookingCard(booking: focused, focused: true),
        for (var i = 0; i < rest.length; i++)
          Entrance(
            index: i.clamp(0, 8),
            child: _BookingCard(booking: rest[i]),
          ),
        if (earlier.isNotEmpty) ...[
          const SizedBox(height: Gap.lg),
          Text('EARLIER', style: AppType.over.c(p.inkFaint)),
          const SizedBox(height: Gap.sm),
          for (final b in earlier) _BookingCard(booking: b),
        ],
      ],
    );
  }
}

class _BookingCard extends ConsumerWidget {
  const _BookingCard({required this.booking, this.focused = false});

  final Booking booking;

  /// The one a tapped notification was about: outlined in the accent.
  final bool focused;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    Vehicle? vehicle;
    for (final v in ref.watch(vehiclesProvider)) {
      if (v.id == booking.vehicleId) vehicle = v;
    }
    final shop = ref.watch(workshopProvider);

    // A lapsed booking is still "upcoming" on paper, but its day has gone by
    // with no job card. Calling it Scheduled, in the hopeful blue, promised a
    // visit that is not going to happen — it is a missed slot, said quietly.
    final tone = switch (booking.status) {
      BookingStatus.upcoming when booking.lapsed => GTone.neutral,
      BookingStatus.upcoming => GTone.info,
      BookingStatus.active => GTone.warning,
      BookingStatus.completed => GTone.success,
      BookingStatus.cancelled => GTone.neutral,
    };
    final label = switch (booking.status) {
      BookingStatus.upcoming when booking.lapsed => 'Missed',
      BookingStatus.upcoming => 'Scheduled',
      BookingStatus.active => 'In Process',
      BookingStatus.completed => 'Completed',
      BookingStatus.cancelled => 'Cancelled',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: Gap.md),
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: R.all(R.lg),
        border: Border.all(
          color: focused ? p.accent : p.line,
          width: focused ? 2 : 1,
        ),
        boxShadow: Shadows.soft(p),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.build_rounded, size: 17, color: p.inkSoft),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(
                  booking.lines.isEmpty
                      ? 'General Servicing'
                      : booking.lines.first.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.labelL.c(p.ink),
                ),
              ),
              GPill(label: label, tone: tone, compact: true),
            ],
          ),
          const SizedBox(height: Gap.sm),
          Row(
            children: [
              Icon(Icons.directions_car_rounded, size: 15, color: p.inkMuted),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(
                  [
                    vehicle?.title ?? 'Vehicle',
                    if (vehicle != null) Fmt.plate(vehicle.regNumber),
                  ].join('  •  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.bodyS.c(p.inkMuted),
                ),
              ),
            ],
          ),
          if (shop.isLinked)
            Row(
              children: [
                Icon(Icons.place_rounded, size: 15, color: p.inkMuted),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Text(shop.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.bodyS.c(p.inkMuted)),
                ),
              ],
            ),
          const SizedBox(height: Gap.md),
          Row(
            children: [
              Expanded(
                child: _Box(
                  label: 'Date & Time',
                  lines: [Fmt.date(booking.slot), Fmt.time(booking.slot)],
                  icons: const [
                    Icons.calendar_today_rounded,
                    Icons.access_time_rounded,
                  ],
                ),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: _Box(
                  label: 'Estimate',
                  lines: [
                    Fmt.money(booking.total),
                    booking.mode == ServiceMode.pickup
                        ? 'Pick & Drop'
                        : 'Direct Visit',
                  ],
                  tint: p.accentInk,
                ),
              ),
            ],
          ),
          // Only while the workshop has not started: after that it is a job
          // card, and the database refuses to withdraw it anyway. Not on a
          // lapsed one either — its day has gone, and moving or calling off a
          // visit nobody is expecting any more only sends the counter noise.
          if (booking.status == BookingStatus.upcoming &&
              booking.jobCard == null &&
              !booking.lapsed) ...[
            const SizedBox(height: Gap.md),
            Row(
              children: [
                Expanded(
                  child: GButton(
                    label: 'Reschedule',
                    icon: Icons.edit_calendar_rounded,
                    kind: GButtonKind.outline,
                    size: GButtonSize.md,
                    onPressed: () => _reschedule(context),
                  ),
                ),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: GButton(
                    label: 'Cancel booking',
                    icon: Icons.event_busy_rounded,
                    kind: GButtonKind.outline,
                    size: GButtonSize.md,
                    onPressed: () => _cancel(context, ref),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Opens the slot picker and, once the workshop has agreed to the move,
  /// says where the booking went.
  ///
  /// The sheet makes the call itself, so a refusal is shown where the
  /// customer is still looking — a toast from here would sit behind the
  /// sheet — and only the good news comes back out to the page.
  Future<void> _reschedule(BuildContext context) async {
    final moved = await GFeedback.sheet<DateTime>(
      context,
      title: 'Reschedule',
      subtitle: 'Pick a new day and time for this visit',
      child: _RescheduleSheet(booking: booking),
    );
    if (moved == null || !context.mounted) return;
    GFeedback.success(
      context,
      'Moved to ${Fmt.date(moved)} at ${Fmt.time(moved)}',
    );
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final go = await GFeedback.confirm(
      context,
      title: 'Cancel this booking?',
      message: 'The workshop is told straight away and the slot is freed.',
      confirmLabel: 'Cancel booking',
      cancelLabel: 'Keep it',
      destructive: true,
    );
    if (!go || !context.mounted) return;
    final error = await ref
        .read(appControllerProvider.notifier)
        .cancelBooking(booking.id, 'Cancelled by you');
    if (!context.mounted) return;
    if (error != null) {
      GFeedback.error(context, error);
    } else {
      GFeedback.success(context, 'Booking cancelled');
    }
  }
}

/// The hours a workshop takes a car in on — the same list the booking screen
/// offers (`_slots` in `appointment_page.dart`), so a moved booking lands on
/// a slot the counter would have accepted in the first place.
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

/// A day and an hour for a booking that already exists, and the call that
/// moves it with the workshop.
///
/// Pops with the new slot once `rescheduleBooking` has agreed. A refusal —
/// the counter has accepted it, or there is no signal — stays on the sheet
/// in a line above the button, because that is where the customer is
/// looking; a toast would render behind the sheet and never be seen.
class _RescheduleSheet extends ConsumerStatefulWidget {
  const _RescheduleSheet({required this.booking});

  final Booking booking;

  @override
  ConsumerState<_RescheduleSheet> createState() => _RescheduleSheetState();
}

class _RescheduleSheetState extends ConsumerState<_RescheduleSheet> {
  late DateTime _date;
  int? _hour;
  bool _saving = false;
  String? _error;

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    final s = widget.booking.slot;
    final day = DateTime(s.year, s.month, s.day);
    // Opens on the booked day when it is still ahead, so moving a visit an
    // hour later is one tap; a slot already behind us starts from today.
    _date = day.isBefore(_today()) ? _today() : day;
    final open = _openOn(_date);
    _hour = open.any((o) => o.hour == s.hour)
        ? s.hour
        : (open.isEmpty ? null : open.first.hour);
  }

  /// The slots still ahead of us on [day]. On today that drops the hours
  /// already gone, which could otherwise be picked and sent to the counter
  /// as a visit in the past.
  List<({int hour, String label})> _openOn(DateTime day) {
    final now = DateTime.now();
    return [
      for (final s in _slots)
        if (DateTime(day.year, day.month, day.day, s.hour).isAfter(now)) s,
    ];
  }

  DateTime? get _slot => _hour == null
      ? null
      : DateTime(_date.year, _date.month, _date.day, _hour!);

  Future<void> _pickDate() async {
    final today = _today();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: today,
      lastDate: today.add(const Duration(days: 90)),
    );
    if (picked == null || !mounted) return;
    final open = _openOn(picked);
    setState(() {
      _date = picked;
      _error = null;
      // Keep the hour they had if the new day still has it.
      if (!open.any((o) => o.hour == _hour)) {
        _hour = open.isEmpty ? null : open.first.hour;
      }
    });
  }

  Future<void> _save() async {
    final slot = _slot;
    if (slot == null || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await ref
        .read(appControllerProvider.notifier)
        .rescheduleBooking(widget.booking.id, slot);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }
    Navigator.of(context).pop(slot);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final open = _openOn(_date);
    final slot = _slot;
    final unchanged = slot != null && slot == widget.booking.slot;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page,
          Gap.h1 + MediaQuery.viewPaddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Date', style: AppType.labelM.c(p.inkMuted)),
          const SizedBox(height: Gap.sm),
          Pressable(
            onTap: _saving ? null : _pickDate,
            scale: 0.98,
            child: Container(
              padding: const EdgeInsets.all(Gap.lg),
              decoration: BoxDecoration(
                color: p.surfaceSunken,
                borderRadius: R.all(R.sm),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded,
                      size: 17, color: p.accent),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Text(Fmt.date(_date),
                        style: AppType.labelL.c(p.ink)),
                  ),
                  Icon(Icons.expand_more_rounded,
                      size: 20, color: p.inkMuted),
                ],
              ),
            ),
          ),
          const SizedBox(height: Gap.lg),
          Text('Time', style: AppType.labelM.c(p.inkMuted)),
          const SizedBox(height: Gap.sm),
          if (open.isEmpty)
            Text(
              'No slots left today. Pick tomorrow or a later day.',
              style: AppType.bodyS.c(p.inkMuted),
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
                for (final s in open)
                  Pressable(
                    onTap: _saving
                        ? null
                        : () => setState(() {
                              _hour = s.hour;
                              _error = null;
                            }),
                    scale: 0.95,
                    child: AnimatedContainer(
                      duration: Motion.fast,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _hour == s.hour ? p.accent : p.surfaceSunken,
                        borderRadius: R.all(R.sm),
                      ),
                      child: Text(
                        s.label,
                        style: AppType.labelM
                            .c(_hour == s.hour ? p.onAccent : p.inkSoft),
                      ),
                    ),
                  ),
              ],
            ),
          if (_error != null) ...[
            const SizedBox(height: Gap.lg),
            Text(_error!, style: AppType.bodyS.c(p.danger)),
          ],
          const SizedBox(height: Gap.xl),
          GButton.accent(
            label: unchanged ? 'Already booked for then' : 'Move booking',
            icon: Icons.event_available_rounded,
            loading: _saving,
            onPressed: slot == null || unchanged ? null : _save,
          ),
        ],
      ),
    );
  }
}

class _JobcardList extends ConsumerWidget {
  const _JobcardList({required this.cards});

  final List<WorkshopCard> cards;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (cards.isEmpty) {
      return const GEmptyState(
        icon: Icons.assignment_outlined,
        title: 'No job cards yet',
        message: 'Once the workshop opens a card for your vehicle it appears '
            'here, with everything they did to it.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.h2),
      itemCount: cards.length,
      itemBuilder: (context, i) => Entrance(
        index: i.clamp(0, 8),
        child: _JobcardCard(card: cards[i]),
      ),
    );
  }
}

class _JobcardCard extends ConsumerWidget {
  const _JobcardCard({required this.card});

  final WorkshopCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final shop = ref.watch(workshopProvider);
    final overdue = card.promisedAt != null &&
        !card.isClosed &&
        card.promisedAt!.isBefore(DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: Gap.md),
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
              Icon(
                card.isClosed
                    ? Icons.check_circle_rounded
                    : Icons.build_circle_rounded,
                size: 18,
                color: card.isClosed ? p.success : p.accent,
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(
                  card.items.isEmpty
                      ? (card.voices.isEmpty ? card.number : card.voices.first)
                      : card.items.first.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.labelL.c(p.ink),
                ),
              ),
              GPill(
                label: card.isClosed
                    ? 'Completed'
                    : (card.isComplete ? 'Ready for Delivery' : 'In Process'),
                tone: card.isClosed
                    ? GTone.success
                    : (card.isComplete ? GTone.success : GTone.warning),
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          Row(
            children: [
              Icon(Icons.directions_car_rounded, size: 15, color: p.inkMuted),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(
                  '${card.vehicleTitle}  •  ${Fmt.plate(card.regNo)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.bodyS.c(p.inkMuted),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Icon(Icons.place_rounded, size: 15, color: p.inkMuted),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(
                  card.garageName.isEmpty || card.garageName == shop.name
                      ? shop.label
                      : card.garageName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.bodyS.c(p.inkMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          Row(
            children: [
              Expanded(
                child: _Box(
                  label: 'Date & Time',
                  lines: [Fmt.date(card.openedAt), Fmt.time(card.openedAt)],
                  icons: const [
                    Icons.calendar_today_rounded,
                    Icons.access_time_rounded,
                  ],
                ),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: _Box(
                  label: 'Estimate',
                  lines: [
                    Fmt.money(card.total),
                    if (overdue) 'Overdue',
                  ],
                  tint: p.accentInk,
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          GButton.accent(
            label: 'View Invoice',
            onPressed: () => showBookingDetailsSheet(context, card),
          ),
          if (card.isClosed) ...[
            const SizedBox(height: Gap.sm),
            RateButton(card: card),
          ],
        ],
      ),
    );
  }
}

/// The little framed pair the reference uses for date and estimate.
class _Box extends StatelessWidget {
  const _Box({
    required this.label,
    required this.lines,
    this.icons = const [],
    this.tint,
  });

  final String label;
  final List<String> lines;
  final List<IconData> icons;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: p.surfaceSunken,
        borderRadius: R.all(R.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppType.labelS.c(p.inkMuted)),
          const SizedBox(height: 4),
          for (var i = 0; i < lines.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  if (i < icons.length) ...[
                    Icon(icons[i], size: 13, color: p.accent),
                    const SizedBox(width: 5),
                  ],
                  Expanded(
                    child: Text(
                      lines[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: i == 0
                          ? AppType.labelL.c(tint ?? p.ink)
                          : AppType.bodyS.c(p.inkMuted),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
