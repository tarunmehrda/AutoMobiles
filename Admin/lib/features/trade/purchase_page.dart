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
import '../../data/repo/admin_data.dart';
import '../../state/admin_state.dart';
import 'payment_sheets.dart';
import 'sales_page.dart';
import 'trade_widgets.dart';

/// The four Purchase tabs, by the `tab` value the dashboard deep-links with.
enum _Tab { bill, payOut, ret, order }

_Tab _parse(String? v) => switch (v) {
  'payOut' => _Tab.payOut,
  'return' => _Tab.ret,
  'order' => _Tab.order,
  _ => _Tab.bill,
};

/// Everything that takes money out to suppliers: bills, payments to them,
/// returns to them, and the orders placed on them.
class PurchasePage extends ConsumerStatefulWidget {
  const PurchasePage({super.key, this.tab});

  final String? tab;

  @override
  ConsumerState<PurchasePage> createState() => _PurchasePageState();
}

class _PurchasePageState extends ConsumerState<PurchasePage> {
  late _Tab _tab = _parse(widget.tab);

  @override
  void didUpdateWidget(PurchasePage old) {
    super.didUpdateWidget(old);
    if (old.tab != widget.tab) _tab = _parse(widget.tab);
  }

  String _label(_Tab t) => switch (t) {
    _Tab.bill => 'Purchase Bill'.tr,
    _Tab.payOut => 'Pay-Out'.tr,
    _Tab.ret => 'Purchase Return'.tr,
    _Tab.order => 'Purchase Order'.tr,
  };

  IconData _icon(_Tab t) => switch (t) {
    _Tab.bill => Icons.receipt_rounded,
    _Tab.payOut => Icons.north_east_rounded,
    _Tab.ret => Icons.assignment_return_rounded,
    _Tab.order => Icons.local_shipping_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final data = ref.watch(adminProvider);
    final owed = data.suppliers.fold<double>(0, (s, e) => s + e.outstanding);

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Purchase'.tr,
        subtitle: owed > 0
            ? 'Owed to suppliers {0}'.trf([Fmt.money(owed)])
            : 'Bills, payments, returns and orders'.tr,
        actions: [
          GIconButton(
            icon: Icons.groups_rounded,
            size: 40,
            tooltip: 'Suppliers'.tr,
            onTap: () => context.push('/inventory/suppliers'),
          ),
        ],
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
        _Tab.bill => TradeTab(data: data, kind: TradeKind.purchaseBill),
        _Tab.payOut => _PayOuts(data: data, owed: owed),
        _Tab.ret => TradeTab(data: data, kind: TradeKind.purchaseReturn),
        _Tab.order => _Orders(data: data),
      },
      bottomNavigationBar: GBottomBar(
        child: switch (_tab) {
          _Tab.bill => _NewButton(kind: TradeKind.purchaseBill),
          _Tab.ret => _NewButton(kind: TradeKind.purchaseReturn),
          _Tab.payOut => GButton(
            label: 'Pay Supplier'.tr,
            kind: GButtonKind.danger,
            icon: Icons.north_east_rounded,
            onPressed: () => showPayOutSheet(context),
          ),
          _Tab.order => GButton.accent(
            label: 'Raise Purchase Order'.tr,
            icon: Icons.add_rounded,
            onPressed: () => context.push('/inventory/purchase-order/new'),
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

class _PayOuts extends StatelessWidget {
  const _PayOuts({required this.data, required this.owed});

  final AdminData data;
  final double owed;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final rows = data.paymentsOut;
    final total = rows.fold<double>(0, (s, e) => s + e.amount);
    return TabList(
      summary: SummaryStrip(
        cells: [
          (label: 'Payments'.tr, value: '${rows.length}', tint: null),
          (label: 'Paid out'.tr, value: Fmt.money(total), tint: p.danger),
          (
            label: 'Still owed'.tr,
            value: Fmt.money(owed),
            tint: owed > 0 ? p.danger : p.success,
          ),
        ],
      ),
      emptyTitle: 'No pay-outs yet'.tr,
      emptyMessage:
          'Money paid to a supplier against what they are owed is listed here.'
              .tr,
      emptyArt: Art.wallet,
      children: [for (final e in rows) PaymentRow(entry: e, data: data)],
    );
  }
}

/// The purchase orders already kept under Inventory, shown here as the
/// fourth tab. Receiving still happens on that page, where it always has.
class _Orders extends StatelessWidget {
  const _Orders({required this.data});

  final AdminData data;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final orders = data.ordersByDate;
    final pending = orders.where((o) => !o.received).toList();
    return TabList(
      summary: SummaryStrip(
        cells: [
          (label: 'Orders'.tr, value: '${orders.length}', tint: null),
          (
            label: 'Total'.tr,
            value: Fmt.money(orders.fold<double>(0, (s, o) => s + o.total)),
            tint: null,
          ),
          (
            label: 'Awaiting'.tr,
            value: '${pending.length}',
            tint: pending.isEmpty ? p.success : p.warning,
          ),
        ],
      ),
      emptyTitle: 'No purchase orders'.tr,
      emptyMessage:
          'Raise one against a supplier and receiving it restocks the shelf.'
              .tr,
      emptyArt: Art.delivery,
      children: [
        for (final o in orders)
          DocRow(
            icon: Icons.local_shipping_rounded,
            tint: p.info,
            title: data.supplierById(o.supplierId)?.name ?? 'Supplier'.tr,
            subtitle: [o.number, Fmt.date(o.at)].join('  ·  '),
            amount: Fmt.money(o.total),
            pill: o.received ? 'Received'.tr : 'Awaiting delivery'.tr,
            pillTone: o.received ? GTone.success : GTone.warning,
            onTap: () => context.push('/inventory/purchase-orders'),
          ),
      ],
    );
  }
}
