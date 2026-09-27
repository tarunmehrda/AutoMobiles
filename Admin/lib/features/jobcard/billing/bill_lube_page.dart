import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/anim/entrance.dart';
import '../../../core/i18n/strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/g_net_image.dart';
import '../../../core/widgets/g_state.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/models/entities.dart';
import '../../../data/models/enums.dart';
import '../../../data/seed/part_media.dart';
import '../../../state/providers.dart';
import 'bill_cart.dart';
import 'bill_chrome.dart';
import 'master_actions.dart';
import 'master_form_page.dart';

/// Lubricants, billed onto a card.
///
/// The kind that is measured rather than counted, and the screen is built
/// around that one fact. A spare is one of a thing; a lube is 2.4 litres out
/// of a 5 litre can, and everything here follows from it:
///
/// * the stepper moves in half units, not ones, because "one engine oil" is
///   not a quantity anybody has ever asked for;
/// * the unit travels with the number wherever it is shown, so 2.5 is never
///   left to be read as cans by one person and litres by another;
/// * each row carries a gauge of what is left in the drum, which on a
///   measured stock is the difference between "we have some" and "we have
///   enough for this car".
///
/// Pops the picked lines, or null if the counter backed out.
class BillLubePage extends ConsumerStatefulWidget {
  const BillLubePage({super.key});

  @override
  ConsumerState<BillLubePage> createState() => _BillLubePageState();
}

class _BillLubePageState extends ConsumerState<BillLubePage> {
  static const _kind = LineKind.lube;

  final _cart = BillCart();
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// One tap's worth, for a row sold by [unit].
  ///
  /// Millilitres and grams step in fifties — a 500 ml bottle stepped in
  /// halves would take a thousand taps — and everything else in halves.
  static double _step(String unit) => switch (unit.toLowerCase()) {
    'ml' || 'gm' => 50,
    'nos' || 'can' || 'set' => 1,
    _ => 0.5,
  };

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final tint = billAccent(p, _kind);
    final all = ref.watch(mastersProvider(_kind));
    final q = _query.trim().toLowerCase();

    final rows = q.isEmpty
        ? all
        : all
              .where(
                (m) =>
                    m.name.toLowerCase().contains(q) ||
                    m.partNo.toLowerCase().contains(q) ||
                    m.make.toLowerCase().contains(q),
              )
              .toList();

    return Scaffold(
      backgroundColor: p.canvas,
      body: Column(
        children: [
          BillMasthead(
            kind: _kind,
            tint: tint,
            eyebrow: 'Drained and filled'.tr,
            title: 'Oils and fluids'.tr,
            total: _cart.totalOver(all),
            count: _cart.rows,
            searchHint: 'Oil, grade or brand',
            controller: _search,
            onQuery: (v) => setState(() => _query = v),
          ),
          Expanded(
            child: rows.isEmpty
                ? GEmptyState(
                    icon: _kind.icon,
                    title: q.isEmpty
                        ? 'No oils priced yet'.tr
                        : 'Nothing matches “{0}”'.trf([_query]),
                    message:
                        'Add the grade once, with what a litre of it costs, and it is on every card after this one.'
                            .tr,
                    actionLabel: 'Add a lubricant'.tr,
                    onAction: _addNew,
                  )
                : EntranceScope(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        Gap.page,
                        Gap.lg,
                        Gap.page,
                        Gap.lg,
                      ),
                      itemCount: rows.length,
                      itemBuilder: (context, i) {
                        final m = rows[i];
                        return Entrance(
                          index: i.clamp(0, 8),
                          child: _LubeRow(
                            lube: m,
                            qty: _cart.qtyOf(m.id),
                            step: _step(m.unit),
                            tint: tint,
                            onAdd: () =>
                                setState(() => _cart.bump(m.id, _step(m.unit))),
                            onRemove: () =>
                                setState(() => _cart.drop(m.id, _step(m.unit))),
                            onManage: () => _manage(m, tint),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: BillFooter(
        kind: _kind,
        tint: tint,
        units: _cart.units,
        unitNoun: 'unit',
        total: _cart.totalOver(all),
        onAddNew: _addNew,
        onSave: _cart.isEmpty
            ? null
            : () => Navigator.of(context).pop(_cart.linesOver(all, _kind)),
      ),
    );
  }

  /// Delete a grade off the lube list, and off this bill with it.
  Future<void> _manage(MasterItem lube, Color tint) async {
    final deleted = await showMasterActions(context, ref, lube, tint: tint);
    if (deleted && mounted) setState(() => _cart.setQty(lube.id, 0));
  }

  Future<void> _addNew() async {
    final created = await Navigator.of(context).push<MasterItem>(
      MaterialPageRoute(builder: (_) => const MasterFormPage(kind: _kind)),
    );
    if (created == null) return;
    setState(() => _cart.setQty(created.id, _step(created.unit)));
  }
}

// ---------------------------------------------------------------------------

/// One grade on the shelf: the bottle, what it is, and how much of it is left.
class _LubeRow extends StatelessWidget {
  const _LubeRow({
    required this.lube,
    required this.qty,
    required this.step,
    required this.tint,
    required this.onAdd,
    required this.onRemove,
    required this.onManage,
  });

  final MasterItem lube;
  final double qty;
  final double step;
  final Color tint;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final on = qty > 0;
    return Pressable(
      onLongPress: onManage,
      scale: 0.99,
      child: AnimatedContainer(
        duration: Motion.fast,
        curve: Motion.enter,
        margin: const EdgeInsets.only(bottom: Gap.md),
        padding: const EdgeInsets.all(Gap.md),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: R.all(R.lg),
          border: Border.all(color: on ? tint : p.line, width: on ? 1.5 : 1),
          boxShadow: on ? Shadows.lifted(p) : Shadows.soft(p),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Portrait, not square: a bottle is a tall object, and a square
            // crop of one is mostly the table it is standing on.
            GNetImage(
              url: PartMedia.urlFor(LineKind.lube, lube.name),
              fallbackIcon: Icons.water_drop_rounded,
              tint: tint,
              height: 96,
              width: 70,
              radius: R.md,
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          lube.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.labelL.s(14.5).c(p.ink),
                        ),
                      ),
                      const SizedBox(width: Gap.sm),
                      _UnitPill(unit: lube.unit, tint: tint),
                      Pressable(
                        onTap: onManage,
                        scale: 0.85,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: Icon(
                            Icons.more_vert_rounded,
                            size: 18,
                            color: p.inkFaint,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (lube.make.isNotEmpty) lube.make,
                      if (lube.partNo.isNotEmpty) lube.partNo,
                      '${Fmt.money(lube.rate)} / ${lube.unit.toUpperCase()}',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.labelS.s(10.5).c(p.inkMuted),
                  ),
                  const SizedBox(height: Gap.sm),
                  _Gauge(lube: lube, taking: qty, tint: tint),
                  const SizedBox(height: Gap.sm),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          on
                              ? Fmt.money(lube.rate * qty)
                              : 'Not on the bill'.tr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: on
                              ? AppType.money.s(17).c(p.ink)
                              : AppType.labelS.c(p.inkFaint),
                        ),
                      ),
                      QtyStepper(
                        qty: qty,
                        tint: tint,
                        step: step,
                        unit: lube.unit,
                        onAdd: onAdd,
                        onRemove: onRemove,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// How much is in the drum, and how much of that this bill is taking.
///
/// Two bars in one track. The pale one is the stock; the solid one is what
/// has been picked, drawn over it — so a row where the bill is about to empty
/// the drum shows it as a shape, before anybody reads a number.
class _Gauge extends StatelessWidget {
  const _Gauge({required this.lube, required this.taking, required this.tint});

  final MasterItem lube;
  final double taking;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    if (!lube.tracksStock) return const SizedBox.shrink();

    // A full drum is whatever the largest of these is: without a capacity on
    // the record, the only honest scale is the stock itself, widened when the
    // bill is asking for more than there is.
    final full = [
      lube.stock,
      taking,
      lube.lowAt * 2,
      1.0,
    ].reduce((a, b) => a > b ? a : b);
    final stockShare = (lube.stock / full).clamp(0.0, 1.0);
    final takeShare = (taking / full).clamp(0.0, 1.0);
    final short = taking > lube.stock;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: R.all(R.pill),
          child: Stack(
            children: [
              Container(height: 7, color: p.surfaceSunken),
              FractionallySizedBox(
                widthFactor: stockShare,
                child: Container(
                  height: 7,
                  color:
                      (lube.out
                              ? p.danger
                              : lube.low
                              ? p.warning
                              : tint)
                          .withValues(alpha: 0.28),
                ),
              ),
              FractionallySizedBox(
                widthFactor: takeShare,
                child: AnimatedContainer(
                  duration: Motion.fast,
                  height: 7,
                  color: short ? p.danger : tint,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          short
              ? 'Short by {0} {1}'.trf([
                  Fmt.number(taking - lube.stock),
                  lube.unit.toUpperCase(),
                ])
              : '{0} {1} in the store'.trf([
                  Fmt.number(lube.stock),
                  lube.unit.toUpperCase(),
                ]),
          style: AppType.labelS
              .s(10)
              .c(
                short
                    ? p.danger
                    : lube.low
                    ? p.warning
                    : p.inkFaint,
              ),
        ),
      ],
    );
  }
}

class _UnitPill extends StatelessWidget {
  const _UnitPill({required this.unit, required this.tint});

  final String unit;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: 3),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: p.isDark ? 0.2 : 0.12),
        borderRadius: R.all(R.xs),
      ),
      child: Text(unit.toUpperCase(), style: AppType.labelS.s(9.5).c(tint)),
    );
  }
}
