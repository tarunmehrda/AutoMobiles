import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/anim/entrance.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/decor.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_state.dart';
import '../../core/widgets/g_surface.dart';
import '../../core/widgets/pressable.dart';
import '../../data/models/entities.dart';
import '../../data/models/enums.dart';
import '../../data/seed/catalog_seed.dart';
import '../../state/app_state.dart';
import '../../state/providers.dart';
import 'widgets/job_timeline.dart';

class TrackingPage extends ConsumerStatefulWidget {
  const TrackingPage({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends ConsumerState<TrackingPage> {
  /// Captured in initState so dispose() never has to touch `ref`.
  AppController? _app;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _app = ref.read(appControllerProvider.notifier);
      _app!.startLiveTracking(widget.bookingId);
    });
  }

  @override
  void dispose() {
    _app?.stopLiveTracking(widget.bookingId);
    super.dispose();
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final booking = ref.watch(bookingProvider(widget.bookingId));
    if (booking == null) {
      return Scaffold(
        backgroundColor: p.canvas,
        appBar: const GHeader(title: 'Booking'),
        body: GEmptyState(
          icon: Icons.receipt_long_rounded,
          title: 'Booking not found',
          message: 'This booking is no longer available.',
          actionLabel: 'My bookings',
          onAction: () => context.go('/garage'),
        ),
      );
    }

    final vehicle = ref.watch(appControllerProvider).vehicleById(booking.vehicleId);
    final inspection = ref.watch(inspectionProvider(booking.id));
    final estimate = ref.watch(latestEstimateProvider(booking.id));
    final invoice = ref.watch(invoiceProvider(booking.id));
    final address = ref.watch(appControllerProvider).addressById(booking.addressId);
    final flow = ref.read(appControllerProvider.notifier).stageFlowFor(booking);

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: booking.code,
        subtitle: '${booking.status.label} • ${Fmt.friendlyDay(booking.slot)}',
        actions: [
          GIconButton(
            icon: Icons.chat_bubble_outline_rounded,
            size: 40,
            onTap: () => context.push('/chat'),
          ),
          GIconButton(
            icon: Icons.more_vert_rounded,
            size: 40,
            onTap: () => _menu(context, booking),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.h2),
        children: [
          Entrance(child: _StageHero(booking: booking, flow: flow)),
          const SizedBox(height: Gap.lg),

          // --- the garage's job card -----------------------------------
          if (booking.jobCard != null) ...[
            Entrance(
              index: 1,
              child: _JobCardStrip(
                card: booking.jobCard!,
                onTap: () => context.push('/booking/${booking.id}/jobcard'),
              ),
            ),
            const SizedBox(height: Gap.lg),
          ],

          // --- quick documents -----------------------------------------
          Entrance(
            index: 1,
            child: Row(
              children: [
                Expanded(
                  child: _DocTile(
                    icon: Icons.fact_check_rounded,
                    label: 'Inspection',
                    value: inspection == null
                        ? 'Pending'
                        : '${inspection.items.length} checks',
                    tone: inspection == null ? GTone.neutral : GTone.info,
                    enabled: inspection != null,
                    onTap: () =>
                        context.push('/booking/${booking.id}/inspection'),
                  ),
                ),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: _DocTile(
                    icon: Icons.request_quote_rounded,
                    label: 'Estimate',
                    value: estimate == null
                        ? 'Pending'
                        : 'v${estimate.version} • ${Fmt.money(estimate.total)}',
                    tone: booking.needsApproval
                        ? GTone.accent
                        : (estimate == null ? GTone.neutral : GTone.success),
                    enabled: estimate != null,
                    badge: booking.needsApproval,
                    onTap: () =>
                        context.push('/booking/${booking.id}/estimate'),
                  ),
                ),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: _DocTile(
                    icon: Icons.receipt_long_rounded,
                    label: 'Invoice',
                    value: invoice == null
                        ? 'Pending'
                        : (invoice.paid ? 'Paid' : Fmt.money(invoice.total)),
                    tone: invoice == null
                        ? GTone.neutral
                        : (invoice.paid ? GTone.success : GTone.warning),
                    enabled: invoice != null,
                    onTap: () =>
                        context.push('/booking/${booking.id}/invoice'),
                  ),
                ),
              ],
            ),
          ),

          // --- timeline --------------------------------------------------
          const SizedBox(height: Gap.xxl),
          Row(
            children: [
              Text('Progress', style: AppType.h1.c(p.ink)),
              const Spacer(),
              if (booking.isLive)
                const GPill(
                    label: 'AUTO-UPDATING',
                    tone: GTone.success,
                    dot: true,
                    pulse: true,
                    compact: true),
            ],
          ),
          const SizedBox(height: Gap.lg),
          Entrance(index: 2, child: JobTimeline(booking: booking, flow: flow)),

          // --- services --------------------------------------------------
          const SizedBox(height: Gap.xxl),
          Text('Booked services', style: AppType.h1.c(p.ink)),
          const SizedBox(height: Gap.md),
          GCard(
            child: Column(
              children: [
                for (final l in booking.lines)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(
                          l.isAddOn
                              ? Icons.add_circle_outline_rounded
                              : Icons.check_circle_rounded,
                          size: 16,
                          color: l.isAddOn ? p.inkMuted : p.success,
                        ),
                        const SizedBox(width: Gap.md),
                        Expanded(
                          child: Text(l.name,
                              style: AppType.bodyM.c(p.inkSoft)),
                        ),
                        Text(Fmt.money(l.price),
                            style: AppType.moneyS.c(p.inkSoft)),
                      ],
                    ),
                  ),
                if (estimate != null && estimate.approvedCount > 0) ...[
                  const SizedBox(height: Gap.sm),
                  const GDashedLine(),
                  const SizedBox(height: Gap.sm),
                  Row(
                    children: [
                      Icon(Icons.add_task_rounded, size: 16, color: p.accent),
                      const SizedBox(width: Gap.md),
                      Expanded(
                        child: Text(
                          '${estimate.approvedCount} approved extra '
                          'item${estimate.approvedCount == 1 ? '' : 's'}',
                          style: AppType.bodyM.c(p.inkSoft),
                        ),
                      ),
                      Text(Fmt.money(estimate.approvedTotal),
                          style: AppType.moneyS.c(p.accentInk)),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // --- details ---------------------------------------------------
          const SizedBox(height: Gap.xxl),
          Text('Booking details', style: AppType.h1.c(p.ink)),
          const SizedBox(height: Gap.md),
          GCard(
            child: Column(
              children: [
                _row(context, Icons.directions_car_rounded, 'Vehicle',
                    vehicle == null
                        ? '—'
                        : '${vehicle.title} • ${vehicle.regNumber}'),
                _row(context, booking.mode.icon, 'Handover',
                    booking.mode.label),
                if (address != null)
                  _row(context, Icons.place_rounded, 'Address',
                      address.shortLine),
                _row(context, Icons.event_rounded, 'Slot',
                    '${Fmt.date(booking.slot)} • ${Fmt.time(booking.slot)}'),
                if (booking.etaAt != null)
                  _row(context, Icons.schedule_rounded, 'Expected ready',
                      Fmt.time(booking.etaAt!)),
                if (booking.notes != null && booking.notes!.isNotEmpty)
                  _row(context, Icons.sticky_note_2_rounded, 'Your note',
                      booking.notes!),
                if (booking.cancelReason != null)
                  _row(context, Icons.cancel_rounded, 'Cancelled',
                      booking.cancelReason!),
              ],
            ),
          ),

          // --- people ----------------------------------------------------
          if (booking.advisor != null || booking.technician != null) ...[
            const SizedBox(height: Gap.xxl),
            Text('Your team', style: AppType.h1.c(p.ink)),
            const SizedBox(height: Gap.md),
            if (booking.advisor != null)
              _PersonCard(
                name: booking.advisor!,
                role: 'Service advisor',
                onCall: () => _launch('tel:${Seed.garage.phone}'),
                onChat: () => context.push('/chat'),
              ),
            if (booking.technician != null) ...[
              const SizedBox(height: Gap.sm),
              _PersonCard(
                name: booking.technician!,
                role: 'Lead technician',
                onCall: () => _launch('tel:${Seed.garage.phone}'),
              ),
            ],
          ],
        ],
      ),
      bottomNavigationBar: _bottomBar(context, booking, invoice),
    );
  }

  Widget? _bottomBar(BuildContext context, Booking booking, Invoice? invoice) {
    if (booking.status == BookingStatus.cancelled) return null;

    if (booking.needsApproval) {
      return GBottomBar(
        child: GButton.accent(
          label: 'Review & approve estimate',
          icon: Icons.how_to_reg_rounded,
          onPressed: () => context.push('/booking/${booking.id}/estimate'),
        ),
      );
    }

    if (invoice != null && !invoice.paid) {
      return GBottomBar(
        child: GButton.accent(
          label: 'Pay now',
          badge: Fmt.money(invoice.total),
          onPressed: () => context.push('/booking/${booking.id}/pay'),
        ),
      );
    }

    if (booking.status == BookingStatus.completed && booking.rating == null) {
      return GBottomBar(
        child: GButton(
          label: 'Rate this service',
          icon: Icons.star_rounded,
          onPressed: () => context.push('/booking/${booking.id}/review'),
        ),
      );
    }

    if (booking.status == BookingStatus.upcoming) {
      return GBottomBar(
        child: Row(
          children: [
            Expanded(
              child: GButton(
                label: 'Reschedule',
                kind: GButtonKind.ghost,
                onPressed: () => _reschedule(booking),
              ),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: GButton(
                label: 'Cancel booking',
                kind: GButtonKind.danger,
                onPressed: () => _cancel(booking),
              ),
            ),
          ],
        ),
      );
    }

    return null;
  }

  void _menu(BuildContext context, Booking booking) {
    GFeedback.sheet<void>(
      context,
      title: 'Booking options',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.h1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (booking.status == BookingStatus.upcoming) ...[
              GTile(
                title: 'Reschedule',
                subtitle: 'Move to another date or time',
                icon: Icons.event_repeat_rounded,
                onTap: () {
                  Navigator.of(context).pop();
                  _reschedule(booking);
                },
              ),
              GTile(
                title: 'Cancel booking',
                subtitle: 'No cancellation charge before handover',
                icon: Icons.cancel_outlined,
                iconColor: context.c.danger,
                onTap: () {
                  Navigator.of(context).pop();
                  _cancel(booking);
                },
              ),
            ],
            GTile(
              title: 'Chat with the garage',
              subtitle: 'Usually replies in a few minutes',
              icon: Icons.chat_bubble_outline_rounded,
              onTap: () {
                Navigator.of(context).pop();
                context.push('/chat');
              },
            ),
            GTile(
              title: 'Call the workshop',
              subtitle: Seed.garage.phone,
              icon: Icons.call_rounded,
              onTap: () {
                Navigator.of(context).pop();
                _launch('tel:${Seed.garage.phone}');
              },
            ),
            GTile(
              title: 'Raise a complaint',
              subtitle: 'We respond within 24 hours',
              icon: Icons.report_gmailerrorred_rounded,
              onTap: () {
                Navigator.of(context).pop();
                context.push('/tickets');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reschedule(Booking booking) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: booking.slot.isAfter(now) ? booking.slot : now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 45)),
      helpText: 'Pick a new date',
    );
    if (date == null || !mounted) return;

    final time = await GFeedback.sheet<String>(
      context,
      title: 'Pick a time',
      subtitle: Fmt.date(date),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.h1),
        child: Wrap(
          spacing: Gap.sm,
          runSpacing: Gap.sm,
          children: [
            for (final t in Seed.slotTimes)
              Pressable(
                onTap: () => Navigator.of(context).pop(t),
                scale: 0.94,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Gap.lg, vertical: Gap.md),
                  decoration: BoxDecoration(
                    color: context.c.surface,
                    borderRadius: R.all(R.md),
                    border: Border.all(color: context.c.line),
                  ),
                  child: Text(t, style: AppType.labelM.c(context.c.ink)),
                ),
              ),
          ],
        ),
      ),
    );
    if (time == null || !mounted) return;

    final parts = time.split(RegExp(r'[: ]'));
    var hour = int.parse(parts[0]);
    if (parts[2] == 'PM' && hour != 12) hour += 12;
    if (parts[2] == 'AM' && hour == 12) hour = 0;

    ref.read(appControllerProvider.notifier).rescheduleBooking(
          booking.id,
          DateTime(date.year, date.month, date.day, hour,
              int.tryParse(parts[1]) ?? 0),
        );
    if (mounted) GFeedback.success(context, 'Booking rescheduled');
  }

  Future<void> _cancel(Booking booking) async {
    final reason = await GFeedback.sheet<String>(
      context,
      title: 'Cancel this booking?',
      subtitle: 'Tell us why so we can improve',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.h1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final r in Seed.cancelReasons)
              GOptionRow(
                label: r,
                selected: false,
                onTap: () => Navigator.of(context).pop(r),
              ),
          ],
        ),
      ),
    );
    if (reason == null || !mounted) return;

    final ok = await GFeedback.confirm(
      context,
      title: 'Confirm cancellation',
      message:
          'Your slot will be released. You can rebook any time — no charges apply.',
      confirmLabel: 'Cancel booking',
      cancelLabel: 'Keep it',
      destructive: true,
      icon: Icons.cancel_outlined,
    );
    if (!ok || !mounted) return;

    ref.read(appControllerProvider.notifier).cancelBooking(booking.id, reason);
    GFeedback.info(context, 'Booking cancelled');
  }

  Widget _row(
      BuildContext context, IconData icon, String label, String value) {
    final p = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: p.inkMuted),
          const SizedBox(width: Gap.md),
          Text(label, style: AppType.bodyM.c(p.inkMuted)),
          const SizedBox(width: Gap.lg),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppType.labelM.c(p.ink),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _StageHero extends StatelessWidget {
  const _StageHero({required this.booking, required this.flow});

  final Booking booking;
  final List<JobStage> flow;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final index = flow.indexOf(booking.stage).clamp(0, flow.length - 1);
    final progress = (index + 1) / flow.length;
    final waiting = booking.needsApproval;
    final done = booking.stage == JobStage.delivered;
    final cancelled = booking.status == BookingStatus.cancelled;

    final accent = cancelled
        ? p.danger
        : (waiting ? p.accent : (done ? p.success : p.volt));

    return Container(
      decoration: BoxDecoration(
        gradient: p.inverseGradient,
        borderRadius: R.all(R.xl),
        boxShadow: Shadows.lifted(p),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: BlueprintPainter(
                  color: p.onInverse, spacing: 26, opacity: 0.05),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Gap.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      height: 52,
                      width: 52,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.16),
                        borderRadius: R.all(R.md),
                      ),
                      child: Icon(
                        cancelled
                            ? Icons.cancel_rounded
                            : booking.stage.icon,
                        color: accent,
                        size: 25,
                      ),
                    ),
                    const SizedBox(width: Gap.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cancelled
                                ? 'Booking cancelled'
                                : booking.stage.label,
                            style: AppType.d3.s(19).c(p.onInverse),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            cancelled
                                ? (booking.cancelReason ?? '')
                                : booking.stage.blurb,
                            style: AppType.bodyS
                                .c(p.onInverse.withValues(alpha: 0.6)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (!cancelled) ...[
                  const SizedBox(height: Gap.xl),
                  ClipRRect(
                    borderRadius: R.all(R.pill),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: progress),
                      duration: Motion.lazy,
                      curve: Motion.enter,
                      builder: (context, v, _) => LinearProgressIndicator(
                        value: v,
                        minHeight: 6,
                        backgroundColor: p.onInverse.withValues(alpha: 0.12),
                        valueColor: AlwaysStoppedAnimation(accent),
                      ),
                    ),
                  ),
                  const SizedBox(height: Gap.md),
                  Row(
                    children: [
                      Text('${index + 1} of ${flow.length} steps',
                          style: AppType.labelS
                              .c(p.onInverse.withValues(alpha: 0.55))),
                      const Spacer(),
                      Text('${(progress * 100).round()}% complete',
                          style: AppType.labelS.c(accent)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DocTile extends StatelessWidget {
  const _DocTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.tone,
    required this.enabled,
    required this.onTap,
    this.badge = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final GTone tone;
  final bool enabled;
  final VoidCallback onTap;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final t = toneOf(context, tone);
    return Pressable(
      onTap: enabled ? onTap : null,
      enabled: enabled,
      scale: 0.96,
      child: Container(
        padding: const EdgeInsets.all(Gap.md),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: R.all(R.md),
          border: Border.all(color: badge ? p.accent : p.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 32,
                  width: 32,
                  decoration:
                      BoxDecoration(color: t.bg, borderRadius: R.all(R.xs)),
                  child: Icon(icon, size: 16, color: t.fg),
                ),
                if (badge)
                  Positioned(
                    right: -3,
                    top: -3,
                    child: Container(
                      height: 9,
                      width: 9,
                      decoration: BoxDecoration(
                        color: p.accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: p.surface, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Gap.sm),
            Text(label, style: AppType.labelM.s(12).c(p.ink)),
            Text(value,
                style: AppType.labelS.s(10).c(p.inkMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.name,
    required this.role,
    this.onCall,
    this.onChat,
  });

  final String name;
  final String role;
  final VoidCallback? onCall;
  final VoidCallback? onChat;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return GCard(
      padding: const EdgeInsets.all(Gap.md),
      child: Row(
        children: [
          GAvatar(initials: Fmt.initials(name), size: 44, tone: GTone.neutral),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppType.labelL.c(p.ink)),
                Text(role, style: AppType.bodyS.c(p.inkMuted)),
              ],
            ),
          ),
          if (onChat != null) ...[
            GIconButton(
              icon: Icons.chat_bubble_outline_rounded,
              size: 38,
              onTap: onChat,
            ),
            const SizedBox(width: Gap.sm),
          ],
          if (onCall != null)
            GIconButton(
              icon: Icons.call_rounded,
              size: 38,
              background: p.successSoft,
              foreground: p.success,
              bordered: false,
              onTap: onCall,
            ),
        ],
      ),
    );
  }
}

/// The garage's job card in one row: their number for this visit and how much
/// they have filled in against it. Tapping opens the full record.
class _JobCardStrip extends StatelessWidget {
  const _JobCardStrip({required this.card, required this.onTap});

  final JobCardRecord card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.c;

    // Only count what the customer would actually find on the page, so the
    // summary never promises more than the screen delivers.
    final bits = <String>[
      if (card.voices.isNotEmpty) '${card.voices.length} reported',
      if (card.accessories.isNotEmpty)
        '${card.accessories.length} accessories',
      if (card.marks.isNotEmpty) '${card.marks.length} marks',
      if (card.photos.isNotEmpty) '${card.photos.length} photos',
    ];

    return Pressable(
      onTap: onTap,
      scale: 0.985,
      child: Container(
        padding: const EdgeInsets.all(Gap.lg),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: R.all(R.lg),
          border: Border.all(color: p.line),
          boxShadow: Shadows.soft(p),
        ),
        child: Row(
          children: [
            Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: p.accentSoft,
                borderRadius: R.all(R.sm),
              ),
              child:
                  Icon(Icons.description_rounded, size: 20, color: p.accentInk),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Job card', style: AppType.labelL.c(p.ink)),
                      const SizedBox(width: Gap.sm),
                      Text(card.number,
                          style: AppType.moneyS.c(p.accentInk)),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    bits.isEmpty
                        ? 'Opened ${Fmt.dateTime(card.openedAt)}'
                        : bits.join('  •  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.bodyS.c(p.inkMuted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: p.inkFaint, size: 22),
          ],
        ),
      ),
    );
  }
}
