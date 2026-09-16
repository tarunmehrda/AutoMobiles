import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/g_badge.dart';
import '../../../core/widgets/g_button.dart';
import '../../../core/widgets/g_feedback.dart';
import '../../../core/widgets/g_field.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/models/entities.dart';
import '../../../data/models/enums.dart';
import '../../../state/admin_state.dart';

/// Everything that happened to the card after it was billed: the message
/// trail, the money collected, and the QR that collects the rest.
class LedgerTabs extends StatefulWidget {
  const LedgerTabs({super.key, required this.card, required this.garage});

  final JobCard card;
  final Garage garage;

  @override
  State<LedgerTabs> createState() => _LedgerTabsState();
}

enum _Tab { sms, transactions, qr }

class _LedgerTabsState extends State<LedgerTabs> {
  _Tab _tab = _Tab.sms;

  String _label(_Tab t) => switch (t) {
        _Tab.sms => 'SMS trail',
        _Tab.transactions => 'Transactions',
        _Tab.qr => 'Payment QR',
      };

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: R.all(R.md),
        border: Border.all(color: p.line),
        boxShadow: Shadows.soft(p),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(Gap.sm),
            child: GSegmented<_Tab>(
              options: _Tab.values,
              selected: _tab,
              onSelect: (t) => setState(() => _tab = t),
              labelOf: _label,
              height: 42,
            ),
          ),
          Divider(height: 1, color: p.lineSoft),
          Padding(
            padding: const EdgeInsets.all(Gap.lg),
            child: switch (_tab) {
              _Tab.sms => _SmsTrail(card: widget.card),
              _Tab.transactions => _Transactions(card: widget.card),
              _Tab.qr => _PaymentQr(card: widget.card, garage: widget.garage),
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _SmsTrail extends StatelessWidget {
  const _SmsTrail({required this.card});

  final JobCard card;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    if (card.sms.isEmpty) {
      return Text('No messages sent yet.',
          style: AppType.bodyS.c(p.inkFaint));
    }
    final sorted = [...card.sms]..sort((a, b) => a.at.compareTo(b.at));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < sorted.length; i++)
          Padding(
            padding: EdgeInsets.only(
                bottom: i == sorted.length - 1 ? 0 : Gap.md),
            child: Row(
              children: [
                Icon(
                  switch (sorted[i].state) {
                    SmsState.delivered => Icons.check_circle_rounded,
                    SmsState.scheduled => Icons.schedule_rounded,
                    SmsState.failed => Icons.error_rounded,
                    SmsState.skipped => Icons.do_not_disturb_on_rounded,
                  },
                  size: 17,
                  color: switch (sorted[i].state) {
                    SmsState.delivered => p.success,
                    SmsState.scheduled => p.info,
                    SmsState.failed => p.danger,
                    SmsState.skipped => p.inkFaint,
                  },
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sorted[i].label,
                          style: AppType.labelM.c(p.ink)),
                      Text(Fmt.fullDateTime(sorted[i].at),
                          style: AppType.bodyS.s(11).c(p.inkMuted)),
                    ],
                  ),
                ),
                GPill(
                  label: sorted[i].state.label,
                  compact: true,
                  tone: switch (sorted[i].state) {
                    SmsState.delivered => GTone.success,
                    SmsState.scheduled => GTone.info,
                    SmsState.failed => GTone.danger,
                    SmsState.skipped => GTone.neutral,
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _Transactions extends ConsumerWidget {
  const _Transactions({required this.card});

  final JobCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _Stat(
                  label: 'Billed', value: Fmt.money2(card.total)),
            ),
            Expanded(
              child: _Stat(
                label: 'Collected',
                value: Fmt.money2(card.paid),
                color: p.success,
              ),
            ),
            Expanded(
              child: _Stat(
                label: 'Balance',
                value: Fmt.money2(card.balance),
                color: card.settled ? p.success : p.danger,
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.lg),
        if (card.payments.isEmpty)
          Text('Nothing collected against this card yet.',
              style: AppType.bodyS.c(p.inkFaint))
        else
          for (final pay in card.payments)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.sm),
              child: Row(
                children: [
                  Container(
                    height: 34,
                    width: 34,
                    decoration: BoxDecoration(
                      color: p.successSoft,
                      borderRadius: R.all(R.sm),
                    ),
                    child:
                        Icon(pay.mode.icon, size: 16, color: p.success),
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pay.mode.label,
                            style: AppType.labelM.c(p.ink)),
                        Text(
                          pay.note.isEmpty
                              ? Fmt.dateTime(pay.at)
                              : '${Fmt.dateTime(pay.at)} • ${pay.note}',
                          style: AppType.bodyS.s(11).c(p.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  Text(Fmt.money2(pay.amount),
                      style: AppType.money.s(15).c(p.ink)),
                  if (!card.isClosed)
                    Pressable(
                      onTap: () => ref
                          .read(adminProvider.notifier)
                          .removePayment(card.id, pay.id),
                      scale: 0.9,
                      child: Padding(
                        padding: const EdgeInsets.only(left: Gap.sm),
                        child: Icon(Icons.close_rounded,
                            size: 16, color: p.inkFaint),
                      ),
                    ),
                ],
              ),
            ),
        if (!card.settled && card.items.isNotEmpty) ...[
          const SizedBox(height: Gap.md),
          GButton(
            label: 'Record payment',
            kind: GButtonKind.ghost,
            size: GButtonSize.md,
            icon: Icons.add_rounded,
            onPressed: () => showCollectSheet(context, ref, card),
          ),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AppType.over.s(9.5).c(p.inkFaint)),
        const SizedBox(height: 3),
        Text(value, style: AppType.money.s(15).c(color ?? p.ink)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _PaymentQr extends StatelessWidget {
  const _PaymentQr({required this.card, required this.garage});

  final JobCard card;
  final Garage garage;

  /// A standard UPI intent — any UPI app reads it and pre-fills the amount.
  String get _upiUri {
    final amount = card.balance > 0 ? card.balance : card.total;
    return Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: {
        'pa': garage.upiId,
        'pn': garage.name,
        'am': amount.toStringAsFixed(2),
        'cu': 'INR',
        'tn': 'Job card ${card.number}',
      },
    ).toString();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    if (garage.upiId.trim().isEmpty) {
      return Column(
        children: [
          Icon(Icons.qr_code_2_rounded, size: 36, color: p.inkFaint),
          const SizedBox(height: Gap.md),
          Text('Add a UPI ID in Settings to show a payment QR here.',
              textAlign: TextAlign.center,
              style: AppType.bodyS.c(p.inkMuted)),
        ],
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(Gap.md),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: R.all(R.md),
            border: Border.all(color: p.line),
          ),
          child: QrImageView(
            data: _upiUri,
            size: 172,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Color(0xFF0D1117),
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Color(0xFF0D1117),
            ),
          ),
        ),
        const SizedBox(height: Gap.md),
        Text(
          Fmt.money2(card.balance > 0 ? card.balance : card.total),
          style: AppType.moneyL.c(p.ink),
        ),
        Text(
          card.balance > 0 ? 'Outstanding balance' : 'Fully settled',
          style: AppType.bodyS
              .c(card.balance > 0 ? p.danger : p.success),
        ),
        const SizedBox(height: Gap.md),
        Pressable(
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: garage.upiId));
            if (context.mounted) {
              GFeedback.success(context, 'UPI ID copied');
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: Gap.md, vertical: Gap.sm),
            decoration: BoxDecoration(
              color: p.surfaceSunken,
              borderRadius: R.all(R.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(garage.upiId, style: AppType.labelM.c(p.inkSoft)),
                const SizedBox(width: Gap.sm),
                Icon(Icons.copy_rounded, size: 14, color: p.inkMuted),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

/// Collect against a card. Offered from the ledger, the close flow and the
/// pending balance screen, so it lives here rather than in any one of them.
Future<void> showCollectSheet(
  BuildContext context,
  WidgetRef ref,
  JobCard card,
) async {
  final controller =
      TextEditingController(text: card.balance.toStringAsFixed(0));
  var mode = PayMode.cash;

  await GFeedback.sheet<void>(
    context,
    title: 'Record payment',
    subtitle: '${Fmt.money2(card.balance)} outstanding on ${card.number}',
    child: StatefulBuilder(
      builder: (context, setSheet) {
        final p = context.c;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            Gap.page,
            Gap.lg,
            Gap.page,
            MediaQuery.of(context).viewInsets.bottom + Gap.h1,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GField(
                label: 'Amount',
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textCapitalization: TextCapitalization.none,
                prefix: Padding(
                  padding: const EdgeInsets.only(right: Gap.sm),
                  child: Text('₹', style: AppType.h2.c(p.inkMuted)),
                ),
              ),
              const SizedBox(height: Gap.lg),
              Text('MODE', style: AppType.over.c(p.inkFaint)),
              const SizedBox(height: Gap.sm),
              Wrap(
                spacing: Gap.sm,
                runSpacing: Gap.sm,
                children: [
                  for (final m in PayMode.values)
                    Pressable(
                      onTap: () => setSheet(() => mode = m),
                      scale: 0.95,
                      child: AnimatedContainer(
                        duration: Motion.fast,
                        padding: const EdgeInsets.symmetric(
                            horizontal: Gap.md, vertical: Gap.sm),
                        decoration: BoxDecoration(
                          color: m == mode ? p.ink : p.surface,
                          borderRadius: R.all(R.pill),
                          border: Border.all(
                              color: m == mode ? p.ink : p.line),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(m.icon,
                                size: 15,
                                color: m == mode
                                    ? (p.isDark ? p.canvas : Colors.white)
                                    : p.inkMuted),
                            const SizedBox(width: 5),
                            Text(
                              m.label,
                              style: AppType.labelM.c(m == mode
                                  ? (p.isDark ? p.canvas : Colors.white)
                                  : p.inkSoft),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: Gap.xxl),
              GButton.accent(
                label: 'Record it',
                onPressed: () {
                  final amount =
                      double.tryParse(controller.text.trim()) ?? 0;
                  if (amount <= 0) {
                    GFeedback.error(context, 'Enter an amount first.');
                    return;
                  }
                  ref.read(adminProvider.notifier).addPayment(
                        card.id,
                        amount: amount,
                        mode: mode,
                      );
                  Navigator.of(context).pop();
                  GFeedback.success(
                      context, '${Fmt.money(amount)} recorded');
                },
              ),
            ],
          ),
        );
      },
    ),
  );
  controller.dispose();
}
