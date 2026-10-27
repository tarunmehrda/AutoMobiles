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
import '../../../data/models/books.dart';
import '../../../data/models/entities.dart' show money;
import '../../../state/admin_state.dart';
import '../../trade/trade_widgets.dart';

final _amountFormat = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];

// ---------------------------------------------------------------------------
// Add or edit a bank account
// ---------------------------------------------------------------------------

/// The bank account form. With [existing] it edits that account in place;
/// its id never changes, so every day-book line that named it still does.
Future<void> showBankSheet(BuildContext context, {BankAccount? existing}) =>
    GFeedback.sheet<void>(
      context,
      title: existing == null ? 'Add Bank Account'.tr : 'Edit Bank Account'.tr,
      subtitle: 'Where UPI, cheques and transfers land'.tr,
      child: _BankSheet(existing: existing),
    );

class _BankSheet extends ConsumerStatefulWidget {
  const _BankSheet({this.existing});

  final BankAccount? existing;

  @override
  ConsumerState<_BankSheet> createState() => _BankSheetState();
}

class _BankSheetState extends ConsumerState<_BankSheet> {
  late final BankAccount? _e = widget.existing;
  late final _name = TextEditingController(text: _e?.name);
  late final _holder = TextEditingController(text: _e?.holder);
  late final _number = TextEditingController(text: _e?.accountNo);
  late final _ifsc = TextEditingController(text: _e?.ifsc);
  late final _branch = TextEditingController(text: _e?.branch);
  late final _upi = TextEditingController(text: _e?.upiId);
  late final _opening = TextEditingController(
    text: _e == null || _e.opening == 0 ? '' : plainAmount(_e.opening),
  );
  late DateTime _openingAt = _e?.openingAt ?? DateTime.now();
  late bool _printBank = _e?.printOnInvoice ?? true;
  late bool _printQr = _e?.printUpiQr ?? false;
  late bool _primary = _e?.primary ?? ref.read(adminProvider).banks.isEmpty;
  bool _saved = false;

  @override
  void dispose() {
    for (final c in [_name, _holder, _number, _ifsc, _branch, _upi, _opening]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (_saved) return;
    if (_name.text.trim().isEmpty) {
      GFeedback.error(context, 'Enter the bank name.'.tr);
      return;
    }
    if (_printQr && _upi.text.trim().isEmpty) {
      GFeedback.error(context, 'A UPI QR needs a UPI ID.'.tr);
      return;
    }
    _saved = true;
    final ctrl = ref.read(adminProvider.notifier);
    final opening = double.tryParse(_opening.text.trim()) ?? 0;
    final e = _e;
    if (e == null) {
      ctrl.addBank(
        name: _name.text,
        holder: _holder.text,
        accountNo: _number.text,
        ifsc: _ifsc.text,
        branch: _branch.text,
        upiId: _upi.text,
        opening: opening,
        openingAt: _openingAt,
        printOnInvoice: _printBank,
        printUpiQr: _printQr,
        primary: _primary,
      );
    } else {
      ctrl.saveAccount(
        e.copyWith(
          name: _name.text.trim(),
          holder: _holder.text.trim(),
          accountNo: _number.text.trim(),
          ifsc: _ifsc.text.trim().toUpperCase(),
          branch: _branch.text.trim(),
          upiId: _upi.text.trim(),
          opening: money(opening),
          openingAt: _openingAt,
          printOnInvoice: _printBank,
          printUpiQr: _printQr,
          primary: _primary,
        ),
      );
    }
    Navigator.of(context).pop();
    GFeedback.success(
      context,
      e == null ? 'Bank account added'.tr : 'Bank account updated'.tr,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return SheetBody(
      children: [
        GField(
          label: 'Bank name *'.tr,
          hint: 'HDFC Bank'.tr,
          controller: _name,
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: Gap.lg),
        GField(
          label: 'Account holder'.tr,
          hint: 'As printed on the passbook'.tr,
          controller: _holder,
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: Gap.lg),
        GField(
          label: 'Account number'.tr,
          hint: '50100123456789',
          controller: _number,
          keyboardType: TextInputType.number,
          textCapitalization: TextCapitalization.none,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: Gap.lg),
        Row(
          children: [
            Expanded(
              child: GField(
                label: 'IFSC',
                hint: 'HDFC0001234',
                controller: _ifsc,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [LengthLimitingTextInputFormatter(11)],
              ),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: GField(
                label: 'Branch'.tr,
                hint: 'MG Road'.tr,
                controller: _branch,
                textCapitalization: TextCapitalization.words,
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.lg),
        GField(
          label: 'UPI ID'.tr,
          hint: 'workshop@okhdfcbank',
          controller: _upi,
          keyboardType: TextInputType.emailAddress,
          textCapitalization: TextCapitalization.none,
        ),
        const SizedBox(height: Gap.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: GField(
                label: 'Opening balance'.tr,
                hint: '0',
                controller: _opening,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: _amountFormat,
                prefix: Text('₹ ', style: AppType.labelL.c(p.inkMuted)),
              ),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: DateField(
                label: 'As of'.tr,
                value: _openingAt,
                onChanged: (d) => setState(() => _openingAt = d),
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.lg),
        _Toggle(
          title: 'Print bank details in invoice'.tr,
          subtitle: 'Name, number and IFSC at the foot of the bill'.tr,
          value: _printBank,
          onChanged: (v) => setState(() => _printBank = v),
        ),
        _Toggle(
          title: 'Print UPI QR in invoice'.tr,
          subtitle: 'Customers scan and pay into this account'.tr,
          value: _printQr,
          onChanged: (v) => setState(() => _printQr = v),
        ),
        _Toggle(
          title: 'Primary account'.tr,
          subtitle: 'UPI, cheques and transfers land here by default'.tr,
          value: _primary,
          onChanged: (v) => setState(() => _primary = v),
        ),
        const SizedBox(height: Gap.xl),
        GButton.accent(
          label: _e == null ? 'Save bank account'.tr : 'Save changes'.tr,
          icon: Icons.check_rounded,
          onPressed: _save,
        ),
      ],
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppType.labelL.c(p.ink)),
                Text(subtitle, style: AppType.bodyS.c(p.inkMuted)),
              ],
            ),
          ),
          const SizedBox(width: Gap.sm),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The drawer's opening balance
// ---------------------------------------------------------------------------

/// What was in the drawer on the day the books start. Everything before
/// that date is left out of Cash in Hand, so a workshop can begin
/// mid-year without its old day book distorting today's figure.
Future<void> showCashOpeningSheet(BuildContext context) =>
    GFeedback.sheet<void>(
      context,
      title: 'Opening balance'.tr,
      subtitle: 'Cash in Hand on the day you start counting'.tr,
      child: const _OpeningSheet(),
    );

class _OpeningSheet extends ConsumerStatefulWidget {
  const _OpeningSheet();

  @override
  ConsumerState<_OpeningSheet> createState() => _OpeningSheetState();
}

class _OpeningSheetState extends ConsumerState<_OpeningSheet> {
  late final BankAccount _cash = ref.read(adminProvider).cashAccount;
  late final _amount = TextEditingController(
    text: _cash.opening == 0 ? '' : plainAmount(_cash.opening),
  );
  late DateTime _at = _cash.openingAt ?? DateTime.now();

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return SheetBody(
      children: [
        GField(
          label: 'Cash in Hand'.tr,
          hint: '0',
          controller: _amount,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: _amountFormat,
          prefix: Text('₹ ', style: AppType.labelL.c(p.inkMuted)),
        ),
        const SizedBox(height: Gap.lg),
        DateField(
          label: 'As of'.tr,
          value: _at,
          onChanged: (d) => setState(() => _at = d),
        ),
        const SizedBox(height: Gap.md),
        Text(
          'Cash-book entries before this date are not counted in Cash in Hand.'
              .tr,
          style: AppType.bodyS.c(p.inkMuted),
        ),
        const SizedBox(height: Gap.xl),
        GButton.accent(
          label: 'Set opening balance'.tr,
          icon: Icons.check_rounded,
          onPressed: () {
            // From the start of the day: a sale rung up at 9 a.m. on the
            // opening day belongs after the count, not before it.
            final day = DateTime(_at.year, _at.month, _at.day);
            ref
                .read(adminProvider.notifier)
                .setCashOpening(double.tryParse(_amount.text.trim()) ?? 0, day);
            Navigator.of(context).pop();
            GFeedback.success(context, 'Opening balance saved'.tr);
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Moving money between accounts
// ---------------------------------------------------------------------------

/// Cash deposited into the bank, cash withdrawn, or bank to bank. Two lines
/// in the day book, one out and one in, so neither account's balance lies.
Future<void> showTransferSheet(
  BuildContext context, {
  String? fromId,
  String? toId,
}) => GFeedback.sheet<void>(
  context,
  title: 'Transfer'.tr,
  subtitle: 'Deposit cash, withdraw, or move between banks'.tr,
  child: _TransferSheet(fromId: fromId, toId: toId),
);

class _TransferSheet extends ConsumerStatefulWidget {
  const _TransferSheet({this.fromId, this.toId});

  final String? fromId;
  final String? toId;

  @override
  ConsumerState<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends ConsumerState<_TransferSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late String _from;
  late String _to;
  DateTime _at = DateTime.now();
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    final data = ref.read(adminProvider);
    // The common case is banking the day's cash.
    _from = widget.fromId ?? kCashAccountId;
    _to =
        widget.toId ??
        (_from == kCashAccountId
            ? (data.primaryBank?.id ?? kCashAccountId)
            : kCashAccountId);
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    if (_saved) return;
    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    if (_from == _to) {
      GFeedback.error(context, 'Choose two different accounts.'.tr);
      return;
    }
    if (amount <= 0) {
      GFeedback.error(context, 'Enter an amount.'.tr);
      return;
    }
    _saved = true;
    ref
        .read(adminProvider.notifier)
        .transferFunds(
          fromId: _from,
          toId: _to,
          amount: amount,
          at: _at,
          note: _note.text.trim().isEmpty
              ? (_from == kCashAccountId
                    ? 'Cash deposit'
                    : _to == kCashAccountId
                    ? 'Cash withdrawal'
                    : 'Transfer')
              : _note.text,
        );
    Navigator.of(context).pop();
    GFeedback.success(context, 'Transfer recorded'.tr);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final data = ref.watch(adminProvider);
    final from = data.accountById(_from);
    final to = data.accountById(_to);

    Widget account(String label, BankAccount? a, ValueChanged<String> set) =>
        GPickerField(
          label: label,
          value: a == null
              ? null
              : '${a.title}  ·  ${Fmt.money(data.balanceOf(a))}',
          leadingIcon: a?.cash ?? true
              ? Icons.payments_rounded
              : Icons.account_balance_rounded,
          onTap: () async {
            final picked = await pickAccount(context, selected: a?.id);
            if (picked != null) setState(() => set(picked));
          },
        );

    return SheetBody(
      children: [
        if (data.banks.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(Gap.md),
            decoration: BoxDecoration(
              color: p.warningSoft,
              borderRadius: R.all(R.md),
            ),
            child: Text(
              'Add a bank account first — there is nowhere to move the cash to yet.'
                  .tr,
              style: AppType.bodyS.c(p.warning),
            ),
          ),
          const SizedBox(height: Gap.lg),
        ],
        account('From'.tr, from, (id) => _from = id),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Gap.xs),
            child: GIconButton(
              icon: Icons.swap_vert_rounded,
              size: 36,
              tooltip: 'Swap'.tr,
              onTap: () => setState(() {
                final t = _from;
                _from = _to;
                _to = t;
              }),
            ),
          ),
        ),
        account('To'.tr, to, (id) => _to = id),
        const SizedBox(height: Gap.lg),
        GField(
          label: 'Amount'.tr,
          hint: '5000',
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: _amountFormat,
          prefix: Text('₹ ', style: AppType.labelL.c(p.inkMuted)),
        ),
        const SizedBox(height: Gap.lg),
        DateField(
          label: 'Date'.tr,
          value: _at,
          onChanged: (d) => setState(() => _at = d),
        ),
        const SizedBox(height: Gap.lg),
        GField(label: 'Note'.tr, hint: 'Optional'.tr, controller: _note),
        const SizedBox(height: Gap.xl),
        GButton.accent(
          label: 'Record transfer'.tr,
          icon: Icons.swap_horiz_rounded,
          onPressed: _save,
        ),
      ],
    );
  }
}
