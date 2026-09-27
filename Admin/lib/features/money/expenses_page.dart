import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/anim/entrance.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_field.dart';
import '../../core/widgets/g_art.dart';
import '../../core/widgets/g_state.dart';
import '../../core/widgets/pressable.dart';
import '../../data/models/entities.dart';
import '../../state/admin_state.dart';
import '../../state/providers.dart';

const _categories = [
  'General',
  'Rent',
  'Electricity',
  'Salary',
  'Spare purchase',
  'Tools',
  'Fuel',
  'Marketing',
];

/// Everything the workshop spends that is not a job card — with the part of
/// it still owed to a supplier kept in view.
class ExpensesPage extends ConsumerWidget {
  const ExpensesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final rows = ref.watch(expensesProvider);
    final totals = ref.watch(expenseTotalsProvider);

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Expenses'.tr,
        subtitle: 'What the shop spends to stay open'.tr,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.lg),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: Gap.lg),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: R.all(R.lg),
                border: Border.all(color: p.line),
                boxShadow: Shadows.soft(p),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _Stat(
                      label: 'Total Expense'.tr,
                      value: Fmt.money(totals.total),
                      tint: p.ink,
                    ),
                  ),
                  Container(height: 38, width: 1, color: p.line),
                  Expanded(
                    child: _Stat(
                      label: 'Total Pending Balance'.tr,
                      value: Fmt.money(totals.pending),
                      tint: totals.pending > 0 ? p.danger : p.success,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: rows.isEmpty
                ? GEmptyState(
                    icon: Icons.receipt_long_rounded,
                    title: 'Data is not available!'.tr,
                    art: Art.wallet,
                    message:
                        'Add what the workshop spends and it lands here with the supplier it went to.'
                            .tr,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      Gap.page,
                      0,
                      Gap.page,
                      Gap.h2,
                    ),
                    itemCount: rows.length,
                    itemBuilder: (context, i) => Entrance(
                      index: i.clamp(0, 8),
                      child: _ExpenseRow(expense: rows[i]),
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: GBottomBar(
        child: GButton.accent(
          label: 'Add Expenses'.tr,
          icon: Icons.add_rounded,
          onPressed: () => showExpenseSheet(context),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.tint});

  final String label;
  final String value;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Column(
      children: [
        Text(value, style: AppType.moneyL.s(22).c(tint)),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          style: AppType.bodyS.c(p.inkMuted),
        ),
      ],
    );
  }
}

class _ExpenseRow extends ConsumerWidget {
  const _ExpenseRow({required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    return Dismissible(
      key: ValueKey(expense.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.only(bottom: Gap.sm),
        padding: const EdgeInsets.only(right: Gap.lg),
        decoration: BoxDecoration(
          color: p.dangerSoft,
          borderRadius: R.all(R.md),
        ),
        child: Icon(Icons.delete_outline_rounded, color: p.danger),
      ),
      onDismissed: (_) {
        ref.read(adminProvider.notifier).removeExpense(expense.id);
        GFeedback.info(context, 'Expense removed'.tr);
      },
      // Tapping opens the settle sheet. Before it, a row could only be
      // swiped away, so a part-paid bill stayed "Due" forever and the
      // dashboard's Expenses badge never cleared.
      child: Pressable(
        onTap: () => _showSettleSheet(context, expense),
        scale: 0.985,
        child: Container(
          margin: const EdgeInsets.only(bottom: Gap.sm),
          padding: const EdgeInsets.all(Gap.lg),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: R.all(R.md),
            border: Border.all(color: p.line),
            boxShadow: Shadows.soft(p),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.labelL.c(p.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        Fmt.date(expense.at),
                        expense.category,
                        if (expense.supplier.isNotEmpty) expense.supplier,
                      ].join('  ·  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.bodyS.c(p.inkMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Gap.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Fmt.money(expense.amount),
                    style: AppType.money.c(p.ink),
                  ),
                  const SizedBox(height: 3),
                  GPill(
                    label: expense.settled
                        ? 'Paid'.tr
                        : 'Due {0}'.trf([Fmt.money(expense.pending)]),
                    tone: expense.settled ? GTone.success : GTone.danger,
                    compact: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The settle sheet: what one expense cost, what has gone out against it so
/// far, and a way to record the rest — typed, or in one tap with "Mark fully
/// paid". Without it a bill saved as part-paid could never be cleared, so it
/// stayed under Total Pending Balance and on the dashboard's DUE badge for
/// good.
///
/// The field holds the total paid to date, not today's instalment, because
/// that is the figure on the supplier's bill the counter is looking at. Only
/// the rise is new money, so only the rise goes into the day book: a
/// cash-out in the same shape [AdminController.addExpense] writes for money
/// paid up front, but dated now rather than on the expense's date, because
/// now is when it left the drawer.
///
/// Lowering the paid figure is refused, not allowed. What was paid before is
/// already sitting in the Cash Book as money out, and nothing links those
/// entries back to this expense, so there is no safe way to take them out
/// again; letting the expense say less than the drawer says would quietly
/// split the two books. The typed figure is also clamped to 0..amount, the
/// same way [AdminController.addExpense] clamps it.
Future<void> _showSettleSheet(BuildContext context, Expense expense) async {
  final paid = TextEditingController(
    text: expense.paid == expense.paid.roundToDouble()
        ? expense.paid.toStringAsFixed(0)
        : expense.paid.toStringAsFixed(2),
  );
  // Set on the first save. The sheet keeps taking taps through its exit
  // transition, and a second tap would book the same payment twice and pop
  // the page underneath.
  var done = false;

  final recorded = await GFeedback.sheet<bool>(
    context,
    title: expense.title,
    subtitle: [
      Fmt.date(expense.at),
      expense.category,
      if (expense.supplier.isNotEmpty) expense.supplier,
    ].join('  ·  '),
    // Owned by the sheet, not by this function: its future completes
    // when the sheet starts closing, and the field goes on reading this
    // all the way through the exit transition.
    disposing: [paid],
    // Its own Consumer rather than the row's ref: the row can be rebuilt
    // or scrolled away while the sheet is up, and a ref from a disposed
    // widget throws on read.
    child: Consumer(
      builder: (context, ref, _) {
        final p = context.c;
        // Watched rather than the row's copy, so a resync while the sheet
        // is open cannot have the save work from a stale paid figure.
        final live = ref
            .watch(expensesProvider)
            .where((e) => e.id == expense.id)
            .firstOrNull;
        final current = live ?? expense;

        void save(double? typed) {
          if (done) return;
          if (live == null) {
            GFeedback.error(context, 'This expense has been deleted.'.tr);
            return;
          }
          if (typed == null) {
            GFeedback.error(
              context,
              'Enter how much has been paid in total.'.tr,
            );
            return;
          }
          final next = money(typed.clamp(0, current.amount));
          if (next < current.paid - 0.009) {
            GFeedback.error(
              context,
              'Already paid {0}. That money is in the Cash Book, so the amount paid can only go up here.'
                  .trf([Fmt.money(current.paid)]),
            );
            return;
          }
          done = true;
          final raised = money(next - current.paid);
          if (raised > 0) {
            final ctrl = ref.read(adminProvider.notifier);
            ctrl.updateExpense(current.copyWith(paid: next));
            ctrl.addCash(
              party: current.supplier.isEmpty ? current.title : current.supplier,
              amount: raised,
              inward: false,
              reason: current.category,
            );
          }
          Navigator.of(context).pop(raised > 0);
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
              Container(
                padding: const EdgeInsets.symmetric(vertical: Gap.lg),
                decoration: BoxDecoration(
                  color: p.surfaceSunken,
                  borderRadius: R.all(R.md),
                  border: Border.all(color: p.line),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _Stat(
                        label: 'Total'.tr,
                        value: Fmt.money(current.amount),
                        tint: p.ink,
                      ),
                    ),
                    Container(height: 38, width: 1, color: p.line),
                    Expanded(
                      child: _Stat(
                        label: 'Already paid'.tr,
                        value: Fmt.money(current.paid),
                        tint: current.settled ? p.success : p.ink,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Gap.xl),
              if (current.settled)
                Row(
                  children: [
                    Icon(Icons.verified_rounded, size: 18, color: p.success),
                    const SizedBox(width: Gap.sm),
                    Text('Fully paid'.tr, style: AppType.labelL.c(p.success)),
                  ],
                )
              else ...[
                GField(
                  label: 'Amount paid'.tr,
                  helper: 'Total paid so far  ·  {0} still due'.trf([
                    Fmt.money(current.pending),
                  ]),
                  controller: paid,
                  keyboardType: TextInputType.number,
                  textCapitalization: TextCapitalization.none,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                ),
                const SizedBox(height: Gap.xxl),
                Row(
                  children: [
                    Expanded(
                      child: GButton(
                        label: 'Save'.tr,
                        kind: GButtonKind.outline,
                        size: GButtonSize.md,
                        onPressed: () =>
                            save(double.tryParse(paid.text.trim())),
                      ),
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      flex: 2,
                      child: GButton.accent(
                        label: 'Mark fully paid'.tr,
                        icon: Icons.check_rounded,
                        size: GButtonSize.md,
                        onPressed: () => save(current.amount),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    ),
  );

  if (recorded == true && context.mounted) {
    GFeedback.success(context, 'Payment recorded'.tr);
  }
}

/// The add-expense sheet. Amount and what it was for are the only things the
/// counter must type; how much was actually handed over defaults to all of it.
Future<void> showExpenseSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _ExpenseSheet(),
    );

class _ExpenseSheet extends ConsumerStatefulWidget {
  const _ExpenseSheet();

  @override
  ConsumerState<_ExpenseSheet> createState() => _ExpenseSheetState();
}

class _ExpenseSheetState extends ConsumerState<_ExpenseSheet> {
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _paid = TextEditingController();
  final _supplier = TextEditingController();
  String _category = _categories.first;

  @override
  void dispose() {
    for (final c in [_title, _amount, _paid, _supplier]) {
      c.dispose();
    }
    super.dispose();
  }

  double get _amountValue => double.tryParse(_amount.text.trim()) ?? 0;

  bool get _valid => _title.text.trim().isNotEmpty && _amountValue > 0;

  void _save() {
    if (!_valid) return;
    final paid = _paid.text.trim().isEmpty
        ? _amountValue
        : (double.tryParse(_paid.text.trim()) ?? 0);
    ref
        .read(adminProvider.notifier)
        .addExpense(
          title: _title.text,
          amount: _amountValue,
          category: _category,
          supplier: _supplier.text,
          paid: paid,
        );
    Navigator.of(context).pop();
    GFeedback.success(context, 'Expense added'.tr);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    height: 4,
                    width: 44,
                    decoration: BoxDecoration(
                      color: p.line,
                      borderRadius: R.all(R.pill),
                    ),
                  ),
                ),
                const SizedBox(height: Gap.lg),
                Text('Add Expense'.tr, style: AppType.h1.c(p.ink)),
                const SizedBox(height: Gap.lg),
                GField(
                  label: 'What was it for'.tr,
                  hint: 'Shop rent, workshop electricity…'.tr,
                  controller: _title,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: Gap.lg),
                Row(
                  children: [
                    Expanded(
                      child: GField(
                        label: 'Amount'.tr,
                        hint: '1500',
                        controller: _amount,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: GField(
                        label: 'Paid now'.tr,
                        hint: 'All of it'.tr,
                        controller: _paid,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Gap.lg),
                GField(
                  label: 'Supplier'.tr,
                  hint: 'Optional'.tr,
                  controller: _supplier,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: Gap.lg),
                Text('CATEGORY', style: AppType.over.c(p.inkFaint)),
                const SizedBox(height: Gap.sm),
                Wrap(
                  spacing: Gap.sm,
                  runSpacing: Gap.sm,
                  children: [
                    for (final c in _categories)
                      Pressable(
                        onTap: () => setState(() => _category = c),
                        scale: 0.95,
                        child: AnimatedContainer(
                          duration: Motion.fast,
                          padding: const EdgeInsets.symmetric(
                            horizontal: Gap.md,
                            vertical: Gap.sm,
                          ),
                          decoration: BoxDecoration(
                            color: _category == c ? p.ink : p.surfaceAlt,
                            borderRadius: R.all(R.pill),
                            border: Border.all(
                              color: _category == c ? p.ink : p.line,
                            ),
                          ),
                          child: Text(
                            c,
                            style: AppType.labelM.c(
                              _category == c
                                  ? (p.isDark ? p.canvas : Colors.white)
                                  : p.inkSoft,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: Gap.xl),
                GButton.accent(
                  label: 'Save expense'.tr,
                  onPressed: _valid ? _save : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
