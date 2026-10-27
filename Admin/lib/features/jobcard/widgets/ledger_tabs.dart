import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/i18n/strings.dart';
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
import '../../shared/sms_text.dart';

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
    _Tab.sms => 'Sms Details',
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

/// The card's messages in order. There is no SMS gateway, so one that is
/// due carries a Send button: it opens the phone's SMS app with the message
/// typed in and marks it sent. A reminder dated later says when it falls due
/// and waits — there is nothing to tap about it today.
class _SmsTrail extends ConsumerWidget {
  const _SmsTrail({required this.card});

  final JobCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    if (card.sms.isEmpty) {
      return Text(
        'No messages sent yet.'.tr,
        style: AppType.bodyS.c(p.inkFaint),
      );
    }
    final sorted = [...card.sms]..sort((a, b) => a.at.compareTo(b.at));
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < sorted.length; i++)
          Padding(
            padding: EdgeInsets.only(
              bottom: i == sorted.length - 1 ? 0 : Gap.md,
            ),
            child: Row(
              children: [
                Icon(
                  smsLook(sorted[i], now: now).icon,
                  size: 17,
                  color: toneOf(context, smsLook(sorted[i], now: now).tone).fg,
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sorted[i].label, style: AppType.labelM.c(p.ink)),
                      Text(
                        smsIsDue(sorted[i], now: now)
                            ? '{0} • {1}'.trf([
                                SmsState.scheduled.label,
                                Fmt.fullDateTime(sorted[i].at),
                              ])
                            : Fmt.fullDateTime(sorted[i].at),
                        style: AppType.bodyS.s(11).c(p.inkMuted),
                      ),
                    ],
                  ),
                ),
                if (smsIsDue(sorted[i], now: now))
                  GButton.accent(
                    label: 'Send'.tr,
                    icon: Icons.send_rounded,
                    size: GButtonSize.sm,
                    expand: false,
                    onPressed: () => sendCardSms(context, ref, card, sorted[i]),
                  )
                else
                  GPill(
                    label: smsLook(sorted[i], now: now).label,
                    compact: true,
                    tone: smsLook(sorted[i], now: now).tone,
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
              child: _Stat(label: 'Billed'.tr, value: Fmt.money2(card.total)),
            ),
            Expanded(
              child: _Stat(
                label: 'Collected'.tr,
                value: Fmt.money2(card.paid),
                color: p.success,
              ),
            ),
            Expanded(
              child: _Stat(
                label: 'Balance'.tr,
                value: Fmt.money2(card.balance),
                color: card.settled ? p.success : p.danger,
              ),
            ),
          ],
        ),
        if (card.excess > 0) ...[
          const SizedBox(height: Gap.md),
          ExcessNote(amount: card.excess),
        ],
        const SizedBox(height: Gap.lg),
        if (card.payments.isEmpty)
          Text(
            'Nothing collected against this card yet.'.tr,
            style: AppType.bodyS.c(p.inkFaint),
          )
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
                    child: Icon(pay.mode.icon, size: 16, color: p.success),
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pay.mode.label, style: AppType.labelM.c(p.ink)),
                        Text(
                          pay.note.isEmpty
                              ? Fmt.dateTime(pay.at)
                              : '${Fmt.dateTime(pay.at)} • ${pay.note}',
                          style: AppType.bodyS.s(11).c(p.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    Fmt.money2(pay.amount),
                    style: AppType.money.s(15).c(p.ink),
                  ),
                  if (!card.isClosed)
                    Pressable(
                      // One stray tap on a 16px cross used to wipe a payment
                      // and its cash-book entry with nothing to say so.
                      onTap: () async {
                        final ok = await GFeedback.confirm(
                          context,
                          title: 'Remove this payment?'.tr,
                          message:
                              '{0} {1} comes off this card and out of the cash book.'
                                  .trf([
                                    Fmt.money2(pay.amount),
                                    pay.mode.label,
                                  ]),
                          confirmLabel: 'Remove'.tr,
                          destructive: true,
                          icon: Icons.delete_outline_rounded,
                        );
                        if (!ok) return;
                        ref
                            .read(adminProvider.notifier)
                            .removePayment(card.id, pay.id);
                      },
                      scale: 0.9,
                      child: Padding(
                        padding: const EdgeInsets.only(left: Gap.sm),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: p.inkFaint,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        if (!card.settled && card.items.isNotEmpty) ...[
          const SizedBox(height: Gap.md),
          GButton(
            label: 'Record payment'.tr,
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

/// "Return to customer ₹X" — money taken beyond the bill, usually an advance
/// bigger than the work turned out to be (see `JobCard.excess`).
///
/// Shown wherever a card's paid and balance are, because a balance of zero
/// on its own reads as "all square" when the workshop is in fact holding the
/// customer's money.
class ExcessNote extends StatelessWidget {
  const ExcessNote({super.key, required this.amount});

  final double amount;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.sm),
      decoration: BoxDecoration(
        color: p.warningSoft,
        borderRadius: R.all(R.sm),
        border: Border.all(color: p.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.undo_rounded, size: 17, color: p.warning),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Text(
              'Return to customer {0}'.trf([Fmt.money2(amount)]),
              style: AppType.labelM.c(p.warning),
            ),
          ),
        ],
      ),
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
          Text(
            'Add a UPI ID in Settings to show a payment QR here.'.tr,
            textAlign: TextAlign.center,
            style: AppType.bodyS.c(p.inkMuted),
          ),
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
          card.balance > 0 ? 'Outstanding balance'.tr : 'Fully settled'.tr,
          style: AppType.bodyS.c(card.balance > 0 ? p.danger : p.success),
        ),
        const SizedBox(height: Gap.md),
        Pressable(
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: garage.upiId));
            if (context.mounted) {
              GFeedback.success(context, 'UPI ID copied'.tr);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.md,
              vertical: Gap.sm,
            ),
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
  final controller = TextEditingController(
    text: card.balance.toStringAsFixed(0),
  );
  var mode = PayMode.cash;

  await GFeedback.sheet<void>(
    context,
    title: 'Record payment'.tr,
    // Owned by the sheet, not by this function: its future completes
    // when the sheet starts closing, and the fields go on reading these
    // all the way through the exit transition.
    disposing: [controller],
    subtitle: '{0} outstanding on {1}'.trf([
      Fmt.money2(card.balance),
      card.number,
    ]),
    child: StatefulBuilder(
      builder: (context, setSheet) {
        final p = context.c;
        return SingleChildScrollView(
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
                label: 'Amount'.tr,
                hint: '1500',
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textCapitalization: TextCapitalization.none,
                prefix: Padding(
                  padding: const EdgeInsets.only(right: Gap.sm),
                  child: Text('₹', style: AppType.h2.c(p.inkMuted)),
                ),
              ),
              const SizedBox(height: Gap.lg),
              Text('RECEIVED BY'.tr, style: AppType.over.c(p.inkFaint)),
              const SizedBox(height: Gap.sm),
              PayModePicker(
                mode: mode,
                onChanged: (m) => setSheet(() => mode = m),
              ),
              const SizedBox(height: Gap.xxl),
              GButton.accent(
                label: 'Record it'.tr,
                onPressed: () {
                  final amount = double.tryParse(controller.text.trim()) ?? 0;
                  if (amount <= 0) {
                    GFeedback.error(context, 'Enter an amount first.'.tr);
                    return;
                  }
                  ref
                      .read(adminProvider.notifier)
                      .addPayment(card.id, amount: amount, mode: mode);
                  Navigator.of(context).pop();
                  GFeedback.success(
                    context,
                    '{0} recorded'.trf([Fmt.money(amount)]),
                  );
                },
              ),
            ],
          ),
        );
      },
    ),
  );
}

// ---------------------------------------------------------------------------

/// The ways money is taken at the counter, in the order they are reached for.
///
/// Card is not offered: the workshops this is for take it through a UPI
/// soundbox or not at all, and a separate "Card" bucket only split the bank
/// statement in two. [PayMode.card] stays in the model so payments recorded
/// as card before still read as card everywhere they are listed.
const List<PayMode> kPickableModes = [
  PayMode.cash,
  PayMode.upi,
  PayMode.cheque,
  PayMode.netbanking,
];

/// Cash / UPI / Cheque / Net Banking, with where the money will land said
/// underneath.
///
/// The cash book files each payment by its mode — cash into the drawer,
/// everything else into the primary bank — so the counter sees which before
/// pressing anything, rather than finding the UPI money in the wrong account
/// at the end of the day. With no bank account set up the line says so.
class PayModePicker extends ConsumerWidget {
  const PayModePicker({super.key, required this.mode, required this.onChanged});

  final PayMode mode;
  final ValueChanged<PayMode> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final data = ref.watch(adminProvider);
    final bank = data.primaryBank;
    final cash = mode == PayMode.cash;
    final (dest, ok) = cash
        ? ('Goes to {0}'.trf([data.cashAccount.title]), true)
        : bank != null
        ? ('Goes to {0}'.trf([bank.title]), true)
        : ('Add a bank account under Bank & Cash'.tr, false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: Gap.sm,
          runSpacing: Gap.sm,
          children: [
            for (final m in kPickableModes)
              Pressable(
                onTap: () => onChanged(m),
                scale: 0.95,
                child: AnimatedContainer(
                  duration: Motion.fast,
                  padding: const EdgeInsets.symmetric(
                    horizontal: Gap.md,
                    vertical: Gap.sm,
                  ),
                  decoration: BoxDecoration(
                    color: m == mode ? p.ink : p.surface,
                    borderRadius: R.all(R.pill),
                    border: Border.all(color: m == mode ? p.ink : p.line),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        m.icon,
                        size: 15,
                        color: m == mode
                            ? (p.isDark ? p.canvas : Colors.white)
                            : p.inkMuted,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        m.label,
                        style: AppType.labelM.c(
                          m == mode
                              ? (p.isDark ? p.canvas : Colors.white)
                              : p.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: Gap.sm),
        Row(
          children: [
            Icon(
              ok
                  ? (cash
                        ? Icons.payments_rounded
                        : Icons.account_balance_rounded)
                  : Icons.info_outline_rounded,
              size: 15,
              color: ok ? p.inkMuted : p.warning,
            ),
            const SizedBox(width: Gap.xs),
            Expanded(
              child: Text(
                dest,
                style: AppType.bodyS.c(ok ? p.inkMuted : p.warning),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
