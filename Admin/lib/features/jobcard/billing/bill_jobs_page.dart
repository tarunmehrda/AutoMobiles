import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/anim/entrance.dart';
import '../../../core/i18n/strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/g_badge.dart';
import '../../../core/widgets/g_state.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/models/entities.dart';
import '../../../data/models/enums.dart';
import '../../../state/providers.dart';
import 'bill_cart.dart';
import 'bill_chrome.dart';
import 'master_actions.dart';
import 'master_form_page.dart';

/// Labour, billed onto a card.
///
/// The one of the three with nothing to photograph. A job is an hour of
/// somebody's time, so the screen is built out of the only things it has —
/// the words and the rate — and it gives them the room the other two spend on
/// pictures: the rate is set in money type down the left edge, large enough
/// to read across a counter, and the row is a single wide target rather than
/// a plus button to aim at.
///
/// Jobs are also the only kind where quantity is usually one. Tapping a row
/// therefore toggles it on and off; the stepper only appears once a row is on,
/// for the rare job billed twice.
///
/// Pops the picked lines, or null if the counter backed out.
class BillJobsPage extends ConsumerStatefulWidget {
  const BillJobsPage({super.key});

  @override
  ConsumerState<BillJobsPage> createState() => _BillJobsPageState();
}

class _BillJobsPageState extends ConsumerState<BillJobsPage> {
  static const _kind = LineKind.job;

  final _cart = BillCart();
  final _search = TextEditingController();
  String _query = '';

  /// Null means both. The two are genuinely different conversations —
  /// in-house work is scheduled, outsourced work is chased — so the split is
  /// a filter here rather than only a tag on the row.
  bool? _outsourced;

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
      if (_outsourced != null && m.outsourced != _outsourced) return false;
      return q.isEmpty || m.name.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: p.canvas,
      body: Column(
        children: [
          BillMasthead(
            kind: _kind,
            tint: tint,
            eyebrow: 'Step 1 of the bill'.tr,
            title: 'What was done'.tr,
            total: _cart.totalOver(all),
            count: _cart.rows,
            searchHint: 'Search the labour list',
            controller: _search,
            onQuery: (v) => setState(() => _query = v),
            filters: Row(
              children: [
                for (final f in const [null, false, true])
                  Padding(
                    padding: const EdgeInsets.only(right: Gap.sm),
                    child: _Filter(
                      label: switch (f) {
                        null => 'Everything'.tr,
                        false => 'In house'.tr,
                        _ => 'Out sourced'.tr,
                      },
                      count: f == null
                          ? all.length
                          : all.where((m) => m.outsourced == f).length,
                      selected: _outsourced == f,
                      tint: tint,
                      onTap: () => setState(() => _outsourced = f),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: rows.isEmpty
                ? GEmptyState(
                    icon: _kind.icon,
                    title: q.isEmpty
                        ? 'No jobs priced yet'.tr
                        : 'Nothing matches “{0}”'.trf([_query]),
                    message: q.isEmpty
                        ? 'Price the work once here and every card after this one finds it ready.'
                              .tr
                        : 'Add it as a new job and it is saved for next time.'
                              .tr,
                    actionLabel: 'Add a job'.tr,
                    onAction: _addNew,
                  )
                : EntranceScope(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        Gap.page,
                        Gap.md,
                        Gap.page,
                        Gap.lg,
                      ),
                      itemCount: rows.length,
                      itemBuilder: (context, i) {
                        final m = rows[i];
                        return Entrance(
                          index: i.clamp(0, 8),
                          child: _JobRow(
                            job: m,
                            qty: _cart.qtyOf(m.id),
                            tint: tint,
                            onToggle: () => setState(
                              () => _cart.setQty(m.id, _cart.has(m.id) ? 0 : 1),
                            ),
                            onAdd: () => setState(() => _cart.bump(m.id)),
                            onRemove: () => setState(() => _cart.drop(m.id)),
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
        unitNoun: 'job',
        total: _cart.totalOver(all),
        onAddNew: _addNew,
        onSave: _cart.isEmpty
            ? null
            : () => Navigator.of(context).pop(_cart.linesOver(all, _kind)),
      ),
    );
  }

  /// Delete a job off the labour list, and off this bill with it.
  Future<void> _manage(MasterItem job, Color tint) async {
    final deleted = await showMasterActions(context, ref, job, tint: tint);
    if (deleted && mounted) setState(() => _cart.setQty(job.id, 0));
  }

  /// A job priced at the counter goes onto the bill straight away — nobody
  /// interrupts a card to type a job in and then declines to bill it.
  Future<void> _addNew() async {
    final created = await Navigator.of(context).push<MasterItem>(
      MaterialPageRoute(builder: (_) => const MasterFormPage(kind: _kind)),
    );
    if (created == null) return;
    setState(() => _cart.setQty(created.id, 1));
  }
}

// ---------------------------------------------------------------------------

/// One labour line: rate down the left, name and tags filling the rest.
class _JobRow extends StatelessWidget {
  const _JobRow({
    required this.job,
    required this.qty,
    required this.tint,
    required this.onToggle,
    required this.onAdd,
    required this.onRemove,
    required this.onManage,
  });

  final MasterItem job;
  final double qty;
  final Color tint;
  final VoidCallback onToggle;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final on = qty > 0;
    return Pressable(
      onTap: onToggle,
      // Long-press for the shortcut, the chevron for the people who do not
      // know there is one.
      onLongPress: onManage,
      scale: 0.99,
      child: AnimatedContainer(
        duration: Motion.fast,
        curve: Motion.enter,
        margin: const EdgeInsets.only(bottom: Gap.sm),
        decoration: BoxDecoration(
          color: on ? p.surface : p.surfaceAlt,
          borderRadius: R.all(R.md),
          border: Border.all(color: on ? tint : p.line, width: on ? 1.4 : 1),
          boxShadow: on ? Shadows.soft(p) : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The price panel. Left, not right: on a labour list every row
              // is a sentence of different length, and a rate on the right
              // ends up at a different distance from the eye on every line.
              AnimatedContainer(
                duration: Motion.fast,
                width: 76,
                padding: const EdgeInsets.symmetric(vertical: Gap.md),
                alignment: Alignment.center,
                color: on
                    ? tint.withValues(alpha: p.isDark ? 0.18 : 0.10)
                    : p.surfaceSunken,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      Fmt.money(job.rate),
                      style: AppType.money.s(16).c(on ? p.ink : p.inkSoft),
                    ),
                    Text(
                      'per job'.tr,
                      style: AppType.labelS.s(9.5).c(p.inkFaint),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Gap.md,
                    Gap.md,
                    Gap.sm,
                    Gap.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        job.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.labelL.s(14.5).c(p.ink),
                      ),
                      const SizedBox(height: 5),
                      // Both children give ground. The middle column of this
                      // row is about a third of the phone once the rate panel
                      // and the stepper have taken theirs, and a tag that
                      // refuses to shrink overflows it on a long job name.
                      Row(
                        children: [
                          Flexible(
                            child: GTag(
                              label: job.outsourced
                                  ? 'Out sourced'.tr
                                  : 'In house'.tr,
                              icon: job.outsourced
                                  ? Icons.call_made_rounded
                                  : Icons.home_repair_service_rounded,
                              tone: job.outsourced ? GTone.warning : GTone.info,
                            ),
                          ),
                          if (job.fits.isNotEmpty) ...[
                            const SizedBox(width: Gap.sm),
                            Flexible(
                              child: Text(
                                job.fits.join(', '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppType.labelS.c(p.inkFaint),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Center(
                child: on
                    ? QtyStepper(
                        qty: qty,
                        tint: tint,
                        compact: true,
                        onAdd: onAdd,
                        onRemove: onRemove,
                      )
                    : Icon(
                        Icons.add_circle_outline_rounded,
                        size: 26,
                        color: p.inkFaint,
                      ),
              ),
              _Manage(onTap: onManage),
            ],
          ),
        ),
      ),
    );
  }
}

/// The way out of a row: edit-by-deletion, for the duplicate that was typed
/// in at the counter two minutes ago.
class _Manage extends StatelessWidget {
  const _Manage({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Pressable(
      onTap: onTap,
      scale: 0.85,
      child: SizedBox(
        width: 30,
        child: Icon(Icons.more_vert_rounded, size: 18, color: p.inkFaint),
      ),
    );
  }
}

/// Filter pill carrying its own count, so the split is legible before it is
/// tapped.
class _Filter extends StatelessWidget {
  const _Filter({
    required this.label,
    required this.count,
    required this.selected,
    required this.tint,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
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
            Text(
              label,
              style: AppType.labelM
                  .s(12)
                  .c(
                    selected
                        ? (p.isDark ? p.canvas : Colors.white)
                        : p.onInverse.withValues(alpha: 0.75),
                  ),
            ),
            const SizedBox(width: 5),
            Text(
              '$count',
              style: AppType.labelS
                  .s(10.5)
                  .c(
                    selected
                        ? (p.isDark ? p.canvas : Colors.white).withValues(
                            alpha: 0.7,
                          )
                        : p.onInverse.withValues(alpha: 0.4),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
