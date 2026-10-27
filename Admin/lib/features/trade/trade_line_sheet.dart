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

/// What each stock unit is called out loud — the client asked for Litres and
/// Kilograms by name, not `ltr` and `kg`.
String unitLabel(String u) => switch (u) {
  'nos' => 'Numbers (nos)'.tr,
  'ltr' => 'Litres (ltr)'.tr,
  'ml' => 'Millilitres (ml)'.tr,
  'kg' => 'Kilograms (kg)'.tr,
  'gm' => 'Grams (gm)'.tr,
  'can' => 'Cans'.tr,
  'set' => 'Sets'.tr,
  'box' => 'Boxes'.tr,
  'pair' => 'Pairs'.tr,
  'mtr' => 'Metres (mtr)'.tr,
  _ => u,
};

/// How an estimate names its groups. Labour is billed as a job line, so
/// "Jobs / Labour" is one group and parts the other. Lube only reads back on
/// lines saved before the workshop dropped it.
String lineGroupLabel(LineKind k) => switch (k) {
  LineKind.job => 'Jobs / Labour'.tr,
  LineKind.spare => 'Parts'.tr,
  LineKind.lube => 'Lube'.tr,
};

String gstLabel(double rate) => '${(rate * 100).toStringAsFixed(0)}%';

/// Opens the editor for one line and returns it, or null if backed out of.
///
/// [estimate] asks for the line's kind as well, because an estimate is read
/// as Jobs / Parts / Labour. [purchase] pre-fills a master item's cost
/// rather than its sale rate — a bill is what the workshop paid.
Future<TradeLine?> showTradeLineSheet(
  BuildContext context, {
  TradeLine? existing,
  bool estimate = false,
  bool purchase = false,
}) => GFeedback.sheet<TradeLine>(
  context,
  title: existing == null ? 'Add Item'.tr : 'Edit Item'.tr,
  subtitle: 'Pick from your master list or type a new one'.tr,
  child: _LineSheet(existing: existing, estimate: estimate, purchase: purchase),
);

class _LineSheet extends ConsumerStatefulWidget {
  const _LineSheet({
    required this.existing,
    required this.estimate,
    required this.purchase,
  });

  final TradeLine? existing;
  final bool estimate;
  final bool purchase;

  @override
  ConsumerState<_LineSheet> createState() => _LineSheetState();
}

class _LineSheetState extends ConsumerState<_LineSheet> {
  late final TextEditingController _name;
  late final TextEditingController _qty;
  late final TextEditingController _rate;
  late final TextEditingController _hsn;
  late LineKind _kind;
  late String _unit;
  late double _gst;
  late bool _taxIncluded;
  String? _masterId;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _qty = TextEditingController(text: e == null ? '1' : plainAmount(e.qty));
    _rate = TextEditingController(
      text: e == null || e.rate == 0 ? '' : plainAmount(e.rate),
    );
    _hsn = TextEditingController(text: e?.hsn ?? '');
    _kind = e?.kind ?? LineKind.spare;
    _unit = e?.unit ?? 'nos';
    _gst = e?.gstRate ?? 0.18;
    _taxIncluded = e?.taxIncluded ?? false;
    _masterId = e?.masterId;
  }

  @override
  void dispose() {
    for (final c in [_name, _qty, _rate, _hsn]) {
      c.dispose();
    }
    super.dispose();
  }

  double get _qtyValue => double.tryParse(_qty.text.trim()) ?? 0;
  double get _rateValue => double.tryParse(_rate.text.trim()) ?? 0;

  TradeLine get _line => TradeLine(
    name: _name.text.trim(),
    kind: _kind,
    masterId: _masterId,
    qty: _qtyValue,
    unit: _unit,
    rate: _rateValue,
    gstRate: _gst,
    taxIncluded: _taxIncluded,
    hsn: _hsn.text.trim(),
  );

  Future<void> _pickMaster() async {
    final masters = [...ref.read(adminProvider).masters]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final picked = await pickFromList<MasterItem>(
      context,
      title: 'Master list'.tr,
      subtitle: '{0} items'.trf([masters.length]),
      items: masters,
      icon: Icons.inventory_2_rounded,
      labelOf: (m) => m.name,
      subtitleOf: (m) => [
        m.kind.label,
        if (m.partNo.isNotEmpty) m.partNo,
        if (m.tracksStock) '${Fmt.number(m.stock)} ${m.unit} in stock',
      ].join('  ·  '),
      trailingOf: (m) => Fmt.money(_rateOf(m)),
      emptyMessage: 'Nothing in the master list yet.'.tr,
    );
    if (picked == null) return;
    setState(() {
      _masterId = picked.id;
      _name.text = picked.name;
      _unit = kStockUnits.contains(picked.unit) ? picked.unit : 'nos';
      _kind = picked.kind;
      final r = _rateOf(picked);
      if (r > 0) _rate.text = plainAmount(r);
    });
  }

  /// A purchase is costed at what the workshop pays, when that is known.
  double _rateOf(MasterItem m) =>
      widget.purchase && m.cost > 0 ? m.cost : m.rate;

  Future<void> _pickUnit() async {
    final picked = await GFeedback.sheet<String>(
      context,
      title: 'Units'.tr,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.h1),
        children: [
          for (final u in kStockUnits)
            GOptionRow(
              label: unitLabel(u),
              selected: u == _unit,
              onTap: () => Navigator.of(context).pop(u),
            ),
        ],
      ),
    );
    if (picked != null) setState(() => _unit = picked);
  }

  void _save() {
    final line = _line;
    if (line.name.isEmpty) {
      GFeedback.error(context, 'Enter the item name.'.tr);
      return;
    }
    if (line.qty <= 0) {
      GFeedback.error(context, 'Quantity has to be more than zero.'.tr);
      return;
    }
    Navigator.of(context).pop(line);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final master = ref.watch(adminProvider).masterById(_masterId);
    final line = _line;
    final amountFormat = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];

    return SheetBody(
      children: [
        GPickerField(
          label: 'From master list'.tr,
          value: master?.name,
          placeholder: 'Pick a saved item (optional)'.tr,
          leadingIcon: Icons.inventory_2_rounded,
          onTap: _pickMaster,
        ),
        const SizedBox(height: Gap.lg),
        GField(
          label: 'Item Name *'.tr,
          hint: 'Brake pad set'.tr,
          controller: _name,
          textCapitalization: TextCapitalization.words,
          // Renaming a picked item makes it a free line: stock only moves
          // for the master item the counter actually chose.
          onChanged: (v) {
            if (master != null && v.trim() != master.name) {
              setState(() => _masterId = null);
            } else {
              setState(() {});
            }
          },
        ),
        if (widget.estimate) ...[
          const SizedBox(height: Gap.lg),
          SectionLabel('Goes under'.tr),
          ChipChoice<LineKind>(
            options: kBillKinds,
            selected: _kind,
            labelOf: lineGroupLabel,
            iconOf: (k) => k.icon,
            onSelect: (k) => setState(() => _kind = k),
          ),
        ],
        const SizedBox(height: Gap.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: GField(
                label: 'Quantity'.tr,
                hint: '1',
                controller: _qty,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: amountFormat,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: GPickerField(
                label: 'Units'.tr,
                value: _unit,
                onTap: _pickUnit,
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.lg),
        GField(
          label: 'Rate'.tr,
          hint: '450',
          controller: _rate,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: amountFormat,
          prefix: Text('₹ ', style: AppType.labelL.c(p.inkMuted)),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: Gap.md),
        GSegmented<bool>(
          options: const [false, true],
          selected: _taxIncluded,
          onSelect: (v) => setState(() => _taxIncluded = v),
          labelOf: (v) => v ? 'With tax'.tr : 'Without tax'.tr,
        ),
        const SizedBox(height: Gap.lg),
        SectionLabel('GST'.tr),
        ChipChoice<double>(
          options: kGstSlabs,
          selected: _gst,
          labelOf: gstLabel,
          onSelect: (v) => setState(() => _gst = v),
        ),
        const SizedBox(height: Gap.lg),
        GField(
          label: 'HSN / SAC'.tr,
          hint: 'Optional'.tr,
          controller: _hsn,
          keyboardType: TextInputType.number,
          textCapitalization: TextCapitalization.none,
        ),
        const SizedBox(height: Gap.lg),
        // What the numbers above come to, so "with tax" and "without tax"
        // are never a guess.
        Container(
          padding: const EdgeInsets.all(Gap.md),
          decoration: BoxDecoration(
            color: p.surfaceSunken,
            borderRadius: R.all(R.md),
            border: Border.all(color: p.line),
          ),
          child: Row(
            children: [
              _Figure(label: 'Taxable'.tr, value: line.taxable),
              _Figure(label: 'GST {0}'.trf([gstLabel(_gst)]), value: line.tax),
              _Figure(label: 'Amount'.tr, value: line.total, strong: true),
            ],
          ),
        ),
        const SizedBox(height: Gap.xl),
        GButton.accent(
          label: widget.existing == null ? 'Add to list'.tr : 'Update item'.tr,
          icon: Icons.check_rounded,
          onPressed: _save,
        ),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final double value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              Fmt.money2(value),
              style: (strong ? AppType.money : AppType.moneyS).c(
                strong ? p.ink : p.inkSoft,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppType.labelS.c(p.inkMuted)),
        ],
      ),
    );
  }
}
