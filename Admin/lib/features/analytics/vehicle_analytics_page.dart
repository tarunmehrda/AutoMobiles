import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/anim/entrance.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/decor.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_field.dart';
import '../../core/widgets/g_art.dart';
import '../../core/widgets/g_state.dart';
import '../../core/widgets/g_surface.dart';
import '../../data/models/entities.dart';
import '../../data/models/enums.dart';
import '../../state/providers.dart';

enum _Window { month, quarter, year, all }

extension on _Window {
  String get label => switch (this) {
    _Window.month => '30 days'.tr,
    _Window.quarter => '90 days'.tr,
    _Window.year => '1 year'.tr,
    _Window.all => 'All time'.tr,
  };

  int? get days => switch (this) {
    _Window.month => 30,
    _Window.quarter => 90,
    _Window.year => 365,
    _Window.all => null,
  };
}

/// What came through the gate: how many vehicles, which makes, how they are
/// fuelled, and who comes back.
class VehicleAnalyticsPage extends ConsumerStatefulWidget {
  const VehicleAnalyticsPage({super.key});

  @override
  ConsumerState<VehicleAnalyticsPage> createState() =>
      _VehicleAnalyticsPageState();
}

class _VehicleAnalyticsPageState extends ConsumerState<VehicleAnalyticsPage> {
  _Window _window = _Window.quarter;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final data = ref.watch(adminDataProvider);

    final days = _window.days;
    final from = days == null
        ? DateTime(2000)
        : DateTime.now().subtract(Duration(days: days));

    final cards = data.jobCards
        .where((j) => !j.createdAt.isBefore(from))
        .toList();

    // Distinct vehicles, and how many of them came more than once.
    final visitsByVehicle = <String, int>{};
    for (final j in cards) {
      visitsByVehicle[j.vehicleId] = (visitsByVehicle[j.vehicleId] ?? 0) + 1;
    }
    final unique = visitsByVehicle.length;
    final repeat = visitsByVehicle.values.where((v) => v > 1).length;

    final byMake = <String, int>{};
    final byFuel = <String, int>{};
    for (final id in visitsByVehicle.keys) {
      final v = data.vehicleById(id);
      if (v == null) continue;
      final make = v.brand.isEmpty ? 'Unknown' : v.brand;
      byMake[make] = (byMake[make] ?? 0) + visitsByVehicle[id]!;
      byFuel[v.fuel.label] = (byFuel[v.fuel.label] ?? 0) + 1;
    }

    final makes = byMake.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final fuels = byFuel.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final kmValues = cards
        .where((j) => j.odometerKm > 0)
        .map((j) => j.odometerKm)
        .toList();
    final avgKm = kmValues.isEmpty
        ? 0
        : kmValues.reduce((a, b) => a + b) / kmValues.length;

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Vehicle Analytics'.tr,
        subtitle: 'Last {0}'.trf([_window.label.toLowerCase()]),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.h2),
        children: [
          GSegmented<_Window>(
            options: _Window.values,
            selected: _window,
            onSelect: (w) => setState(() => _window = w),
            labelOf: (w) => w.label,
          ),
          const SizedBox(height: Gap.lg),
          Entrance(
            child: Container(
              padding: const EdgeInsets.all(Gap.xl),
              decoration: BoxDecoration(
                gradient: p.inverseGradient,
                borderRadius: R.all(R.xl),
                boxShadow: Shadows.lifted(p),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: R.all(R.xl),
                      child: CustomPaint(
                        painter: BlueprintPainter(
                          color: p.onInverse,
                          opacity: 0.06,
                        ),
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VEHICLES IN'.tr,
                        style: AppType.over.c(
                          p.onInverse.withValues(alpha: 0.55),
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedCount(
                        value: cards.length.toDouble(),
                        builder: (context, v) => Text(
                          v.round().toString(),
                          style: AppType.d1.c(p.onInverse),
                        ),
                      ),
                      const SizedBox(height: Gap.lg),
                      Row(
                        children: [
                          Expanded(
                            child: _HeroStat(
                              label: 'Unique vehicles'.tr,
                              value: '$unique',
                            ),
                          ),
                          Expanded(
                            child: _HeroStat(
                              label: 'Came back'.tr,
                              value: '$repeat',
                              tint: p.volt,
                            ),
                          ),
                          Expanded(
                            child: _HeroStat(
                              label: 'Average odometer'.tr,
                              value: avgKm == 0 ? '—' : Fmt.km(avgKm.round()),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          GSectionHeader(
            title: 'Which makes come in'.tr,
            padding: EdgeInsets.fromLTRB(0, Gap.xxl, 0, Gap.md),
          ),
          if (makes.isEmpty)
            GEmptyState(
              compact: true,
              icon: Icons.directions_car_filled_rounded,
              title: 'Nothing in this window'.tr,
              art: Art.noData,
              message: 'Open a job card and the vehicle is counted here.'.tr,
            )
          else
            GCard(
              child: Column(
                children: [
                  for (final e in makes.take(6)) ...[
                    _Bar(
                      label: e.key,
                      count: e.value,
                      share: e.value / cards.length,
                      color: p.accent,
                    ),
                    if (e != makes.take(6).last) const SizedBox(height: Gap.md),
                  ],
                ],
              ),
            ),
          GSectionHeader(
            title: 'How they are fuelled'.tr,
            padding: EdgeInsets.fromLTRB(0, Gap.xxl, 0, Gap.md),
          ),
          if (fuels.isEmpty)
            Text('Nothing to split yet.'.tr, style: AppType.bodyS.c(p.inkFaint))
          else
            GCard(
              child: Column(
                children: [
                  for (final e in fuels) ...[
                    _Bar(
                      label: e.key,
                      count: e.value,
                      share: unique == 0 ? 0 : e.value / unique,
                      color: p.info,
                    ),
                    if (e != fuels.last) const SizedBox(height: Gap.md),
                  ],
                ],
              ),
            ),
          GSectionHeader(
            title: 'Most frequent visitors'.tr,
            padding: EdgeInsets.fromLTRB(0, Gap.xxl, 0, Gap.md),
          ),
          _TopVisitors(visits: visitsByVehicle),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value, this.tint});

  final String label;
  final String value;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppType.labelS.c(p.onInverse.withValues(alpha: 0.55)),
        ),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppType.money.c(tint ?? p.onInverse),
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.label,
    required this.count,
    required this.share,
    required this.color,
  });

  final String label;
  final int count;
  final double share;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.labelM.c(p.ink),
              ),
            ),
            Text('$count', style: AppType.moneyS.c(p.inkSoft)),
            const SizedBox(width: Gap.sm),
            SizedBox(
              width: 38,
              child: Text(
                '${(share * 100).round()}%',
                textAlign: TextAlign.right,
                style: AppType.labelS.c(p.inkFaint),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        GMeter(value: share.clamp(0, 1), color: color, height: 5),
      ],
    );
  }
}

class _TopVisitors extends ConsumerWidget {
  const _TopVisitors({required this.visits});

  final Map<String, int> visits;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final data = ref.watch(adminDataProvider);
    final rows = visits.entries.where((e) => e.value > 1).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (rows.isEmpty) {
      return Text(
        'No vehicle has been in twice yet.'.tr,
        style: AppType.bodyS.c(p.inkFaint),
      );
    }
    return GCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final e in rows.take(5))
            Builder(
              builder: (context) {
                final Vehicle? v = data.vehicleById(e.key);
                return GTile(
                  dense: true,
                  showChevron: false,
                  title: v == null ? 'Vehicle'.tr : Fmt.plate(v.regNo),
                  subtitle: v?.title,
                  leading: GAvatar(
                    initials: v == null ? '?' : Fmt.initials(v.brand),
                    size: 34,
                    tone: GTone.neutral,
                  ),
                  trailing: GPill(
                    label: '{0} visits'.trf([e.value]),
                    tone: GTone.accent,
                    compact: true,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
