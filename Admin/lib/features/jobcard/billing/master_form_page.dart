import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../../../core/widgets/g_net_image.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/models/entities.dart';
import '../../../data/models/enums.dart';
import '../../../data/seed/part_media.dart';
import '../../../state/admin_state.dart';
import 'bill_cart.dart';

/// Create one catalogue row, from the screen that needed it.
///
/// A page rather than the bottom sheet this replaced, for one reason: a spare
/// has eleven fields across four subjects, and a sheet that tall is a sheet
/// you scroll blind — the keyboard takes half of it and the Save button is
/// somewhere under your thumb. A page keeps the total and the Save where they
/// belong, pinned, while the form scrolls past them.
///
/// The row is written to the master list before it is handed back, which is
/// the point of asking for a purchase price and a rack number at all: this is
/// the last time anyone will type this part in. The next card finds it
/// priced, grouped and located.
///
/// Pops the created [MasterItem], or null if the counter backed out.
class MasterFormPage extends ConsumerStatefulWidget {
  const MasterFormPage({super.key, required this.kind});

  final LineKind kind;

  @override
  ConsumerState<MasterFormPage> createState() => _MasterFormPageState();
}

class _MasterFormPageState extends ConsumerState<MasterFormPage> {
  final _name = TextEditingController();
  final _partNo = TextEditingController();
  final _make = TextEditingController();
  final _rack = TextEditingController();
  final _stock = TextEditingController(text: '1');
  final _lowAt = TextEditingController(text: '2');
  final _cost = TextEditingController();
  final _rate = TextEditingController();
  final _fitment = TextEditingController();

  final _fits = <String>[];
  late String _unit = widget.kind == LineKind.lube ? 'ltr' : 'nos';
  PartGroup _group = PartGroup.running;
  bool _outsourced = false;

  LineKind get _kind => widget.kind;

  @override
  void initState() {
    super.initState();
    // The preview at the top of the page is drawn from these, so every one
    // of them has to be able to redraw it as it is typed into.
    for (final c in [_name, _make, _partNo, _cost, _rate, _stock]) {
      c.addListener(_redraw);
    }
  }

  void _redraw() => setState(() {});

  @override
  void dispose() {
    for (final c in [
      _name,
      _partNo,
      _make,
      _rack,
      _stock,
      _lowAt,
      _cost,
      _rate,
      _fitment,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double get _sale => double.tryParse(_rate.text.trim()) ?? 0;
  double get _purchase => double.tryParse(_cost.text.trim()) ?? 0;
  double get _openingStock => double.tryParse(_stock.text.trim()) ?? 0;

  bool get _valid => _name.text.trim().isNotEmpty && _sale > 0;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final tint = billAccent(p, _kind);

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'New {0}'.trf([_kind.singular.toLowerCase()]),
        subtitle: 'Saved to the {0} master list'.trf([_kind.label]),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.xxl),
        children: [
          _Preview(
            kind: _kind,
            tint: tint,
            name: _name.text.trim(),
            make: _make.text.trim(),
            partNo: _partNo.text.trim(),
            rate: _sale,
            stock: _openingStock,
            unit: _unit,
          ),
          const SizedBox(height: Gap.xl),

          // --- 01 ------------------------------------------------------
          _Block(
            step: '01',
            title: 'What it is'.tr,
            blurb: _kind == LineKind.job
                ? 'The line as it will read on the customer’s bill.'.tr
                : 'Named the way the storeman asks for it, not the way the invoice from the distributor spells it.'
                      .tr,
            tint: tint,
            children: [
              if (_kind == LineKind.job) ...[
                _Toggle(
                  tint: tint,
                  left: 'In house',
                  right: 'Out sourced',
                  rightSelected: _outsourced,
                  onSelect: (v) => setState(() => _outsourced = v),
                ),
                const SizedBox(height: Gap.lg),
              ],
              if (_kind == LineKind.spare) ...[
                _GroupPicker(
                  selected: _group,
                  tint: tint,
                  onSelect: (g) => setState(() => _group = g),
                ),
                const SizedBox(height: Gap.lg),
              ],
              GField(
                label: '{0} name *'.trf([_kind.singular]),
                hint: _kind == LineKind.job
                    ? 'Clutch overhauling'.tr
                    : (_kind == LineKind.lube
                          ? 'Semi synthetic engine oil'.tr
                          : 'Front disc pad'.tr),
                controller: _name,
                textCapitalization: TextCapitalization.words,
                autofocus: true,
              ),
              if (_kind != LineKind.job) ...[
                const SizedBox(height: Gap.lg),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: GField(
                        label: 'Part number'.tr,
                        hint: 'Optional'.tr,
                        controller: _partNo,
                        textCapitalization: TextCapitalization.characters,
                      ),
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      flex: 2,
                      child: GPickerField(
                        label: 'Sold by'.tr,
                        value: _unit.toUpperCase(),
                        onTap: _pickUnit,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Gap.lg),
                GField(
                  label: 'Brand'.tr,
                  hint: _kind == LineKind.lube ? 'Yamalube'.tr : 'Bosch'.tr,
                  controller: _make,
                  textCapitalization: TextCapitalization.words,
                ),
              ],
            ],
          ),

          // --- 02 ------------------------------------------------------
          _Block(
            step: '02',
            title: 'What it fits'.tr,
            blurb:
                'Advisory only — nothing stops it going on another vehicle. It is here so the next person does not have to ask.'
                    .tr,
            tint: tint,
            children: [
              GField(
                label: 'Add a vehicle'.tr,
                hint: 'Splendor Plus'.tr,
                controller: _fitment,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _addFitment(),
                suffix: Pressable(
                  onTap: _addFitment,
                  scale: 0.88,
                  child: Icon(Icons.add_circle_rounded, size: 24, color: tint),
                ),
              ),
              if (_fits.isNotEmpty) ...[
                const SizedBox(height: Gap.md),
                Wrap(
                  spacing: Gap.sm,
                  runSpacing: Gap.sm,
                  children: [
                    for (final f in _fits)
                      Pressable(
                        onTap: () => setState(() => _fits.remove(f)),
                        scale: 0.94,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(
                            Gap.md,
                            7,
                            Gap.sm,
                            7,
                          ),
                          decoration: BoxDecoration(
                            color: p.surfaceSunken,
                            borderRadius: R.all(R.pill),
                            border: Border.all(color: p.line),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(f, style: AppType.labelM.c(p.inkSoft)),
                              const SizedBox(width: 5),
                              Icon(
                                Icons.close_rounded,
                                size: 15,
                                color: p.inkFaint,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),

          // --- 03 ------------------------------------------------------
          if (_kind.isStocked)
            _Block(
              step: '03',
              title: 'What is on the shelf'.tr,
              blurb:
                  'Stock moves on its own from here — parts leave when a card is opened and come back when a line is deleted.'
                      .tr,
              tint: tint,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: GField(
                        label: 'Opening stock'.tr,
                        hint: '1',
                        controller: _stock,
                        keyboardType: TextInputType.number,
                        textCapitalization: TextCapitalization.none,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                      ),
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: GField(
                        label: 'Warn under'.tr,
                        hint: '2',
                        controller: _lowAt,
                        keyboardType: TextInputType.number,
                        textCapitalization: TextCapitalization.none,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Gap.lg),
                GField(
                  label: 'Rack'.tr,
                  hint: 'B-14'.tr,
                  controller: _rack,
                  textCapitalization: TextCapitalization.characters,
                ),
              ],
            ),

          // --- 04 ------------------------------------------------------
          _Block(
            step: _kind.isStocked ? '04' : '03',
            title: 'What it costs'.tr,
            blurb: _kind.isStocked
                ? 'Both figures, and the shelf starts telling you what it is earning. The purchase price never leaves this app.'
                      .tr
                : 'What the customer is charged for the job.'.tr,
            tint: tint,
            last: true,
            children: [
              Row(
                children: [
                  if (_kind.isStocked) ...[
                    Expanded(
                      child: GField(
                        label: 'You pay'.tr,
                        hint: '0',
                        controller: _cost,
                        keyboardType: TextInputType.number,
                        textCapitalization: TextCapitalization.none,
                        prefix: Text('₹', style: AppType.bodyL.c(p.inkMuted)),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                      ),
                    ),
                    const SizedBox(width: Gap.md),
                  ],
                  Expanded(
                    child: GField(
                      label: 'They pay *'.tr,
                      hint: '0',
                      controller: _rate,
                      keyboardType: TextInputType.number,
                      textCapitalization: TextCapitalization.none,
                      prefix: Text('₹', style: AppType.bodyL.c(p.inkMuted)),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: GBottomBar(
        child: Row(
          children: [
            Expanded(
              child: _MarginReadout(cost: _purchase, rate: _sale),
            ),
            const SizedBox(width: Gap.md),
            GButton.accent(
              label: 'Save'.tr,
              expand: false,
              trailingIcon: Icons.arrow_forward_rounded,
              onPressed: _valid ? _save : null,
            ),
          ],
        ),
      ),
    );
  }

  void _addFitment() {
    final v = _fitment.text.trim();
    if (v.isEmpty || _fits.contains(v)) return;
    setState(() {
      _fits.add(v);
      _fitment.clear();
    });
  }

  Future<void> _pickUnit() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final p = context.c;
        return Container(
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(R.xxl),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Gap.page,
                Gap.lg,
                Gap.page,
                Gap.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sold by'.tr, style: AppType.h2.c(p.ink)),
                  const SizedBox(height: Gap.md),
                  Wrap(
                    spacing: Gap.sm,
                    runSpacing: Gap.sm,
                    children: [
                      for (final u in kStockUnits)
                        Pressable(
                          onTap: () => Navigator.of(context).pop(u),
                          scale: 0.94,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Gap.xl,
                              vertical: Gap.md,
                            ),
                            decoration: BoxDecoration(
                              color: u == _unit ? p.ink : p.surfaceSunken,
                              borderRadius: R.all(R.pill),
                              border: Border.all(
                                color: u == _unit ? p.ink : p.line,
                              ),
                            ),
                            child: Text(
                              u.toUpperCase(),
                              style: AppType.labelL.c(
                                u == _unit
                                    ? (p.isDark ? p.canvas : Colors.white)
                                    : p.inkSoft,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (picked != null) setState(() => _unit = picked);
  }

  void _save() {
    final created = ref
        .read(adminProvider.notifier)
        .addMaster(
          kind: _kind,
          name: _name.text,
          partNo: _partNo.text,
          rate: _sale,
          cost: _kind.isStocked ? _purchase : 0,
          stock: _kind.isStocked ? _openingStock : 0,
          unit: _kind.isStocked ? _unit : 'nos',
          lowAt: double.tryParse(_lowAt.text.trim()) ?? 2,
          make: _make.text,
          rack: _rack.text,
          group: _group,
          outsourced: _kind == LineKind.job && _outsourced,
          fits: List.unmodifiable(_fits),
        );
    GFeedback.success(
      context,
      '{0} saved to your master list'.trf([created.name]),
    );
    Navigator.of(context).pop(created);
  }
}

// ---------------------------------------------------------------------------

/// The row as the picker will draw it, above the form that is building it.
///
/// Not decoration. Half of what is typed here — the brand, the unit, the part
/// number — only ever appears as a line of small print on a catalogue row,
/// and the only way to know it reads right is to see it read.
class _Preview extends StatelessWidget {
  const _Preview({
    required this.kind,
    required this.tint,
    required this.name,
    required this.make,
    required this.partNo,
    required this.rate,
    required this.stock,
    required this.unit,
  });

  final LineKind kind;
  final Color tint;
  final String name;
  final String make;
  final String partNo;
  final double rate;
  final double stock;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final blank = name.isEmpty;
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        gradient: p.inverseGradient,
        borderRadius: R.all(R.lg),
        boxShadow: Shadows.lifted(p),
      ),
      child: Row(
        children: [
          GNetImage(
            url: PartMedia.urlFor(kind, name),
            fallbackIcon: kind.icon,
            tint: tint,
            height: 62,
            width: 62,
            radius: R.md,
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AS IT WILL LOOK'.tr, style: AppType.over.c(tint)),
                const SizedBox(height: 3),
                Text(
                  blank
                      ? 'Untitled {0}'.trf([kind.singular.toLowerCase()])
                      : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.labelL
                      .s(15)
                      .c(
                        blank
                            ? p.onInverse.withValues(alpha: 0.4)
                            : p.onInverse,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (make.isNotEmpty) make,
                    if (partNo.isNotEmpty) partNo,
                    if (kind.isStocked)
                      '${Fmt.number(stock)} ${unit.toUpperCase()}',
                  ].join('  ·  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.labelS.c(p.onInverse.withValues(alpha: 0.55)),
                ),
              ],
            ),
          ),
          const SizedBox(width: Gap.sm),
          Text(Fmt.money(rate), style: AppType.money.c(p.volt)),
        ],
      ),
    );
  }
}

/// One numbered subject of the form.
class _Block extends StatelessWidget {
  const _Block({
    required this.step,
    required this.title,
    required this.blurb,
    required this.tint,
    required this.children,
    this.last = false,
  });

  final String step;
  final String title;
  final String blurb;
  final Color tint;
  final List<Widget> children;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A rail rather than a heading with a dot on it: the numbers give
          // the form a length you can see, so it is obvious from the first
          // screen that this is four short subjects and not an endless one.
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  height: 26,
                  width: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: p.isDark ? 0.2 : 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Text(step, style: AppType.labelS.s(10).c(tint)),
                ),
                if (!last)
                  Expanded(child: Container(width: 1.5, color: p.lineSoft)),
              ],
            ),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : Gap.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppType.h2.s(17).c(p.ink)),
                  const SizedBox(height: 2),
                  Text(blurb, style: AppType.bodyS.c(p.inkMuted)),
                  const SizedBox(height: Gap.lg),
                  ...children,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Two-state switch, drawn as one track so the pair reads as a choice
/// already made rather than as two buttons waiting to be pressed.
class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.tint,
    required this.left,
    required this.right,
    required this.rightSelected,
    required this.onSelect,
  });

  final Color tint;
  final String left;
  final String right;
  final bool rightSelected;
  final ValueChanged<bool> onSelect;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    Widget half(String label, bool isRight) {
      final on = isRight == rightSelected;
      return Expanded(
        child: Pressable(
          onTap: () => onSelect(isRight),
          scale: 0.97,
          child: AnimatedContainer(
            duration: Motion.fast,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? tint : Colors.transparent,
              borderRadius: R.all(R.pill),
            ),
            child: Text(
              label,
              style: AppType.labelL.c(
                on ? (p.isDark ? p.canvas : Colors.white) : p.inkMuted,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.surfaceSunken,
        borderRadius: R.all(R.pill),
        border: Border.all(color: p.line),
      ),
      child: Row(children: [half(left, false), half(right, true)]),
    );
  }
}

/// The three shelves, as full-width rows rather than chips — each one gets
/// its own line of explanation, which a chip has no room for.
class _GroupPicker extends StatelessWidget {
  const _GroupPicker({
    required this.selected,
    required this.tint,
    required this.onSelect,
  });

  final PartGroup selected;
  final Color tint;
  final ValueChanged<PartGroup> onSelect;

  static const Map<PartGroup, String> _blurbs = {
    PartGroup.running: 'Wears out and gets replaced — pads, cables, filters',
    PartGroup.engine: 'Comes out only when the engine is opened',
    PartGroup.accessory: 'Fitted because the customer asked for it',
  };

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Column(
      children: [
        for (final g in PartGroup.values)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.sm),
            child: Pressable(
              onTap: () => onSelect(g),
              scale: 0.98,
              child: AnimatedContainer(
                duration: Motion.fast,
                padding: const EdgeInsets.all(Gap.md),
                decoration: BoxDecoration(
                  color: g == selected
                      ? tint.withValues(alpha: p.isDark ? 0.18 : 0.10)
                      : p.surface,
                  borderRadius: R.all(R.md),
                  border: Border.all(color: g == selected ? tint : p.line),
                ),
                child: Row(
                  children: [
                    Icon(
                      g.icon,
                      size: 20,
                      color: g == selected ? tint : p.inkFaint,
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(g.label, style: AppType.labelL.c(p.ink)),
                          Text(
                            _blurbs[g]!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.labelS.c(p.inkMuted),
                          ),
                        ],
                      ),
                    ),
                    if (g == selected)
                      Icon(Icons.check_circle_rounded, size: 20, color: tint),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// What the workshop keeps on one of these, said in rupees and in percent.
class _MarginReadout extends StatelessWidget {
  const _MarginReadout({required this.cost, required this.rate});

  final double cost;
  final double rate;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    if (cost <= 0 || rate <= 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Sale price'.tr, style: AppType.labelS.c(p.inkMuted)),
          Text(Fmt.money(rate), style: AppType.money.c(p.ink)),
        ],
      );
    }
    final margin = rate - cost;
    final pct = (margin / rate * 100).round();
    final healthy = margin > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text('You keep'.tr, style: AppType.labelS.c(p.inkMuted)),
            const SizedBox(width: Gap.sm),
            GPill(
              label: healthy ? '$pct%' : 'At a loss'.tr,
              tone: healthy ? GTone.success : GTone.danger,
              compact: true,
            ),
          ],
        ),
        Text(
          Fmt.money(margin),
          style: AppType.money.c(healthy ? p.ink : p.danger),
        ),
      ],
    );
  }
}
