import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/anim/entrance.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/decor.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_image.dart';
import '../../core/widgets/g_state.dart';
import '../../core/widgets/g_surface.dart';
import '../../data/models/entities.dart';
import '../../data/models/enums.dart';
import '../../state/app_state.dart';
import '../../state/providers.dart';

/// The garage's job card, as the customer sees it.
///
/// This is the workshop's own record of the visit — the number on every
/// document they hand over, what you told them, what went in with the car,
/// what was already damaged, and when the car is due back. It is read-only on
/// purpose: it is their copy, mirrored so both sides quote the same thing.
class JobCardPage extends ConsumerWidget {
  const JobCardPage({super.key, required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final booking = ref.watch(bookingProvider(bookingId));
    final card = booking?.jobCard;
    final vehicle = ref.watch(
        appControllerProvider.select((s) => s.vehicleById(booking?.vehicleId)));

    if (booking == null || card == null) {
      return Scaffold(
        backgroundColor: p.canvas,
        appBar: const GHeader(title: 'Job card'),
        body: const GEmptyState(
          icon: Icons.description_outlined,
          title: 'No job card yet',
          message:
              'The garage opens a job card when your vehicle is received. '
              'Everything they record against it shows up here.',
        ),
      );
    }

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Job card',
        subtitle: card.number,
        actions: [
          GIconButton(
            icon: Icons.ios_share_rounded,
            size: 40,
            onTap: () => SharePlus.instance.share(
              ShareParams(
                text: _summary(card, booking, vehicle),
                subject: 'Job card ${card.number}',
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.h2),
        children: [
          Entrance(
            child: _Header(card: card, booking: booking, vehicle: vehicle),
          ),

          // --- what you told them --------------------------------------
          if (card.voices.isNotEmpty) ...[
            const _Heading('What you told us', Icons.record_voice_over_rounded),
            Entrance(
              index: 1,
              child: GCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < card.voices.length; i++)
                      Padding(
                        padding: EdgeInsets.only(
                            bottom: i == card.voices.length - 1 ? 0 : Gap.sm),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 20,
                              child: Text('${i + 1}',
                                  style: AppType.moneyS
                                      .s(11.5)
                                      .c(p.inkFaint)),
                            ),
                            Expanded(
                              child: Text(card.voices[i],
                                  style: AppType.bodyM.c(p.inkSoft)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],

          // --- accessories ---------------------------------------------
          if (card.accessories.isNotEmpty) ...[
            const _Heading('Handed over with the car', Icons.luggage_rounded),
            Entrance(
              index: 2,
              child: GCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: Gap.sm,
                      runSpacing: Gap.sm,
                      children: [
                        for (final a in card.accessories)
                          GTag(
                            label: a,
                            icon: Icons.check_rounded,
                            tone: GTone.success,
                          ),
                      ],
                    ),
                    const SizedBox(height: Gap.md),
                    Text(
                      'Checked back against this list when the car is '
                      'returned to you.',
                      style: AppType.bodyS.c(p.inkFaint),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // --- damage on arrival ---------------------------------------
          if (card.marks.isNotEmpty) ...[
            const _Heading(
                'Damage noted on arrival', Icons.car_crash_rounded),
            Entrance(
              index: 3,
              child: GCard(
                child: Column(
                  children: [
                    Text(
                      'Marked by the workshop before any work started, so '
                      'nothing already there gets confused with new damage.',
                      style: AppType.bodyS.c(p.inkMuted),
                    ),
                    const SizedBox(height: Gap.lg),
                    AspectRatio(
                      aspectRatio: 0.78,
                      child: LayoutBuilder(
                        builder: (context, box) => Stack(
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                painter: BodyDiagramPainter(
                                  line: p.inkFaint,
                                  fill: p.surfaceSunken,
                                ),
                              ),
                            ),
                            for (final m in card.marks)
                              Positioned(
                                left: m.dx * box.maxWidth - 12,
                                top: m.dy * box.maxHeight - 12,
                                child: Tooltip(
                                  message: m.note.isEmpty
                                      ? m.kind.label
                                      : '${m.kind.label} — ${m.note}',
                                  child: Container(
                                    height: 24,
                                    width: 24,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: _markColor(p, m.kind),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: p.surface, width: 2),
                                      boxShadow: Shadows.soft(p),
                                    ),
                                    child: Text(
                                      m.kind.label.substring(0, 1),
                                      style: AppType.labelS
                                          .s(10)
                                          .c(Colors.white),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: Gap.md),
                    for (final m in card.marks)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Gap.sm),
                        child: Row(
                          children: [
                            Container(
                              height: 10,
                              width: 10,
                              decoration: BoxDecoration(
                                color: _markColor(p, m.kind),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: Gap.md),
                            Text(m.kind.label,
                                style: AppType.labelM.c(p.ink)),
                            const SizedBox(width: Gap.sm),
                            Expanded(
                              child: Text(
                                m.note,
                                style: AppType.bodyS.c(p.inkMuted),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],

          // --- photos ---------------------------------------------------
          if (card.photos.isNotEmpty) ...[
            const _Heading('Photos from the workshop',
                Icons.photo_camera_rounded),
            Entrance(
              index: 4,
              child: SizedBox(
                height: 110,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: card.photos.length,
                  separatorBuilder: (_, _) => const SizedBox(width: Gap.sm),
                  itemBuilder: (context, i) => GImage(
                    url: card.photos[i],
                    height: 110,
                    width: 146,
                    fallbackIcon: Icons.photo_camera_rounded,
                  ),
                ),
              ),
            ),
          ],

          // --- the garage's note ----------------------------------------
          if (card.workNote.trim().isNotEmpty) ...[
            const _Heading(
                'The workshop\'s note', Icons.sticky_note_2_rounded),
            Entrance(
              index: 5,
              child: GCard(
                color: p.surfaceAlt,
                child: Text(card.workNote,
                    style: AppType.bodyM.c(p.inkSoft)),
              ),
            ),
          ],

          // --- next service ---------------------------------------------
          if (card.nextServiceAt != null) ...[
            const _Heading('Next service', Icons.event_repeat_rounded),
            Entrance(
              index: 6,
              child: _NextService(card: card),
            ),
          ],

          const SizedBox(height: Gap.xxl),
          Entrance(
            index: 7,
            child: GButton.outline(
              label: 'Back to tracking',
              expand: true,
              size: GButtonSize.lg,
              icon: Icons.timeline_rounded,
              onPressed: () => context.pop(),
            ),
          ),
        ],
      ),
    );
  }

  static Color _markColor(AppPalette p, MarkKind kind) => switch (kind) {
        MarkKind.scratch => p.warning,
        MarkKind.dent => p.accent,
        MarkKind.crack => p.danger,
        MarkKind.rust => p.info,
      };

  String _summary(JobCardRecord card, Booking booking, Vehicle? vehicle) {
    final lines = <String>[
      'Job card ${card.number}',
      if (vehicle != null) '${vehicle.title} • ${vehicle.regNumber}',
      'Opened ${Fmt.fullDateTime(card.openedAt)}',
      'Odometer ${Fmt.km(card.odometerKm)} • Fuel ${card.fuelPercent}%',
      if (card.voices.isNotEmpty) ...[
        '',
        'Reported:',
        ...card.voices.map((v) => '- $v'),
      ],
      if (card.accessories.isNotEmpty) ...[
        '',
        'Handed over: ${card.accessories.join(', ')}',
      ],
      if (card.nextServiceAt != null) ...[
        '',
        'Next service due ${Fmt.date(card.nextServiceAt!)}',
      ],
    ];
    return lines.join('\n');
  }
}

// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({
    required this.card,
    required this.booking,
    required this.vehicle,
  });

  final JobCardRecord card;
  final Booking booking;
  final Vehicle? vehicle;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final late = card.promisedAt != null &&
        card.promisedAt!.isBefore(DateTime.now()) &&
        booking.stage != JobStage.delivered;

    return Container(
      padding: const EdgeInsets.all(Gap.xl),
      decoration: BoxDecoration(
        gradient: p.inverseGradient,
        borderRadius: R.all(R.xl),
        boxShadow: Shadows.lifted(p),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: R.all(R.xl),
              child: CustomPaint(
                painter:
                    BlueprintPainter(color: p.onInverse, opacity: 0.06),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('JOB CARD',
                      style: AppType.over
                          .c(p.onInverse.withValues(alpha: 0.55))),
                  const Spacer(),
                  GPill(
                    label: booking.stage.label,
                    tone: GTone.volt,
                    compact: true,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(card.number, style: AppType.d1.c(p.onInverse)),
              if (vehicle != null) ...[
                const SizedBox(height: 2),
                Text(
                  '${vehicle!.title} • ${Fmt.plate(vehicle!.regNumber)}',
                  style: AppType.bodyM
                      .c(p.onInverse.withValues(alpha: 0.7)),
                ),
              ],
              const SizedBox(height: Gap.lg),
              Row(
                children: [
                  Expanded(
                    child: _HeaderStat(
                      label: 'Odometer',
                      value: Fmt.km(card.odometerKm),
                      icon: Icons.speed_rounded,
                    ),
                  ),
                  Container(
                    height: 32,
                    width: 1,
                    color: p.onInverse.withValues(alpha: 0.12),
                  ),
                  Expanded(
                    child: _HeaderStat(
                      label: 'Fuel in',
                      value: '${card.fuelPercent}%',
                      icon: Icons.local_gas_station_rounded,
                    ),
                  ),
                  Container(
                    height: 32,
                    width: 1,
                    color: p.onInverse.withValues(alpha: 0.12),
                  ),
                  Expanded(
                    child: _HeaderStat(
                      label: 'Opened',
                      value: Fmt.time(card.openedAt),
                      icon: Icons.schedule_rounded,
                    ),
                  ),
                ],
              ),
              if (card.mechanic != null || card.promisedAt != null) ...[
                const SizedBox(height: Gap.lg),
                Wrap(
                  spacing: Gap.sm,
                  runSpacing: Gap.sm,
                  children: [
                    if (card.mechanic != null)
                      GPill(
                        label: 'Technician ${card.mechanic}',
                        tone: GTone.neutral,
                        icon: Icons.engineering_rounded,
                        compact: true,
                      ),
                    if (card.promisedAt != null)
                      GPill(
                        label: late
                            ? 'Was due ${Fmt.relative(card.promisedAt!)}'
                            : 'Ready by ${Fmt.dateTime(card.promisedAt!)}',
                        tone: late ? GTone.warning : GTone.success,
                        icon: Icons.event_available_rounded,
                        compact: true,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon,
                  size: 12, color: p.onInverse.withValues(alpha: 0.5)),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.over
                      .s(9)
                      .c(p.onInverse.withValues(alpha: 0.5)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(value, style: AppType.money.s(15).c(p.onInverse)),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.title, this.icon);

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, Gap.xxl, 0, Gap.md),
      child: Row(
        children: [
          Icon(icon, size: 17, color: p.accentInk),
          const SizedBox(width: Gap.sm),
          Text(title, style: AppType.h1.c(p.ink)),
        ],
      ),
    );
  }
}

class _NextService extends StatelessWidget {
  const _NextService({required this.card});

  final JobCardRecord card;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final due = card.nextServiceAt!;
    final days = due.difference(DateTime.now()).inDays;
    final soon = days <= 15;

    return GCard(
      color: soon ? p.warningSoft : p.surface,
      borderColor: soon ? p.warning.withValues(alpha: 0.3) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(Fmt.date(due),
                        style: AppType.d3
                            .c(soon ? p.warning : p.ink)),
                    Text(
                      days < 0
                          ? 'Overdue by ${-days} day${days == -1 ? '' : 's'}'
                          : 'In $days day${days == 1 ? '' : 's'}',
                      style: AppType.bodyS.c(p.inkMuted),
                    ),
                  ],
                ),
              ),
              if (card.nextServiceKm != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('OR AT',
                        style: AppType.over.s(9.5).c(p.inkFaint)),
                    Text(Fmt.km(card.nextServiceKm!),
                        style: AppType.money.c(p.ink)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: Gap.md),
          Text(
            'Whichever comes first. The garage will remind you before the '
            'date, and you can book straight from Home.',
            style: AppType.bodyS.c(p.inkMuted),
          ),
          const SizedBox(height: Gap.md),
          GButton(
            label: 'Book this service',
            kind: soon ? GButtonKind.accent : GButtonKind.ghost,
            size: GButtonSize.md,
            icon: Icons.event_available_rounded,
            onPressed: () => context.go('/book'),
          ),
        ],
      ),
    );
  }
}

/// A plan view of a car, painted so the marks land on a panel rather than a
/// photograph of somebody else's model.
class BodyDiagramPainter extends CustomPainter {
  BodyDiagramPainter({required this.line, required this.fill});

  final Color line;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round;
    final body = Paint()
      ..color = fill
      ..style = PaintingStyle.fill;

    final shell = RRect.fromRectAndCorners(
      Rect.fromLTWH(w * 0.18, h * 0.06, w * 0.64, h * 0.88),
      topLeft: Radius.circular(w * 0.22),
      topRight: Radius.circular(w * 0.22),
      bottomLeft: Radius.circular(w * 0.16),
      bottomRight: Radius.circular(w * 0.16),
    );
    canvas.drawRRect(shell, body);
    canvas.drawRRect(shell, stroke);

    final glass = Paint()
      ..color = line.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    for (final rect in [
      Rect.fromLTWH(w * 0.26, h * 0.17, w * 0.48, h * 0.10),
      Rect.fromLTWH(w * 0.24, h * 0.30, w * 0.52, h * 0.26),
      Rect.fromLTWH(w * 0.26, h * 0.60, w * 0.48, h * 0.10),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(w * 0.05)),
        glass,
      );
    }

    final split = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (final y in [0.30, 0.43, 0.56, 0.70]) {
      canvas.drawLine(
          Offset(w * 0.18, h * y), Offset(w * 0.82, h * y), split);
    }

    final wheel = Paint()
      ..color = line.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;
    for (final spot in [
      [0.14, 0.24],
      [0.86, 0.24],
      [0.14, 0.70],
      [0.86, 0.70],
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(w * spot[0], h * spot[1]),
            width: w * 0.09,
            height: h * 0.11,
          ),
          Radius.circular(w * 0.02),
        ),
        wheel,
      );
    }

    final label = TextPainter(
      text: TextSpan(
        text: 'FRONT',
        style: TextStyle(
          color: line,
          fontSize: math.max(8, w * 0.045),
          letterSpacing: 1.4,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, Offset(w / 2 - label.width / 2, 0));
  }

  @override
  bool shouldRepaint(covariant BodyDiagramPainter old) =>
      old.line != line || old.fill != fill;
}
