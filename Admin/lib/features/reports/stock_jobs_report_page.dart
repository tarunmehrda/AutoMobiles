import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/anim/entrance.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_art.dart';
import '../../core/widgets/g_state.dart';
import '../../core/widgets/pressable.dart';
import '../../data/models/enums.dart';
import '../../data/repo/admin_data.dart';
import '../../state/providers.dart';
import 'widgets/date_range_bar.dart';

/// What was sold out of the store and off the bench, in a window, filtered
/// down to a make and model when the owner wants to know what a car costs to
/// keep on the road.
class StockJobsReportPage extends ConsumerStatefulWidget {
  const StockJobsReportPage({super.key});

  @override
  ConsumerState<StockJobsReportPage> createState() =>
      _StockJobsReportPageState();
}

class _StockJobsReportPageState extends ConsumerState<StockJobsReportPage> {
  ReportRange _range = ReportRange.week;
  DateSpan _span = DateSpan.of(ReportRange.week);
  LineKind _kind = LineKind.spare;
  String _make = 'All';
  String _model = 'All';

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final data = ref.watch(adminDataProvider);

    final makes = <String>{
      'All',
      for (final v in data.vehicles)
        if (v.brand.isNotEmpty) v.brand,
    }.toList();
    final models = <String>{
      'All',
      for (final v in data.vehicles)
        if (_make == 'All' || v.brand == _make)
          if (v.model.isNotEmpty) v.model,
    }.toList();

    final rows = _rows(data);
    final soldQty = rows.fold<double>(0, (s, r) => s + r.qty);
    final profit = rows.fold<double>(0, (s, r) => s + r.profit);

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Stock & Jobs'.tr,
        subtitle: 'What was fitted, and what it earned'.tr,
      ),
      body: Column(
        children: [
          DateRangeBar(
            range: _range,
            span: _span,
            onChanged: (r, s) => setState(() {
              _range = r;
              _span = s;
            }),
          ),
          Container(
            color: p.accentSoft,
            padding: const EdgeInsets.symmetric(vertical: Gap.sm),
            child: Row(
              children: [
                Expanded(
                  child: _Drop<LineKind>(
                    label: 'Report Type'.tr,
                    value: _kind,
                    options: LineKind.values,
                    labelOf: (k) => k.label,
                    onChanged: (k) => setState(() => _kind = k),
                  ),
                ),
                Expanded(
                  child: _Drop<String>(
                    label: 'Make'.tr,
                    value: makes.contains(_make) ? _make : 'All',
                    options: makes,
                    labelOf: (v) => v,
                    onChanged: (v) => setState(() {
                      _make = v;
                      _model = 'All';
                    }),
                  ),
                ),
                Expanded(
                  child: _Drop<String>(
                    label: 'Model'.tr,
                    value: models.contains(_model) ? _model : 'All',
                    options: models,
                    labelOf: (v) => v,
                    onChanged: (v) => setState(() => _model = v),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: rows.isEmpty
                ? GEmptyState(
                    icon: Icons.inventory_rounded,
                    title: 'Nothing sold in this window'.tr,
                    art: Art.invoice,
                    message: 'Widen the dates or clear the make and model.'.tr,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      Gap.page,
                      Gap.lg,
                      Gap.page,
                      Gap.lg,
                    ),
                    itemCount: rows.length,
                    itemBuilder: (context, i) => Entrance(
                      index: i.clamp(0, 8),
                      child: _Row(row: rows[i]),
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: ReportFooter(
        leftLabel: 'Total Sold Qt',
        leftValue: Fmt.number(soldQty),
        rightLabel: 'Total Profit',
        rightValue: Fmt.money(profit),
      ),
    );
  }

  /// One row per distinct line name, with quantity, value and the margin
  /// against the master rate where the item came from the store.
  List<_SoldRow> _rows(AdminData data) {
    final byName = <String, _SoldRow>{};
    for (final card in data.jobCards) {
      final at = card.completedAt ?? card.createdAt;
      if (!_span.contains(at)) continue;

      final vehicle = data.vehicleById(card.vehicleId);
      if (_make != 'All' && vehicle?.brand != _make) continue;
      if (_model != 'All' && vehicle?.model != _model) continue;

      for (final li in card.items) {
        if (li.kind != _kind) continue;
        // Labour has no cost price, so its whole value is the margin.
        final master = data.masterById(li.masterId);
        final cost = master == null || li.kind == LineKind.job
            ? 0.0
            : master.rate * 0.72 * li.qty;
        final row =
            byName[li.name] ?? _SoldRow(name: li.name, partNo: li.partNo);
        byName[li.name] = row.plus(
          qty: li.qty,
          value: li.amount,
          profit: li.amount - cost,
        );
      }
    }
    final list = byName.values.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return list;
  }
}

class _SoldRow {
  const _SoldRow({
    required this.name,
    this.partNo = '',
    this.qty = 0,
    this.value = 0,
    this.profit = 0,
  });

  final String name;
  final String partNo;
  final double qty;
  final double value;
  final double profit;

  _SoldRow plus({
    required double qty,
    required double value,
    required double profit,
  }) => _SoldRow(
    name: name,
    partNo: partNo,
    qty: this.qty + qty,
    value: this.value + value,
    profit: this.profit + profit,
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.row});

  final _SoldRow row;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
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
                  row.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.labelL.c(p.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (row.partNo.isNotEmpty) row.partNo,
                    'Qty {0}'.trf([Fmt.number(row.qty)]),
                  ].join('  ·  '),
                  style: AppType.bodyS.c(p.inkMuted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(Fmt.money(row.value), style: AppType.money.c(p.ink)),
              Text(
                'Profit {0}'.trf([Fmt.money(row.profit)]),
                style: AppType.labelS.c(p.success),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A compact dropdown that keeps its caption under the value, the way the
/// filter strip reads.
class _Drop<T> extends StatelessWidget {
  const _Drop({
    required this.label,
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> options;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  Future<void> _pick(BuildContext context) async {
    final p = context.c;
    final picked = await showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(R.xxl),
          ),
        ),
        child: SafeArea(
          top: false,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: Gap.lg),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Gap.page,
                  0,
                  Gap.page,
                  Gap.md,
                ),
                child: Text(label, style: AppType.h1.c(p.ink)),
              ),
              for (final o in options)
                ListTile(
                  title: Text(labelOf(o), style: AppType.labelL.c(p.ink)),
                  trailing: o == value
                      ? Icon(Icons.check_rounded, color: p.accent)
                      : null,
                  onTap: () => Navigator.of(context).pop(o),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Pressable(
      onTap: () => _pick(context),
      scale: 0.95,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  labelOf(value),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.labelL.c(p.ink),
                ),
              ),
              Icon(Icons.expand_more_rounded, size: 18, color: p.accent),
            ],
          ),
          Text(label, style: AppType.labelS.s(10).c(p.inkMuted)),
        ],
      ),
    );
  }
}
