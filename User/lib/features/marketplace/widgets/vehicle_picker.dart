import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/widgets/g_field.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/models/entities.dart';

/// Which car the part is for.
///
/// The customer's own vehicles come first as chips, because that is the
/// answer nine times out of ten. "Another vehicle" is always offered too — a
/// person buys a part for a car they do not own yet, or for a relative's, and
/// a picker that only knew about their own garage would simply block them.
class VehiclePicker extends StatelessWidget {
  const VehiclePicker({
    super.key,
    required this.vehicles,
    required this.selected,
    required this.other,
    required this.otherController,
    required this.onSelect,
    required this.onOther,
    this.onOtherChanged,
    this.label = 'Which vehicle',
  });

  final List<Vehicle> vehicles;
  final Vehicle? selected;

  /// True when "Another vehicle" is chosen and the free-text field is live.
  final bool other;
  final TextEditingController otherController;

  final ValueChanged<Vehicle> onSelect;
  final VoidCallback onOther;
  final ValueChanged<String>? onOtherChanged;
  final String label;

  static String describe(Vehicle v) =>
      [v.brand, v.model, if ((v.variant ?? '').isNotEmpty) v.variant!]
          .join(' ');

  @override
  Widget build(BuildContext context) {
    final p = context.c;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppType.labelM.c(p.ink)),
        const SizedBox(height: Gap.md),
        Wrap(
          spacing: Gap.sm,
          runSpacing: Gap.sm,
          children: [
            for (final v in vehicles)
              _Chip(
                label: describe(v),
                sub: v.regNumber,
                on: !other && selected?.id == v.id,
                onTap: () => onSelect(v),
              ),
            _Chip(
              label: 'Another vehicle',
              on: other,
              onTap: onOther,
            ),
          ],
        ),
        if (other) ...[
          const SizedBox(height: Gap.md),
          GField(
            hint: 'Make, model and year — Maruti Swift 2018',
            controller: otherController,
            onChanged: onOtherChanged,
            textCapitalization: TextCapitalization.words,
          ),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.on,
    required this.onTap,
    this.sub,
  });

  final String label;
  final String? sub;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Pressable(
      onTap: onTap,
      scale: 0.97,
      child: AnimatedContainer(
        duration: Motion.fast,
        padding: const EdgeInsets.symmetric(
            horizontal: Gap.lg, vertical: Gap.md),
        decoration: BoxDecoration(
          color: on ? p.accent : p.surface,
          borderRadius: R.rMd,
          border: Border.all(color: on ? p.accent : p.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: AppType.labelM.c(on ? p.onAccent : p.ink)),
            if (sub != null && sub!.isNotEmpty) ...[
              const SizedBox(height: Gap.xxs),
              Text(
                sub!,
                style: AppType.labelS.c(
                    on ? p.onAccent.withValues(alpha: 0.8) : p.inkFaint),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
