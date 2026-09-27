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

/// Spares, billed onto a card.
///
/// A gallery, not a list, and for a reason that is about the job rather than
/// about taste: a spare is a physical object that somebody is about to walk
/// into the store and fetch. They are matching a shape in their hand against
/// a shape on a screen, so the picture has to be big enough to be a picture.
/// Two columns is the largest a photograph can be while still showing enough
/// rows to scan, and it is the reason this screen scrolls in a grid while the
/// labour screen scrolls in a ledger.
///
/// The shelf groups are filters along the top. They are on the form as well,
/// where they are recorded — here they are the fastest way through six
/// hundred parts to the eight that could possibly be it.
///
/// Pops the picked lines, or null if the counter backed out.
class BillSparePage extends ConsumerStatefulWidget {
  const BillSparePage({super.key});

  @override
  ConsumerState<BillSparePage> createState() => _BillSparePageState();
}

class _BillSparePageState extends ConsumerState<BillSparePage> {
  static const _kind = LineKind.spare;

  final _cart = BillCart();
  final _search = TextEditingController();
  String _query = '';

  /// Null means every shelf.
  PartGroup? _group;

  /// Hides anything the store cannot actually supply. Off by default: a part
  /// that is out of stock is still worth quoting, and hiding it silently is
  /// how a customer gets told a part does not exist.
  bool _inStockOnly = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final tint = billAccent(p, _kind);
    final all = ref.watch(mastersProvider(_kind));
    final q = _query.trim().toLowerCase();

    final rows = all.where((m) {
      if (_group != null && m.group != _group) return false;
      if (_inStockOnly && m.out) return false;
      if (q.isEmpty) return true;
      return m.name.toLowerCase().contains(q) ||
          m.partNo.toLowerCase().contains(q) ||
          m.make.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: p.canvas,
      body: Column(
        children: [
          BillMasthead(
            kind: _kind,
            tint: tint,
            eyebrow: 'Off the shelf'.tr,
            title: 'Parts fitted'.tr,
            total: _cart.totalOver(all),
            count: _cart.rows,
            searchHint: 'Part name, number or brand',
            controller: _search,
            onQuery: (v) => setState(() => _query = v),
            filters: Row(
              children: [
                _Chip(
                  label: 'All shelves'.tr,
                  selected: _group == null,
                  tint: tint,
                  onTap: () => setState(() => _group = null),
                ),
                for (final g in PartGroup.values) ...[
                  const SizedBox(width: Gap.sm),
                  _Chip(
                    label: g.short,
                    icon: g.icon,
                    selected: _group == g,
                    tint: tint,
                    onTap: () => setState(() => _group = g),
                  ),
                ],
                const SizedBox(width: Gap.sm),
                _Chip(
                  label: 'In stock'.tr,
                  icon: Icons.inventory_2_rounded,
                  selected: _inStockOnly,
                  tint: tint,
                  onTap: () => setState(() => _inStockOnly = !_inStockOnly),
                ),
              ],
            ),
          ),
          Expanded(
            child: rows.isEmpty
                ? GEmptyState(
                    icon: _kind.icon,
                    title: q.isEmpty
                        ? 'Nothing on this shelf'.tr
                        : 'Nothing matches “{0}”'.trf([_query]),
                    message:
                        'Add the part once and it is priced, grouped and located for every card after this one.'
                            .tr,
                    actionLabel: 'Add a part'.tr,
                    onAction: _addNew,
                  )
                : EntranceScope(
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        Gap.page,
                        Gap.lg,
                        Gap.page,
                        Gap.lg,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: Gap.md,
                            crossAxisSpacing: Gap.md,
                            // Cover, then three lines of text and a control row.
                            // Fixed rather than aspect-driven so a two-line part
                            // name does not make its neighbour taller.
                            mainAxisExtent: 246,
                          ),
                      itemCount: rows.length,
                      itemBuilder: (context, i) {
                        final m = rows[i];
                        return Entrance(
                          index: i.clamp(0, 8),
                          child: _PartCard(
                            part: m,
                            qty: _cart.qtyOf(m.id),
                            tint: tint,
                            onAdd: () => setState(() => _cart.bump(m.id)),
                            onRemove: () => setState(() => _cart.drop(m.id)),
                            onManage: () => _manage(m, tint),
                          ),
                        );
                      },
                    ),
                  ),
          ),
          if (!_cart.isEmpty)
            _CartStrip(
              masters: all,
              cart: _cart,
              tint: tint,
              onDrop: (id) => setState(() => _cart.setQty(id, 0)),
            ),
        ],
      ),
      bottomNavigationBar: BillFooter(
        kind: _kind,
        tint: tint,
        units: _cart.units,
        unitNoun: 'part',
        total: _cart.totalOver(all),
        onAddNew: _addNew,
        onSave: _cart.isEmpty
            ? null
            : () => Navigator.of(context).pop(_cart.linesOver(all, _kind)),
      ),
    );
  }

  /// Delete a part off the shelf list, and off this bill with it.
  Future<void> _manage(MasterItem part, Color tint) async {
    final deleted = await showMasterActions(context, ref, part, tint: tint);
    if (deleted && mounted) setState(() => _cart.setQty(part.id, 0));
  }

  Future<void> _addNew() async {
    final created = await Navigator.of(context).push<MasterItem>(
      MaterialPageRoute(builder: (_) => const MasterFormPage(kind: _kind)),
    );
    if (created == null) return;
    setState(() => _cart.setQty(created.id, 1));
  }
}

// ---------------------------------------------------------------------------

/// One part, as a photograph with its papers underneath.
class _PartCard extends StatelessWidget {
  const _PartCard({
    required this.part,
    required this.qty,
    required this.tint,
    required this.onAdd,
    required this.onRemove,
    required this.onManage,
  });

  final MasterItem part;
  final double qty;
  final Color tint;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final on = qty > 0;
    // Long-press anywhere on the card, as well as the button on the cover —
    // one for the people who know, one for the people who do not. No card-wide
    // `onTap`: the plus is a target of its own, and a tap that also meant
    // "add" would make the two ambiguous.
    return Pressable(
      onLongPress: onManage,
      scale: 0.99,
      child: AnimatedContainer(
        duration: Motion.fast,
        curve: Motion.enter,
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: R.all(R.lg),
          border: Border.all(color: on ? tint : p.line, width: on ? 1.6 : 1),
          boxShadow: on ? Shadows.lifted(p) : Shadows.soft(p),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                GNetImage(
                  url: PartMedia.urlFor(LineKind.spare, part.name),
                  fallbackIcon: part.group.icon,
                  tint: tint,
                  height: 112,
                  width: double.infinity,
                  radius: 0,
                ),
                // Stock, over the picture rather than under the name. It is the
                // thing that decides whether this part is an option at all, so
                // it has to be seen at the same moment as the part is.
                if (part.tracksStock)
                  Positioned(
                    left: Gap.sm,
                    top: Gap.sm,
                    child: _StockRibbon(part: part),
                  ),
                Positioned(
                  right: 4,
                  top: 4,
                  child: Pressable(
                    onTap: onManage,
                    scale: 0.85,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: p.surface.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.more_horiz_rounded,
                        size: 16,
                        color: p.inkSoft,
                      ),
                    ),
                  ),
                ),
                if (on)
                  Positioned.fill(
                    child: Container(
                      color: tint.withValues(alpha: 0.14),
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Gap.md,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: tint,
                          borderRadius: R.all(R.pill),
                        ),
                        child: Text(
                          '{0} on bill'.trf([Fmt.number(qty)]),
                          style: AppType.labelM
                              .s(11.5)
                              .c(p.isDark ? p.canvas : Colors.white),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Gap.md,
                  Gap.sm,
                  Gap.sm,
                  Gap.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      part.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.labelL.s(13.5).c(p.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (part.make.isNotEmpty) part.make,
                        if (part.partNo.isNotEmpty) part.partNo,
                        if (part.rack.isNotEmpty) 'Rack {0}'.trf([part.rack]),
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.labelS.s(10).c(p.inkFaint),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            Fmt.money(part.rate),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.money.s(16).c(p.ink),
                          ),
                        ),
                        QtyStepper(
                          qty: qty,
                          tint: tint,
                          compact: true,
                          onAdd: onAdd,
                          onRemove: onRemove,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// How many are on the shelf, coloured by whether that is a problem.
class _StockRibbon extends StatelessWidget {
  const _StockRibbon({required this.part});

  final MasterItem part;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final (bg, fg, text) = part.out
        ? (p.danger, Colors.white, 'Out of stock')
        : part.low
        ? (p.warning, Colors.white, '${Fmt.number(part.stock)} left')
        : (
            p.surface.withValues(alpha: 0.92),
            p.inkSoft,
            '${Fmt.number(part.stock)} ${part.unit.toUpperCase()}',
          );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: R.all(R.xs)),
      child: Text(text, style: AppType.labelS.s(9.5).c(fg)),
    );
  }
}

/// What is already on the bill, as thumbnails above the commit bar.
///
/// The grid scrolls away from what has been picked, and on a long catalogue
/// the only proof a part was added is a number that is now three screens up.
/// This is that proof, kept where it can be checked and undone with one tap.
class _CartStrip extends StatelessWidget {
  const _CartStrip({
    required this.masters,
    required this.cart,
    required this.tint,
    required this.onDrop,
  });

  final List<MasterItem> masters;
  final BillCart cart;
  final Color tint;
  final ValueChanged<String> onDrop;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final picked = masters.where((m) => cart.has(m.id)).toList();
    return Container(
      height: 74,
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        border: Border(top: BorderSide(color: p.line)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.page,
          vertical: Gap.sm,
        ),
        itemCount: picked.length,
        separatorBuilder: (_, _) => const SizedBox(width: Gap.sm),
        itemBuilder: (context, i) {
          final m = picked[i];
          return Pressable(
            onTap: () => onDrop(m.id),
            scale: 0.9,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                GNetImage(
                  url: PartMedia.urlFor(LineKind.spare, m.name),
                  fallbackIcon: m.group.icon,
                  tint: tint,
                  height: 54,
                  width: 54,
                  radius: R.sm,
                ),
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tint,
                      borderRadius: R.all(R.pill),
                      border: Border.all(color: p.surfaceAlt, width: 2),
                    ),
                    child: Text(
                      Fmt.number(cart.qtyOf(m.id)),
                      style: AppType.labelS
                          .s(9.5)
                          .c(p.isDark ? p.canvas : Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Filter pill for the masthead, which is dark — so these take their unselected
/// colours from the inverse surface rather than from the page.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.tint,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final Color tint;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final fg = selected
        ? (p.isDark ? p.canvas : Colors.white)
        : p.onInverse.withValues(alpha: 0.75);
    return Pressable(
      onTap: onTap,
      scale: 0.94,
      child: AnimatedContainer(
        duration: Motion.fast,
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.md,
          vertical: Gap.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? tint : p.onInverse.withValues(alpha: 0.10),
          borderRadius: R.all(R.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 5),
            ],
            Text(label, style: AppType.labelM.s(12).c(fg)),
          ],
        ),
      ),
    );
  }
}
