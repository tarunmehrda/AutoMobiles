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
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_state.dart';
import '../../data/models/enums.dart';
import '../../data/seed/catalog_seed.dart';
import '../../state/providers.dart';

class PaymentSuccessPage extends ConsumerStatefulWidget {
  const PaymentSuccessPage({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<PaymentSuccessPage> createState() =>
      _PaymentSuccessPageState();
}

class _PaymentSuccessPageState extends ConsumerState<PaymentSuccessPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final invoice = ref.watch(invoiceProvider(widget.bookingId));
    final booking = ref.watch(bookingProvider(widget.bookingId));

    if (invoice == null || booking == null) {
      return Scaffold(
        backgroundColor: p.canvas,
        body: GEmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Receipt unavailable',
          message: 'We could not find this payment.',
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
        backgroundColor: p.inverse,
        body: Stack(
          children: [
            Positioned.fill(child: _Confetti(controller: _c)),
            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                          Gap.page, Gap.h2, Gap.page, Gap.xxl),
                      children: [
                        Center(
                          child: Entrance(
                            scaleFrom: 0.6,
                            duration: Motion.lazy,
                            child: Container(
                              height: 88,
                              width: 88,
                              decoration: BoxDecoration(
                                color: p.volt,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: p.volt.withValues(alpha: 0.35),
                                    blurRadius: 40,
                                    offset: const Offset(0, 14),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.check_rounded,
                                  size: 46, color: Color(0xFF10160A)),
                            ),
                          ),
                        ),
                        const SizedBox(height: Gap.xxl),
                        Entrance(
                          index: 1,
                          child: Column(
                            children: [
                              Text('Payment successful',
                                  textAlign: TextAlign.center,
                                  style: AppType.d1.s(30).c(p.onInverse)),
                              const SizedBox(height: Gap.sm),
                              Text(
                                'Thanks — your ${booking.code} job is closed.',
                                textAlign: TextAlign.center,
                                style: AppType.bodyL.c(
                                    p.onInverse.withValues(alpha: 0.65)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: Gap.h1),
                        Entrance(
                          index: 2,
                          scaleFrom: 0.96,
                          child: Container(
                            padding: const EdgeInsets.all(Gap.xl),
                            decoration: BoxDecoration(
                              color: p.onInverse.withValues(alpha: 0.06),
                              borderRadius: R.all(R.xl),
                              border: Border.all(
                                  color:
                                      p.onInverse.withValues(alpha: 0.1)),
                            ),
                            child: Column(
                              children: [
                                Text(Fmt.money(invoice.total),
                                    style:
                                        AppType.moneyL.s(38).c(p.onInverse)),
                                const SizedBox(height: Gap.xl),
                                _row(context, 'Paid via',
                                    invoice.method?.label ?? '—'),
                                _row(context, 'Transaction ID',
                                    invoice.transactionId ?? '—'),
                                _row(
                                    context,
                                    'Date & time',
                                    invoice.paidAt == null
                                        ? '—'
                                        : Fmt.fullDateTime(invoice.paidAt!)),
                                _row(context, 'Invoice', invoice.number),
                                _row(context, 'Garage', Seed.garage.name),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: Gap.xl),
                        Entrance(
                          index: 3,
                          child: Row(
                            children: [
                              Expanded(
                                child: _GhostButton(
                                  label: 'Invoice',
                                  icon: Icons.receipt_long_rounded,
                                  onTap: () => context.push(
                                      '/booking/${widget.bookingId}/invoice'),
                                ),
                              ),
                              const SizedBox(width: Gap.sm),
                              Expanded(
                                child: _GhostButton(
                                  label: 'Share',
                                  icon: Icons.ios_share_rounded,
                                  onTap: () => SharePlus.instance.share(
                                    ShareParams(
                                      text:
                                          'Paid ${Fmt.money(invoice.total)} at ${Seed.garage.name}. '
                                          'Invoice ${invoice.number}, txn ${invoice.transactionId}.',
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: Gap.sm),
                              Expanded(
                                child: _GhostButton(
                                  label: 'Copy ID',
                                  icon: Icons.content_copy_rounded,
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(
                                        text: invoice.transactionId ?? ''));
                                    GFeedback.toast(
                                        context, 'Transaction ID copied',
                                        icon: Icons.check_rounded);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        Gap.page, 0, Gap.page, Gap.lg),
                    child: Column(
                      children: [
                        GButton(
                          label: 'Rate your experience',
                          kind: GButtonKind.volt,
                          icon: Icons.star_rounded,
                          onPressed: () => context.pushReplacement(
                              '/booking/${widget.bookingId}/review'),
                        ),
                        const SizedBox(height: Gap.sm),
                        TextButton(
                          onPressed: () => context.go('/home'),
                          child: Text('Back to home',
                              style: AppType.labelM.c(
                                  p.onInverse.withValues(alpha: 0.7))),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final p = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(label,
              style:
                  AppType.bodyM.c(p.onInverse.withValues(alpha: 0.55))),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppType.labelM.c(p.onInverse),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 62,
        decoration: BoxDecoration(
          color: p.onInverse.withValues(alpha: 0.06),
          borderRadius: R.all(R.md),
          border: Border.all(color: p.onInverse.withValues(alpha: 0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: p.onInverse),
            const SizedBox(height: 4),
            Text(label, style: AppType.labelS.c(p.onInverse)),
          ],
        ),
      ),
    );
  }
}

/// Lightweight celebratory burst — no package, no image assets.
class _Confetti extends StatelessWidget {
  const _Confetti({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => CustomPaint(
        painter: _ConfettiPainter(
          t: controller.value,
          colors: [p.volt, p.accent, p.info, p.success],
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.t, required this.colors});

  final double t;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    if (t >= 1) return;
    final origin = Offset(size.width / 2, size.height * 0.24);
    for (var i = 0; i < 42; i++) {
      final angle = (i / 42) * 6.28318 + i * 0.37;
      final speed = 120 + (i % 7) * 46;
      final eased = Curves.easeOutCubic.transform(t.clamp(0.0, 1.0));
      final dx = origin.dx + speed * eased * (i.isEven ? 1 : -1) * 0.6 *
          (0.5 + (i % 5) / 5);
      final dy = origin.dy +
          (speed * eased * (angle.remainder(1.6) - 0.6)) +
          260 * eased * eased;
      final opacity = (1 - t).clamp(0.0, 1.0);
      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(angle + t * 6);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: 7, height: 11),
          const Radius.circular(2),
        ),
        Paint()
          ..color = colors[i % colors.length].withValues(alpha: opacity * 0.9),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}
