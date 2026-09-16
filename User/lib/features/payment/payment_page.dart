import 'package:flutter/material.dart';
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
import '../../core/widgets/g_state.dart';
import '../../core/widgets/g_surface.dart';
import '../../core/widgets/pressable.dart';
import '../../data/models/enums.dart';
import '../../state/app_state.dart';
import '../../state/providers.dart';

class PaymentPage extends ConsumerStatefulWidget {
  const PaymentPage({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends ConsumerState<PaymentPage> {
  PaymentMethod _method = PaymentMethod.upi;
  String _upiApp = 'Google Pay';
  bool _paying = false;

  static const _upiApps = ['Google Pay', 'PhonePe', 'Paytm', 'Other UPI'];

  Future<void> _pay(int amount) async {
    setState(() => _paying = true);
    final invoice = await ref
        .read(appControllerProvider.notifier)
        .payInvoice(widget.bookingId, _method);
    if (!mounted) return;
    setState(() => _paying = false);
    if (invoice == null) {
      GFeedback.error(context, 'Payment could not be completed. Try again.');
      return;
    }
    ref.read(appControllerProvider.notifier).completeBooking(widget.bookingId);
    context.pushReplacement('/booking/${widget.bookingId}/paid');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final invoice = ref.watch(invoiceProvider(widget.bookingId));
    final booking = ref.watch(bookingProvider(widget.bookingId));

    if (invoice == null || booking == null) {
      return Scaffold(
        backgroundColor: p.canvas,
        appBar: const GHeader(title: 'Payment'),
        body: GEmptyState(
          icon: Icons.payments_rounded,
          title: 'Nothing to pay yet',
          message: 'The invoice is raised once the work is complete.',
          actionLabel: 'Back',
          onAction: () => context.pop(),
        ),
      );
    }

    if (invoice.paid) {
      return Scaffold(
        backgroundColor: p.canvas,
        appBar: const GHeader(title: 'Payment'),
        body: GEmptyState(
          icon: Icons.verified_rounded,
          title: 'Already paid',
          message:
              '${Fmt.money(invoice.total)} was settled via ${invoice.method?.label ?? 'card'}.',
          actionLabel: 'View invoice',
          tone: p.success,
          onAction: () => context.pushReplacement(
              '/booking/${widget.bookingId}/invoice'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Pay ${Fmt.money(invoice.total)}',
        subtitle: invoice.number,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.h2),
        children: [
          // --- amount ---------------------------------------------------
          Entrance(
            child: Container(
              padding: const EdgeInsets.all(Gap.xl),
              decoration: BoxDecoration(
                gradient: p.inverseGradient,
                borderRadius: R.all(R.xl),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AMOUNT DUE',
                      style: AppType.over
                          .c(p.onInverse.withValues(alpha: 0.5))),
                  const SizedBox(height: Gap.sm),
                  Text(Fmt.money(invoice.total),
                      style: AppType.moneyL.s(36).c(p.onInverse)),
                  const SizedBox(height: Gap.md),
                  Row(
                    children: [
                      Icon(Icons.lock_rounded,
                          size: 13,
                          color: p.onInverse.withValues(alpha: 0.5)),
                      const SizedBox(width: 5),
                      Text(
                        'Secured payment • ${booking.code}',
                        style: AppType.labelS
                            .c(p.onInverse.withValues(alpha: 0.55)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: Gap.xl),
          Text('Pay using', style: AppType.h1.c(p.ink)),
          const SizedBox(height: Gap.md),

          for (final m in PaymentMethod.values) ...[
            Entrance(
              index: PaymentMethod.values.indexOf(m),
              stagger: const Duration(milliseconds: 40),
              child: _MethodCard(
                method: m,
                selected: _method == m,
                onTap: () => setState(() => _method = m),
                child: m == PaymentMethod.upi && _method == PaymentMethod.upi
                    ? Padding(
                        padding: const EdgeInsets.only(top: Gap.md),
                        child: Wrap(
                          spacing: Gap.sm,
                          runSpacing: Gap.sm,
                          children: [
                            for (final app in _upiApps)
                              Pressable(
                                onTap: () => setState(() => _upiApp = app),
                                scale: 0.94,
                                child: AnimatedContainer(
                                  duration: Motion.fast,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: Gap.md, vertical: Gap.sm),
                                  decoration: BoxDecoration(
                                    color: _upiApp == app
                                        ? p.ink
                                        : p.surfaceSunken,
                                    borderRadius: R.all(R.sm),
                                    border: Border.all(
                                        color: _upiApp == app
                                            ? p.ink
                                            : p.line),
                                  ),
                                  child: Text(
                                    app,
                                    style: AppType.labelS.c(_upiApp == app
                                        ? (p.isDark ? p.canvas : Colors.white)
                                        : p.inkSoft),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: Gap.sm),
          ],

          const SizedBox(height: Gap.lg),

          // --- breakdown --------------------------------------------------
          GCard(
            child: Column(
              children: [
                GKeyValue(
                    label: 'Services & parts',
                    value: Fmt.money(invoice.subtotal)),
                if (invoice.pickupFee > 0)
                  GKeyValue(
                      label: 'Pickup & drop',
                      value: Fmt.money(invoice.pickupFee)),
                if (invoice.discount > 0)
                  GKeyValue(
                    label: 'Discount',
                    value: '− ${Fmt.money(invoice.discount)}',
                    valueColor: p.success,
                  ),
                GKeyValue(label: 'GST 18%', value: Fmt.money(invoice.gst)),
                const SizedBox(height: Gap.sm),
                const GDashedLine(),
                const SizedBox(height: Gap.sm),
                GKeyValue(
                  label: 'Total',
                  value: Fmt.money(invoice.total),
                  emphasize: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: Gap.lg),
          Row(
            children: [
              Icon(Icons.shield_rounded, size: 15, color: p.success),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Payments are attached to invoice ${invoice.number}. '
                  'A receipt lands in this app the moment it clears.',
                  style: AppType.bodyS.c(p.inkMuted),
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: GBottomBar(
        child: GButton.accent(
          label: _method.isOnline
              ? 'Pay ${Fmt.money(invoice.total)}'
              : 'Confirm ${_method.label.toLowerCase()}',
          icon: _method.isOnline ? Icons.lock_rounded : Icons.check_rounded,
          loading: _paying,
          onPressed: () => _pay(invoice.total),
        ),
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.method,
    required this.selected,
    required this.onTap,
    this.child,
  });

  final PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Pressable(
      onTap: onTap,
      scale: 0.99,
      child: AnimatedContainer(
        duration: Motion.fast,
        padding: const EdgeInsets.all(Gap.lg),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: R.all(R.lg),
          border: Border.all(
              color: selected ? p.accent : p.line,
              width: selected ? 1.6 : 1),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: selected ? p.accentSoft : p.surfaceSunken,
                    borderRadius: R.all(R.sm),
                  ),
                  child: Icon(method.icon,
                      size: 20,
                      color: selected ? p.accentInk : p.inkSoft),
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(method.label, style: AppType.labelL.c(p.ink)),
                          if (method == PaymentMethod.upi) ...[
                            const SizedBox(width: Gap.sm),
                            const GPill(
                                label: 'FASTEST',
                                tone: GTone.success,
                                compact: true),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(method.blurb,
                          style: AppType.bodyS.c(p.inkMuted)),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 21,
                  color: selected ? p.accent : p.line,
                ),
              ],
            ),
            if (child != null) child!,
          ],
        ),
      ),
    );
  }
}
