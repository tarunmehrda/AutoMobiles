import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/anim/entrance.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_field.dart';
import '../../core/widgets/g_state.dart';
import '../../core/widgets/pressable.dart';
import '../../data/models/entities.dart';
import '../../data/models/enums.dart';
import '../../state/admin_state.dart';
import '../../state/providers.dart';

/// The master list behind every bill: what the workshop charges for labour,
/// and what it holds on the shelf. Stock moves on its own as parts go onto
/// job cards, so this screen is mostly about rates and receiving.
class InventoryPage extends ConsumerStatefulWidget {
  const InventoryPage({super.key});

  @override
  ConsumerState<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends ConsumerState<InventoryPage> {
  LineKind _kind = LineKind.spare;
  final _search = TextEditingController();
  String _query = '';
  bool _lowOnly = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final all = ref.watch(mastersProvider(_kind));
    final low = ref.watch(lowStockProvider);
    final q = _query.trim().toLowerCase();

    final rows = all.where((m) {
      if (_lowOnly && !(m.low || m.out)) return false;
      if (q.isEmpty) return true;
      return m.name.toLowerCase().contains(q) ||
          m.partNo.toLowerCase().contains(q);
    }).toList();

    final stockValue = all
        .where((m) => m.tracksStock)
        .fold<double>(0, (s, m) => s + m.stock * m.rate);

    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Gap.page, Gap.sm, Gap.page, Gap.md),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Inventory', style: AppType.d2.c(p.ink)),
                        Text(
                          _kind.isStocked
                              ? '${Fmt.money(stockValue)} on the shelf'
                              : 'Labour rates charged per job',
                          style: AppType.bodyS.c(p.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  GIconButton(
                    icon: Icons.add_rounded,
                    size: 42,
                    onTap: () => _editor(null),
                  ),
                ],
              ),
            ),

            if (low.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.md),
                child: Pressable(
                  onTap: () => setState(() => _lowOnly = !_lowOnly),
                  scale: 0.98,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: Gap.lg, vertical: Gap.md),
                    decoration: BoxDecoration(
                      color: _lowOnly ? p.warning : p.warningSoft,
                      borderRadius: R.all(R.md),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 18,
                            color: _lowOnly ? Colors.white : p.warning),
                        const SizedBox(width: Gap.md),
                        Expanded(
                          child: Text(
                            '${low.length} item${low.length == 1 ? '' : 's'} '
                            'low or out of stock',
                            style: AppType.labelM
                                .c(_lowOnly ? Colors.white : p.warning),
                          ),
                        ),
                        Text(
                          _lowOnly ? 'Show all' : 'Show only these',
                          style: AppType.labelS
                              .c(_lowOnly ? Colors.white : p.warning),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.page),
              child: GSegmented<LineKind>(
                options: LineKind.values,
                selected: _kind,
                onSelect: (k) => setState(() => _kind = k),
                labelOf: (k) => k.label,
                iconOf: (k) => k.icon,
              ),
            ),
            const SizedBox(height: Gap.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.page),
              child: GSearchBar(
                hint: 'Search ${_kind.label.toLowerCase()} or part number',
                controller: _search,
                onChanged: (v) => setState(() => _query = v),
                onClear: _query.isEmpty
                    ? null
                    : () {
                        _search.clear();
                        setState(() => _query = '');
                      },
              ),
            ),
            const SizedBox(height: Gap.lg),

            Expanded(
              child: rows.isEmpty
                  ? GEmptyState(
                      icon: _kind.icon,
                      title: 'Nothing here',
                      message: q.isEmpty
                          ? 'Add the ${_kind.label.toLowerCase()} this '
                              'workshop charges for.'
                          : 'No match for that search.',
                      actionLabel: 'Add ${_kind.singular}',
                      onAction: () => _editor(null),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                          Gap.page, 0, Gap.page, 110),
                      itemCount: rows.length,
                      itemBuilder: (context, i) => Entrance(
                        index: i.clamp(0, 8),
                        child: _MasterRow(
                          item: rows[i],
                          onTap: () => _editor(rows[i]),
                          onRestock: rows[i].tracksStock
                              ? () => _restock(rows[i])
                              : null,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _restock(MasterItem item) async {
    final controller = TextEditingController(text: '10');
    await GFeedback.sheet<void>(
      context,
      title: 'Receive stock',
      subtitle: '${item.name} • ${item.stock.toStringAsFixed(0)} ${item.unit} '
          'on hand',
      child: Padding(
        padding: EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page,
            MediaQuery.of(context).viewInsets.bottom + Gap.h1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GField(
              label: 'Quantity received',
              controller: controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textCapitalization: TextCapitalization.none,
              suffix: Text(item.unit,
                  style: AppType.labelM.c(context.c.inkMuted)),
            ),
            const SizedBox(height: Gap.xxl),
            GButton.accent(
              label: 'Add to stock',
              onPressed: () {
                final qty = double.tryParse(controller.text.trim()) ?? 0;
                if (qty > 0) {
                  ref.read(adminProvider.notifier).restock(item.id, qty);
                }
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  Future<void> _editor(MasterItem? existing) async {
    final kind = existing?.kind ?? _kind;
    final name = TextEditingController(text: existing?.name ?? '');
    final partNo = TextEditingController(text: existing?.partNo ?? '');
    final rate =
        TextEditingController(text: (existing?.rate ?? 0).toStringAsFixed(0));
    final stock = TextEditingController(
        text: (existing?.stock ?? 0).toStringAsFixed(0));
    final unit = TextEditingController(text: existing?.unit ?? 'nos');

    await GFeedback.sheet<void>(
      context,
      title: existing == null ? 'Add ${kind.singular}' : 'Edit item',
      subtitle: kind.label,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page,
            MediaQuery.of(context).viewInsets.bottom + Gap.h1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GField(
              label: 'Name',
              controller: name,
              autofocus: existing == null,
              textCapitalization: TextCapitalization.words,
            ),
            if (kind.isStocked) ...[
              const SizedBox(height: Gap.lg),
              GField(
                label: 'Part number',
                hint: 'Optional',
                controller: partNo,
                textCapitalization: TextCapitalization.characters,
              ),
            ],
            const SizedBox(height: Gap.lg),
            Row(
              children: [
                Expanded(
                  child: GField(
                    label: 'Rate',
                    controller: rate,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    textCapitalization: TextCapitalization.none,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                  ),
                ),
                if (kind.isStocked) ...[
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: GField(
                      label: 'In stock',
                      controller: stock,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      textCapitalization: TextCapitalization.none,
                    ),
                  ),
                  const SizedBox(width: Gap.md),
                  SizedBox(
                    width: 78,
                    child: GField(
                      label: 'Unit',
                      controller: unit,
                      textCapitalization: TextCapitalization.none,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: Gap.xxl),
            Row(
              children: [
                if (existing != null) ...[
                  Expanded(
                    child: GButton(
                      label: 'Delete',
                      kind: GButtonKind.danger,
                      size: GButtonSize.md,
                      onPressed: () {
                        ref
                            .read(adminProvider.notifier)
                            .removeMaster(existing.id);
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                  const SizedBox(width: Gap.md),
                ],
                Expanded(
                  flex: 2,
                  child: GButton.accent(
                    label: existing == null ? 'Add' : 'Save',
                    size: GButtonSize.md,
                    onPressed: () {
                      if (name.text.trim().isEmpty) return;
                      final ctrl = ref.read(adminProvider.notifier);
                      if (existing == null) {
                        ctrl.addMaster(
                          kind: kind,
                          name: name.text.trim(),
                          partNo: partNo.text.trim(),
                          rate: double.tryParse(rate.text.trim()) ?? 0,
                          stock: double.tryParse(stock.text.trim()) ?? 0,
                          unit: unit.text.trim().isEmpty
                              ? 'nos'
                              : unit.text.trim(),
                        );
                      } else {
                        ctrl.updateMaster(existing.copyWith(
                          name: name.text.trim(),
                          partNo: partNo.text.trim(),
                          rate: double.tryParse(rate.text.trim()) ?? 0,
                          stock: double.tryParse(stock.text.trim()) ?? 0,
                          unit: unit.text.trim().isEmpty
                              ? 'nos'
                              : unit.text.trim(),
                        ));
                      }
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    for (final c in [name, partNo, rate, stock, unit]) {
      c.dispose();
    }
  }
}

class _MasterRow extends StatelessWidget {
  const _MasterRow({
    required this.item,
    required this.onTap,
    this.onRestock,
  });

  final MasterItem item;
  final VoidCallback onTap;
  final VoidCallback? onRestock;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Pressable(
      onTap: onTap,
      scale: 0.985,
      child: Container(
        margin: const EdgeInsets.only(bottom: Gap.sm),
        padding: const EdgeInsets.symmetric(
            horizontal: Gap.lg, vertical: Gap.md),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: R.all(R.md),
          border: Border.all(color: item.out ? p.danger : p.line),
          boxShadow: Shadows.soft(p),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.labelL.c(p.ink)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (item.partNo.isNotEmpty) ...[
                        Text(item.partNo,
                            style: AppType.labelS.s(10.5).c(p.inkFaint)),
                        const SizedBox(width: Gap.sm),
                      ],
                      if (item.tracksStock)
                        GPill(
                          label: item.out
                              ? 'Out of stock'
                              : '${item.stock.toStringAsFixed(0)} ${item.unit}',
                          compact: true,
                          tone: item.out
                              ? GTone.danger
                              : item.low
                                  ? GTone.warning
                                  : GTone.success,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: Gap.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(Fmt.money(item.rate),
                    style: AppType.money.s(15).c(p.ink)),
                if (onRestock != null)
                  Pressable(
                    onTap: onRestock,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('Receive',
                          style: AppType.labelS.c(p.accentInk)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
