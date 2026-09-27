import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_art.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_state.dart';
import '../../core/widgets/g_surface.dart';
import '../../data/models/attendance.dart';
import '../../state/admin_state.dart';
import '../../state/providers.dart';
import 'attendance_page.dart' show PunchRow;

/// What the register can be narrowed to.
enum _Lens { all, marked, refused }

extension on _Lens {
  String get label => switch (this) {
    _Lens.all => 'Everything'.tr,
    _Lens.marked => 'Marked'.tr,
    _Lens.refused => 'Refused'.tr,
  };

  IconData get icon => switch (this) {
    _Lens.all => Icons.list_rounded,
    _Lens.marked => Icons.check_circle_rounded,
    _Lens.refused => Icons.block_rounded,
  };
}

/// The attendance register, day by day.
///
/// Refused attempts are here on the same footing as accepted ones, and the
/// Refused lens exists because that is the view an owner actually opens this
/// screen for. A register that only showed successful punches would answer
/// "who was here" and hide "who tried to say they were" — and the second
/// question is the one that made this feature worth building.
class AttendanceRegisterPage extends ConsumerStatefulWidget {
  const AttendanceRegisterPage({super.key});

  @override
  ConsumerState<AttendanceRegisterPage> createState() =>
      _AttendanceRegisterPageState();
}

class _AttendanceRegisterPageState
    extends ConsumerState<AttendanceRegisterPage> {
  _Lens _lens = _Lens.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(adminProvider.notifier).refreshAttendance();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final log = ref.watch(attendanceProvider);
    final rows = switch (_lens) {
      _Lens.all => log,
      _Lens.marked => log.where((e) => e.accepted).toList(),
      _Lens.refused => log.where((e) => !e.accepted).toList(),
    };
    final abuse = log.where((e) => !e.accepted && e.block.isAbuse).length;

    // Newest day first, and each day's rows newest first inside it.
    final days = <DateTime, List<AttendancePunch>>{};
    for (final row in rows) {
      final key = DateTime(row.at.year, row.at.month, row.at.day);
      (days[key] ??= []).add(row);
    }
    final ordered = days.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Register'.tr,
        subtitle: '{0} marked · {1} refused'.trf([
          log.where((e) => e.accepted).length,
          log.where((e) => !e.accepted).length,
        ]),
      ),
      body: Column(
        children: [
          const SizedBox(height: Gap.sm),
          GChoiceChips<_Lens>(
            options: _Lens.values,
            selected: _lens,
            onSelect: (v) => setState(() => _lens = v),
            labelOf: (v) => v.label,
            iconOf: (v) => v.icon,
            countOf: (v) => switch (v) {
              _Lens.all => '${log.length}',
              _Lens.marked => '${log.where((e) => e.accepted).length}',
              _Lens.refused => '${log.where((e) => !e.accepted).length}',
            },
          ),
          if (abuse > 0 && _lens != _Lens.marked) ...[
            const SizedBox(height: Gap.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.page),
              child: _AbuseBanner(count: abuse),
            ),
          ],
          Expanded(
            child: ordered.isEmpty
                ? GEmptyState(
                    icon: Icons.fact_check_rounded,
                    art: Art.done,
                    title: _lens == _Lens.refused
                        ? 'Nothing has been refused'.tr
                        : 'The register is empty'.tr,
                    message: _lens == _Lens.refused
                        ? 'No punch has been turned away. That is the reading you want.'
                              .tr
                        : 'Punches appear here as the team marks in and out.'
                              .tr,
                  )
                : RefreshIndicator(
                    onRefresh: () =>
                        ref.read(adminProvider.notifier).refreshAttendance(),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        Gap.page,
                        Gap.md,
                        Gap.page,
                        Gap.h2,
                      ),
                      itemCount: ordered.length,
                      itemBuilder: (context, i) =>
                          _Day(day: ordered[i], rows: days[ordered[i]]!),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// One day: a heading, who worked how long, and every row under it.
class _Day extends ConsumerWidget {
  const _Day({required this.day, required this.rows});

  final DateTime day;
  final List<AttendancePunch> rows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    // Hours are computed from the whole day, not from the filtered rows: a
    // shift does not get shorter because the screen is showing refusals.
    final whole = ref.watch(attendanceDayProvider(day));
    final people = {for (final r in whole) r.staffId: r.staffName};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: Gap.md, bottom: Gap.sm),
          child: Row(
            children: [
              Text(Fmt.friendlyDay(day), style: AppType.h2.c(p.ink)),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(Fmt.date(day), style: AppType.bodyS.c(p.inkFaint)),
              ),
            ],
          ),
        ),
        if (people.isNotEmpty)
          GCard(
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.md,
              vertical: Gap.sm,
            ),
            child: Column(
              children: [
                for (final entry in people.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.value.isEmpty ? 'Unnamed'.tr : entry.value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.bodyS.c(p.inkMuted),
                          ),
                        ),
                        Text(
                          _hhmm(Shift.worked(whole, entry.key)),
                          style: AppType.labelM.c(p.ink),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: Gap.sm),
        for (final row in rows) PunchRow(punch: row),
        const SizedBox(height: Gap.sm),
      ],
    );
  }

  /// A shift still running, or one where somebody forgot to punch out,
  /// pairs with nothing and reads as a dash rather than as zero — the two
  /// mean very different things to whoever runs payroll.
  static String _hhmm(Duration d) {
    if (d == Duration.zero) return '—';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return h == 0 ? '${m}m' : '${h}h ${m}m';
  }
}

class _AbuseBanner extends StatelessWidget {
  const _AbuseBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final t = toneOf(context, GTone.danger);
    return GCard(
      color: t.bg,
      borderColor: t.fg.withValues(alpha: 0.25),
      padding: const EdgeInsets.all(Gap.md),
      child: Row(
        children: [
          Icon(Icons.gpp_bad_rounded, size: 19, color: t.fg),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Text(
              count == 1
                  ? 'One attempt was refused as a faked location.'.tr
                  : '{0} attempts were refused as faked locations.'.trf([
                      count,
                    ]),
              style: AppType.bodyS.c(t.fg),
            ),
          ),
        ],
      ),
    );
  }
}
