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
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_field.dart';
import '../../core/widgets/g_art.dart';
import '../../core/widgets/g_state.dart';
import '../../core/widgets/pressable.dart';
import '../../data/models/entities.dart';
import '../../data/models/enums.dart';
import '../../state/admin_state.dart';
import '../../state/providers.dart';
import '../jobcard/billing/billing.dart';
import 'suppliers_page.dart';

/// Orders placed on suppliers. An order on its own moves nothing — marking it
/// received is what puts the parts on the shelf.
class PurchaseOrdersPage extends ConsumerWidget {
  const PurchaseOrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final orders = ref.watch(purchaseOrdersProvider);
    final data = ref.watch(adminDataProvider);

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Purchase Orders'.tr,
        subtitle: '{0} awaiting delivery'.trf([
          orders.where((o) => !o.received).length,
        ]),
      ),
      body: orders.isEmpty
          ? GEmptyState(
              icon: Icons.receipt_long_rounded,
              title: 'No purchase orders'.tr,
              art: Art.delivery,
              message:
                  'Raise one against a supplier and receiving it restocks the shelf.'
                      .tr,
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.h2),
              itemCount: orders.length,
              itemBuilder: (context, i) {
                final o = orders[i];
                final supplier = data.supplierById(o.supplierId);
                return Entrance(
                  index: i.clamp(0, 8),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: Gap.sm),
                    padding: const EdgeInsets.all(Gap.lg),
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: R.all(R.md),
                      border: Border.all(color: p.line),
                      boxShadow: Shadows.soft(p),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    supplier?.name ?? 'Supplier'.tr,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppType.labelL.c(p.ink),
                                  ),
                                  Text(
                                    '{0}  ·  {1}  ·  {2} pcs'.trf([
                                      o.number,
                                      Fmt.date(o.at),
                                      Fmt.number(o.qty),
                                    ]),
                                    style: AppType.bodyS.c(p.inkMuted),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  Fmt.money(o.total),
                                  style: AppType.money.c(p.ink),
                                ),
                                const SizedBox(height: 4),
                                GPill(
                                  label: o.received
                                      ? 'Received'.tr
                                      : 'Awaiting delivery'.tr,
                                  tone: o.received
                                      ? GTone.success
                                      : GTone.warning,
                                  compact: true,
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (!o.received) ...[
                          const SizedBox(height: Gap.md),
                          GButton(
                            label: 'Mark received'.tr,
                            kind: GButtonKind.outline,
                            size: GButtonSize.sm,
                            icon: Icons.inventory_rounded,
                            onPressed: () {
                              ref
                                  .read(adminProvider.notifier)
                                  .receivePurchaseOrder(o.id);
                              GFeedback.success(
                                context,
                                'Stock updated from {0}'.trf([o.number]),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: GBottomBar(
        child: GButton.accent(
          label: 'Raise Purchase Order'.tr,
          icon: Icons.add_rounded,
          onPressed: () => context.push('/inventory/purchase-order/new'),
        ),
      ),
    );
  }
}

/// Build one order: pick the supplier, then the parts and how many.
class CreatePurchaseOrderPage extends ConsumerStatefulWidget {
  const CreatePurchaseOrderPage({super.key});

  @override
  ConsumerState<CreatePurchaseOrderPage> createState() =>
      _CreatePurchaseOrderPageState();
}

class _CreatePurchaseOrderPageState
    extends ConsumerState<CreatePurchaseOrderPage> {
  String? _supplierId;
  final _lines = <LineItem>[];
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  double get _total => _lines.fold<double>(0, (s, e) => s + e.amount);
  bool get _valid => _supplierId != null && _lines.isNotEmpty;

  Future<void> _add(LineKind kind) async {
    final picked = await openBillPicker(context, kind);
    if (picked == null || picked.isEmpty) return;
    setState(() => _lines.addAll(picked));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final suppliers = ref.watch(suppliersProvider);
    final selected = suppliers.where((s) => s.id == _supplierId).firstOrNull;

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Purchase Order'.tr,
        subtitle: 'What you ordered, and from whom'.tr,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.h2),
        children: [
          if (suppliers.isEmpty)
            GEmptyState(
              compact: true,
              icon: Icons.local_shipping_rounded,
              title: 'No suppliers yet'.tr,
              art: Art.delivery,
              message: 'An order has to be placed on somebody.'.tr,
              actionLabel: 'Add supplier'.tr,
              onAction: () => showSupplierSheet(context),
            )
          else
            GPickerField(
              label: 'Supplier'.tr,
              value: selected?.name,
              placeholder: 'Choose a supplier'.tr,
              leadingIcon: Icons.local_shipping_rounded,
              onTap: () async {
                final picked = await showModalBottomSheet<String>(
                  context: context,
                  backgroundColor: Colors.transparent,
                  builder: (_) => Container(
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(R.xxl),
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: Gap.lg),
                        children: [
                          for (final s in suppliers)
                            ListTile(
                              title: Text(
                                s.name,
                                style: AppType.labelL.c(p.ink),
                              ),
                              subtitle: s.phone.isEmpty
                                  ? null
                                  : Text(
                                      s.phone,
                                      style: AppType.bodyS.c(p.inkMuted),
                                    ),
                              trailing: s.id == _supplierId
                                  ? Icon(Icons.check_rounded, color: p.accent)
                                  : null,
                              onTap: () => Navigator.of(context).pop(s.id),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
                if (picked != null) setState(() => _supplierId = picked);
              },
            ),
          SizedBox(height: Gap.xl),
          Row(
            children: [
              Expanded(
                child: GButton(
                  label: 'Add Spare'.tr,
                  kind: GButtonKind.outline,
                  icon: Icons.settings_rounded,
                  onPressed: () => _add(LineKind.spare),
                ),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: GButton(
                  label: 'Add Lube'.tr,
                  kind: GButtonKind.outline,
                  icon: Icons.water_drop_rounded,
                  onPressed: () => _add(LineKind.lube),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.lg),
          if (_lines.isEmpty)
            GEmptyState(
              compact: true,
              icon: Icons.inventory_2_outlined,
              title: 'Nothing ordered yet'.tr,
              art: Art.delivery,
              message: 'Pick what you are buying from your master list.'.tr,
            )
          else
            for (final li in _lines)
              Container(
                margin: const EdgeInsets.only(bottom: Gap.sm),
                padding: const EdgeInsets.all(Gap.md),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: R.all(R.md),
                  border: Border.all(color: p.line),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            li.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.labelL.c(p.ink),
                          ),
                          Text(
                            li.breakdown,
                            style: AppType.bodyS.c(p.inkMuted),
                          ),
                        ],
                      ),
                    ),
                    Text(Fmt.money(li.amount), style: AppType.money.c(p.ink)),
                    const SizedBox(width: Gap.sm),
                    Pressable(
                      onTap: () => setState(() => _lines.remove(li)),
                      scale: 0.88,
                      child: Icon(
                        Icons.close_rounded,
                        size: 19,
                        color: p.danger,
                      ),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: Gap.lg),
          GField(
            label: 'Note'.tr,
            hint: 'Optional'.tr,
            controller: _note,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
      bottomNavigationBar: GBottomBar(
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Order value'.tr, style: AppType.labelS.c(p.inkMuted)),
                Text(Fmt.money(_total), style: AppType.money.c(p.ink)),
              ],
            ),
            const SizedBox(width: Gap.lg),
            Expanded(
              child: GButton.accent(
                label: 'Raise order'.tr,
                onPressed: !_valid
                    ? null
                    : () {
                        final order = ref
                            .read(adminProvider.notifier)
                            .addPurchaseOrder(
                              supplierId: _supplierId!,
                              items: _lines,
                              note: _note.text,
                            );
                        GFeedback.success(
                          context,
                          '{0} raised'.trf([order.number]),
                        );
                        context.pop();
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
