import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_art.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_field.dart';
import '../../core/widgets/g_state.dart';
import '../../core/widgets/g_surface.dart';
import '../../core/widgets/pressable.dart';
import '../../data/models/books.dart';
import '../../data/models/entities.dart';
import '../../data/models/enums.dart';
import '../../state/admin_state.dart';
import '../inventory/suppliers_page.dart';
import 'trade_line_sheet.dart';
import 'trade_widgets.dart';

/// One form for the five documents — estimate, sale return, sale order,
/// purchase bill, purchase return. They differ only in who the party is,
/// what the reference number means, and whether money changes hands now.
class TradeFormPage extends ConsumerStatefulWidget {
  const TradeFormPage({super.key, required this.kind, this.fromId});

  final TradeKind kind;

  /// A document to start from — a sale order being invoiced, an estimate
  /// being copied.
  final String? fromId;

  @override
  ConsumerState<TradeFormPage> createState() => _TradeFormPageState();
}

class _TradeFormPageState extends ConsumerState<TradeFormPage> {
  final _party = TextEditingController();
  final _phone = TextEditingController();
  final _gstin = TextEditingController();
  final _address = TextEditingController();
  final _ref = TextEditingController();
  final _discount = TextEditingController();
  final _paid = TextEditingController();
  final _note = TextEditingController();

  String? _supplierId;
  String? _customerId;
  DateTime _at = DateTime.now();
  DateTime? _dueAt;
  final _lines = <TradeLine>[];
  TaxSplit _split = TaxSplit.intra;
  PayMode _mode = PayMode.cash;
  String? _account;
  bool _saving = false;

  TradeKind get kind => widget.kind;
  bool get _purchase => !kind.isSale;

  @override
  void initState() {
    super.initState();
    final data = ref.read(adminProvider);
    final from = data.tradeDocs.where((d) => d.id == widget.fromId).firstOrNull;
    if (from != null) {
      // Copy what the other paper already says. Money is not copied: what
      // was paid on that one was paid on that one.
      _party.text = from.party;
      _phone.text = from.phone;
      _gstin.text = from.gstin;
      _address.text = from.address;
      _supplierId = _purchase ? from.supplierId : null;
      _customerId = kind.isSale ? from.customerId : null;
      _lines.addAll(from.lines);
      _split = from.split;
      if (from.discount > 0) _discount.text = plainAmount(from.discount);
      _ref.text = from.number;
      _note.text = from.note;
    }
  }

  @override
  void dispose() {
    for (final c in [
      _party,
      _phone,
      _gstin,
      _address,
      _ref,
      _discount,
      _paid,
      _note,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // --- the numbers ----------------------------------------------------------

  /// The document as it stands, so every total on screen is worked out by
  /// the same getters the saved one will use.
  TradeDoc get _draft => TradeDoc(
    id: '',
    kind: kind,
    number: '',
    at: _at,
    lines: _lines,
    split: _split,
    discount: double.tryParse(_discount.text.trim()) ?? 0,
    paid: double.tryParse(_paid.text.trim()) ?? 0,
  );

  String get _refLabel => switch (kind) {
    TradeKind.purchaseBill => 'Supplier bill no.'.tr,
    TradeKind.purchaseReturn => 'Original bill no.'.tr,
    TradeKind.saleReturn => 'Original invoice no.'.tr,
    TradeKind.saleOrder => 'Customer PO no.'.tr,
    TradeKind.estimate => 'Reference'.tr,
  };

  String get _paidLabel => switch (kind) {
    TradeKind.purchaseBill => 'Paid now'.tr,
    TradeKind.purchaseReturn => 'Refund received now'.tr,
    TradeKind.saleReturn => 'Refunded now'.tr,
    TradeKind.saleOrder => 'Advance received'.tr,
    TradeKind.estimate => '',
  };

  // --- party ----------------------------------------------------------------

  void _takeSupplier(Supplier s) {
    _supplierId = s.id;
    _party.text = s.name;
    _phone.text = s.phone;
    _gstin.text = s.gstin;
    _address.text = s.address;
  }

  Future<void> _pickSupplier() async {
    final suppliers = [...ref.read(adminProvider).suppliers]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final picked = await pickFromList<Supplier>(
      context,
      title: 'Supplier'.tr,
      subtitle: '{0} on record'.trf([suppliers.length]),
      items: suppliers,
      icon: Icons.local_shipping_rounded,
      labelOf: (s) => s.name,
      subtitleOf: (s) => [
        if (s.phone.isNotEmpty) s.phone,
        if (s.gstin.isNotEmpty) s.gstin,
      ].join('  ·  '),
      trailingOf: (s) => s.outstanding > 0 ? Fmt.money(s.outstanding) : '',
      emptyMessage: 'No suppliers yet. Add one below.'.tr,
    );
    if (picked != null) setState(() => _takeSupplier(picked));
  }

  Future<void> _addSupplier() async {
    final s = await showSupplierSheet(context);
    if (s != null && mounted) setState(() => _takeSupplier(s));
  }

  Future<void> _pickCustomer() async {
    final data = ref.read(adminProvider);
    final customers = [...data.customers]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final picked = await pickFromList<Customer>(
      context,
      title: 'Customer'.tr,
      subtitle: '{0} on record'.trf([customers.length]),
      items: customers,
      icon: Icons.person_rounded,
      labelOf: (c) => c.name,
      subtitleOf: (c) => c.phone,
      emptyMessage: 'No customers yet. Type the name instead.'.tr,
    );
    if (picked == null) return;
    setState(() {
      _customerId = picked.id;
      _party.text = picked.name;
      _phone.text = picked.phone;
      _gstin.text = picked.gstin;
      _address.text = picked.address;
    });
  }

  // --- lines ----------------------------------------------------------------

  Future<void> _editLine([int? index]) async {
    final line = await showTradeLineSheet(
      context,
      existing: index == null ? null : _lines[index],
      estimate: kind.isQuote,
      purchase: _purchase,
    );
    if (line == null || !mounted) return;
    setState(() {
      if (index == null) {
        _lines.add(line);
      } else {
        _lines[index] = line;
      }
    });
  }

  // --- save -----------------------------------------------------------------

  void _save() {
    if (_saving) return;
    if (_party.text.trim().isEmpty) {
      GFeedback.error(
        context,
        _purchase ? 'Choose the supplier.'.tr : 'Enter the party name.'.tr,
      );
      return;
    }
    if (_lines.isEmpty) {
      GFeedback.error(context, 'Add at least one item.'.tr);
      return;
    }
    final draft = _draft;
    if (draft.paid > draft.total + 0.009) {
      GFeedback.error(
        context,
        'Paid cannot be more than the total {0}.'.trf([Fmt.money(draft.total)]),
      );
      return;
    }
    _saving = true;
    final data = ref.read(adminProvider);
    final doc = ref
        .read(adminProvider.notifier)
        .addTradeDoc(
          kind: kind,
          lines: List.of(_lines),
          party: _party.text,
          phone: _phone.text,
          gstin: _gstin.text,
          address: _address.text,
          supplierId: _supplierId,
          customerId: _customerId,
          split: _split,
          discount: draft.discount,
          paid: kind.isQuote ? 0 : draft.paid,
          mode: _mode,
          accountId: _account ?? defaultAccountFor(data, _mode),
          note: _note.text,
          refNo: _ref.text,
          at: _at,
          dueAt: kind == TradeKind.saleOrder ? _dueAt : null,
        );
    GFeedback.success(context, '{0} saved'.trf([doc.number]));
    // Replace rather than push: Back from the saved document goes to the
    // list, not into a form that would save it a second time.
    context.pushReplacement('/trade/${doc.id}');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final draft = _draft;
    final number = ref.read(adminProvider.notifier).nextTradeNumber(kind);
    final supplier = ref.watch(adminProvider).supplierById(_supplierId);

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: kind == TradeKind.estimate
            ? 'New Estimate'.tr
            : 'New {0}'.trf([kind.label]),
        subtitle: number,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.h2),
        children: [
          // --- who ----------------------------------------------------------
          _Section(
            title: _purchase ? 'Supplier'.tr : 'Party'.tr,
            icon: _purchase
                ? Icons.local_shipping_rounded
                : Icons.person_rounded,
            children: [
              if (_purchase) ...[
                GPickerField(
                  label: 'Supplier *'.tr,
                  value: _party.text.isEmpty ? null : _party.text,
                  placeholder: 'Choose a supplier'.tr,
                  leadingIcon: Icons.local_shipping_rounded,
                  onTap: _pickSupplier,
                ),
                const SizedBox(height: Gap.sm),
                Row(
                  children: [
                    if (supplier != null && supplier.outstanding > 0)
                      Expanded(
                        child: Text(
                          'Outstanding {0}'.trf([
                            Fmt.money(supplier.outstanding),
                          ]),
                          style: AppType.labelM.c(p.danger),
                        ),
                      )
                    else
                      const Spacer(),
                    GLink(
                      label: 'Add supplier'.tr,
                      icon: Icons.add_rounded,
                      onTap: _addSupplier,
                    ),
                  ],
                ),
              ] else
                GField(
                  label: kind.isQuote
                      ? 'Customer name *'.tr
                      : 'Party name *'.tr,
                  hint: 'Rahul Sharma'.tr,
                  controller: _party,
                  textCapitalization: TextCapitalization.words,
                  // Typing over a picked customer makes it a free name.
                  onChanged: (_) => setState(() => _customerId = null),
                  suffix: Pressable(
                    onTap: _pickCustomer,
                    scale: 0.9,
                    child: Icon(
                      Icons.contacts_rounded,
                      size: 20,
                      color: p.accentInk,
                    ),
                  ),
                ),
              const SizedBox(height: Gap.lg),
              Row(
                children: [
                  Expanded(
                    child: GField(
                      label: 'Phone'.tr,
                      hint: 'Optional'.tr,
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      textCapitalization: TextCapitalization.none,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                      ],
                    ),
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: GField(
                      label: 'GSTIN',
                      hint: 'Optional'.tr,
                      controller: _gstin,
                      textCapitalization: TextCapitalization.characters,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.lg),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: GField(
                      label: _refLabel,
                      hint: 'Optional'.tr,
                      controller: _ref,
                      textCapitalization: TextCapitalization.characters,
                    ),
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: DateField(
                      label: 'Date'.tr,
                      value: _at,
                      onChanged: (d) => setState(() => _at = d),
                    ),
                  ),
                ],
              ),
              if (kind == TradeKind.saleOrder) ...[
                const SizedBox(height: Gap.lg),
                DateField(
                  label: 'Due date'.tr,
                  value: _dueAt,
                  placeholder: 'When it is to be delivered'.tr,
                  first: DateTime.now().subtract(const Duration(days: 1)),
                  onChanged: (d) => setState(() => _dueAt = d),
                ),
              ],
            ],
          ),

          // --- what ---------------------------------------------------------
          _Section(
            title: kind.isQuote ? 'Jobs / Parts / Labour'.tr : 'Items'.tr,
            icon: Icons.list_alt_rounded,
            trailing: _lines.isEmpty
                ? null
                : Text(
                    Tr.plural(_lines.length, '{0} item', '{0} items'),
                    style: AppType.labelM.c(p.inkMuted),
                  ),
            children: [
              if (_lines.isEmpty)
                GEmptyState(
                  compact: true,
                  icon: Icons.add_shopping_cart_rounded,
                  art: Art.invoice,
                  title: 'No items yet'.tr,
                  message: 'Pick from the master list or type any item.'.tr,
                )
              else
                for (var i = 0; i < _lines.length; i++)
                  _LineCard(
                    line: _lines[i],
                    split: _split,
                    showKind: kind.isQuote,
                    onTap: () => _editLine(i),
                    onRemove: () => setState(() => _lines.removeAt(i)),
                  ),
              const SizedBox(height: Gap.sm),
              GButton(
                label: '+ Add Items'.tr,
                kind: GButtonKind.outline,
                size: GButtonSize.md,
                onPressed: () => _editLine(),
              ),
            ],
          ),

          // --- tax ----------------------------------------------------------
          _Section(
            title: 'Tax & totals'.tr,
            icon: Icons.percent_rounded,
            children: [
              _SplitToggle(
                split: _split,
                onChanged: (s) => setState(() => _split = s),
              ),
              const SizedBox(height: Gap.lg),
              TaxBreakdown(doc: draft),
              const SizedBox(height: Gap.md),
              GField(
                label: 'Discount'.tr,
                hint: '0',
                controller: _discount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                prefix: Text('₹ ', style: AppType.labelL.c(p.inkMuted)),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: Gap.md),
              GKeyValue(
                label: 'Total'.tr,
                value: Fmt.money2(draft.total),
                emphasize: true,
              ),
            ],
          ),

          // --- money --------------------------------------------------------
          if (!kind.isQuote)
            _Section(
              title: 'Payment'.tr,
              icon: Icons.payments_rounded,
              children: [
                GField(
                  label: _paidLabel,
                  hint: '0',
                  controller: _paid,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  prefix: Text('₹ ', style: AppType.labelL.c(p.inkMuted)),
                  suffix: GLink(
                    label: 'Full'.tr,
                    onTap: () =>
                        setState(() => _paid.text = plainAmount(_draft.total)),
                  ),
                  onChanged: (_) => setState(() {}),
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
                const SizedBox(height: Gap.md),
                GKeyValue(
                  label: 'Balance'.tr,
                  value: Fmt.money2(draft.balance),
                  emphasize: true,
                  valueColor: draft.balance > 0 ? p.danger : p.success,
                ),
              ],
            ),

          _Section(
            title: 'Note'.tr,
            icon: Icons.sticky_note_2_rounded,
            children: [
              GField(
                hint: kind.isQuote
                    ? 'Valid for 7 days, parts subject to availability'.tr
                    : 'Optional'.tr,
                controller: _note,
                maxLines: 3,
              ),
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
                Text(Fmt.money(draft.total), style: AppType.money.c(p.ink)),
              ],
            ),
            const SizedBox(width: Gap.lg),
            Expanded(
              child: GButton.accent(
                label: 'Save {0}'.trf([kind.label]),
                icon: Icons.check_rounded,
                onPressed: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A titled card on the form.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.children,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
      margin: const EdgeInsets.only(bottom: Gap.md),
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: R.all(R.lg),
        border: Border.all(color: p.line),
        boxShadow: Shadows.soft(p),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                height: 28,
                width: 28,
                decoration: BoxDecoration(
                  color: p.accentSoft,
                  borderRadius: R.all(R.xs),
                ),
                child: Icon(icon, size: 15, color: p.accentInk),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(child: Text(title, style: AppType.h3.c(p.ink))),
              ?trailing,
            ],
          ),
          const SizedBox(height: Gap.lg),
          ...children,
        ],
      ),
    );
  }
}

/// One line on the form: what it is, how many at what, and its money.
class _LineCard extends StatelessWidget {
  const _LineCard({
    required this.line,
    required this.split,
    required this.showKind,
    required this.onTap,
    required this.onRemove,
  });

  final TradeLine line;
  final TaxSplit split;
  final bool showKind;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final taxBits = split == TaxSplit.intra
        ? 'CGST ${Fmt.money2(line.cgst(split))} + SGST ${Fmt.money2(line.sgst(split))}'
        : 'IGST ${Fmt.money2(line.igst(split))}';
    return Pressable(
      onTap: onTap,
      scale: 0.99,
      child: Container(
        margin: const EdgeInsets.only(bottom: Gap.sm),
        padding: const EdgeInsets.all(Gap.md),
        decoration: BoxDecoration(
          color: p.surfaceAlt,
          borderRadius: R.all(R.md),
          border: Border.all(color: p.line),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (showKind) lineGroupLabel(line.kind),
                      '${Fmt.number(line.qty)} ${line.unit} × ${Fmt.money2(line.rate)}',
                      if (line.taxIncluded) 'incl. tax'.tr,
                      'GST ${gstLabel(line.gstRate)}',
                      if (line.hsn.isNotEmpty) 'HSN ${line.hsn}',
                    ].join('  ·  '),
                    style: AppType.bodyS.c(p.inkMuted),
                  ),
                  if (line.tax > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Taxable ${Fmt.money2(line.taxable)}  ·  $taxBits',
                      style: AppType.labelS.c(p.inkFaint),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: Gap.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(Fmt.money2(line.total), style: AppType.moneyS.c(p.ink)),
                const SizedBox(height: Gap.sm),
                Pressable(
                  onTap: onRemove,
                  scale: 0.88,
                  child: Icon(Icons.close_rounded, size: 19, color: p.danger),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Same state or other state — two cards rather than a segmented control,
/// because each needs its tax names under it and a 360dp phone has no room
/// for "Same state (CGST + SGST)" on one pill.
class _SplitToggle extends StatelessWidget {
  const _SplitToggle({required this.split, required this.onChanged});

  final TaxSplit split;
  final ValueChanged<TaxSplit> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    Widget card(TaxSplit s, String title, String sub) {
      final on = s == split;
      return Expanded(
        child: Pressable(
          onTap: () => onChanged(s),
          scale: 0.97,
          child: AnimatedContainer(
            duration: Motion.fast,
            padding: const EdgeInsets.all(Gap.md),
            decoration: BoxDecoration(
              color: on ? p.accentSoft : p.surfaceAlt,
              borderRadius: R.all(R.md),
              border: Border.all(color: on ? p.accent : p.line),
            ),
            child: Row(
              children: [
                Icon(
                  on
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 18,
                  color: on ? p.accentInk : p.inkFaint,
                ),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.labelM.c(p.ink),
                      ),
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.labelS.c(p.inkMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        card(TaxSplit.intra, 'Same state'.tr, 'CGST + SGST'),
        const SizedBox(width: Gap.sm),
        card(TaxSplit.inter, 'Other state'.tr, 'IGST'),
      ],
    );
  }
}

/// Taxable value, then the tax slab by slab — CGST and SGST at half the
/// rate each inside the state, IGST at the full rate across — then the
/// discount. Shared with the document view so both read the same.
class TaxBreakdown extends StatelessWidget {
  const TaxBreakdown({super.key, required this.doc});

  final TradeDoc doc;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    // Tax grouped by slab, so a bill with 18% parts and 28% lubes shows
    // both rates rather than one blended figure nobody can check.
    final bySlab = <double, double>{};
    for (final l in doc.lines) {
      if (l.tax <= 0) continue;
      bySlab[l.gstRate] = (bySlab[l.gstRate] ?? 0) + l.tax;
    }
    final slabs = bySlab.keys.toList()..sort();
    String pct(double v) {
      final s = (v * 100).toStringAsFixed(1);
      return '${s.endsWith('.0') ? s.substring(0, s.length - 2) : s}%';
    }

    return Column(
      children: [
        GKeyValue(label: 'Taxable value'.tr, value: Fmt.money2(doc.taxable)),
        for (final r in slabs)
          if (doc.split == TaxSplit.intra) ...[
            GKeyValue(
              label: 'CGST @ {0}'.trf([pct(r / 2)]),
              value: Fmt.money2(money(bySlab[r]! / 2)),
            ),
            GKeyValue(
              label: 'SGST @ {0}'.trf([pct(r / 2)]),
              value: Fmt.money2(money(bySlab[r]! - bySlab[r]! / 2)),
            ),
          ] else
            GKeyValue(
              label: 'IGST @ {0}'.trf([pct(r)]),
              value: Fmt.money2(money(bySlab[r]!)),
            ),
        if (slabs.isEmpty) GKeyValue(label: 'GST'.tr, value: Fmt.money2(0)),
        if (doc.discount > 0)
          GKeyValue(
            label: 'Discount'.tr,
            value: '- ${Fmt.money2(doc.discount)}',
            valueColor: p.success,
          ),
      ],
    );
  }
}
