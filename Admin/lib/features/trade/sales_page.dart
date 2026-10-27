import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_art.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../data/models/books.dart';
import '../../data/models/entities.dart';
import '../../data/models/enums.dart';
import '../../data/repo/admin_data.dart';
import '../../state/admin_state.dart';
import 'payment_sheets.dart';
import 'trade_detail_page.dart';
import 'trade_widgets.dart';

/// The four Sales tabs, by the `tab` value the dashboard deep-links with.
enum _Tab { invoice, ret, order, paymentIn }

_Tab _parse(String? v) => switch (v) {
  'return' => _Tab.ret,
  'order' => _Tab.order,
  'paymentIn' => _Tab.paymentIn,
  _ => _Tab.invoice,
};

/// Everything that brings money in: invoices (job cards and counter
/// sales), returns, orders, and money received outside any of them.
class SalesPage extends ConsumerStatefulWidget {
  const SalesPage({super.key, this.tab});

  final String? tab;

  @override
  ConsumerState<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends ConsumerState<SalesPage> {
  late _Tab _tab = _parse(widget.tab);

  @override
  void didUpdateWidget(SalesPage old) {
    super.didUpdateWidget(old);
    // A second deep link onto the page already open switches the tab.
    if (old.tab != widget.tab) _tab = _parse(widget.tab);
  }

  String _label(_Tab t) => switch (t) {
    _Tab.invoice => 'Sale Invoice'.tr,
    _Tab.ret => 'Sale Return'.tr,
    _Tab.order => 'Sale Order'.tr,
    _Tab.paymentIn => 'Payment-In'.tr,
  };

  IconData _icon(_Tab t) => switch (t) {
    _Tab.invoice => Icons.receipt_long_rounded,
    _Tab.ret => Icons.assignment_return_rounded,
    _Tab.order => Icons.shopping_bag_rounded,
    _Tab.paymentIn => Icons.south_west_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final data = ref.watch(adminProvider);

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Sales'.tr,
        subtitle: 'Invoices, returns, orders and payments in'.tr,
        bottomHeight: 52,
        bottom: HubTabs<_Tab>(
          options: _Tab.values,
          selected: _tab,
          onSelect: (t) => setState(() => _tab = t),
          labelOf: _label,
          iconOf: _icon,
        ),
      ),
      body: switch (_tab) {
        _Tab.invoice => _Invoices(data: data),
        _Tab.ret => TradeTab(data: data, kind: TradeKind.saleReturn),
        _Tab.order => TradeTab(data: data, kind: TradeKind.saleOrder),
        _Tab.paymentIn => _PaymentsIn(data: data),
      },
      bottomNavigationBar: GBottomBar(
        child: switch (_tab) {
          _Tab.invoice => GButton.accent(
            label: 'New Counter Sale'.tr,
            icon: Icons.add_rounded,
            onPressed: () => context.push('/inventory/counter-sale/new'),
          ),
          _Tab.ret => _NewButton(kind: TradeKind.saleReturn),
          _Tab.order => _NewButton(kind: TradeKind.saleOrder),
          _Tab.paymentIn => GButton(
            label: 'Receive Payment'.tr,
            kind: GButtonKind.volt,
            icon: Icons.south_west_rounded,
            onPressed: () => showReceivePaymentSheet(context),
          ),
        },
      ),
    );
  }
}

class _NewButton extends StatelessWidget {
  const _NewButton({required this.kind});

  final TradeKind kind;

  @override
  Widget build(BuildContext context) => GButton.accent(
    label: 'New {0}'.trf([kind.label]),
    icon: Icons.add_rounded,
    onPressed: () => context.push('/trade/new?kind=${kind.name}'),
  );
}

/// Job card invoices and counter sales together, newest first — both are
/// what the workshop billed, they are just kept in different books.
class _Invoices extends StatelessWidget {
  const _Invoices({required this.data});

  final AdminData data;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final cards = data.billedCards;
    final counter = data.counterSalesByDate;
    final rows = <({DateTime at, Widget row})>[
      for (final j in cards)
        (
          at: j.completedAt ?? j.createdAt,
          row: DocRow(
            icon: Icons.build_circle_rounded,
            tint: p.accent,
            title: data.customerById(j.customerId)?.name ?? j.number,
            subtitle: [
              j.number,
              if (data.vehicleById(j.vehicleId) case final v?) v.regNo,
              Fmt.date(j.completedAt ?? j.createdAt),
            ].join('  ·  '),
            amount: Fmt.money(j.total),
            pill: j.settled ? 'Paid'.tr : 'Due {0}'.trf([Fmt.money(j.balance)]),
            pillTone: j.settled ? GTone.success : GTone.danger,
            onTap: () => context.push('/job/${j.id}?doc=invoice'),
          ),
        ),
      for (final s in counter)
        (
          at: s.at,
          row: DocRow(
            icon: Icons.storefront_rounded,
            tint: p.success,
            title: s.customer.isEmpty ? 'Walk-in'.tr : s.customer,
            subtitle: [
              s.number,
              'Counter sale'.tr,
              Fmt.date(s.at),
            ].join('  ·  '),
            amount: Fmt.money(s.total),
            pill: s.balance <= 0.009
                ? 'Paid'.tr
                : 'Due {0}'.trf([Fmt.money(s.balance)]),
            pillTone: s.balance <= 0.009 ? GTone.success : GTone.danger,
            onTap: () => context.push('/inventory/counter-sales'),
          ),
        ),
    ]..sort((a, b) => b.at.compareTo(a.at));

    final total =
        cards.fold<double>(0, (s, j) => s + j.total) +
        counter.fold<double>(0, (s, c) => s + c.total);
    final unpaid =
        cards.fold<double>(0, (s, j) => s + j.balance) +
        counter.fold<double>(0, (s, c) => s + c.balance);

    return TabList(
      summary: SummaryStrip(
        cells: [
          (label: 'Invoices'.tr, value: '${rows.length}', tint: null),
          (label: 'Total sales'.tr, value: Fmt.money(total), tint: null),
          (
            label: 'Unpaid'.tr,
            value: Fmt.money(unpaid),
            tint: unpaid > 0 ? p.danger : p.success,
          ),
        ],
      ),
      emptyTitle: 'No invoices yet'.tr,
      emptyMessage:
          'Completed job cards and counter sales are listed here as invoices.'
              .tr,
      children: [for (final r in rows) r.row],
    );
  }
}

/// Returns, orders, bills — any [TradeKind] list with its strip.
class TradeTab extends StatelessWidget {
  const TradeTab({super.key, required this.data, required this.kind});

  final AdminData data;
  final TradeKind kind;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final docs = data.tradeOf(kind);
    final total = docs.fold<double>(0, (s, d) => s + d.total);
    final unpaid = docs.fold<double>(0, (s, d) => s + d.balance);

    return TabList(
      summary: SummaryStrip(
        cells: [
          (label: 'Count'.tr, value: '${docs.length}', tint: null),
          (label: 'Total'.tr, value: Fmt.money(total), tint: null),
          (
            label: kind.moneyIn ? 'To receive'.tr : 'To pay'.tr,
            value: Fmt.money(unpaid),
            tint: unpaid > 0 ? p.danger : p.success,
          ),
        ],
      ),
      emptyTitle: 'No {0} yet'.trf([kind.label]),
      emptyMessage: 'Tap New {0} below to make the first one.'.trf([
        kind.label,
      ]),
      children: [
        for (final d in docs)
          Builder(
            builder: (context) {
              final status = tradeStatus(d);
              return DocRow(
                icon: Icons.description_rounded,
                tint: kind.isSale ? p.accent : p.info,
                title: d.party.isEmpty ? 'Walk-in'.tr : d.party,
                subtitle: [
                  d.number,
                  Fmt.date(d.at),
                  if (d.dueAt != null && !d.fulfilled)
                    'Due {0}'.trf([Fmt.dateShort(d.dueAt!)]),
                ].join('  ·  '),
                amount: Fmt.money(d.total),
                pill: status.label,
                pillTone: status.tone,
                onTap: () => context.push('/trade/${d.id}'),
              );
            },
          ),
      ],
    );
  }
}

class _PaymentsIn extends StatelessWidget {
  const _PaymentsIn({required this.data});

  final AdminData data;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final rows = data.paymentsIn;
    final total = rows.fold<double>(0, (s, e) => s + e.amount);

    return TabList(
      summary: SummaryStrip(
        cells: [
          (label: 'Payments'.tr, value: '${rows.length}', tint: null),
          (label: 'Received'.tr, value: Fmt.money(total), tint: p.success),
          (
            label: 'Still owed'.tr,
            value: Fmt.money(data.pendingTotal),
            tint: data.pendingTotal > 0 ? p.danger : p.success,
          ),
        ],
      ),
      emptyTitle: 'No payments received'.tr,
      emptyMessage:
          'Money a customer pays against an old balance, or any party pays in, is listed here.'
              .tr,
      emptyArt: Art.wallet,
      children: [for (final e in rows) PaymentRow(entry: e, data: data)],
    );
  }
}

/// One Payment-In or Pay-Out line: who, when, how, and through which
/// account. Swiping removes a free-standing one; one taken on a job card is
/// removed from the card instead, where its balance lives.
class PaymentRow extends ConsumerWidget {
  const PaymentRow({super.key, required this.entry, required this.data});

  final CashEntry entry;
  final AdminData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final card = data.jobById(entry.jobCardId);
    final row = DocRow(
      icon: entry.inward ? Icons.south_west_rounded : Icons.north_east_rounded,
      tint: entry.inward ? p.success : p.danger,
      title: entry.party.isEmpty ? 'Walk-in'.tr : entry.party,
      subtitle: [
        Fmt.date(entry.at),
        entry.mode.label,
        accountLabel(data, data.accountOf(entry)),
        if (card != null) card.number,
      ].join('  ·  '),
      amount: '${entry.inward ? '' : '- '}${Fmt.money(entry.amount)}',
      amountTint: entry.inward ? p.success : p.danger,
      onTap: card == null ? null : () => context.push('/job/${card.id}'),
    );
    if (entry.jobCardId != null) return row;
    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(Icons.delete_outline_rounded, color: p.danger),
      ),
      confirmDismiss: (_) => GFeedback.confirm(
        context,
        title: 'Remove this payment?'.tr,
        message: entry.inward
            ? 'It comes off the account it was received into.'.tr
            : 'It comes off the account it was paid from. A supplier\'s outstanding is not raised back automatically.'
                  .tr,
        confirmLabel: 'Remove'.tr,
        destructive: true,
      ),
      onDismissed: (_) {
        final ctrl = ref.read(adminProvider.notifier);
        ctrl.removeCash(entry.id);
        // A pay-out took this much off the supplier's account. The line does
        // not keep the supplier's id, but the sheet always files it under the
        // supplier's name, so the name finds them.
        if (!entry.inward && entry.reason == kPayOut) {
          final s = data.suppliers
              .where((s) => s.name == entry.party)
              .firstOrNull;
          if (s != null) {
            ctrl.updateSupplier(
              s.copyWith(outstanding: money(s.outstanding + entry.amount)),
            );
          }
        }
        GFeedback.info(context, 'Entry removed'.tr);
      },
      child: row,
    );
  }
}
