import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/widgets/g_feedback.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/repo/platform_gateway.dart';

/// What the partner register is narrowed to: active (not blocked) or not,
/// then State → District → PIN code. Null means "any".
@immutable
class PartnerFilter {
  const PartnerFilter({
    this.active = true,
    this.state,
    this.district,
    this.pin,
  });

  final bool active;
  final String? state;
  final String? district;
  final String? pin;

  bool get narrowed => state != null || district != null || pin != null;

  static bool _same(String a, String b) =>
      a.trim().toLowerCase() == b.trim().toLowerCase();

  bool _inPlace(RegisteredGarage g, {bool upToDistrict = false}) =>
      (state == null || _same(g.state, state!)) &&
      (upToDistrict || district == null || _same(g.districtOrCity, district!));

  /// The partners that pass every part of the filter.
  List<RegisteredGarage> apply(List<RegisteredGarage> all) => [
        for (final g in all)
          if (g.blocked != active &&
              _inPlace(g) &&
              (pin == null || g.pin.trim() == pin))
            g,
      ];

  /// The choices for each dropdown, drawn from the partners on the
  /// selected side (active or not) and inside the levels above it, so a
  /// choice never leads to an empty list. Each is value → partner count.
  Map<String, int> states(List<RegisteredGarage> all) =>
      _options(all, (g) => g.state, (g) => true);

  Map<String, int> districts(List<RegisteredGarage> all) =>
      _options(all, (g) => g.districtOrCity,
          (g) => state == null || _same(g.state, state!));

  Map<String, int> pins(List<RegisteredGarage> all) =>
      _options(all, (g) => g.pin, (g) => _inPlace(g));

  Map<String, int> _options(
    List<RegisteredGarage> all,
    String Function(RegisteredGarage) key,
    bool Function(RegisteredGarage) within,
  ) {
    // Keyed case-blind, shown in the first spelling met: "chandigarh" and
    // "Chandigarh" are one place, not two rows.
    final shown = <String, String>{};
    final counts = <String, int>{};
    for (final g in all) {
      if (g.blocked == active || !within(g)) continue;
      final v = key(g).trim();
      if (v.isEmpty) continue;
      final k = v.toLowerCase();
      shown.putIfAbsent(k, () => v);
      counts[k] = (counts[k] ?? 0) + 1;
    }
    final keys = shown.keys.toList()..sort();
    return {for (final k in keys) shown[k]!: counts[k]!};
  }

  PartnerFilter copyWith({
    bool? active,
    String? Function()? state,
    String? Function()? district,
    String? Function()? pin,
  }) =>
      PartnerFilter(
        active: active ?? this.active,
        state: state != null ? state() : this.state,
        district: district != null ? district() : this.district,
        pin: pin != null ? pin() : this.pin,
      );
}

/// The strip under the Platform tabs: an Active / Non-active switch with
/// counts, and the three place filters.
class PartnerFilterBar extends StatelessWidget {
  const PartnerFilterBar({
    super.key,
    required this.garages,
    required this.filter,
    required this.onChanged,
  });

  final List<RegisteredGarage> garages;
  final PartnerFilter filter;
  final ValueChanged<PartnerFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final blocked = garages.where((g) => g.blocked).length;
    final active = garages.length - blocked;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: R.all(R.pill),
              border: Border.all(color: p.line),
            ),
            child: Row(
              children: [
                _Segment(
                  label: 'Active',
                  count: active,
                  icon: Icons.check_circle_rounded,
                  on: filter.active,
                  onTap: () => onChanged(const PartnerFilter()),
                ),
                _Segment(
                  label: 'Non-active',
                  count: blocked,
                  icon: Icons.block_rounded,
                  on: !filter.active,
                  onTap: () =>
                      onChanged(const PartnerFilter(active: false)),
                ),
              ],
            ),
          ),
          const SizedBox(height: Gap.sm),
          Row(
            children: [
              Expanded(
                child: _Dropdown(
                  label: 'State',
                  value: filter.state,
                  onTap: () => _pick(
                    context,
                    title: 'State',
                    options: filter.states(garages),
                    current: filter.state,
                    apply: (v) => filter.copyWith(
                      state: () => v,
                      district: () => null,
                      pin: () => null,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Gap.xs),
              Expanded(
                child: _Dropdown(
                  label: 'District',
                  value: filter.district,
                  onTap: () => _pick(
                    context,
                    title: 'District',
                    subtitle: filter.state,
                    options: filter.districts(garages),
                    current: filter.district,
                    apply: (v) => filter.copyWith(
                      district: () => v,
                      pin: () => null,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Gap.xs),
              Expanded(
                child: _Dropdown(
                  label: 'PIN code',
                  value: filter.pin,
                  onTap: () => _pick(
                    context,
                    title: 'PIN code',
                    subtitle: filter.district ?? filter.state,
                    options: filter.pins(garages),
                    current: filter.pin,
                    apply: (v) => filter.copyWith(pin: () => v),
                  ),
                ),
              ),
            ],
          ),
          if (filter.narrowed)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () =>
                    onChanged(PartnerFilter(active: filter.active)),
                style: TextButton.styleFrom(
                  foregroundColor: p.accentInk,
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.close_rounded, size: 16),
                label: Text('Clear filters', style: AppType.labelS),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pick(
    BuildContext context, {
    required String title,
    String? subtitle,
    required Map<String, int> options,
    required String? current,
    required PartnerFilter Function(String?) apply,
  }) async {
    // Wrapped so "All" (null) and a dismissed sheet can be told apart.
    final picked = await GFeedback.sheet<({String? value})>(
      context,
      title: title,
      subtitle: subtitle,
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.fromLTRB(
          Gap.page,
          Gap.lg,
          Gap.page,
          Gap.lg + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          GOptionRow(
            label: 'All',
            subtitle: '${options.values.fold(0, (a, b) => a + b)} partners',
            selected: current == null,
            onTap: () => Navigator.of(context).pop((value: null)),
          ),
          if (options.isEmpty)
            Padding(
              padding: const EdgeInsets.all(Gap.lg),
              child: Text(
                'No partner has filled this in yet.',
                textAlign: TextAlign.center,
                style: AppType.bodyS.c(context.c.inkMuted),
              ),
            ),
          for (final e in options.entries)
            GOptionRow(
              label: e.key,
              subtitle: '${e.value} ${e.value == 1 ? 'partner' : 'partners'}',
              selected: current != null &&
                  current.toLowerCase() == e.key.toLowerCase(),
              onTap: () => Navigator.of(context).pop((value: e.key)),
            ),
        ],
      ),
    );
    if (picked == null) return;
    onChanged(apply(picked.value));
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.count,
    required this.icon,
    required this.on,
    required this.onTap,
  });

  final String label;
  final int count;
  final IconData icon;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final fg = on ? p.onAccent : p.inkMuted;
    return Expanded(
      child: Pressable(
        onTap: onTap,
        scale: 0.98,
        child: AnimatedContainer(
          duration: Motion.fast,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? p.accent : Colors.transparent,
            borderRadius: R.all(R.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: Gap.xs),
              Text(label, style: AppType.labelM.c(fg)),
              const SizedBox(width: Gap.xs),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: 1),
                decoration: BoxDecoration(
                  color: on
                      ? p.onAccent.withValues(alpha: 0.22)
                      : p.surfaceSunken,
                  borderRadius: R.all(R.pill),
                ),
                child: Text('$count', style: AppType.labelS.c(fg)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final set = value != null;
    return Pressable(
      onTap: onTap,
      scale: 0.97,
      child: AnimatedContainer(
        duration: Motion.fast,
        height: 48,
        padding: const EdgeInsets.fromLTRB(Gap.md, Gap.xs, Gap.xs, Gap.xs),
        decoration: BoxDecoration(
          color: set ? p.accentSoft : p.surface,
          borderRadius: R.rMd,
          border: Border.all(color: set ? p.accent : p.line),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppType.labelS.c(set ? p.accentInk : p.inkMuted),
                  ),
                  Text(
                    value ?? 'All',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.labelM.c(p.ink),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: set ? p.accentInk : p.inkMuted,
            ),
          ],
        ),
      ),
    );
  }
}
