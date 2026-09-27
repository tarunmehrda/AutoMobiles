import 'package:flutter/material.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/widgets/g_field.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/models/entities.dart';
import '../../../data/models/enums.dart';
import '../../../state/admin_state.dart';
import 'damage_sheet.dart';
import 'vehicle_blueprint.dart';
import 'vehicle_parts.dart';

/// Which drawing a face of the vehicle is marked up on.
BlueprintView? viewFor(VehicleKind kind, VehicleArea area) {
  final key = area.view;
  if (key == null) return null;
  for (final v in kBlueprints[kind] ?? const <BlueprintView>[]) {
    if (v.key == key) return v;
  }
  return null;
}

/// How a mark taken on [area] records which drawing it is on. The inside of
/// the vehicle has no drawing, so it gets a name of its own that no view
/// answers to and is therefore never plotted on the sheet.
String areaViewId(VehicleKind kind, VehicleArea area) {
  final v = viewFor(kind, area);
  return v == null ? '${kind.name}.interior' : viewId(kind, v);
}

/// Damage recorded by tapping the component it is on.
///
/// The counter is handed a drawing of one face of the vehicle with a dot over
/// every panel, and taps the one that is damaged. That names the part, which
/// is what the estimate is actually written against — a brush stroke over a
/// door says where the damage is but not what has to be ordered.
class ComponentSheet extends StatefulWidget {
  const ComponentSheet({
    super.key,
    required this.kind,
    required this.area,
    required this.marks,
    required this.severity,
    required this.erasing,
    required this.onArea,
    required this.onPinned,
    required this.onErased,
  });

  final VehicleKind kind;
  final VehicleArea area;

  /// Every mark on the card. Ones on another body or another face are counted
  /// but not plotted.
  final List<DentMark> marks;

  final DentSeverity severity;

  /// Whether a tap rubs a mark out instead of pinning one.
  final bool erasing;

  final ValueChanged<VehicleArea> onArea;
  final void Function(DentMark) onPinned;
  final void Function(Set<String> ids) onErased;

  @override
  State<ComponentSheet> createState() => _ComponentSheetState();
}

class _ComponentSheetState extends State<ComponentSheet> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// The mark on a component, if it already carries one.
  DentMark? _markOn(VehiclePart part) {
    final id = partId(widget.kind, part);
    for (final m in widget.marks) {
      if (m.part == id) return m;
    }
    return null;
  }

  /// Tapping a panel pins damage to it; tapping one that already carries a
  /// mark takes it off again, so a mis-tap is undone the same way it was made.
  void _tap(VehiclePart part) {
    final existing = _markOn(part);
    if (existing != null) return widget.onErased({existing.id});
    if (widget.erasing) return;

    final area = part.area;
    // Stored in the drawing's own space. The passenger's flank is the side
    // drawing flipped, so the tap has to be flipped back before it is kept or
    // the mark lands on the wrong end of the vehicle on the printed sheet.
    final mirrored = areaMirrored(widget.kind, area);
    widget.onPinned(
      DentMark.spot(
        id: newId('d'),
        view: areaViewId(widget.kind, area),
        part: partId(widget.kind, part),
        label: part.qualified(widget.kind),
        at: Offset(mirrored ? 1 - part.x : part.x, part.y),
        severity: widget.severity,
      ),
    );
  }

  /// How many marks sit on one face of the body.
  int _countOn(VehicleArea area) {
    final prefix = '${widget.kind.name}.${area.name}.';
    return widget.marks.where((m) => m.part.startsWith(prefix)).length;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final parts = partsFor(widget.kind, widget.area);
    final hits = _query.isEmpty ? const <VehiclePart>[] : _hits();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.erasing
                    ? 'Tap a marked component to rub it out'.tr
                    : 'Tap the component where you’d like to capture damage'.tr,
                style: AppType.bodyM.c(p.ink).w(FontWeight.w600),
              ),
              const SizedBox(height: Gap.sm),
              Text(
                widget.area.heading(widget.kind),
                style: AppType.over.s(10).c(p.inkFaint),
              ),
            ],
          ),
        ),

        // --- the face on show ------------------------------------------------
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.page),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: R.all(R.lg),
                border: Border.all(color: p.line),
              ),
              padding: const EdgeInsets.all(Gap.md),
              child: widget.area == VehicleArea.interior
                  ? _InsideList(
                      parts: parts,
                      markOn: _markOn,
                      onTap: _tap,
                      palette: p,
                    )
                  : _Diagram(
                      kind: widget.kind,
                      area: widget.area,
                      parts: parts,
                      markOn: _markOn,
                      onTap: _tap,
                      palette: p,
                    ),
            ),
          ),
        ),

        // --- find it by name instead ----------------------------------------
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Gap.page,
            Gap.md,
            Gap.page,
            Gap.sm,
          ),
          child: GSearchBar(
            hint: 'Search component...'.tr,
            controller: _search,
            onChanged: (v) => setState(() => _query = v.trim()),
            onClear: () => setState(() {
              _search.clear();
              _query = '';
            }),
          ),
        ),

        if (_query.isNotEmpty)
          SizedBox(
            height: 132,
            child: hits.isEmpty
                ? Center(
                    child: Text(
                      'No component called “{0}”'.trf([_query]),
                      style: AppType.bodyS.c(p.inkFaint),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: Gap.page),
                    itemCount: hits.length,
                    itemBuilder: (context, i) => _Hit(
                      part: hits[i],
                      kind: widget.kind,
                      marked: _markOn(hits[i]) != null,
                      onTap: () {
                        widget.onArea(hits[i].area);
                        _tap(hits[i]);
                        setState(() {
                          _search.clear();
                          _query = '';
                        });
                        FocusScope.of(context).unfocus();
                      },
                    ),
                  ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.page),
            child: _AreaGrid(
              kind: widget.kind,
              selected: widget.area,
              count: _countOn,
              onArea: widget.onArea,
            ),
          ),
      ],
    );
  }

  /// The search looks over the whole body, not just the face on screen, so a
  /// part can be found without knowing which side it was filed under.
  List<VehiclePart> _hits() {
    final q = _query.toLowerCase();
    return [
      for (final part in allPartsFor(widget.kind))
        if (part.name.toLowerCase().contains(q) ||
            part.id.replaceAll('_', ' ').contains(q) ||
            part.area.label(widget.kind).toLowerCase().contains(q))
          part,
    ];
  }
}

/// The drawing of one face with a dot over every panel on it.
class _Diagram extends StatelessWidget {
  const _Diagram({
    required this.kind,
    required this.area,
    required this.parts,
    required this.markOn,
    required this.onTap,
    required this.palette,
  });

  final VehicleKind kind;
  final VehicleArea area;
  final List<VehiclePart> parts;
  final DentMark? Function(VehiclePart) markOn;
  final ValueChanged<VehiclePart> onTap;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final view = viewFor(kind, area);
    if (view == null) return const SizedBox.shrink();
    final mirrored = areaMirrored(kind, area);

    return Center(
      child: AspectRatio(
        aspectRatio: view.aspect,
        child: LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth;
            final h = box.maxHeight;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                // Only the line art is flipped. The dots are placed from the
                // flipped coordinate, so their labels stay the right way round.
                Positioned.fill(
                  child: Transform(
                    alignment: Alignment.center,
                    transform: mirrored
                        ? Matrix4.diagonal3Values(-1, 1, 1)
                        : Matrix4.identity(),
                    child: view.asset != null
                        ? Image.asset(view.asset!, fit: BoxFit.fill)
                        : CustomPaint(
                            painter: BlueprintPainter(
                              view: view,
                              line: palette.inkSoft,
                            ),
                          ),
                  ),
                ),
                for (final part in parts)
                  Positioned(
                    left: (mirrored ? 1 - part.x : part.x) * w - 13,
                    top: part.y * h - 13,
                    child: _Dot(
                      part: part,
                      mark: markOn(part),
                      palette: palette,
                      onTap: () => onTap(part),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// One hotspot. Empty until something is recorded on it, then it fills with
/// the colour that kind of damage is drawn in everywhere else.
class _Dot extends StatelessWidget {
  const _Dot({
    required this.part,
    required this.mark,
    required this.palette,
    required this.onTap,
  });

  final VehiclePart part;
  final DentMark? mark;
  final AppPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = mark;
    final fill = m == null ? null : dentColor(palette, m.severity);
    return Tooltip(
      message: part.name,
      child: Pressable(
        onTap: onTap,
        scale: 0.85,
        child: SizedBox(
          width: 26,
          height: 26,
          child: Center(
            child: AnimatedContainer(
              duration: Motion.fast,
              width: m == null ? 15 : 21,
              height: m == null ? 15 : 21,
              decoration: BoxDecoration(
                color: fill ?? palette.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: fill ?? palette.accent,
                  width: m == null ? 2.2 : 2.6,
                ),
                boxShadow: m == null ? null : Shadows.soft(palette),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The inside of the vehicle, which has no drawing, listed as chips instead.
class _InsideList extends StatelessWidget {
  const _InsideList({
    required this.parts,
    required this.markOn,
    required this.onTap,
    required this.palette,
  });

  final List<VehiclePart> parts;
  final DentMark? Function(VehiclePart) markOn;
  final ValueChanged<VehiclePart> onTap;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Wrap(
        spacing: Gap.sm,
        runSpacing: Gap.sm,
        children: [
          for (final part in parts)
            Builder(
              builder: (context) {
                final m = markOn(part);
                final fill = m == null ? null : dentColor(palette, m.severity);
                return Pressable(
                  onTap: () => onTap(part),
                  scale: 0.95,
                  child: AnimatedContainer(
                    duration: Motion.fast,
                    padding: const EdgeInsets.symmetric(
                      horizontal: Gap.md,
                      vertical: Gap.sm,
                    ),
                    decoration: BoxDecoration(
                      color: fill?.withValues(alpha: 0.9) ?? palette.surfaceAlt,
                      borderRadius: R.all(R.pill),
                      border: Border.all(color: fill ?? palette.line),
                    ),
                    child: Text(
                      part.name,
                      style: AppType.labelS.c(
                        fill == null
                            ? palette.inkSoft
                            : const Color(0xFF17202B),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// The six faces, each drawn as the view it opens on so the card shows what
/// tapping it will give you.
class _AreaGrid extends StatelessWidget {
  const _AreaGrid({
    required this.kind,
    required this.selected,
    required this.count,
    required this.onArea,
  });

  final VehicleKind kind;
  final VehicleArea selected;
  final int Function(VehicleArea) count;
  final ValueChanged<VehicleArea> onArea;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    const rows = [
      [VehicleArea.front, VehicleArea.driver, VehicleArea.passenger],
      [VehicleArea.rear, VehicleArea.roof, VehicleArea.interior],
    ];

    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.sm),
            child: Row(
              children: [
                for (final area in row)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Gap.xs),
                      child: _AreaCard(
                        kind: kind,
                        area: area,
                        selected: area == selected,
                        marks: count(area),
                        palette: p,
                        onTap: () => onArea(area),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _AreaCard extends StatelessWidget {
  const _AreaCard({
    required this.kind,
    required this.area,
    required this.selected,
    required this.marks,
    required this.palette,
    required this.onTap,
  });

  final VehicleKind kind;
  final VehicleArea area;
  final bool selected;
  final int marks;
  final AppPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final view = viewFor(kind, area);
    final mirrored = areaMirrored(kind, area);

    return Pressable(
      onTap: onTap,
      scale: 0.94,
      child: AnimatedContainer(
        duration: Motion.fast,
        padding: const EdgeInsets.symmetric(vertical: Gap.sm, horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? p.accentSoft : p.surface,
          borderRadius: R.all(R.md),
          border: Border.all(color: selected ? p.accent : p.line),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 30,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(
                    child: view == null
                        ? Icon(
                            area.icon,
                            size: 24,
                            color: selected ? p.accentInk : p.inkMuted,
                          )
                        : Transform(
                            alignment: Alignment.center,
                            transform: mirrored
                                ? Matrix4.diagonal3Values(-1, 1, 1)
                                : Matrix4.identity(),
                            child: AspectRatio(
                              aspectRatio: view.aspect,
                              child: CustomPaint(
                                painter: BlueprintPainter(
                                  view: view,
                                  line: selected ? p.accentInk : p.inkMuted,
                                ),
                              ),
                            ),
                          ),
                  ),
                  if (marks > 0)
                    Positioned(
                      right: -2,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: p.danger,
                          borderRadius: R.all(R.pill),
                        ),
                        child: Text(
                          '$marks',
                          style: AppType.labelS.s(9).c(Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Gap.xs),
            Text(
              area.label(kind).toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.over.s(8.5).c(selected ? p.accentInk : p.inkFaint),
            ),
          ],
        ),
      ),
    );
  }
}

/// One row of the search results.
class _Hit extends StatelessWidget {
  const _Hit({
    required this.part,
    required this.kind,
    required this.marked,
    required this.onTap,
  });

  final VehiclePart part;
  final VehicleKind kind;
  final bool marked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: Container(
        margin: const EdgeInsets.only(bottom: Gap.xs),
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.md,
          vertical: Gap.sm,
        ),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: R.all(R.sm),
          border: Border.all(color: marked ? p.danger : p.line),
        ),
        child: Row(
          children: [
            Icon(part.area.icon, size: 16, color: p.inkMuted),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Text(
                part.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.bodyS.c(p.ink),
              ),
            ),
            Text(
              part.area.label(kind),
              style: AppType.labelS.s(9).c(p.inkFaint),
            ),
            const SizedBox(width: Gap.sm),
            Icon(
              marked ? Icons.close_rounded : Icons.add_rounded,
              size: 16,
              color: marked ? p.danger : p.accent,
            ),
          ],
        ),
      ),
    );
  }
}
