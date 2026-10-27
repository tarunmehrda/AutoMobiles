import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../../core/widgets/g_surface.dart';
import '../../core/widgets/pressable.dart';
import '../../data/models/books.dart';
import '../../state/admin_state.dart';
import 'widgets/bank_sheets.dart';

/// Where the money is: the drawer and every bank account, each with its
/// balance worked out from its opening figure and the day book since.
class BankAccountsPage extends ConsumerWidget {
  const BankAccountsPage({super.key, this.tab});

  /// `cash` when the dashboard sent the owner here to look at Cash in Hand —
  /// that card is drawn highlighted.
  final String? tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final data = ref.watch(adminProvider);
    final cash = data.cashAccount;
    final banks = data.banks;

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Bank & Cash'.tr,
        subtitle: 'Cash in Hand and your bank accounts'.tr,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.h2),
        children: [
          Entrance(
            child: _TotalHero(
              total: data.totalFunds,
              cash: data.balanceOf(cash),
              bank: data.totalFunds - data.balanceOf(cash),
            ),
          ),
          const SizedBox(height: Gap.md),
          Entrance(
            index: 1,
            child: _CashCard(
              account: cash,
              balance: data.balanceOf(cash),
              highlight: tab == 'cash',
            ),
          ),
          GSectionHeader(
            title: 'Bank accounts'.tr,
            subtitle: Tr.plural(banks.length, '{0} account', '{0} accounts'),
            icon: Icons.account_balance_rounded,
            iconTint: p.info,
            actionLabel: banks.isEmpty ? null : 'Add'.tr,
            onAction: () => showBankSheet(context),
            padding: const EdgeInsets.fromLTRB(0, Gap.xxl, 0, Gap.md),
          ),
          if (banks.isEmpty)
            GEmptyState(
              compact: true,
              icon: Icons.account_balance_rounded,
              art: Art.wallet,
              title: 'No bank account yet'.tr,
              message:
                  'Add the account UPI and cheques go into, and its details can be printed on every invoice.'
                      .tr,
              actionLabel: '+ Add Bank Account'.tr,
              onAction: () => showBankSheet(context),
            )
          else
            for (var i = 0; i < banks.length; i++)
              Entrance(
                index: (i + 2).clamp(0, 8),
                child: _BankCard(
                  account: banks[i],
                  balance: data.balanceOf(banks[i]),
                ),
              ),
        ],
      ),
      bottomNavigationBar: GBottomBar(
        child: Row(
          children: [
            Expanded(
              child: GButton(
                label: 'Transfer'.tr,
                kind: GButtonKind.outline,
                icon: Icons.swap_horiz_rounded,
                onPressed: () => showTransferSheet(context),
              ),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              flex: 2,
              child: GButton.accent(
                label: 'Add Bank Account'.tr,
                icon: Icons.add_rounded,
                onPressed: () => showBankSheet(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalHero extends StatelessWidget {
  const _TotalHero({
    required this.total,
    required this.cash,
    required this.bank,
  });

  final double total;
  final double cash;
  final double bank;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(p.accent.withValues(alpha: 0.15), p.surface),
            Color.alphaBlend(p.accent.withValues(alpha: 0.04), p.surface),
          ],
        ),
        borderRadius: R.all(R.xl),
        border: Border.all(color: p.accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total funds'.tr, style: AppType.labelM.s(12.5).c(p.inkMuted)),
          const SizedBox(height: 2),
          AnimatedCount(
            value: total,
            builder: (context, v) => FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                Fmt.money(v),
                style: AppType.d1
                    .s(30)
                    .c(total < 0 ? p.danger : p.ink)
                    .w(FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(height: Gap.md),
          Row(
            children: [
              Expanded(
                child: _Split(
                  icon: Icons.payments_rounded,
                  label: 'Cash'.tr,
                  value: cash,
                  tint: p.success,
                ),
              ),
              Expanded(
                child: _Split(
                  icon: Icons.account_balance_rounded,
                  label: 'Bank'.tr,
                  value: bank,
                  tint: p.info,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Split extends StatelessWidget {
  const _Split({
    required this.icon,
    required this.label,
    required this.value,
    required this.tint,
  });

  final IconData icon;
  final String label;
  final double value;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Row(
      children: [
        Icon(icon, size: 16, color: tint),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            '$label  ${Fmt.money(value)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.labelM.c(p.inkSoft),
          ),
        ),
      ],
    );
  }
}

class _CashCard extends StatelessWidget {
  const _CashCard({
    required this.account,
    required this.balance,
    required this.highlight,
  });

  final BankAccount account;
  final double balance;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Pressable(
      onTap: () => context.push('/bank-accounts/$kCashAccountId'),
      scale: 0.985,
      child: Container(
        padding: const EdgeInsets.all(Gap.lg),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: R.all(R.lg),
          border: Border.all(
            color: highlight ? p.accent : p.line,
            width: highlight ? 1.6 : 1,
          ),
          boxShadow: highlight ? Shadows.lifted(p) : Shadows.soft(p),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Badge(icon: Icons.payments_rounded, tint: p.success),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cash in Hand'.tr, style: AppType.labelL.c(p.ink)),
                      Text(
                        account.openingAt == null
                            ? 'No opening balance set'.tr
                            : 'Opening {0} on {1}'.trf([
                                Fmt.money(account.opening),
                                Fmt.date(account.openingAt!),
                              ]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.bodyS.c(p.inkMuted),
                      ),
                    ],
                  ),
                ),
                Text(
                  Fmt.money(balance),
                  style: AppType.money.c(balance < 0 ? p.danger : p.ink),
                ),
              ],
            ),
            const SizedBox(height: Gap.md),
            // Wraps rather than sits in a Row: with a large font the two
            // links do not fit side by side on a 320dp phone.
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: Gap.md,
              runSpacing: Gap.sm,
              children: [
                GLink(
                  label: 'Set opening balance'.tr,
                  icon: Icons.edit_rounded,
                  onTap: () => showCashOpeningSheet(context),
                ),
                GLink(
                  label: 'Statement'.tr,
                  icon: Icons.chevron_right_rounded,
                  onTap: () => context.push('/bank-accounts/$kCashAccountId'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BankCard extends ConsumerWidget {
  const _BankCard({required this.account, required this.balance});

  final BankAccount account;
  final double balance;

  Future<void> _actions(BuildContext context, WidgetRef ref) async {
    final choice = await GFeedback.sheet<String>(
      context,
      title: account.name,
      subtitle: account.masked.isEmpty ? null : account.masked,
      child: Builder(
        builder: (context) => ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
            Gap.page,
            Gap.lg,
            Gap.page,
            Gap.h1,
          ),
          children: [
            for (final (id, label, icon) in [
              ('statement', 'View statement'.tr, Icons.receipt_long_rounded),
              ('edit', 'Edit details'.tr, Icons.edit_rounded),
              ('deposit', 'Deposit cash here'.tr, Icons.south_west_rounded),
              ('withdraw', 'Withdraw cash'.tr, Icons.north_east_rounded),
              ('delete', 'Delete account'.tr, Icons.delete_outline_rounded),
            ])
              GTile(
                title: label,
                icon: icon,
                iconColor: id == 'delete' ? context.c.danger : null,
                onTap: () => Navigator.of(context).pop(id),
              ),
          ],
        ),
      ),
    );
    if (!context.mounted || choice == null) return;
    switch (choice) {
      case 'statement':
        context.push('/bank-accounts/${account.id}');
      case 'edit':
        showBankSheet(context, existing: account);
      case 'deposit':
        showTransferSheet(context, fromId: kCashAccountId, toId: account.id);
      case 'withdraw':
        showTransferSheet(context, fromId: account.id, toId: kCashAccountId);
      case 'delete':
        final ok = await GFeedback.confirm(
          context,
          title: 'Delete {0}?'.trf([account.name]),
          message:
              'Entries that went through it stay in the cash book and are counted by their payment mode instead.'
                  .tr,
          confirmLabel: 'Delete'.tr,
          destructive: true,
          icon: Icons.delete_outline_rounded,
        );
        if (!ok || !context.mounted) return;
        ref.read(adminProvider.notifier).removeAccount(account.id);
        GFeedback.info(context, 'Bank account deleted'.tr);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    return Pressable(
      onTap: () => context.push('/bank-accounts/${account.id}'),
      onLongPress: () => _actions(context, ref),
      scale: 0.985,
      child: Container(
        margin: const EdgeInsets.only(bottom: Gap.sm),
        padding: const EdgeInsets.all(Gap.lg),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: R.all(R.lg),
          border: Border.all(color: account.primary ? p.info : p.line),
          boxShadow: Shadows.soft(p),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Badge(icon: Icons.account_balance_rounded, tint: p.info),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.labelL.c(p.ink),
                      ),
                      Text(
                        [
                          if (account.masked.isNotEmpty) account.masked,
                          if (account.ifsc.isNotEmpty) account.ifsc,
                          if (account.masked.isEmpty && account.ifsc.isEmpty)
                            account.holder,
                        ].join('  ·  '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.bodyS.c(p.inkMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Gap.sm),
                Text(
                  Fmt.money(balance),
                  style: AppType.money.c(balance < 0 ? p.danger : p.ink),
                ),
                GIconButton(
                  icon: Icons.more_vert_rounded,
                  size: 32,
                  bordered: false,
                  background: Colors.transparent,
                  tooltip: 'More'.tr,
                  onTap: () => _actions(context, ref),
                ),
              ],
            ),
            if (account.primary ||
                account.printOnInvoice ||
                account.printUpiQr ||
                account.upiId.isNotEmpty) ...[
              const SizedBox(height: Gap.md),
              Wrap(
                spacing: Gap.sm,
                runSpacing: Gap.xs,
                children: [
                  if (account.primary)
                    GPill(
                      label: 'Primary'.tr,
                      tone: GTone.info,
                      icon: Icons.star_rounded,
                      compact: true,
                    ),
                  if (account.printOnInvoice)
                    GPill(
                      label: 'Printed on invoice'.tr,
                      tone: GTone.neutral,
                      icon: Icons.print_rounded,
                      compact: true,
                    ),
                  if (account.printUpiQr)
                    GPill(
                      label: 'UPI QR on invoice'.tr,
                      tone: GTone.success,
                      icon: Icons.qr_code_2_rounded,
                      compact: true,
                    ),
                  if (account.upiId.isNotEmpty && !account.printUpiQr)
                    GPill(
                      label: account.upiId,
                      tone: GTone.neutral,
                      compact: true,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.tint});

  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) => Container(
    height: 40,
    width: 40,
    decoration: BoxDecoration(
      color: tint.withValues(alpha: 0.12),
      borderRadius: R.all(R.sm),
    ),
    child: Icon(icon, size: 19, color: tint),
  );
}
