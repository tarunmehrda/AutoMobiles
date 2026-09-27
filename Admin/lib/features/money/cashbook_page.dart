import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/anim/entrance.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_field.dart';
import '../../core/widgets/g_art.dart';
import '../../core/widgets/g_state.dart';
import '../../core/widgets/pressable.dart';
import '../../data/models/entities.dart';
import '../../state/admin_state.dart';
import '../../state/providers.dart';

/// The day book. One day at a time, cash in on the left, cash out on the
/// right, and the two buttons that add either.
class CashBookPage extends ConsumerStatefulWidget {
  const CashBookPage({super.key});

  @override
  ConsumerState<CashBookPage> createState() => _CashBookPageState();
}

class _CashBookPageState extends ConsumerState<CashBookPage> {
  final _search = TextEditingController();
  String _query = '';
  DateTime _day = DateTime.now();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _shift(int days) =>
      setState(() => _day = _day.add(Duration(days: days)));

  bool get _isToday {
    final now = DateTime.now();
    return _day.year == now.year &&
        _day.month == now.month &&
        _day.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    // Searching looks across the whole book, not just the day on screen —
    // otherwise finding a name means paging through weeks.
    final searching = _query.trim().isNotEmpty;
    final all = ref.watch(cashBookProvider);
    final day = ref.watch(cashDayProvider(_day));
    final summary = ref.watch(cashSummaryProvider(_day));

    final q = _query.trim().toLowerCase();
    final rows = searching
        ? (all
              .where(
                (e) =>
                    e.party.toLowerCase().contains(q) ||
                    e.reason.toLowerCase().contains(q),
              )
              .toList()
            ..sort((a, b) => b.at.compareTo(a.at)))
        : day;

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(title: 'CashBook'.tr),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.md),
            child: GSearchBar(
              hint: 'Search by Name & Mobile No.'.tr,
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

          // --- the day's summary --------------------------------------
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.page),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: R.all(R.lg),
                border: Border.all(color: p.line),
                boxShadow: Shadows.soft(p),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(Gap.lg),
                    child: Row(
                      children: [
                        Expanded(
                          child: _Money(
                            label: 'Cash Received'.tr,
                            value: summary.inward,
                            icon: Icons.south_west_rounded,
                            tint: p.success,
                          ),
                        ),
                        Expanded(
                          child: _Money(
                            label: 'Cash Paid'.tr,
                            value: summary.outward,
                            icon: Icons.north_east_rounded,
                            tint: p.danger,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    color: p.infoSoft,
                    padding: const EdgeInsets.symmetric(vertical: Gap.sm),
                    child: Text(
                      _isToday ? "Today's Summary".tr : 'Summary'.tr,
                      textAlign: TextAlign.center,
                      style: AppType.labelL.c(p.info),
                    ),
                  ),
                  Container(
                    color: p.surfaceAlt,
                    padding: const EdgeInsets.symmetric(
                      horizontal: Gap.md,
                      vertical: Gap.sm,
                    ),
                    child: Row(
                      children: [
                        _Step(
                          label: 'Prev'.tr,
                          icon: Icons.chevron_left_rounded,
                          onTap: () => _shift(-1),
                        ),
                        Expanded(
                          child: Center(
                            child: GSwap(
                              child: Text(
                                Fmt.date(_day),
                                key: ValueKey(_day.day),
                                style: AppType.labelL.c(p.accentInk),
                              ),
                            ),
                          ),
                        ),
                        _Step(
                          label: 'Next'.tr,
                          icon: Icons.chevron_right_rounded,
                          trailing: true,
                          onTap: () => _shift(1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: Gap.md),
          Expanded(
            child: rows.isEmpty
                ? GEmptyState(
                    icon: Icons.savings_rounded,
                    title: searching ? 'Nothing found'.tr : 'No entries'.tr,
                    art: Art.wallet,
                    message: searching
                        ? 'No cash entry matches that name.'.tr
                        : 'Nothing has moved through the drawer on this day.'
                              .tr,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      Gap.page,
                      0,
                      Gap.page,
                      Gap.h2,
                    ),
                    itemCount: rows.length,
                    itemBuilder: (context, i) => Entrance(
                      index: i.clamp(0, 8),
                      child: _CashRow(entry: rows[i]),
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: GBottomBar(
        child: Row(
          children: [
            Expanded(
              child: GButton(
                label: '- OUT'.tr,
                kind: GButtonKind.danger,
                onPressed: () => showCashSheet(context, inward: false),
              ),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: GButton(
                label: '+ IN'.tr,
                kind: GButtonKind.volt,
                onPressed: () => showCashSheet(context, inward: true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Money extends StatelessWidget {
  const _Money({
    required this.label,
    required this.value,
    required this.icon,
    required this.tint,
  });

  final String label;
  final double value;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Row(
      children: [
        Container(
          height: 34,
          width: 34,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.12),
            borderRadius: R.all(R.sm),
          ),
          child: Icon(icon, size: 17, color: tint),
        ),
        const SizedBox(width: Gap.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedCount(
                value: value,
                builder: (context, v) => Text(
                  Fmt.money(v),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.money.c(tint),
                ),
              ),
              Text(label, style: AppType.bodyS.s(11).c(p.inkMuted)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.label,
    required this.icon,
    required this.onTap,
    this.trailing = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final text = Text(label, style: AppType.labelM.c(p.info));
    final chevron = Icon(icon, size: 18, color: p.info);
    return Pressable(
      onTap: onTap,
      scale: 0.92,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: trailing ? [text, chevron] : [chevron, text],
        ),
      ),
    );
  }
}

class _CashRow extends ConsumerWidget {
  const _CashRow({required this.entry});

  final CashEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final tint = entry.inward ? p.success : p.danger;
    return Dismissible(
      key: ValueKey(entry.id),
      direction: entry.jobCardId == null
          ? DismissDirection.endToStart
          : DismissDirection.none,
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.only(bottom: Gap.sm),
        padding: const EdgeInsets.only(right: Gap.lg),
        decoration: BoxDecoration(
          color: p.dangerSoft,
          borderRadius: R.all(R.md),
        ),
        child: Icon(Icons.delete_outline_rounded, color: p.danger),
      ),
      onDismissed: (_) {
        ref.read(adminProvider.notifier).removeCash(entry.id);
        GFeedback.info(context, 'Entry removed'.tr);
      },
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
                  Text(Fmt.date(entry.at), style: AppType.labelS.c(p.inkFaint)),
                  const SizedBox(height: 2),
                  Text(
                    entry.party.isEmpty ? 'Walk-in'.tr : entry.party,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.labelL.c(p.ink),
                  ),
                  if (entry.reason.isNotEmpty) ...[
                    const SizedBox(height: Gap.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Gap.sm,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: p.surfaceSunken,
                        borderRadius: R.all(R.pill),
                      ),
                      child: Text(
                        entry.reason,
                        style: AppType.labelS.s(10.5).c(p.inkMuted),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              '${entry.inward ? '' : '- '}${Fmt.money(entry.amount)}',
              style: AppType.money.c(tint),
            ),
          ],
        ),
      ),
    );
  }
}

/// Add one line to the day book.
Future<void> showCashSheet(BuildContext context, {required bool inward}) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CashSheet(inward: inward),
    );

class _CashSheet extends ConsumerStatefulWidget {
  const _CashSheet({required this.inward});

  final bool inward;

  @override
  ConsumerState<_CashSheet> createState() => _CashSheetState();
}

class _CashSheetState extends ConsumerState<_CashSheet> {
  final _party = TextEditingController();
  final _amount = TextEditingController();
  final _reason = TextEditingController();

  @override
  void dispose() {
    for (final c in [_party, _amount, _reason]) {
      c.dispose();
    }
    super.dispose();
  }

  double get _value => double.tryParse(_amount.text.trim()) ?? 0;
  bool get _valid => _party.text.trim().isNotEmpty && _value > 0;

  void _save() {
    if (!_valid) return;
    ref
        .read(adminProvider.notifier)
        .addCash(
          party: _party.text,
          amount: _value,
          inward: widget.inward,
          reason: _reason.text,
        );
    Navigator.of(context).pop();
    GFeedback.success(
      context,
      widget.inward ? 'Cash received'.tr : 'Cash paid out'.tr,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final tint = widget.inward ? p.success : p.danger;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(R.xxl),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              Gap.page,
              Gap.md,
              Gap.page,
              Gap.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    height: 4,
                    width: 44,
                    decoration: BoxDecoration(
                      color: p.line,
                      borderRadius: R.all(R.pill),
                    ),
                  ),
                ),
                const SizedBox(height: Gap.lg),
                Text(
                  widget.inward ? 'Cash In'.tr : 'Cash Out'.tr,
                  style: AppType.h1.c(tint),
                ),
                const SizedBox(height: Gap.lg),
                GField(
                  label: widget.inward ? 'Received from'.tr : 'Paid to'.tr,
                  hint: 'Rahul Sharma'.tr,
                  controller: _party,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: Gap.lg),
                GField(
                  label: 'Amount'.tr,
                  hint: '1500',
                  controller: _amount,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: Gap.lg),
                GField(
                  label: 'Reason'.tr,
                  hint: 'Optional'.tr,
                  controller: _reason,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: Gap.xl),
                GButton(
                  label: widget.inward
                      ? 'Record cash in'.tr
                      : 'Record cash out'.tr,
                  kind: widget.inward ? GButtonKind.volt : GButtonKind.danger,
                  onPressed: _valid ? _save : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
