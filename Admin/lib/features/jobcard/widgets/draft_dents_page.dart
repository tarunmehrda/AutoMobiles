import 'package:flutter/material.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/widgets/g_appbar.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/models/entities.dart';
import '../../../data/models/enums.dart';
import 'component_sheet.dart';
import 'damage_sheet.dart';
import 'vehicle_blueprint.dart';
import 'vehicle_parts.dart';

/// The damage sheet as the create wizard needs it: marks live in a local list
/// and come back on pop, because there is no card to attach them to yet.
class DraftDentsPage extends StatefulWidget {
  const DraftDentsPage({
    super.key,
    required this.marks,
    this.shape = VehicleShape.fourWheeler,
  });

  final List<DentMark> marks;

  /// What the counter said the vehicle is, so the sheet opens on the right
  /// body instead of on a guess made from the marque.
  final VehicleShape shape;

  @override
  State<DraftDentsPage> createState() => _DraftDentsPageState();
}

class _DraftDentsPageState extends State<DraftDentsPage> {
  late List<DentMark> _marks;
  late VehicleKind _kind;
  DentSeverity _severity = DentSeverity.dent;
  bool _erasing = false;

  @override
  void initState() {
    super.initState();
    _marks = [...widget.marks];
    _kind = kindOfMarks(_marks) ?? widget.shape.sheet;
  }

  @override
  Widget build(BuildContext context) {
    return DentScaffold(
      title: 'Dent Marks'.tr,
      marks: _marks,
      kind: _kind,
      severity: _severity,
      erasing: _erasing,
      onKind: (k) => setState(() => _kind = k),
      onSeverity: (s) => setState(() {
        _severity = s;
        _erasing = false;
      }),
      onErase: () => setState(() => _erasing = !_erasing),
      onPainted: (m) => setState(() => _marks = [..._marks, m]),
      onErased: (ids) => setState(
        () => _marks = [..._marks.where((m) => !ids.contains(m.id))],
      ),
      onDiscard: () => Navigator.of(context).pop(),
      onSave: () => Navigator.of(context).pop(_marks),
    );
  }
}

/// Which body a set of marks was drawn on, if they agree on one.
VehicleKind? kindOfMarks(List<DentMark> marks) {
  for (final m in marks) {
    final dot = m.view.indexOf('.');
    if (dot > 0) return VehicleKindX.parse(m.view.substring(0, dot));
  }
  return null;
}

/// How damage is being put on the sheet.
enum DentMode {
  /// Tap the panel it is on. Names the part, which is what gets ordered.
  part,

  /// Paint over it. For damage that crosses panels, or that has no name.
  brush,
}

/// The shared chrome: the kind strip, the body picker, the sheet and the
/// discard/keep pair. Both the wizard's draft page and the live panel are this
/// screen with a different place to put the marks.
///
/// Which of the two ways in is on show, and which face of the body is open,
/// are the screen's own business — nothing outside it needs to know, and the
/// two callers would only have to carry the same state twice.
class DentScaffold extends StatefulWidget {
  const DentScaffold({
    super.key,
    required this.title,
    required this.marks,
    required this.kind,
    required this.severity,
    required this.erasing,
    required this.onKind,
    required this.onSeverity,
    required this.onErase,
    required this.onPainted,
    required this.onErased,
    required this.onDiscard,
    required this.onSave,
  });

  final String title;
  final List<DentMark> marks;
  final VehicleKind kind;
  final DentSeverity severity;
  final bool erasing;
  final ValueChanged<VehicleKind> onKind;
  final ValueChanged<DentSeverity> onSeverity;
  final VoidCallback onErase;
  final void Function(DentMark) onPainted;
  final void Function(Set<String>) onErased;
  final VoidCallback onDiscard;
  final VoidCallback onSave;

  @override
  State<DentScaffold> createState() => _DentScaffoldState();
}

class _DentScaffoldState extends State<DentScaffold> {
  DentMode _mode = DentMode.part;
  VehicleArea _area = VehicleArea.driver;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final marks = widget.marks;
    final kind = widget.kind;
    final erasing = widget.erasing;
    final onSheet = marks
        .where((m) => m.view.startsWith('${kind.name}.'))
        .length;

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: widget.title,
        subtitle: '{0} on this body · {1} in all'.trf([onSheet, marks.length]),
        onBack: widget.onDiscard,
        actions: [
          Pressable(
            onTap: () => setState(
              () => _mode = _mode == DentMode.part
                  ? DentMode.brush
                  : DentMode.part,
            ),
            scale: 0.9,
            child: Container(
              margin: const EdgeInsets.only(right: Gap.sm),
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.md,
                vertical: Gap.sm,
              ),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: R.all(R.pill),
                border: Border.all(color: p.line),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _mode == DentMode.part
                        ? Icons.touch_app_rounded
                        : Icons.brush_rounded,
                    size: 16,
                    color: p.accentInk,
                  ),
                  const SizedBox(width: Gap.xs),
                  Text(
                    _mode == DentMode.part ? 'Tap part'.tr : 'Brush'.tr,
                    style: AppType.labelS.c(p.inkSoft),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // --- what the mark is recorded as -----------------------------
          Container(
            margin: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.sm),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: R.all(R.sm),
              border: Border.all(color: p.line),
            ),
            child: Row(
              children: [
                for (final s in DentSeverity.values)
                  Expanded(
                    child: _Cell(
                      label: s.label,
                      selected: !erasing && widget.severity == s,
                      fill: dentColor(p, s),
                      onTap: () => widget.onSeverity(s),
                    ),
                  ),
                Expanded(
                  child: _Cell(
                    label: erasing ? 'Erase On'.tr : 'Erase Off'.tr,
                    selected: erasing,
                    fill: p.danger,
                    onTap: widget.onErase,
                  ),
                ),
              ],
            ),
          ),

          // --- which body ------------------------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.sm),
            child: Row(
              children: [
                for (final k in VehicleKind.values)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: Gap.sm),
                      child: Pressable(
                        onTap: () => widget.onKind(k),
                        scale: 0.95,
                        child: AnimatedContainer(
                          duration: Motion.fast,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: kind == k ? p.ink : p.surface,
                            borderRadius: R.all(R.pill),
                            border: Border.all(
                              color: kind == k ? p.ink : p.line,
                            ),
                          ),
                          child: Text(
                            k.label,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.labelS.c(
                              kind == k
                                  ? (p.isDark ? p.canvas : Colors.white)
                                  : p.inkSoft,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // --- the sheet ---------------------------------------------------
          if (_mode == DentMode.part)
            Expanded(
              child: ComponentSheet(
                kind: kind,
                area: _area,
                marks: marks,
                severity: widget.severity,
                erasing: erasing,
                onArea: (a) => setState(() => _area = a),
                onPinned: widget.onPainted,
                onErased: widget.onErased,
              ),
            )
          else ...[
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
                  child: DamageSheet(
                    kind: kind,
                    marks: marks,
                    severity: widget.severity,
                    erasing: erasing,
                    onPainted: widget.onPainted,
                    onErased: widget.onErased,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, 0),
              child: Text(
                erasing
                    ? 'Drag over a mark to rub it out.'.tr
                    : 'Draw over the damage on whichever view shows it.'.tr,
                textAlign: TextAlign.center,
                style: AppType.bodyS.c(p.inkFaint),
              ),
            ),
          ],

          // --- discard / keep ------------------------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.h1, Gap.md, Gap.h1, Gap.lg),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Pressable(
                  onTap: widget.onDiscard,
                  scale: 0.9,
                  child: Icon(Icons.close_rounded, size: 44, color: p.danger),
                ),
                Pressable(
                  onTap: widget.onSave,
                  scale: 0.9,
                  child: Container(
                    height: 62,
                    width: 62,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: p.danger,
                      shape: BoxShape.circle,
                      boxShadow: Shadows.soft(p),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 34,
                      color: Colors.white,
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

class _Cell extends StatelessWidget {
  const _Cell({
    required this.label,
    required this.selected,
    required this.fill,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color fill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Pressable(
      onTap: onTap,
      scale: 0.96,
      child: AnimatedContainer(
        duration: Motion.fast,
        padding: const EdgeInsets.symmetric(vertical: Gap.md, horizontal: 2),
        color: selected ? fill.withValues(alpha: 0.92) : Colors.transparent,
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppType.labelS.c(
            selected ? const Color(0xFF17202B) : p.inkSoft,
          ),
        ),
      ),
    );
  }
}
