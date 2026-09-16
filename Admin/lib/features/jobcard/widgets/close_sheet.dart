import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
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

/// Closing a card is the one moment where the money and the follow-up get
/// settled together, so both live in one sheet: collect what is owed, then
/// set when the customer should come back.
Future<bool> showCloseSheet(
  BuildContext context,
  WidgetRef ref,
  JobCard card,
) async {
  final amount =
      TextEditingController(text: card.balance.toStringAsFixed(0));
  final km = TextEditingController(
      text: '${card.odometerKm + AppConfig.nextServiceKm}');
  var mode = PayMode.cash;
  var collect = card.balance > 0;
  var due = DateTime.now()
      .add(const Duration(days: 30 * AppConfig.nextServiceMonths));
  var closed = false;

  await GFeedback.sheet<void>(
    context,
    title: 'Close ${card.number}',
    subtitle: '${Fmt.money2(card.total)} billed • '
        '${Fmt.money2(card.balance)} outstanding',
    child: StatefulBuilder(
      builder: (context, setSheet) {
        final p = context.c;

        Future<void> pickDate() async {
          final picked = await showDatePicker(
            context: context,
            initialDate: due,
            firstDate: DateTime.now(),
            lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
          );
          if (picked != null) setSheet(() => due = picked);
        }

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            Gap.page,
            Gap.lg,
            Gap.page,
            MediaQuery.of(context).viewInsets.bottom + Gap.h1,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- money ------------------------------------------------
              if (card.balance > 0) ...[
                Pressable(
                  onTap: () => setSheet(() => collect = !collect),
                  scale: 0.99,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: Gap.lg, vertical: Gap.md),
                    decoration: BoxDecoration(
                      color: collect ? p.successSoft : p.surfaceSunken,
                      borderRadius: R.all(R.md),
                      border: Border.all(
                          color: collect ? p.success : p.line),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          collect
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          size: 20,
                          color: collect ? p.success : p.inkFaint,
                        ),
                        const SizedBox(width: Gap.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Collect payment now',
                                  style: AppType.labelL.c(p.ink)),
                              Text(
                                collect
                                    ? 'The card closes settled'
                                    : 'The balance stays under Pending balance',
                                style: AppType.bodyS.c(p.inkMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (collect) ...[
                  const SizedBox(height: Gap.lg),
                  GField(
                    label: 'Amount collected',
                    controller: amount,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textCapitalization: TextCapitalization.none,
                    prefix: Padding(
                      padding: const EdgeInsets.only(right: Gap.sm),
                      child: Text('₹', style: AppType.h2.c(p.inkMuted)),
                    ),
                  ),
                  const SizedBox(height: Gap.md),
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
                            child: Text(
                              m.label,
                              style: AppType.labelM.c(m == mode
                                  ? (p.isDark ? p.canvas : Colors.white)
                                  : p.inkSoft),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: Gap.xxl),
              ] else ...[
                Row(
                  children: [
                    Icon(Icons.verified_rounded, size: 18, color: p.success),
                    const SizedBox(width: Gap.sm),
                    Text('Fully settled',
                        style: AppType.labelL.c(p.success)),
                  ],
                ),
                const SizedBox(height: Gap.xxl),
              ],

              // --- next service ----------------------------------------
              Text('NEXT SERVICE', style: AppType.over.c(p.inkFaint)),
              const SizedBox(height: Gap.sm),
              Text(
                'Three reminders go out around this date — '
                '${Fmt.date(due)}.',
                style: AppType.bodyS.c(p.inkMuted),
              ),
              const SizedBox(height: Gap.md),
              Row(
                children: [
                  Expanded(
                    child: GPickerField(
                      label: 'Due on',
                      value: Fmt.date(due),
                      icon: Icons.event_rounded,
                      onTap: pickDate,
                    ),
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: GField(
                      label: 'Or at km',
                      controller: km,
                      keyboardType: TextInputType.number,
                      textCapitalization: TextCapitalization.none,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.md),
              Wrap(
                spacing: Gap.sm,
                children: [
                  for (final months in [3, 6, 12])
                    Pressable(
                      onTap: () => setSheet(() => due = DateTime.now()
                          .add(Duration(days: 30 * months))),
                      scale: 0.95,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: Gap.md, vertical: 6),
                        decoration: BoxDecoration(
                          color: p.surfaceSunken,
                          borderRadius: R.all(R.pill),
                          border: Border.all(color: p.line),
                        ),
                        child: Text('$months months',
                            style: AppType.labelM.c(p.inkSoft)),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: Gap.h1),
              GButton.accent(
                label: 'Close job card',
                icon: Icons.lock_rounded,
                onPressed: () {
                  final ctrl = ref.read(adminProvider.notifier);
                  if (collect && card.balance > 0) {
                    final value =
                        double.tryParse(amount.text.trim()) ?? 0;
                    if (value > 0) {
                      ctrl.addPayment(card.id, amount: value, mode: mode);
                    }
                  }
                  closed = ctrl.closeJobCard(
                    card.id,
                    nextServiceAt: due,
                    nextServiceKm: int.tryParse(km.text.trim()),
                  );
                  Navigator.of(context).pop();
                },
              ),
              const SizedBox(height: Gap.sm),
              Center(
                child: Text(
                  'A closed card can still be reopened from its menu.',
                  style: AppType.bodyS.c(p.inkFaint),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  amount.dispose();
  km.dispose();
  return closed;
}
