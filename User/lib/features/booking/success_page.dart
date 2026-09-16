import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/anim/entrance.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/decor.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_state.dart';
import '../../core/widgets/g_surface.dart';
import '../../core/widgets/pressable.dart';
import '../../data/models/enums.dart';
import '../../data/seed/catalog_seed.dart';
import '../../state/providers.dart';

class SuccessPage extends ConsumerStatefulWidget {
  const SuccessPage({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<SuccessPage> createState() => _SuccessPageState();
}

class _SuccessPageState extends ConsumerState<SuccessPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final booking = ref.watch(bookingProvider(widget.bookingId));
    final vehicle = ref.watch(activeVehicleProvider);
    final address = ref
        .watch(addressesProvider)
        .where((a) => a.id == booking?.addressId)
        .firstOrNull;

    if (booking == null) {
      return Scaffold(
        backgroundColor: p.canvas,
        body: GEmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Booking not found',
          message: 'It may have been cancelled.',
          actionLabel: 'Go home',
          onAction: () => context.go('/home'),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/home');
      },
      child: Scaffold(
        backgroundColor: p.canvas,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                      Gap.page, Gap.xxl, Gap.page, Gap.xxl),
                  children: [
                    Center(child: _Tick(controller: _c)),
                    const SizedBox(height: Gap.xxl),
                    Entrance(
                      delay: const Duration(milliseconds: 300),
                      child: Column(
                        children: [
                          Text('Booking confirmed',
                              textAlign: TextAlign.center,
                              style: AppType.d1.s(30).c(p.ink)),
                          const SizedBox(height: Gap.sm),
                          Text(
                            'We have reserved your slot. You will get a reminder '
                            'the day before.',
                            textAlign: TextAlign.center,
                            style: AppType.bodyL.c(p.inkMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Gap.h1),

                    // --- ticket -------------------------------------------
                    Entrance(
                      delay: const Duration(milliseconds: 420),
                      scaleFrom: 0.96,
                      child: _Ticket(
                        code: booking.code,
                        rows: [
                          ('Vehicle', vehicle?.title ?? '—'),
                          ('Registration', vehicle?.regNumber ?? '—'),
                          (
                            'Date',
                            '${Fmt.friendlyDay(booking.slot)}, ${Fmt.date(booking.slot)}'
                          ),
                          ('Time', Fmt.time(booking.slot)),
                          ('Handover', booking.mode.label),
                          if (address != null) ('Pickup from', address.shortLine),
                          ('Services', '${booking.lines.length} selected'),
                          ('Estimated total', Fmt.money(booking.total)),
                        ],
                      ),
                    ),
                    const SizedBox(height: Gap.xl),

                    // --- what happens next ---------------------------------
                    Entrance(
                      delay: const Duration(milliseconds: 560),
                      child: GCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('WHAT HAPPENS NEXT',
                                style: AppType.over.c(p.inkFaint)),
                            const SizedBox(height: Gap.md),
                            for (final s in const [
                              (
                                Icons.phone_in_talk_rounded,
                                'We confirm by call',
                                'Your advisor rings within 30 minutes'
                              ),
                              (
                                Icons.local_shipping_rounded,
                                'Handover',
                                'Driver or drive-in, exactly at your slot'
                              ),
                              (
                                Icons.fact_check_rounded,
                                'Free 38-point inspection',
                                'Photos and findings land in this app'
                              ),
                              (
                                Icons.how_to_reg_rounded,
                                'You approve the work',
                                'Nothing extra happens without your yes'
                              ),
                            ])
                              Padding(
                                padding: const EdgeInsets.only(bottom: Gap.md),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(s.$1, size: 18, color: p.accentInk),
                                    const SizedBox(width: Gap.md),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(s.$2,
                                              style:
                                                  AppType.labelM.c(p.ink)),
                                          Text(s.$3,
                                              style: AppType.bodyS
                                                  .c(p.inkMuted)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: Gap.lg),
                    Entrance(
                      delay: const Duration(milliseconds: 660),
                      child: Row(
                        children: [
                          Expanded(
                            child: GButton.outline(
                              label: 'Share',
                              icon: Icons.ios_share_rounded,
                              expand: true,
                              onPressed: () => SharePlus.instance.share(
                                ShareParams(
                                  text:
                                      'Booked ${booking.lines.map((e) => e.name).join(', ')} '
                                      'at ${Seed.garage.name} on '
                                      '${Fmt.date(booking.slot)} at ${Fmt.time(booking.slot)}. '
                                      'Booking ${booking.code}.',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: Gap.sm),
                          Expanded(
                            child: GButton.outline(
                              label: 'Contact',
                              icon: Icons.chat_bubble_outline_rounded,
                              expand: true,
                              onPressed: () => context.push('/chat'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              GBottomBar(
                child: Row(
                  children: [
                    Expanded(
                      child: GButton(
                        label: 'Go home',
                        kind: GButtonKind.ghost,
                        onPressed: () => context.go('/home'),
                      ),
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      flex: 2,
                      child: GButton.accent(
                        label: 'Track booking',
                        trailingIcon: Icons.arrow_forward_rounded,
                        onPressed: () {
                          context.go('/home');
                          context.push('/booking/${booking.id}');
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Draws the tick stroke on, then settles with a soft ring.
class _Tick extends StatelessWidget {
  const _Tick({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final ring = Curves.easeOutBack
            .transform(Curves.easeOut.transform(
                (controller.value / 0.55).clamp(0.0, 1.0)));
        final tick =
            ((controller.value - 0.35) / 0.45).clamp(0.0, 1.0);
        return SizedBox(
          height: 108,
          width: 108,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: ring,
                child: Container(
                  height: 108,
                  width: 108,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      p.success.withValues(alpha: 0.18),
                      p.success.withValues(alpha: 0.02),
                    ]),
                  ),
                ),
              ),
              Transform.scale(
                scale: ring,
                child: Container(
                  height: 74,
                  width: 74,
                  decoration: BoxDecoration(
                    color: p.success,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: p.success.withValues(alpha: 0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                ),
              ),
              CustomPaint(
                size: const Size(40, 40),
                painter: _TickPainter(progress: tick, color: Colors.white),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TickPainter extends CustomPainter {
  _TickPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final path = Path()
      ..moveTo(size.width * 0.16, size.height * 0.52)
      ..lineTo(size.width * 0.42, size.height * 0.76)
      ..lineTo(size.width * 0.84, size.height * 0.26);

    final metrics = path.computeMetrics().toList();
    final out = Path();
    for (final m in metrics) {
      out.addPath(m.extractPath(0, m.length * progress), Offset.zero);
    }
    canvas.drawPath(
      out,
      Paint()
        ..color = color
        ..strokeWidth = 4.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _TickPainter old) => old.progress != progress;
}

class _Ticket extends StatelessWidget {
  const _Ticket({required this.code, required this.rows});

  final String code;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return ClipPath(
      clipper: NotchedCardClipper(notchY: 78, radius: 13, corner: R.xl),
      child: Container(
        decoration: BoxDecoration(color: p.surface),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Gap.xl),
              decoration: BoxDecoration(gradient: p.inverseGradient),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('BOOKING ID',
                            style: AppType.over
                                .c(p.onInverse.withValues(alpha: 0.5))),
                        const SizedBox(height: 4),
                        Text(code,
                            style: AppType.h1
                                .c(p.onInverse)
                                .copyWith(letterSpacing: 0.6)),
                      ],
                    ),
                  ),
                  Pressable(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: code));
                      GFeedback.toast(context, 'Booking ID copied',
                          icon: Icons.content_copy_rounded);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(Gap.sm),
                      decoration: BoxDecoration(
                        color: p.onInverse.withValues(alpha: 0.1),
                        borderRadius: R.all(R.xs),
                      ),
                      child: Icon(Icons.content_copy_rounded,
                          size: 16, color: p.onInverse),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Gap.xl, Gap.xl, Gap.xl, Gap.lg),
              child: Column(
                children: [
                  for (final r in rows)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.$1, style: AppType.bodyM.c(p.inkMuted)),
                          const Spacer(),
                          Flexible(
                            child: Text(
                              r.$2,
                              textAlign: TextAlign.end,
                              style: AppType.labelM.c(p.ink),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: Gap.md),
                  const GDashedLine(),
                  const SizedBox(height: Gap.md),
                  Row(
                    children: [
                      Icon(Icons.qr_code_2_rounded, size: 34, color: p.ink),
                      const SizedBox(width: Gap.md),
                      Expanded(
                        child: Text(
                          'Show this ID at the gate, or just give your '
                          'registration number.',
                          style: AppType.bodyS.c(p.inkMuted),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
