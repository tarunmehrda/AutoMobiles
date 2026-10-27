import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_field.dart';
import '../../data/models/books.dart';
import '../../data/models/entities.dart';
import '../../data/models/enums.dart';
import '../../state/admin_state.dart';
import 'trade_widgets.dart';

final _amountFormat = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];

double _parse(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

// ---------------------------------------------------------------------------
// Payment-In: money received from a customer
// ---------------------------------------------------------------------------

/// Receive a payment. Two kinds of party:
///
/// * a customer with a job card still owing — the money goes onto that card
///   with `addPayment`, so the card's balance, the Pending list and the
///   invoice all move together. Filed under [kPaymentIn] so it also lists
///   on the Payment-In tab;
/// * anyone else, typed by name — `recordPaymentIn`, a plain day-book line.
Future<void> showReceivePaymentSheet(BuildContext context) async {
  final done = await GFeedback.sheet<bool>(
    context,
    title: 'Receive Payment'.tr,
    subtitle: 'Payment-In from a customer or any party'.tr,
    child: const _ReceiveSheet(),
  );
  if (done == true && context.mounted) {
    GFeedback.success(context, 'Payment received'.tr);
  }
}

class _ReceiveSheet extends ConsumerStatefulWidget {
  const _ReceiveSheet();

  @override
  ConsumerState<_ReceiveSheet> createState() => _ReceiveSheetState();
}

class _ReceiveSheetState extends ConsumerState<_ReceiveSheet> {
  final _party = TextEditingController();
  final _amount = TextEditingController();
  String? _cardId;
  PayMode _mode = PayMode.cash;
  String? _account;
  DateTime _at = DateTime.now();
  bool _saved = false;

  @override
  void dispose() {
    _party.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickCard() async {
    final data = ref.read(adminProvider);
    final owing = data.pendingBalance;
    final picked = await pickFromList<Object>(
      context,
      title: 'Customer with a balance'.tr,
      subtitle: '{0} job cards owing'.trf([owing.length]),
      items: owing,
      icon: Icons.person_rounded,
      labelOf: (o) {
        final j = o as JobCard;
        return data.customerById(j.customerId)?.name ?? j.number;
      },
      subtitleOf: (o) {
        final j = o as JobCard;
        final v = data.vehicleById(j.vehicleId);
        return [j.number, if (v != null) v.regNo].join('  ·  ');
      },
      trailingOf: (o) => Fmt.money((o as JobCard).balance),
      // A name typed in is a party with no card behind it.
      freeText: (typed) => typed,
      emptyMessage: 'No job card is owing right now. Type a name instead.'.tr,
    );
    if (picked == null) return;
    setState(() {
      if (picked is JobCard) {
        _cardId = picked.id;
        _party.text =
            data.customerById(picked.customerId)?.name ?? picked.number;
        _amount.text = plainAmount(picked.balance);
      } else {
        _cardId = null;
        _party.text = picked as String;
      }
    });
  }

  void _save() {
    if (_saved) return;
    final amount = _parse(_amount);
    final party = _party.text.trim();
    if (party.isEmpty || amount <= 0) {
      GFeedback.error(context, 'Enter who paid and how much.'.tr);
      return;
    }
    final ctrl = ref.read(adminProvider.notifier);
    final data = ref.read(adminProvider);
    if (_cardId != null) {
      final card = data.jobById(_cardId);
      if (card == null) return;
      if (amount > card.balance + 0.009) {
        GFeedback.error(
          context,
          'Only {0} is owing on {1}.'.trf([
            Fmt.money(card.balance),
            card.number,
          ]),
        );
        return;
      }
      _saved = true;
      ctrl.addPayment(
        card.id,
        amount: amount,
        mode: _mode,
        note: kPaymentIn,
        accountId: _account ?? defaultAccountFor(data, _mode),
      );
    } else {
      _saved = true;
      ctrl.recordPaymentIn(
        party: party,
        amount: amount,
        mode: _mode,
        accountId: _account ?? defaultAccountFor(data, _mode),
        at: _at,
      );
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final data = ref.watch(adminProvider);
    final card = data.jobById(_cardId);
    return SheetBody(
      children: [
        GPickerField(
          label: 'Party'.tr,
          value: _party.text.isEmpty ? null : _party.text,
          placeholder: 'Pick a customer or type a name'.tr,
          leadingIcon: Icons.person_search_rounded,
          onTap: _pickCard,
        ),
        if (card != null) ...[
          const SizedBox(height: Gap.sm),
          Text(
            'Against {0}  ·  {1} owing'.trf([
              card.number,
              Fmt.money(card.balance),
            ]),
            style: AppType.labelM.c(p.accentInk),
          ),
        ],
        const SizedBox(height: Gap.lg),
        GField(
          label: 'Amount'.tr,
          hint: '1500',
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: _amountFormat,
          prefix: Text('₹ ', style: AppType.labelL.c(p.inkMuted)),
        ),
        const SizedBox(height: Gap.lg),
        PayControls(
          mode: _mode,
          accountId: _account,
          // A job card payment follows its mode into the books; the card has
          // no account of its own to name.
          showAccount: card == null,
          onChanged: (m, a) => setState(() {
            _mode = m;
            _account = a;
          }),
        ),
        if (card == null) ...[
          const SizedBox(height: Gap.lg),
          DateField(
            label: 'Date'.tr,
            value: _at,
            onChanged: (d) => setState(() => _at = d),
          ),
        ] else ...[
          const SizedBox(height: Gap.md),
          Text(
            'Goes to {0}, dated today.'.trf([
              accountLabel(data, _account ?? defaultAccountFor(data, _mode)),
            ]),
            style: AppType.bodyS.c(p.inkMuted),
          ),
        ],
        const SizedBox(height: Gap.xl),
        GButton(
          label: 'Receive payment'.tr,
          kind: GButtonKind.volt,
          icon: Icons.south_west_rounded,
          onPressed: _save,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Pay-Out: money paid to a supplier
// ---------------------------------------------------------------------------

/// Pay a supplier. Picking one shows what they are owed and fills it in;
/// the payment comes off that figure.
Future<void> showPayOutSheet(BuildContext context, {String? supplierId}) async {
  final done = await GFeedback.sheet<bool>(
    context,
    title: 'Pay-Out'.tr,
    subtitle: 'Money paid to a supplier'.tr,
    child: _PayOutSheet(supplierId: supplierId),
  );
  if (done == true && context.mounted) {
    GFeedback.success(context, 'Payment recorded'.tr);
  }
}

class _PayOutSheet extends ConsumerStatefulWidget {
  const _PayOutSheet({this.supplierId});

  final String? supplierId;

  @override
  ConsumerState<_PayOutSheet> createState() => _PayOutSheetState();
}

class _PayOutSheetState extends ConsumerState<_PayOutSheet> {
  final _amount = TextEditingController();
  String? _supplierId;
  String _party = '';
  PayMode _mode = PayMode.cash;
  String? _account;
  DateTime _at = DateTime.now();
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    final s = ref.read(adminProvider).supplierById(widget.supplierId);
    if (s != null) _choose(s);
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _choose(Supplier s) {
    _supplierId = s.id;
    _party = s.name;
    if (s.outstanding > 0) _amount.text = plainAmount(s.outstanding);
  }

  Future<void> _pick() async {
    final suppliers = [...ref.read(adminProvider).suppliers]
      ..sort((a, b) => b.outstanding.compareTo(a.outstanding));
    final picked = await pickFromList<Object>(
      context,
      title: 'Supplier'.tr,
      items: suppliers,
      icon: Icons.local_shipping_rounded,
      labelOf: (o) => (o as Supplier).name,
      subtitleOf: (o) => (o as Supplier).phone,
      trailingOf: (o) {
        final s = o as Supplier;
        return s.outstanding > 0 ? Fmt.money(s.outstanding) : '';
      },
      freeText: (typed) => typed,
      emptyMessage: 'No suppliers yet. Type a name instead.'.tr,
    );
    if (picked == null) return;
    setState(() {
      if (picked is Supplier) {
        _choose(picked);
      } else {
        _supplierId = null;
        _party = picked as String;
      }
    });
  }

  void _save() {
    if (_saved) return;
    final amount = _parse(_amount);
    if (_party.trim().isEmpty || amount <= 0) {
      GFeedback.error(context, 'Choose who was paid and how much.'.tr);
      return;
    }
    _saved = true;
    final data = ref.read(adminProvider);
    ref
        .read(adminProvider.notifier)
        .recordPayOut(
          party: _party,
          amount: amount,
          supplierId: _supplierId,
          mode: _mode,
          accountId: _account ?? defaultAccountFor(data, _mode),
          at: _at,
        );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final s = ref.watch(adminProvider).supplierById(_supplierId);
    return SheetBody(
      children: [
        GPickerField(
          label: 'Supplier'.tr,
          value: _party.isEmpty ? null : _party,
          placeholder: 'Choose a supplier'.tr,
          leadingIcon: Icons.local_shipping_rounded,
          onTap: _pick,
        ),
        if (s != null) ...[
          const SizedBox(height: Gap.sm),
          Text(
            s.outstanding > 0
                ? 'Outstanding {0}'.trf([Fmt.money(s.outstanding)])
                : 'Nothing outstanding'.tr,
            style: AppType.labelM.c(s.outstanding > 0 ? p.danger : p.success),
          ),
        ],
        const SizedBox(height: Gap.lg),
        GField(
          label: 'Amount'.tr,
          hint: '1500',
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: _amountFormat,
          prefix: Text('₹ ', style: AppType.labelL.c(p.inkMuted)),
        ),
        const SizedBox(height: Gap.lg),
        PayControls(
          mode: _mode,
          accountId: _account,
          onChanged: (m, a) => setState(() {
            _mode = m;
            _account = a;
          }),
        ),
        const SizedBox(height: Gap.lg),
        DateField(
          label: 'Date'.tr,
          value: _at,
          onChanged: (d) => setState(() => _at = d),
        ),
        const SizedBox(height: Gap.xl),
        GButton(
          label: 'Record pay-out'.tr,
          kind: GButtonKind.danger,
          icon: Icons.north_east_rounded,
          onPressed: _save,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Settling a document after the fact
// ---------------------------------------------------------------------------

/// Takes more money against a document — or, for a sale order, hands it
/// over ([fulfil]) and collects what is due at delivery.
Future<void> showSettleSheet(
  BuildContext context,
  TradeDoc doc, {
  bool fulfil = false,
}) async {
  final done = await GFeedback.sheet<bool>(
    context,
    title: fulfil ? 'Fulfil order'.tr : _settleTitle(doc.kind),
    subtitle: '{0}  ·  {1} due'.trf([doc.number, Fmt.money(doc.balance)]),
    child: _SettleSheet(doc: doc, fulfil: fulfil),
  );
  if (done == true && context.mounted) {
    GFeedback.success(
      context,
      fulfil ? 'Order fulfilled'.tr : 'Payment recorded'.tr,
    );
  }
}

String _settleTitle(TradeKind k) => switch (k) {
  TradeKind.saleReturn => 'Refund customer'.tr,
  TradeKind.purchaseReturn => 'Refund received'.tr,
  TradeKind.purchaseBill => 'Pay supplier'.tr,
  _ => 'Record payment'.tr,
};

class _SettleSheet extends ConsumerStatefulWidget {
  const _SettleSheet({required this.doc, required this.fulfil});

  final TradeDoc doc;
  final bool fulfil;

  @override
  ConsumerState<_SettleSheet> createState() => _SettleSheetState();
}

class _SettleSheetState extends ConsumerState<_SettleSheet> {
  late final _amount = TextEditingController(
    text: widget.doc.balance > 0 ? plainAmount(widget.doc.balance) : '',
  );
  PayMode _mode = PayMode.cash;
  String? _account;
  bool _saved = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _save() {
    if (_saved) return;
    final amount = _parse(_amount);
    final data = ref.read(adminProvider);
    final live = data.tradeDocs.where((e) => e.id == widget.doc.id).firstOrNull;
    if (live == null) {
      GFeedback.error(context, 'This document has been deleted.'.tr);
      return;
    }
    if (!widget.fulfil && amount <= 0) {
      GFeedback.error(context, 'Enter an amount.'.tr);
      return;
    }
    if (amount > live.balance + 0.009) {
      GFeedback.error(
        context,
        'Only {0} is due.'.trf([Fmt.money(live.balance)]),
      );
      return;
    }
    _saved = true;
    final ctrl = ref.read(adminProvider.notifier);
    final account = _account ?? defaultAccountFor(data, _mode);
    if (widget.fulfil) {
      ctrl.fulfilSaleOrder(
        live.id,
        collect: amount,
        mode: _mode,
        accountId: account,
      );
    } else {
      ctrl.settleTradeDoc(
        live.id,
        amount: amount,
        mode: _mode,
        accountId: account,
      );
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final doc = widget.doc;
    return SheetBody(
      children: [
        if (widget.fulfil) ...[
          Text(
            'The stock on this order goes out now. Collect whatever is still due at delivery, or leave it at zero.'
                .tr,
            style: AppType.bodyM.c(p.inkMuted),
          ),
          const SizedBox(height: Gap.lg),
        ],
        GField(
          label: widget.fulfil
              ? 'Collected at delivery'.tr
              : (doc.kind.moneyIn ? 'Amount received'.tr : 'Amount paid'.tr),
          hint: plainAmount(doc.balance),
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: _amountFormat,
          prefix: Text('₹ ', style: AppType.labelL.c(p.inkMuted)),
        ),
        const SizedBox(height: Gap.lg),
        PayControls(
          mode: _mode,
          accountId: _account,
          onChanged: (m, a) => setState(() {
            _mode = m;
            _account = a;
          }),
        ),
        const SizedBox(height: Gap.xl),
        GButton.accent(
          label: widget.fulfil ? 'Mark delivered'.tr : 'Save payment'.tr,
          icon: widget.fulfil
              ? Icons.local_shipping_rounded
              : Icons.check_rounded,
          onPressed: _save,
        ),
      ],
    );
  }
}
