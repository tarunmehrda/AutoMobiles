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
import '../../core/utils/words.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_state.dart';
import '../../core/widgets/g_surface.dart';
import '../../data/models/entities.dart';
import '../../data/models/enums.dart';
import '../../data/seed/catalog_seed.dart';
import '../../state/app_state.dart';
import '../../state/providers.dart';

class InvoicePage extends ConsumerWidget {
  const InvoicePage({super.key, required this.bookingId});

  final String bookingId;

  String _plainText(Invoice inv, Booking booking, String? vehicle) {
    final b = StringBuffer()
      ..writeln('${Seed.garage.name} — Tax invoice')
      ..writeln('Invoice: ${inv.number}')
      ..writeln('Job card: ${inv.jobCardNumber ?? '-'}')
      ..writeln('Booking: ${booking.code}')
      ..writeln('Vehicle: ${vehicle ?? '-'}')
      ..writeln('Date: ${Fmt.date(inv.createdAt)}')
      ..writeln('');
    for (final l in inv.lines) {
      b.writeln('${l.name}  ${Fmt.money(l.amount)}');
    }
    b
      ..writeln('')
      ..writeln('Subtotal: ${Fmt.money(inv.subtotal)}')
      ..writeln('GST 18%: ${Fmt.money(inv.gst)}')
      ..writeln('Total: ${Fmt.money(inv.total)}')
      ..writeln(inv.paid ? 'Status: PAID' : 'Status: DUE');
    return b.toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final booking = ref.watch(bookingProvider(bookingId));
    final invoice = ref.watch(invoiceProvider(bookingId));

    if (booking == null) {
      return Scaffold(
        backgroundColor: p.canvas,
        appBar: const GHeader(title: 'Invoice'),
        body: const GEmptyState(
          icon: Icons.receipt_long_rounded,
          title: 'Booking not found',
          message: 'This invoice is no longer available.',
        ),
      );
    }

    if (invoice == null) {
      return Scaffold(
        backgroundColor: p.canvas,
        appBar: const GHeader(title: 'Invoice'),
        body: GEmptyState(
          icon: Icons.receipt_long_rounded,
          title: 'Invoice not generated yet',
          message:
              'The final bill is raised once the work is finished and quality '
              'checked. You will be notified.',
          actionLabel: 'Back to booking',
          onAction: () => context.pop(),
        ),
      );
    }

    final vehicle =
        ref.watch(appControllerProvider).vehicleById(booking.vehicleId);
    final user = ref.watch(userProvider);

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Tax invoice',
        subtitle: invoice.number,
        actions: [
          GIconButton(
            icon: Icons.ios_share_rounded,
            size: 40,
            onTap: () => SharePlus.instance.share(ShareParams(
              text: _plainText(invoice, booking, vehicle?.title),
              subject: 'Invoice ${invoice.number}',
            )),
          ),
          GIconButton(
            icon: Icons.download_rounded,
            size: 40,
            onTap: () {
              Clipboard.setData(ClipboardData(
                  text: _plainText(invoice, booking, vehicle?.title)));
              GFeedback.success(context, 'Invoice copied to clipboard');
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.h2),
        children: [
          Entrance(
            child: GCard(
              padding: EdgeInsets.zero,
              clip: true,
              child: Column(
                children: [
                  // --- header ---------------------------------------
                  Container(
                    padding: const EdgeInsets.all(Gap.xl),
                    decoration: BoxDecoration(gradient: p.inverseGradient),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const BrandLogo(width: 148, onDark: true),
                            const Spacer(),
                            GPill(
                              label: invoice.paid ? 'PAID' : 'PAYMENT DUE',
                              tone: invoice.paid
                                  ? GTone.volt
                                  : GTone.warning,
                              compact: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: Gap.lg),
                        Text(Seed.garage.name,
                            style: AppType.labelL.c(p.onInverse)),
                        const SizedBox(height: 2),
                        Text(Seed.garage.address,
                            style: AppType.bodyS
                                .c(p.onInverse.withValues(alpha: 0.6))),
                        const SizedBox(height: 2),
                        Text('GSTIN ${Seed.garage.gstin}',
                            style: AppType.labelS
                                .c(p.onInverse.withValues(alpha: 0.6))),
                      ],
                    ),
                  ),

                  // --- meta -----------------------------------------
                  Padding(
                    padding: const EdgeInsets.all(Gap.xl),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _metaBlock(context, 'BILLED TO', [
                                user?.name ?? '',
                                user?.phone ?? '',
                                if (user?.email != null) user!.email!,
                              ]),
                            ),
                            const SizedBox(width: Gap.lg),
                            Expanded(
                              child: _metaBlock(context, 'VEHICLE', [
                                vehicle?.title ?? '—',
                                vehicle?.regNumber ?? '',
                                if (vehicle != null)
                                  '${vehicle.fuel.label} • ${vehicle.year}',
                              ]),
                            ),
                          ],
                        ),
                        const SizedBox(height: Gap.lg),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _metaBlock(context, 'INVOICE', [
                                invoice.number,
                                Fmt.date(invoice.createdAt),
                              ]),
                            ),
                            const SizedBox(width: Gap.lg),
                            Expanded(
                              child: _metaBlock(context, 'JOB CARD', [
                                invoice.jobCardNumber ?? '—',
                                booking.code,
                              ]),
                            ),
                          ],
                        ),
                        const SizedBox(height: Gap.xl),
                        const GDashedLine(),
                        const SizedBox(height: Gap.lg),

                        // --- line items -----------------------------
                        Row(
                          children: [
                            Expanded(
                              flex: 6,
                              child: Text('DESCRIPTION',
                                  style: AppType.over.s(9).c(p.inkFaint)),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text('PARTS',
                                  textAlign: TextAlign.end,
                                  style: AppType.over.s(9).c(p.inkFaint)),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text('LABOUR',
                                  textAlign: TextAlign.end,
                                  style: AppType.over.s(9).c(p.inkFaint)),
                            ),
                            Expanded(
                              flex: 4,
                              child: Text('AMOUNT',
                                  textAlign: TextAlign.end,
                                  style: AppType.over.s(9).c(p.inkFaint)),
                            ),
                          ],
                        ),
                        const SizedBox(height: Gap.sm),
                        for (final l in invoice.lines)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 6,
                                  child: Text(l.name,
                                      style: AppType.bodyM.c(p.ink)),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    l.parts == 0 ? '—' : Fmt.money(l.parts),
                                    textAlign: TextAlign.end,
                                    style: AppType.moneyS.s(12).c(p.inkMuted),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    l.labour == 0 ? '—' : Fmt.money(l.labour),
                                    textAlign: TextAlign.end,
                                    style: AppType.moneyS.s(12).c(p.inkMuted),
                                  ),
                                ),
                                Expanded(
                                  flex: 4,
                                  child: Text(
                                    Fmt.money(l.amount),
                                    textAlign: TextAlign.end,
                                    style: AppType.moneyS.c(p.ink),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: Gap.md),
                        const GDashedLine(),
                        const SizedBox(height: Gap.sm),

                        GKeyValue(
                            label: 'Subtotal',
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
                        GKeyValue(
                            label: 'CGST 9%', value: Fmt.money(invoice.cgst)),
                        GKeyValue(
                            label: 'SGST 9%', value: Fmt.money(invoice.sgst)),
                        const SizedBox(height: Gap.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: Gap.md, vertical: Gap.md),
                          decoration: BoxDecoration(
                            color: p.surfaceSunken,
                            borderRadius: R.all(R.sm),
                          ),
                          child: Row(
                            children: [
                              Flexible(
                                child: Text('Total payable',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppType.h2.c(p.ink)),
                              ),
                              const SizedBox(width: Gap.md),
                              Flexible(
                                child: Text(Fmt.money(invoice.total),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.end,
                                    style: AppType.moneyL.s(22).c(p.ink)),
                              ),
                            ],
                          ),
                        ),

                        // Spelled out the way every Indian bill does it, so
                        // the figure cannot be misread.
                        const SizedBox(height: Gap.md),
                        Text('AMOUNT IN WORDS',
                            style: AppType.over.s(9).c(p.inkFaint)),
                        const SizedBox(height: 2),
                        Text(Words.rupees(invoice.total),
                            style: AppType.labelM.c(p.inkSoft)),

                        if (booking.jobCard?.nextServiceAt != null) ...[
                          const SizedBox(height: Gap.lg),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: Gap.md, vertical: Gap.sm),
                            decoration: BoxDecoration(
                              color: p.infoSoft,
                              borderRadius: R.all(R.sm),
                            ),
                            child: Text(
                              'Next service due on '
                              '${Fmt.date(booking.jobCard!.nextServiceAt!)}'
                              '${booking.jobCard!.nextServiceKm == null ? '' : ' or at ${Fmt.km(booking.jobCard!.nextServiceKm!)}'}'
                              ', whichever is earlier.',
                              textAlign: TextAlign.center,
                              style: AppType.labelS.s(11).c(p.info),
                            ),
                          ),
                        ],

                        if (invoice.paid) ...[
                          const SizedBox(height: Gap.lg),
                          Container(
                            padding: const EdgeInsets.all(Gap.md),
                            decoration: BoxDecoration(
                              color: p.successSoft,
                              borderRadius: R.all(R.md),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.verified_rounded,
                                    size: 18, color: p.success),
                                const SizedBox(width: Gap.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Paid via ${invoice.method?.label ?? 'card'}',
                                        style: AppType.labelM.c(p.success),
                                      ),
                                      Text(
                                        '${invoice.transactionId ?? ''} • '
                                        '${invoice.paidAt == null ? '' : Fmt.fullDateTime(invoice.paidAt!)}',
                                        style: AppType.labelS.c(p.success
                                            .withValues(alpha: 0.8)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: Gap.lg),
                        Text(
                          'Warranty on parts and labour as per the package terms. '
                          'This is a computer-generated invoice and needs no signature.',
                          style: AppType.labelS.s(10).c(p.inkFaint),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: Gap.lg),
          Row(
            children: [
              Expanded(
                child: GButton.outline(
                  label: 'Share',
                  icon: Icons.ios_share_rounded,
                  expand: true,
                  onPressed: () => SharePlus.instance.share(ShareParams(
                    text: _plainText(invoice, booking, vehicle?.title),
                  )),
                ),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: GButton.outline(
                  label: 'Need help?',
                  icon: Icons.help_outline_rounded,
                  expand: true,
                  onPressed: () => context.push('/tickets'),
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: invoice.paid
          ? null
          : GBottomBar(
              child: GButton.accent(
                label: 'Pay now',
                badge: Fmt.money(invoice.total),
                onPressed: () => context.push('/booking/$bookingId/pay'),
              ),
            ),
    );
  }

  Widget _metaBlock(BuildContext context, String label, List<String> lines) {
    final p = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppType.over.c(p.inkFaint)),
        const SizedBox(height: 4),
        for (final l in lines.where((e) => e.trim().isNotEmpty))
          Text(l, style: AppType.bodyS.c(p.inkSoft)),
      ],
    );
  }
}
