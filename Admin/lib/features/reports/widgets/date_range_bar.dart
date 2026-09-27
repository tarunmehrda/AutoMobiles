import 'package:flutter/material.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/pressable.dart';

/// The preset windows every report screen offers.
enum ReportRange { week, currentMonth, custom, lastMonth, lastYear }

extension ReportRangeX on ReportRange {
  String get label => switch (this) {
    ReportRange.week => 'Week'.tr,
    ReportRange.currentMonth => 'Current Month'.tr,
    ReportRange.custom => 'Select Custom'.tr,
    ReportRange.lastMonth => 'Last Month'.tr,
    ReportRange.lastYear => 'Last Year'.tr,
  };
}

/// An inclusive from/to window.
@immutable
class DateSpan {
  const DateSpan(this.from, this.to);

  final DateTime from;
  final DateTime to;

  bool contains(DateTime d) => !d.isBefore(from) && !d.isAfter(to);

  /// The window a preset resolves to, anchored on today.
  static DateSpan of(ReportRange range) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime end(DateTime d) =>
        DateTime(d.year, d.month, d.day, 23, 59, 59, 999);
    return switch (range) {
      ReportRange.week => DateSpan(
        today.subtract(const Duration(days: 6)),
        end(today),
      ),
      ReportRange.currentMonth => DateSpan(
        DateTime(now.year, now.month),
        end(today),
      ),
      ReportRange.lastMonth => DateSpan(
        DateTime(now.year, now.month - 1),
        end(DateTime(now.year, now.month, 0)),
      ),
      ReportRange.lastYear => DateSpan(
        DateTime(now.year - 1),
        end(DateTime(now.year - 1, 12, 31)),
      ),
      // Custom starts as the current month and is then dragged by the picker.
      ReportRange.custom => DateSpan(DateTime(now.year, now.month), end(today)),
    };
  }
}

/// Chips plus the red from/to band that sits under them. Owned by the caller
/// so every report screen keeps its own window.
class DateRangeBar extends StatelessWidget {
  const DateRangeBar({
    super.key,
    required this.range,
    required this.span,
    required this.onChanged,
  });

  final ReportRange range;
  final DateSpan span;
  final void Function(ReportRange range, DateSpan span) onChanged;

  Future<void> _pickCustom(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: DateTimeRange(start: span.from, end: span.to),
    );
    if (picked == null) return;
    onChanged(
      ReportRange.custom,
      DateSpan(
        DateTime(picked.start.year, picked.start.month, picked.start.day),
        DateTime(
          picked.end.year,
          picked.end.month,
          picked.end.day,
          23,
          59,
          59,
          999,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Gap.page),
            children: [
              for (final r in ReportRange.values) ...[
                _Chip(
                  label: r.label,
                  selected: range == r,
                  onTap: () => r == ReportRange.custom
                      ? _pickCustom(context)
                      : onChanged(r, DateSpan.of(r)),
                ),
                const SizedBox(width: Gap.sm),
              ],
            ],
          ),
        ),
        const SizedBox(height: Gap.md),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.page,
            vertical: Gap.md,
          ),
          decoration: BoxDecoration(gradient: p.accentGradient),
          // Each end takes half and no more: two full dates at h2 are wider
          // than a 360pt phone, and a Spacer between two unbounded children
          // has nothing to give.
          child: Row(
            children: [
              Expanded(
                child: _Edge(label: 'From'.tr, value: Fmt.date(span.from)),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: _Edge(
                  label: 'To'.tr,
                  value: Fmt.date(span.to),
                  alignEnd: true,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Edge extends StatelessWidget {
  const _Edge({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: alignEnd
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: AppType.labelS.c(Colors.white.withValues(alpha: 0.85)),
      ),
      const SizedBox(height: 2),
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppType.h2.c(Colors.white),
      ),
    ],
  );
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Pressable(
      onTap: onTap,
      scale: 0.94,
      child: AnimatedContainer(
        duration: Motion.fast,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
        decoration: BoxDecoration(
          color: selected ? p.accentSoft : p.surface,
          borderRadius: R.all(R.pill),
          border: Border.all(color: selected ? p.accent : p.line),
        ),
        child: Text(
          label,
          style: AppType.labelM.c(selected ? p.accentInk : p.inkSoft),
        ),
      ),
    );
  }
}

/// Footer strip used by the reports that total a column.
class ReportFooter extends StatelessWidget {
  const ReportFooter({
    super.key,
    required this.leftLabel,
    required this.leftValue,
    required this.rightLabel,
    required this.rightValue,
  });

  final String leftLabel;
  final String leftValue;
  final String rightLabel;
  final String rightValue;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.md),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.line)),
      ),
      child: SafeArea(
        top: false,
        // Both columns shrink-wrap. A Scaffold lays its
        // `bottomNavigationBar` out with *loose* constraints, so maxHeight is
        // the whole screen — and a column left on the default
        // MainAxisSize.max grows to fill it, taking the Row and this
        // Container with it. The bar then measures the full 904px, which
        // pins it at the top of the screen and paints its opaque surface
        // colour over everything. That is exactly what the Stock & Jobs
        // report did on a handset: a blank white page with the totals
        // sitting over the clock.
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(leftLabel, style: AppType.bodyS.c(p.inkMuted)),
                Text(leftValue, style: AppType.money.c(p.accentInk)),
              ],
            ),
            const Spacer(),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  rightLabel.toUpperCase(),
                  style: AppType.over.s(9.5).c(p.inkMuted),
                ),
                Text(rightValue, style: AppType.moneyL.s(20).c(p.accentInk)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
