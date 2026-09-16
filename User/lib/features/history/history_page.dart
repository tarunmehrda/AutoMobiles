import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/anim/entrance.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_state.dart';
import '../../core/widgets/g_surface.dart';
import '../../data/models/entities.dart';
import '../../data/models/enums.dart';
import '../../state/app_state.dart';
import '../../state/providers.dart';
import 'widgets/booking_card.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  String _vehicleFilter = 'All vehicles';

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final data = ref.watch(appControllerProvider);
    final vehicles = ref.watch(vehiclesProvider);
    final stats = ref.watch(garageStatsProvider);

    final options = ['All vehicles', ...vehicles.map((v) => v.title)];
    var done = data.bookings
        .where((b) => b.status == BookingStatus.completed)
        .toList()
      ..sort((a, b) => b.slot.compareTo(a.slot));

    if (_vehicleFilter != 'All vehicles') {
      final match =
          vehicles.where((v) => v.title == _vehicleFilter).firstOrNull;
      done = done.where((b) => b.vehicleId == match?.id).toList();
    }

    // Group by year so long histories stay readable.
    final byYear = <int, List<Booking>>{};
    for (final b in done) {
      (byYear[b.slot.year] ??= []).add(b);
    }

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Service history',
        subtitle: '${done.length} completed ${done.length == 1 ? 'job' : 'jobs'}',
      ),
      body: done.isEmpty && _vehicleFilter == 'All vehicles'
          ? GEmptyState(
              icon: Icons.history_rounded,
              title: 'No history yet',
              message:
                  'Every completed job, its invoice and the parts fitted will '
                  'be kept here permanently.',
              actionLabel: 'Book a service',
              onAction: () => context.go('/book'),
            )
          : ListView(
              padding:
                  const EdgeInsets.fromLTRB(0, Gap.sm, 0, Gap.h2),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Gap.page),
                  child: Entrance(
                    child: GCard(
                      child: Row(
                        children: [
                          _stat(context, '${stats.services}', 'Services'),
                          Container(
                              height: 32, width: 1, color: p.line),
                          _stat(context, Fmt.money(stats.spend), 'Total spend'),
                          Container(
                              height: 32, width: 1, color: p.line),
                          _stat(context, Fmt.money(stats.saved), 'Saved',
                              tone: p.success),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: Gap.lg),
                if (options.length > 1)
                  GChoiceChips<String>(
                    options: options,
                    selected: _vehicleFilter,
                    onSelect: (v) => setState(() => _vehicleFilter = v),
                    labelOf: (v) => v,
                  ),
                const SizedBox(height: Gap.lg),
                if (done.isEmpty)
                  const GEmptyState(
                    icon: Icons.filter_alt_off_rounded,
                    title: 'Nothing for this vehicle',
                    message: 'Try another vehicle from the filter above.',
                    compact: true,
                  ),
                for (final year in byYear.keys.toList()..sort((a, b) => b - a))
                  ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        Gap.page, Gap.md, Gap.page, Gap.md),
                    child: Row(
                      children: [
                        Text('$year', style: AppType.h1.c(p.ink)),
                        const SizedBox(width: Gap.md),
                        Expanded(child: Divider(color: p.lineSoft)),
                        const SizedBox(width: Gap.md),
                        Text(
                          Fmt.money(byYear[year]!.fold<int>(
                              0,
                              (s, b) =>
                                  s + (data.invoices[b.id]?.total ?? b.total))),
                          style: AppType.labelM.c(p.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  for (var i = 0; i < byYear[year]!.length; i++)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          Gap.page, 0, Gap.page, Gap.md),
                      child: BookingCard(
                        booking: byYear[year]![i],
                        index: i,
                      ),
                    ),
                ],
              ],
            ),
    );
  }

  Widget _stat(BuildContext context, String value, String label,
      {Color? tone}) {
    final p = context.c;
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: AppType.money.s(16).c(tone ?? p.ink),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label.toUpperCase(), style: AppType.over.s(8.5).c(p.inkFaint)),
        ],
      ),
    );
  }
}
