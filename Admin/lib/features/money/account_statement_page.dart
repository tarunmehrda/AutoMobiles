import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/anim/entrance.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_art.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_state.dart';
import '../../data/models/books.dart';
import '../../data/models/entities.dart';
import '../../data/models/enums.dart';
import '../../state/admin_state.dart';
import 'widgets/bank_sheets.dart';

/// Which slice of the statement is on screen.
enum _Range { all, month, lastMonth, custom }

/// One account's passbook: its opening balance, then every day-book line
/// that went through it since, each with the balance it left behind.
class AccountStatementPage extends ConsumerStatefulWidget {
  const AccountStatementPage({super.key, required this.id});

  final String id;

  @override
  ConsumerState<AccountStatementPage> createState() =>
      _AccountStatementPageState();
}

class _AccountStatementPageState extends ConsumerState<AccountStatementPage> {
  _Range _range = _Range.all;
  DateTimeRange? _custom;

  String _label(_Range r) => switch (r) {
    _Range.all => 'All'.tr,
    _Range.month => 'This month'.tr,
    _Range.lastMonth => 'Last month'.tr,
    _Range.custom =>
      _custom == null
          ? 'Custom'.tr
          : '${Fmt.dateShort(_custom!.start)} – ${Fmt.dateShort(_custom!.end)}',
  };

  /// The window as [from, to): `to` is exclusive so a whole last day counts.
  (DateTime?, DateTime?) get _window {
    final now = DateTime.now();
    return switch (_range) {
      _Range.all => (null, null),
      _Range.month => (DateTime(now.year, now.month), null),
      _Range.lastMonth => (
        DateTime(now.year, now.month - 1),
        DateTime(now.year, now.month),
      ),
      _Range.custom =>
        _custom == null
            ? (null, null)
            : (
                _custom!.start,
                DateTime(
                  _custom!.end.year,
                  _custom!.end.month,
                  _custom!.end.day + 1,
                ),
              ),
    };
  }

  Future<void> _select(_Range r) async {
    if (r != _Range.custom) {
      setState(() => _range = r);
      return;
    }
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _custom,
    );
    if (picked == null) return;
    setState(() {
      _custom = picked;
      _range = _Range.custom;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final data = ref.watch(adminProvider);
    final account = data.accountById(widget.id);

    if (account == null) {
      return Scaffold(
        backgroundColor: p.canvas,
        appBar: GHeader(title: 'Statement'.tr),
        body: GEmptyState(
          icon: Icons.account_balance_rounded,
          art: Art.noData,
          title: 'Account not found'.tr,
          message: 'It may have been deleted on another phone.'.tr,
        ),
      );
    }

    // Oldest first, so the running balance can be carried down the page.
    final since = account.openingAt;
    final lines =
        data.cashBook
            .where(
              (e) =>
                  data.accountOf(e) == account.id &&
                  (since == null || !e.at.isBefore(since)),
            )
            .toList()
          ..sort((a, b) => a.at.compareTo(b.at));

    var running = account.opening;
    final withBalance = <({CashEntry e, double after})>[];
    for (final e in lines) {
      running += e.inward ? e.amount : -e.amount;
      withBalance.add((e: e, after: money(running)));
    }

    final (from, to) = _window;
    bool inside(DateTime at) =>
        (from == null || !at.isBefore(from)) && (to == null || at.isBefore(to));
    final shown = withBalance.where((r) => inside(r.e.at)).toList();

    // What the account held when the window opens: the opening balance plus
    // everything before it.
    var broughtForward = account.opening;
    for (final r in withBalance) {
      if (from != null && r.e.at.isBefore(from)) broughtForward = r.after;
    }
    final inSum = shown
        .where((r) => r.e.inward)
        .fold<double>(0, (s, r) => s + r.e.amount);
    final outSum = shown
        .where((r) => !r.e.inward)
        .fold<double>(0, (s, r) => s + r.e.amount);
    final closing = money(broughtForward + inSum - outSum);
    final showOpening =
        from == null || since == null || !since.isBefore(from) && inside(since);

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: account.title,
        subtitle: account.cash
            ? 'Statement'.tr
            : [
                if (account.masked.isNotEmpty) account.masked,
                'Statement'.tr,
              ].join('  ·  '),
        bottomHeight: 52,
        bottom: Align(
          alignment: Alignment.topCenter,
          child: GChoiceChips<_Range>(
            options: _Range.values,
            selected: _range,
            onSelect: _select,
            labelOf: _label,
            iconOf: (r) => r == _Range.custom ? Icons.date_range_rounded : null,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.h2),
        children: [
          Entrance(
            child: Container(
              padding: const EdgeInsets.all(Gap.lg),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: R.all(R.lg),
                border: Border.all(color: p.line),
                boxShadow: Shadows.soft(p),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _Cell(
                        label: from == null
                            ? 'Opening'.tr
                            : 'Brought forward'.tr,
                        value: from == null ? account.opening : broughtForward,
                      ),
                      _Cell(label: 'In'.tr, value: inSum, tint: p.success),
                      _Cell(label: 'Out'.tr, value: outSum, tint: p.danger),
                    ],
                  ),
                  const Divider(height: Gap.xl),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          to == null ? 'Balance now'.tr : 'Closing balance'.tr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.labelL.c(p.inkMuted),
                        ),
                      ),
                      const SizedBox(width: Gap.sm),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            Fmt.money(closing),
                            style: AppType.moneyL
                                .s(22)
                                .c(closing < 0 ? p.danger : p.ink),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Gap.lg),
          if (shown.isEmpty && !showOpening)
            GEmptyState(
              compact: true,
              icon: Icons.receipt_long_rounded,
              art: Art.wallet,
              title: 'No entries'.tr,
              message: 'Nothing went through this account in that period.'.tr,
            )
          else ...[
            // Newest at the top, as the cash book reads.
            for (final (i, r) in shown.reversed.indexed)
              Entrance(
                index: (i + 1).clamp(0, 8),
                child: _Line(entry: r.e, after: r.after),
              ),
            if (showOpening) _OpeningLine(account: account),
          ],
        ],
      ),
      bottomNavigationBar: account.cash
          ? GBottomBar(
              child: GButton(
                label: 'Set opening balance'.tr,
                kind: GButtonKind.outline,
                icon: Icons.edit_rounded,
                onPressed: () => showCashOpeningSheet(context),
              ),
            )
          : GBottomBar(
              child: GButton(
                label: 'Edit account'.tr,
                kind: GButtonKind.outline,
                icon: Icons.edit_rounded,
                onPressed: () => showBankSheet(context, existing: account),
              ),
            ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.label, required this.value, this.tint});

  final String label;
  final double value;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              Fmt.money(value),
              style: AppType.money.s(16).c(tint ?? p.ink),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.bodyS.s(11.5).c(p.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.entry, required this.after});

  final CashEntry entry;
  final double after;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final tint = entry.inward ? p.success : p.danger;
    return Container(
      margin: const EdgeInsets.only(bottom: Gap.sm),
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: R.all(R.md),
        border: Border.all(color: p.line),
      ),
      child: Row(
        children: [
          // The in/out colour as a bar down the edge. Not a coloured left
          // border: Flutter refuses a radius on a border of mixed colours.
          Container(
            width: 3,
            height: 34,
            decoration: BoxDecoration(color: tint, borderRadius: R.all(R.pill)),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.party.isEmpty ? 'Walk-in'.tr : entry.party,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.labelL.c(p.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    Fmt.dateTime(entry.at),
                    entry.mode.label,
                    if (entry.reason.isNotEmpty) entry.reason,
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
                '${entry.inward ? '+ ' : '- '}${Fmt.money(entry.amount)}',
                style: AppType.money.c(tint),
              ),
              Text(
                'Bal {0}'.trf([Fmt.money(after)]),
                style: AppType.labelS.c(p.inkFaint),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OpeningLine extends StatelessWidget {
  const _OpeningLine({required this.account});

  final BankAccount account;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: p.surfaceSunken,
        borderRadius: R.all(R.md),
        border: Border.all(color: p.line),
      ),
      child: Row(
        children: [
          Icon(Icons.flag_rounded, size: 18, color: p.inkMuted),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Text(
              account.openingAt == null
                  ? 'Opening balance'.tr
                  : 'Opening balance  ·  {0}'.trf([
                      Fmt.date(account.openingAt!),
                    ]),
              style: AppType.labelM.c(p.inkSoft),
            ),
          ),
          GPill(label: Fmt.money(account.opening), compact: true),
        ],
      ),
    );
  }
}
