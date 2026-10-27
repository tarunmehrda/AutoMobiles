import 'package:flutter/material.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/vehicle_art.dart';
import '../../../data/models/entities.dart';
import '../../../data/models/enums.dart';
import '../widgets/damage_sheet.dart';
import '../widgets/vehicle_blueprint.dart';
import '../widgets/vehicle_parts.dart';

/// What the counter calls a kind of damage.
///
/// The enum's own label says "Break" for [DentSeverity.crack]; the
/// workshop's intake sheet — and the customer standing at it — says
/// "Broken", so that is what this step says.
String damageName(DentSeverity s) =>
    s == DentSeverity.crack ? 'Broken'.tr : s.label;

/// The face of the vehicle a mark is on, if it can be told.
///
/// A mark pinned to a component knows exactly. A mark painted freehand only
/// knows the drawing it was painted on, and the side drawing serves both
/// flanks — so a side stroke is left unplaced rather than guessed onto one.
VehicleArea? areaOfMark(DentMark m) {
  final part = partOf(m.part);
  if (part != null) return part.area;
  final dot = m.view.indexOf('.');
  final view = dot < 0 ? m.view : m.view.substring(dot + 1);
  return switch (view) {
    'front' => VehicleArea.front,
    'rear' => VehicleArea.rear,
    'top' => VehicleArea.roof,
    _ => null,
  };
}

/// "Rear Right Door — Dent": what the mark is on, then what it is.
String markLine(DentMark m) {
  final on = m.label.trim().isNotEmpty
      ? m.label.trim()
      : partOf(m.part)?.name ??
            areaOfMark(m)?.label(VehicleKind.fourWheeler) ??
            'Marked on the drawing'.tr;
  return '$on — ${damageName(m.severity)}';
}

/// The colour key, as it is printed on the workshop's own intake sheet.
class DamageLegend extends StatelessWidget {
  const DamageLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Wrap(
      spacing: Gap.md,
      runSpacing: Gap.sm,
      children: [
        for (final s in DentSeverity.values)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 12,
                width: 12,
                decoration: BoxDecoration(
                  color: dentColor(p, s),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(damageName(s), style: AppType.labelM.c(p.inkSoft)),
            ],
          ),
      ],
    );
  }
}

/// The vehicle with a tally under it of where it has been marked.
///
/// The drawing itself lives on the marking page; here it is a reminder of
/// which body is being marked up, and the tiles under it answer "did we look
/// at the roof?" at a glance — an area with nothing on it reads as empty
/// rather than being left off.
class DamageAreaMap extends StatelessWidget {
  const DamageAreaMap({
    super.key,
    required this.marks,
    required this.shape,
    required this.onTap,
    this.onArea,
  });

  final List<DentMark> marks;
  final VehicleShape shape;
  final VoidCallback onTap;

  /// Opens the marking page on the area tapped, rather than on the default.
  final ValueChanged<VehicleArea>? onArea;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final kind = shape.sheet;
    final counts = <VehicleArea, List<DentMark>>{};
    for (final m in marks) {
      final a = areaOfMark(m);
      if (a != null) (counts[a] ??= []).add(m);
    }

    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: Container(
        padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, Gap.md),
        decoration: BoxDecoration(
          color: p.surfaceAlt,
          borderRadius: R.all(R.lg),
          border: Border.all(color: p.line),
        ),
        child: Column(
          children: [
            VehicleArt(
              shape: shape,
              height: 92,
              animate: false,
              tint: p.inkFaint,
            ),
            const SizedBox(height: Gap.md),
            Wrap(
              spacing: Gap.sm,
              runSpacing: Gap.sm,
              alignment: WrapAlignment.center,
              children: [
                for (final a in VehicleArea.values)
                  Pressable(
                    onTap: onArea == null ? onTap : () => onArea!(a),
                    scale: 0.94,
                    child: _AreaTile(
                      label: a.label(kind),
                      icon: a.icon,
                      marks: counts[a] ?? const [],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AreaTile extends StatelessWidget {
  const _AreaTile({
    required this.label,
    required this.icon,
    required this.marks,
  });

  final String label;
  final IconData icon;
  final List<DentMark> marks;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final hit = marks.isNotEmpty;
    // The tile takes the colour of its worst-looking mark — the first one
    // recorded — so a red tile is a scratch somewhere on that face.
    final tint = hit ? dentColor(p, marks.first.severity) : p.inkFaint;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.sm + 2, vertical: 6),
      decoration: BoxDecoration(
        color: hit ? tint.withValues(alpha: 0.12) : p.surface,
        borderRadius: R.all(R.pill),
        border: Border.all(
          color: hit ? tint.withValues(alpha: 0.6) : p.lineSoft,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: hit ? p.ink : p.inkFaint),
          const SizedBox(width: 4),
          Text(label, style: AppType.labelS.s(11).c(hit ? p.ink : p.inkMuted)),
          if (hit) ...[
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: tint,
                borderRadius: R.all(R.pill),
              ),
              child: Text(
                '${marks.length}',
                style: AppType.labelS.s(10).c(Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Every mark as a line of text, each with its own way off.
class DamageMarkList extends StatelessWidget {
  const DamageMarkList({
    super.key,
    required this.marks,
    required this.onRemove,
  });

  final List<DentMark> marks;
  final ValueChanged<DentMark> onRemove;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: R.all(R.md),
        border: Border.all(color: p.line),
      ),
      child: Column(
        children: [
          for (final m in marks)
            Container(
              padding: const EdgeInsets.only(left: Gap.md),
              decoration: BoxDecoration(
                border: m == marks.last
                    ? null
                    : Border(bottom: BorderSide(color: p.lineSoft)),
              ),
              child: Row(
                children: [
                  Container(
                    height: 10,
                    width: 10,
                    decoration: BoxDecoration(
                      color: dentColor(p, m.severity),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          markLine(m),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.labelM.c(p.ink),
                        ),
                        if (m.note.trim().isNotEmpty)
                          Text(
                            m.note.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.bodyS.s(11).c(p.inkMuted),
                          ),
                      ],
                    ),
                  ),
                  Pressable(
                    onTap: () => onRemove(m),
                    scale: 0.85,
                    child: SizedBox(
                      height: 44,
                      width: 44,
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: p.inkFaint,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
