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
import '../../state/providers.dart';
import 'widgets/date_range_bar.dart';

/// What one mechanic turned out in a window: how many vehicles, and the
/// value split the way the bill splits it.
class MechanicReportPage extends ConsumerStatefulWidget {
  const MechanicReportPage({super.key});

  @override
  ConsumerState<MechanicReportPage> createState() => _MechanicReportPageState();
}

class _MechanicReportPageState extends ConsumerState<MechanicReportPage> {
  ReportRange _range = ReportRange.week;
  DateSpan _span = DateSpan.of(ReportRange.week);
  String? _staffId;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final data = ref.watch(adminDataProvider);
    final staff = ref.watch(staffProvider);

    if (staff.isEmpty) {
      return Scaffold(
        backgroundColor: p.canvas,
        appBar: GHeader(title: 'Mechanic Report'.tr),
        body: GEmptyState(
          icon: Icons.engineering_rounded,
          title: 'No staff yet'.tr,
          art: Art.customers,
          message:
              'Add a mechanic under Staff and their work shows up here.'.tr,
        ),
      );
    }

    final selected = staff.firstWhere(
      (s) => s.id == _staffId,
      orElse: () => staff.first,
    );

    // A card counts for a mechanic if they are assigned to it, or if any line
    // on it was booked against them.
    final cards = data.jobCards.where((j) {
      if (!_span.contains(j.completedAt ?? j.createdAt)) return false;
      if (j.mechanicIds.contains(selected.id)) return true;
      return j.items.any((li) => li.mechanicId == selected.id);
    }).toList();

    double sum(LineKind kind, {bool? outsourced}) {
      var t = 0.0;
      for (final j in cards) {
        for (final li in j.items) {
          if (li.kind != kind) continue;
          if (li.mechanicId != null && li.mechanicId != selected.id) continue;
          // A job with no master behind it is treated as bought in.
          if (outsourced != null &&
              kind == LineKind.job &&
              (li.masterId == null) != outsourced) {
            continue;
          }
          t += li.amount;
        }
      }
      return t;
    }

    final spare = sum(LineKind.spare);
    final lube = sum(LineKind.lube);
    final inHouse = sum(LineKind.job, outsourced: false);
    final outSource = sum(LineKind.job, outsourced: true);
    final total = spare + lube + inHouse + outSource;

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(title: 'Mechanic Report'.tr),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          DateRangeBar(
            range: _range,
            span: _span,
            onChanged: (r, s) => setState(() {
              _range = r;
              _span = s;
            }),
          ),
          const SizedBox(height: Gap.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.page),
            child: Pressable(
              onTap: () async {
                final picked = await showModalBottomSheet<String>(
                  context: context,
                  backgroundColor: Colors.transparent,
                  builder: (_) => Container(
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
                          for (final s in staff)
                            ListTile(
                              title: Text(
                                s.name,
                                style: AppType.labelL.c(p.ink),
                              ),
                              subtitle: Text(
                                s.skill,
                                style: AppType.bodyS.c(p.inkMuted),
                              ),
                              trailing: s.id == selected.id
                                  ? Icon(Icons.check_rounded, color: p.accent)
                                  : null,
                              onTap: () => Navigator.of(context).pop(s.id),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
                if (picked != null) setState(() => _staffId = picked);
              },
              scale: 0.98,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Gap.lg,
                  vertical: Gap.md,
                ),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: R.all(R.md),
                  border: Border.all(color: p.accent.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person_rounded, size: 19, color: p.accent),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: Text(
                        selected.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.labelL.c(p.ink),
                      ),
                    ),
                    Icon(Icons.expand_more_rounded, color: p.accent),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: Gap.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.page),
            child: Entrance(
              child: Column(
                children: [
                  _Line(
                    label: 'Total Vehicle Worked'.tr,
                    value: '${cards.length}',
                    strong: true,
                  ),
                  _Line(label: 'Spare Total'.tr, value: Fmt.money(spare)),
                  _Line(label: 'Lube Total'.tr, value: Fmt.money(lube)),
                  _Line(label: 'In-House Total'.tr, value: Fmt.money(inHouse)),
                  _Line(
                    label: 'Out-Source Total'.tr,
                    value: Fmt.money(outSource),
                  ),
                  Divider(height: Gap.xxl, color: p.line),
                  _Line(
                    label: 'Total'.tr,
                    value: Fmt.money(total),
                    strong: true,
                    tint: p.accentInk,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Gap.h2),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.value,
    this.strong = false,
    this.tint,
  });

  final String label;
  final String value;
  final bool strong;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.md),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: strong
                  ? AppType.h2.c(tint ?? p.ink)
                  : AppType.bodyL.c(p.inkSoft),
            ),
          ),
          Text(
            value,
            style: strong
                ? AppType.money.c(tint ?? p.ink)
                : AppType.moneyS.c(p.inkSoft),
          ),
        ],
      ),
    );
  }
}
