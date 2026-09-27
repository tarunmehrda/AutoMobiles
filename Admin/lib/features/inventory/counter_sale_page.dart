import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Spares and lubes sold across the counter, with no job card behind them.
/// Stock comes off the shelf the moment the sale is saved.
class CounterSalePage extends ConsumerStatefulWidget {
  const CounterSalePage({super.key});

  @override
  ConsumerState<CounterSalePage> createState() => _CounterSalePageState();
}

class _CounterSalePageState extends ConsumerState<CounterSalePage> {
  final _customer = TextEditingController();
  final _phone = TextEditingController();
  final _paid = TextEditingController();
  final _lines = <LineItem>[];

  @override
  void dispose() {
    for (final c in [_customer, _phone, _paid]) {
      c.dispose();
    }
    super.dispose();
  }

  double get _total => _lines.fold<double>(0, (s, e) => s + e.amount);

  bool get _valid => _lines.isNotEmpty && _customer.text.trim().isNotEmpty;

  Future<void> _add(LineKind kind) async {
    final picked = await openBillPicker(context, kind);
    if (picked == null || picked.isEmpty) return;
    setState(() => _lines.addAll(picked));
  }

  void _save() {
    if (!_valid) return;
    final paid = _paid.text.trim().isEmpty
        ? _total
        : (double.tryParse(_paid.text.trim()) ?? 0);
    final sale = ref
        .read(adminProvider.notifier)
        .addCounterSale(
          customer: _customer.text,
          items: _lines,
          phone: _phone.text,
          paid: paid,
        );
    GFeedback.success(context, '{0} saved'.trf([sale.number]));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Counter Sale'.tr,
        subtitle: 'Sell off the shelf, no job card'.tr,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.h2),
        children: [
          GField(
            label: 'Customer name *'.tr,
            hint: 'Rahul Sharma'.tr,
            controller: _customer,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Gap.lg),
          GField(
            label: 'Mobile number'.tr,
            hint: '9876543210',
            controller: _phone,
            keyboardType: TextInputType.phone,
            textCapitalization: TextCapitalization.none,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
          ),
          const SizedBox(height: Gap.xl),
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
              icon: Icons.shopping_bag_outlined,
              title: 'Nothing on the sale yet'.tr,
              art: Art.stock,
              message: 'Add a spare or a lube from your inventory.'.tr,
            )
          else
            for (final li in _lines)
              Entrance(
                child: Container(
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
              ),
          const SizedBox(height: Gap.lg),
          GField(
            label: 'Paid now'.tr,
            hint: _total > 0 ? Fmt.money(_total) : 'All of it'.tr,
            controller: _paid,
            keyboardType: TextInputType.number,
            textCapitalization: TextCapitalization.none,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
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
                Text('Total'.tr, style: AppType.labelS.c(p.inkMuted)),
                Text(Fmt.money(_total), style: AppType.money.c(p.ink)),
              ],
            ),
            const SizedBox(width: Gap.lg),
            Expanded(
              child: GButton.accent(
                label: 'Save sale'.tr,
                onPressed: _valid ? _save : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Every counter sale raised, newest first.
class CounterSaleListPage extends ConsumerWidget {
  const CounterSaleListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final sales = ref.watch(counterSalesProvider);

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Counter Sale List'.tr,
        subtitle: Tr.plural(sales.length, '{0} sale', '{0} sales'),
      ),
      body: sales.isEmpty
          ? GEmptyState(
              icon: Icons.storefront_rounded,
              title: 'No counter sales'.tr,
              art: Art.invoice,
              message: 'Sell a spare over the counter and it lands here.'.tr,
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.h2),
              itemCount: sales.length,
              itemBuilder: (context, i) {
                final s = sales[i];
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
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.customer.isEmpty ? 'Walk-in'.tr : s.customer,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppType.labelL.c(p.ink),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${s.number}  ·  ${Fmt.dateTime(s.at)}',
                                style: AppType.bodyS.c(p.inkMuted),
                              ),
                              const SizedBox(height: Gap.sm),
                              Wrap(
                                spacing: Gap.xs,
                                runSpacing: Gap.xs,
                                children: [
                                  for (final li in s.items.take(3))
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: Gap.sm,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: p.surfaceSunken,
                                        borderRadius: R.all(R.pill),
                                      ),
                                      child: Text(
                                        li.name,
                                        style: AppType.labelS
                                            .s(10)
                                            .c(p.inkMuted),
                                      ),
                                    ),
                                  if (s.items.length > 3)
                                    Text(
                                      '+{0} more'.trf([s.items.length - 3]),
                                      style: AppType.labelS.c(p.inkFaint),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              Fmt.money(s.total),
                              style: AppType.money.c(p.ink),
                            ),
                            const SizedBox(height: 4),
                            GPill(
                              label: s.balance <= 0
                                  ? 'Paid'.tr
                                  : 'Due {0}'.trf([Fmt.money(s.balance)]),
                              tone: s.balance <= 0
                                  ? GTone.success
                                  : GTone.danger,
                              compact: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: GBottomBar(
        child: GButton.accent(
          label: 'Create Counter Sale'.tr,
          icon: Icons.add_rounded,
          onPressed: () => context.push('/inventory/counter-sale/new'),
        ),
      ),
    );
  }
}
