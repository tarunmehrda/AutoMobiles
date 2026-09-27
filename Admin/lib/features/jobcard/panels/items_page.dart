import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/anim/entrance.dart';
import '../../../core/i18n/strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/g_appbar.dart';
import '../../../core/widgets/g_badge.dart';
import '../../../core/widgets/g_button.dart';
import '../../../core/widgets/g_feedback.dart';
import '../../../core/widgets/g_field.dart';
import '../../../core/widgets/g_art.dart';
import '../../../core/widgets/g_state.dart';
import '../../../core/widgets/g_surface.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/models/entities.dart';
import '../../../data/models/enums.dart';
import '../../../state/admin_state.dart';
import '../../../state/providers.dart';
import '../widgets/ledger_tabs.dart';

/// The bill, built one line at a time. Three tabs because a workshop thinks
/// in three buckets — what was done, what was fitted, what was poured in —
/// and the totals for each need to be readable without arithmetic.
class ItemsPage extends ConsumerStatefulWidget {
  const ItemsPage({super.key, required this.id, this.initial = LineKind.job});

  final String id;
  final LineKind initial;

  @override
  ConsumerState<ItemsPage> createState() => _ItemsPageState();
}

class _ItemsPageState extends ConsumerState<ItemsPage> {
  late LineKind _kind = widget.initial;
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _search.clear();
    setState(() => _query = '');
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final card = ref.watch(jobCardProvider(widget.id));
    if (card == null) {
      return Scaffold(
        backgroundColor: p.canvas,
        appBar: GHeader(
          title: 'Items'.tr,
          subtitle: 'Parts, oil and labour on this card'.tr,
        ),
        body: GEmptyState(
          icon: Icons.remove_shopping_cart_rounded,
          title: 'Job card not found'.tr,
          art: Art.searching,
          message: 'Nothing to bill against.'.tr,
        ),
      );
    }

    final rows = card.itemsOf(_kind);
    final masters = ref.watch(mastersProvider(_kind));
    final suggestions = _suggest(masters, rows);
    final locked = card.isClosed;

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Items'.tr,
        subtitle: Tr.plural(
          card.items.length,
          '{0} • {1} line',
          '{0} • {1} lines',
          [card.number, card.items.length],
        ),
      ),
      body: Column(
        children: [
          // --- the three buckets, each showing its own running total ----
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Gap.page,
              Gap.sm,
              Gap.page,
              Gap.md,
            ),
            child: Row(
              children: [
                for (var i = 0; i < LineKind.values.length; i++) ...[
                  Expanded(
                    child: _KindTab(
                      kind: LineKind.values[i],
                      total: card.totalOf(LineKind.values[i]),
                      count: card.itemsOf(LineKind.values[i]).length,
                      selected: _kind == LineKind.values[i],
                      onTap: () {
                        setState(() => _kind = LineKind.values[i]);
                        _clearSearch();
                      },
                    ),
                  ),
                  if (i != LineKind.values.length - 1)
                    const SizedBox(width: Gap.sm),
                ],
              ],
            ),
          ),

          if (locked)
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.md),
              child: const _LockedNote(),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.md),
              child: GSearchBar(
                hint: 'Search {0} or type a new one'.trf([
                  _kind.label.toLowerCase(),
                ]),
                controller: _search,
                onChanged: (v) => setState(() => _query = v),
                onClear: _query.isEmpty ? null : _clearSearch,
                trailing: Pressable(
                  onTap: () => _openEditor(card, null),
                  scale: 0.9,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
                    child: Icon(
                      Icons.add_circle_rounded,
                      size: 22,
                      color: p.accent,
                    ),
                  ),
                ),
              ),
            ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.h2),
              children: [
                // --- master suggestions while typing --------------------
                if (!locked && _query.trim().isNotEmpty) ...[
                  _SuggestionList(
                    suggestions: suggestions,
                    query: _query.trim(),
                    kind: _kind,
                    onPick: (m) {
                      ref
                          .read(adminProvider.notifier)
                          .addItem(
                            card.id,
                            kind: _kind,
                            name: m.name,
                            partNo: m.partNo,
                            rate: m.rate,
                            master: m,
                          );
                      _clearSearch();
                    },
                    onCreate: () =>
                        _openEditor(card, null, prefillName: _query.trim()),
                  ),
                  const SizedBox(height: Gap.lg),
                ],

                // --- the lines already on the card ----------------------
                if (rows.isEmpty)
                  GEmptyState(
                    compact: true,
                    icon: _kind.icon,
                    title: 'No {0} yet'.trf([_kind.label.toLowerCase()]),
                    message: locked
                        ? 'This card is closed.'.tr
                        : 'Search above to pull one from the master list, or add a one-off line.'
                              .tr,
                    actionLabel: locked
                        ? null
                        : 'Add {0}'.trf([_kind.singular]),
                    onAction: () => _openEditor(card, null),
                  )
                else
                  for (var i = 0; i < rows.length; i++)
                    Entrance(
                      index: i.clamp(0, 6),
                      child: _LineRow(
                        line: rows[i],
                        index: i + 1,
                        locked: locked,
                        onEdit: () => _openEditor(card, rows[i]),
                        onRemove: () => ref
                            .read(adminProvider.notifier)
                            .removeItem(card.id, rows[i].id),
                      ),
                    ),

                const SizedBox(height: Gap.lg),
                _BillSummary(card: card, locked: locked),
              ],
            ),
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
                Text('TOTAL', style: AppType.over.s(9.5).c(p.inkFaint)),
                Text(
                  Fmt.money2(card.total),
                  style: AppType.moneyL.s(22).c(p.ink),
                ),
              ],
            ),
            const Spacer(),
            GButton.accent(
              label: 'Done'.tr,
              expand: false,
              onPressed: () => context.pop(),
            ),
          ],
        ),
      ),
    );
  }

  /// Master rows matching the query, minus anything already on the card.
  List<MasterItem> _suggest(List<MasterItem> masters, List<LineItem> rows) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final used = rows.map((e) => e.masterId).whereType<String>().toSet();
    return masters
        .where(
          (m) =>
              !used.contains(m.id) &&
              (m.name.toLowerCase().contains(q) ||
                  m.partNo.toLowerCase().contains(q)),
        )
        .take(8)
        .toList();
  }

  Future<void> _openEditor(
    JobCard card,
    LineItem? existing, {
    String prefillName = '',
  }) async {
    final result = await showLineEditor(
      context,
      kind: existing?.kind ?? _kind,
      // Inactive staff cannot be given new work (see the Staff screen). The
      // one already on this line stays offered, so editing the line does
      // not quietly hide who did it.
      staff: ref
          .read(staffProvider)
          .where((s) => s.active || s.id == existing?.mechanicId)
          .toList(),
      existing: existing,
      prefillName: prefillName,
    );
    if (result == null) return;
    final ctrl = ref.read(adminProvider.notifier);
    if (existing == null) {
      ctrl.addItem(
        card.id,
        kind: result.kind,
        name: result.name,
        partNo: result.partNo,
        qty: result.qty,
        rate: result.rate,
        mechanicId: result.mechanicId,
      );
    } else {
      ctrl.updateItem(
        card.id,
        existing.copyWith(
          name: result.name,
          partNo: result.partNo,
          qty: result.qty,
          rate: result.rate,
          mechanicId: result.mechanicId,
          clearMechanic: result.mechanicId == null,
          remark: result.remark,
          state: result.state,
        ),
      );
    }
    if (mounted) _clearSearch();
  }
}

// ---------------------------------------------------------------------------

class _KindTab extends StatelessWidget {
  const _KindTab({
    required this.kind,
    required this.total,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final LineKind kind;
  final double total;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Pressable(
      onTap: onTap,
      scale: 0.96,
      child: AnimatedContainer(
        duration: Motion.fast,
        curve: Motion.enter,
        padding: const EdgeInsets.symmetric(vertical: Gap.md),
        decoration: BoxDecoration(
          color: selected ? p.ink : p.surface,
          borderRadius: R.all(R.md),
          border: Border.all(color: selected ? p.ink : p.line),
          boxShadow: selected ? Shadows.soft(p) : null,
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  kind.icon,
                  size: 14,
                  color: selected
                      ? (p.isDark ? p.canvas : Colors.white)
                      : p.inkMuted,
                ),
                const SizedBox(width: 5),
                Text(
                  kind.label,
                  style: AppType.labelM.c(
                    selected ? (p.isDark ? p.canvas : Colors.white) : p.inkSoft,
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 4),
                  Text(
                    '$count',
                    style: AppType.labelS
                        .s(10)
                        .c(
                          selected
                              ? (p.isDark ? p.canvas : Colors.white).withValues(
                                  alpha: 0.6,
                                )
                              : p.inkFaint,
                        ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Text(
              Fmt.money(total),
              style: AppType.moneyS.c(
                selected ? (p.isDark ? p.canvas : Colors.white) : p.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LineRow extends ConsumerWidget {
  const _LineRow({
    required this.line,
    required this.index,
    required this.locked,
    required this.onEdit,
    required this.onRemove,
  });

  final LineItem line;
  final int index;
  final bool locked;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final mechanic = ref.watch(adminProvider).staffById(line.mechanicId);

    return Container(
      margin: const EdgeInsets.only(bottom: Gap.sm),
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, Gap.md),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: R.all(R.md),
        border: Border.all(color: p.line),
        boxShadow: Shadows.soft(p),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 18,
                child: Text(
                  '$index',
                  style: AppType.moneyS.s(11).c(p.inkFaint),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.labelL.c(p.ink),
                    ),
                    const SizedBox(height: 1),
                    // Both halves give: on a narrow phone the breakdown and
                    // the part number together are wider than the line they
                    // sit on, and neither is worth pushing the amount off
                    // the card for.
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Qty × rate: {0}'.trf([line.breakdown]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.bodyS.s(11.5).c(p.inkMuted),
                          ),
                        ),
                        if (line.partNo.isNotEmpty) ...[
                          const SizedBox(width: Gap.sm),
                          Flexible(
                            child: Text(
                              line.partNo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.labelS.s(10).c(p.inkFaint),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Gap.sm),
              Text(
                Fmt.money2(line.amount),
                style: AppType.money.s(15).c(p.ink),
              ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          Row(
            children: [
              const SizedBox(width: 18),
              // The status and the mechanic share what the actions leave, so
              // a long mechanic name cannot push the row off the card.
              Expanded(
                child: Row(
                  children: [
                    GPill(
                      label: line.state.label,
                      compact: true,
                      tone: switch (line.state) {
                        WorkState.done => GTone.success,
                        WorkState.running => GTone.info,
                        WorkState.skipped => GTone.neutral,
                        WorkState.pending => GTone.warning,
                      },
                    ),
                    if (mechanic != null) ...[
                      const SizedBox(width: Gap.sm),
                      Flexible(
                        child: GTag(
                          label: mechanic.name.split(' ').first,
                          icon: Icons.engineering_rounded,
                          outlined: true,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: Gap.sm),
              if (!locked) ...[
                GButton(
                  label: 'Edit'.tr,
                  kind: GButtonKind.ghost,
                  size: GButtonSize.sm,
                  expand: false,
                  onPressed: onEdit,
                ),
                const SizedBox(width: Gap.sm),
                Pressable(
                  onTap: onRemove,
                  scale: 0.88,
                  child: Container(
                    height: 32,
                    width: 32,
                    decoration: BoxDecoration(
                      color: p.dangerSoft,
                      borderRadius: R.all(R.sm),
                    ),
                    child: Icon(Icons.close_rounded, size: 16, color: p.danger),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SuggestionList extends StatelessWidget {
  const _SuggestionList({
    required this.suggestions,
    required this.query,
    required this.kind,
    required this.onPick,
    required this.onCreate,
  });

  final List<MasterItem> suggestions;
  final String query;
  final LineKind kind;
  final ValueChanged<MasterItem> onPick;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return GCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final m in suggestions)
            GTile(
              dense: true,
              title: m.name,
              subtitle: [
                if (m.partNo.isNotEmpty) m.partNo,
                Fmt.money2(m.rate),
                if (m.tracksStock)
                  m.out
                      ? 'Out of stock'.tr
                      : '{0} {1} in stock'.trf([
                          m.stock.toStringAsFixed(0),
                          m.unit,
                        ]),
              ].join('  •  '),
              icon: kind.icon,
              iconColor: m.out ? p.danger : p.inkSoft,
              trailing: Icon(Icons.add_rounded, color: p.accent, size: 20),
              onTap: () => onPick(m),
            ),
          GTile(
            dense: true,
            title: 'Add "{0}" as a one-off'.trf([query]),
            subtitle: 'Not saved to the master list'.tr,
            icon: Icons.edit_rounded,
            iconColor: p.accentInk,
            iconBg: p.accentSoft,
            onTap: onCreate,
          ),
        ],
      ),
    );
  }
}

class _BillSummary extends ConsumerWidget {
  const _BillSummary({required this.card, required this.locked});

  final JobCard card;
  final bool locked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    return GCard(
      child: Column(
        children: [
          for (final k in LineKind.values)
            GKeyValue(label: k.label, value: Fmt.money2(card.totalOf(k))),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Gap.sm),
            child: GDashedLine(color: p.line),
          ),
          GKeyValue(label: 'Sub total'.tr, value: Fmt.money2(card.subTotal)),
          if (card.discount > 0)
            GKeyValue(
              label: 'Discount'.tr,
              value: '- ${Fmt.money2(card.discount)}',
              valueColor: p.success,
            ),
          if (card.taxRate > 0)
            GKeyValue(
              label: 'GST {0}%'.trf([(card.taxRate * 100).toStringAsFixed(0)]),
              value: Fmt.money2(card.taxAmount),
            ),
          GKeyValue(
            label: 'Payable'.tr,
            value: Fmt.money2(card.total),
            emphasize: true,
          ),
          // Taking lines off a bill that already has an advance against it
          // can leave the workshop holding more than it is owed; say so here,
          // where the lines come off, rather than only on the ledger.
          if (card.excess > 0) ...[
            const SizedBox(height: Gap.sm),
            ExcessNote(amount: card.excess),
          ],
          if (!locked) ...[
            const SizedBox(height: Gap.md),
            Row(
              children: [
                Expanded(
                  child: GButton(
                    label: card.discount > 0
                        ? 'Edit discount'.tr
                        : 'Discount'.tr,
                    kind: GButtonKind.ghost,
                    size: GButtonSize.sm,
                    icon: Icons.percent_rounded,
                    onPressed: () => _discount(context, ref),
                  ),
                ),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: GButton(
                    label: card.taxRate > 0
                        ? 'GST {0}%'.trf([
                            (card.taxRate * 100).toStringAsFixed(0),
                          ])
                        : 'Add GST'.tr,
                    kind: GButtonKind.ghost,
                    size: GButtonSize.sm,
                    icon: Icons.receipt_rounded,
                    onPressed: () => _tax(context, ref),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _discount(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(
      text: card.discount.toStringAsFixed(0),
    );
    await GFeedback.sheet<void>(
      context,
      title: 'Discount'.tr,
      // Owned by the sheet, not by this function: its future completes
      // when the sheet starts closing, and the fields go on reading these
      // all the way through the exit transition.
      disposing: [controller],
      subtitle: 'Comes off before GST. Max {0}.'.trf([
        Fmt.money2(card.subTotal),
      ]),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Gap.page,
          Gap.lg,
          Gap.page,
          MediaQuery.of(context).viewInsets.bottom + Gap.h1,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GField(
              label: 'Amount off'.tr,
              hint: '100',
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textCapitalization: TextCapitalization.none,
            ),
            const SizedBox(height: Gap.xxl),
            GButton.accent(
              label: 'Apply'.tr,
              onPressed: () {
                ref
                    .read(adminProvider.notifier)
                    .setDiscount(
                      card.id,
                      double.tryParse(controller.text.trim()) ?? 0,
                    );
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _tax(BuildContext context, WidgetRef ref) async {
    await GFeedback.sheet<void>(
      context,
      title: 'GST',
      subtitle: 'Applied to the amount after discount.'.tr,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.h1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final rate in [0.0, 0.05, 0.12, 0.18, 0.28])
              GOptionRow(
                label: rate == 0
                    ? 'No GST'.tr
                    : '${(rate * 100).toStringAsFixed(0)}%',
                subtitle: rate == 0
                    ? 'Bill the amount as it stands'.tr
                    : 'Adds {0}'.trf([Fmt.money2(card.taxable * rate)]),
                selected: (card.taxRate - rate).abs() < 0.001,
                onTap: () {
                  ref.read(adminProvider.notifier).setTaxRate(card.id, rate);
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _LockedNote extends StatelessWidget {
  const _LockedNote();

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
      decoration: BoxDecoration(
        color: p.surfaceSunken,
        borderRadius: R.all(R.md),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_rounded, size: 16, color: p.inkMuted),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Text(
              'This card is closed — the bill is frozen. Reopen it from the job card menu to make changes.'
                  .tr,
              style: AppType.bodyS.c(p.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// What the editor hands back.
class LineDraft {
  const LineDraft({
    required this.kind,
    required this.name,
    required this.partNo,
    required this.qty,
    required this.rate,
    required this.mechanicId,
    required this.state,
    required this.remark,
  });

  final LineKind kind;
  final String name;
  final String partNo;
  final double qty;
  final double rate;
  final String? mechanicId;
  final WorkState state;
  final String remark;
}

/// Add or edit one line. Also where the mechanic and the floor remark get
/// set, because that is the same row on the mechanic copy.
Future<LineDraft?> showLineEditor(
  BuildContext context, {
  required LineKind kind,
  required List<Staff> staff,
  LineItem? existing,
  String prefillName = '',
}) async {
  final name = TextEditingController(text: existing?.name ?? prefillName);
  final partNo = TextEditingController(text: existing?.partNo ?? '');
  final qty = TextEditingController(
    text: (existing?.qty ?? 1).toStringAsFixed(0),
  );
  final rate = TextEditingController(
    text: (existing?.rate ?? 0).toStringAsFixed(0),
  );
  final remark = TextEditingController(text: existing?.remark ?? '');
  var mechanicId = existing?.mechanicId;
  var work = existing?.state ?? WorkState.pending;
  LineDraft? out;

  await GFeedback.sheet<void>(
    context,
    title: existing == null ? 'Add {0}'.trf([kind.singular]) : 'Edit line'.tr,
    // Owned by the sheet, not by this function: its future completes
    // when the sheet starts closing, and the fields go on reading these
    // all the way through the exit transition.
    disposing: [name, partNo, qty, rate, remark],
    subtitle: kind.label,
    child: StatefulBuilder(
      builder: (context, setSheet) {
        final p = context.c;
        final q = double.tryParse(qty.text.trim()) ?? 0;
        final r = double.tryParse(rate.text.trim()) ?? 0;

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
              GField(
                label: 'Description'.tr,
                hint: 'Enter {0} name'.trf([kind.singular]),
                controller: name,
                autofocus: existing == null && prefillName.isEmpty,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setSheet(() {}),
              ),
              if (kind.isStocked) ...[
                const SizedBox(height: Gap.lg),
                GField(
                  label: 'Part number'.tr,
                  hint: 'Optional'.tr,
                  controller: partNo,
                  textCapitalization: TextCapitalization.characters,
                ),
              ],
              const SizedBox(height: Gap.lg),
              Row(
                children: [
                  Expanded(
                    child: GField(
                      label: 'Quantity'.tr,
                      hint: '1',
                      controller: qty,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textCapitalization: TextCapitalization.none,
                      onChanged: (_) => setSheet(() {}),
                    ),
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: GField(
                      label: 'Rate'.tr,
                      hint: '450',
                      controller: rate,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textCapitalization: TextCapitalization.none,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      onChanged: (_) => setSheet(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.md),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Gap.lg,
                  vertical: Gap.md,
                ),
                decoration: BoxDecoration(
                  color: p.surfaceSunken,
                  borderRadius: R.all(R.md),
                ),
                child: Row(
                  children: [
                    Text('Line amount'.tr, style: AppType.labelM.c(p.inkMuted)),
                    const Spacer(),
                    Text(Fmt.money2(q * r), style: AppType.money.c(p.ink)),
                  ],
                ),
              ),
              if (staff.isNotEmpty) ...[
                const SizedBox(height: Gap.lg),
                Text('MECHANIC', style: AppType.over.c(p.inkFaint)),
                const SizedBox(height: Gap.sm),
                Wrap(
                  spacing: Gap.sm,
                  runSpacing: Gap.sm,
                  children: [
                    for (final s in staff)
                      Pressable(
                        onTap: () => setSheet(
                          () => mechanicId = mechanicId == s.id ? null : s.id,
                        ),
                        scale: 0.95,
                        child: AnimatedContainer(
                          duration: Motion.fast,
                          padding: const EdgeInsets.symmetric(
                            horizontal: Gap.md,
                            vertical: Gap.sm,
                          ),
                          decoration: BoxDecoration(
                            color: mechanicId == s.id ? p.ink : p.surface,
                            borderRadius: R.all(R.pill),
                            border: Border.all(
                              color: mechanicId == s.id ? p.ink : p.line,
                            ),
                          ),
                          child: Text(
                            s.name,
                            style: AppType.labelM.c(
                              mechanicId == s.id
                                  ? (p.isDark ? p.canvas : Colors.white)
                                  : p.inkSoft,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              if (existing != null) ...[
                const SizedBox(height: Gap.lg),
                Text('STATUS', style: AppType.over.c(p.inkFaint)),
                const SizedBox(height: Gap.sm),
                GSegmented<WorkState>(
                  options: WorkState.values,
                  selected: work,
                  onSelect: (w) => setSheet(() => work = w),
                  labelOf: (w) => w.label,
                  height: 42,
                ),
                const SizedBox(height: Gap.lg),
                GField(
                  label: 'Remark for the floor'.tr,
                  hint: 'Shows on the mechanic copy'.tr,
                  controller: remark,
                  maxLines: 2,
                ),
              ],
              const SizedBox(height: Gap.xxl),
              GButton.accent(
                label: existing == null ? 'Add to bill'.tr : 'Save line'.tr,
                onPressed: name.text.trim().isEmpty
                    ? null
                    : () {
                        out = LineDraft(
                          kind: kind,
                          name: name.text.trim(),
                          partNo: partNo.text.trim(),
                          qty: q <= 0 ? 1 : q,
                          rate: r,
                          mechanicId: mechanicId,
                          state: work,
                          remark: remark.text.trim(),
                        );
                        Navigator.of(context).pop();
                      },
              ),
            ],
          ),
        );
      },
    ),
  );

  return out;
}
