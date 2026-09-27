import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/g_button.dart';
import '../../../core/widgets/g_feedback.dart';
import '../../../core/widgets/g_field.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/models/entities.dart';
import '../../../data/models/enums.dart';
import '../../../state/admin_state.dart';
import '../../shared/sms_text.dart';
import 'ledger_tabs.dart';

/// What comes back from the sheet, so the caller knows whether to switch the
/// document or just refresh.
enum CompleteOutcome { cancelled, updated, completed }

/// The settlement sheet the counter opens from "Update or Complete".
///
/// It is one place to read the bill as three totals, take a payment and the
/// discount, and either save those against the open card or push it through
/// to Complete — opening the vehicle-ready SMS in the phone's SMS app when
/// its switch is on.
///
/// The money field is "Payment received now", empty to start, with what is
/// already paid shown above it and left alone. It used to be an "Advance"
/// box prefilled with everything paid so far, of which only an increase was
/// ever recorded: typing a smaller figure — to correct it, or because the
/// counter read it as "still to collect" — silently did nothing while the
/// sheet showed the new number.
Future<CompleteOutcome> showCompleteSheet(
  BuildContext context,
  WidgetRef ref,
  JobCard card,
) async {
  final received = TextEditingController();
  final discount = TextEditingController(
    text: card.discount == 0 ? '' : card.discount.toStringAsFixed(0),
  );
  var percentMode = false;
  var sms = ref.read(adminProvider).smsEnabled;
  var date = DateTime.now();
  var outcome = CompleteOutcome.cancelled;

  final labour = card.totalOf(LineKind.job);
  final spare = card.totalOf(LineKind.spare);
  final lube = card.totalOf(LineKind.lube);
  final gross = card.subTotal;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    // Owned by the sheet, not by this function: `showModalBottomSheet`
    // completes when the sheet starts closing, and the fields go on
    // reading these all the way through the exit transition.
    builder: (sheetContext) => DisposeWithSubtree(
      disposables: [received, discount],
      child: StatefulBuilder(
        builder: (context, setSheet) {
          final p = context.c;

          // Discount can be typed either way; the card always stores rupees.
          final typed = double.tryParse(discount.text.trim()) ?? 0;
          final discountValue = (percentMode ? gross * (typed / 100) : typed)
              .clamp(0, gross);
          // GST is on the discounted figure, exactly as `JobCard.total`
          // works it out. Leaving it off made a taxed card whose advance
          // covered the pre-tax bill read as money owed back.
          final taxable = (gross - discountValue).clamp(0, double.infinity);
          final tax = taxable * card.taxRate;
          final payable = taxable + tax;
          final alreadyPaid = card.paid;
          // What is still owed before anything taken now.
          final due = (payable - alreadyPaid).clamp(0, double.infinity);
          final nowValue = (double.tryParse(received.text.trim()) ?? 0).clamp(
            0,
            double.infinity,
          );
          // What is still to be collected at the counter. Without it the
          // sheet showed the whole bill directly under the money already
          // taken, which reads as the figure to charge — and takes the
          // advance off the customer twice.
          final toCollect = (due - nowValue).clamp(0, double.infinity);
          // Already paid beyond the (possibly just discounted) bill: owed
          // back, see `JobCard.excess`.
          final excess = (alreadyPaid - payable).clamp(0, double.infinity);

          void apply() {
            final ctrl = ref.read(adminProvider.notifier);
            ctrl.setDiscount(card.id, discountValue.toDouble());
            // An ordinary payment: it stops at the balance, like every
            // other place money is taken against a card.
            if (nowValue > 0) {
              ctrl.addPayment(
                card.id,
                amount: nowValue.toDouble(),
                mode: PayMode.cash,
              );
            }
          }

          Future<void> pickDate() async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: card.createdAt.subtract(const Duration(days: 1)),
              lastDate: DateTime.now().add(const Duration(days: 30)),
            );
            if (picked == null) return;
            // The picker hands back midnight; keep the time of day so a
            // card completed "today" does not read as done at 12:00 am.
            final now = DateTime.now();
            setSheet(
              () => date = DateTime(
                picked.year,
                picked.month,
                picked.day,
                now.hour,
                now.minute,
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(R.xxl),
                ),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    Gap.page,
                    Gap.md,
                    Gap.page,
                    Gap.lg,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Spacer(),
                          Pressable(
                            onTap: () => Navigator.of(context).pop(),
                            scale: 0.9,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: p.danger,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Close'.tr,
                                  style: AppType.labelM.c(p.danger),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Gap.md),

                      // --- the bill as three lines ---------------------
                      _Line(label: 'Labour Total'.tr, value: labour),
                      _Line(label: 'Spare Total'.tr, value: spare),
                      _Line(label: 'Lube Total'.tr, value: lube),
                      Divider(height: Gap.xl, color: p.line),
                      _Line(
                        label: 'TOTAL AMOUNT'.tr,
                        value: gross,
                        strong: true,
                      ),
                      const SizedBox(height: Gap.lg),

                      // --- money in -------------------------------------
                      if (alreadyPaid > 0)
                        _Line(label: 'Already paid'.tr, value: alreadyPaid),
                      _Entry(
                        label: 'Payment received now'.tr,
                        child: _Box(
                          controller: received,
                          onChanged: () => setSheet(() {}),
                        ),
                      ),
                      if (nowValue > due) ...[
                        const SizedBox(height: Gap.xs),
                        Text(
                          due > 0
                              ? 'Only {0} is due — that is what will be recorded.'
                                    .trf([Fmt.money2(due.toDouble())])
                              : 'Nothing is due on this card.'.tr,
                          textAlign: TextAlign.right,
                          style: AppType.bodyS.c(p.warning),
                        ),
                      ],
                      const SizedBox(height: Gap.md),

                      // --- discount -------------------------------------
                      _Entry(
                        label: 'Discount'.tr,
                        labelColor: p.danger,
                        child: Row(
                          children: [
                            Pressable(
                              onTap: () =>
                                  setSheet(() => percentMode = !percentMode),
                              scale: 0.92,
                              child: Container(
                                height: 44,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: Gap.md,
                                ),
                                decoration: BoxDecoration(
                                  color: p.accentSoft,
                                  borderRadius: const BorderRadius.horizontal(
                                    left: Radius.circular(R.xs),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      percentMode ? '%' : '₹',
                                      style: AppType.h2.c(p.accentInk),
                                    ),
                                    Icon(
                                      Icons.expand_more_rounded,
                                      size: 17,
                                      color: p.accentInk,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              child: _Box(
                                controller: discount,
                                tint: p.danger,
                                onChanged: () => setSheet(() {}),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Gap.lg),

                      if (card.taxRate > 0)
                        _Line(
                          label: 'GST {0}%'.trf([
                            (card.taxRate * 100).toStringAsFixed(0),
                          ]),
                          value: tax.toDouble(),
                        ),
                      _Line(
                        label: 'Payable Amount'.tr,
                        value: payable.toDouble(),
                        strong: true,
                      ),
                      if (alreadyPaid > 0 || nowValue > 0)
                        _Line(
                          label: 'Balance to collect'.tr,
                          value: toCollect.toDouble(),
                          strong: true,
                        ),
                      if (excess > 0) ...[
                        const SizedBox(height: Gap.sm),
                        ExcessNote(amount: excess.toDouble()),
                      ],

                      const SizedBox(height: Gap.lg),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Pressable(
                          onTap: pickDate,
                          scale: 0.96,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Select Date:  '.tr,
                                style: AppType.labelM.c(p.info),
                              ),
                              Text(
                                Fmt.fullDateTime(date),
                                style: AppType.labelM
                                    .c(p.info)
                                    .copyWith(
                                      decoration: TextDecoration.underline,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: Gap.lg),

                      // --- the two ways out ----------------------------
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: R.all(R.sm),
                          border: Border.all(color: p.line),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: Gap.md,
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    'SMS Alert'.tr,
                                    style: AppType.labelM.c(p.ink),
                                  ),
                                  Switch(
                                    value: sms,
                                    onChanged: (v) => setSheet(() => sms = v),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: GButton.accent(
                                label: 'Confirm & Complete'.tr,
                                onPressed: card.items.isEmpty
                                    ? null
                                    : () {
                                        apply();
                                        final ctrl = ref.read(
                                          adminProvider.notifier,
                                        );
                                        // This card's choice and this
                                        // card's date — the workshop-wide
                                        // SMS setting is left alone.
                                        if (ctrl.markComplete(
                                          card.id,
                                          at: date,
                                          sms: sms,
                                        )) {
                                          outcome = CompleteOutcome.completed;
                                        }
                                        Navigator.of(context).pop();
                                      },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Gap.md),
                      GButton(
                        label: 'Update'.tr,
                        kind: GButtonKind.danger,
                        onPressed: () {
                          apply();
                          outcome = CompleteOutcome.updated;
                          Navigator.of(context).pop();
                        },
                      ),
                      const SizedBox(height: Gap.sm),
                      Center(
                        child: Text(
                          'Note: with SMS Alert on, your SMS app opens with the vehicle-ready message for the customer. Tap Send there.'
                              .tr,
                          textAlign: TextAlign.center,
                          style: AppType.bodyS.c(p.inkFaint),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );

  if (context.mounted) {
    if (outcome == CompleteOutcome.completed) {
      GFeedback.success(context, 'Jobcard Updated Successfully!!'.tr);
      // There is no SMS gateway: the message goes when the counter taps
      // Send in the phone's SMS app, which this opens with it typed in.
      if (sms) await sendNewCardSms(context, ref, card.id, 'Work complete');
    } else if (outcome == CompleteOutcome.updated) {
      GFeedback.info(context, 'Jobcard updated'.tr);
    }
  }
  return outcome;
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, this.strong = false});

  final String label;
  final double value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: strong ? AppType.h2.c(p.ink) : AppType.bodyL.c(p.inkSoft),
            ),
          ),
          Text(
            value.toStringAsFixed(2),
            style: strong
                ? AppType.money.c(p.ink)
                : AppType.moneyS.c(p.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({required this.label, required this.child, this.labelColor});

  final String label;
  final Widget child;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Row(
      children: [
        Expanded(
          child: Text(label, style: AppType.bodyL.c(labelColor ?? p.inkSoft)),
        ),
        SizedBox(width: 170, child: child),
      ],
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.controller, required this.onChanged, this.tint});

  final TextEditingController controller;
  final VoidCallback onChanged;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return SizedBox(
      height: 44,
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.right,
        onChanged: (_) => onChanged(),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        style: AppType.money.s(15).c(tint ?? p.ink),
        decoration: InputDecoration(
          hintText: '0',
          hintStyle: AppType.money.s(15).c(p.inkFaint),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: Gap.md,
            vertical: Gap.md,
          ),
          filled: true,
          fillColor: p.surface,
          enabledBorder: OutlineInputBorder(
            borderRadius: R.all(R.xs),
            borderSide: BorderSide(color: p.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: R.all(R.xs),
            borderSide: BorderSide(color: tint ?? p.accent),
          ),
        ),
      ),
    );
  }
}
