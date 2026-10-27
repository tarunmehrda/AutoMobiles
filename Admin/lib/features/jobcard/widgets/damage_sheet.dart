import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../data/models/entities.dart';
import '../../../data/models/enums.dart';
import '../../../state/admin_state.dart';
import 'vehicle_blueprint.dart';

/// The colour a kind of damage is marked in, on screen and on the printed
/// copy. Kept in one place so the picker, the sheet and the summary list can
/// never drift apart.
///
/// The workshop's own key, as printed on its intake sheet: scratch red, dent
/// yellow, broken green, rust blue. Fixed rather than taken from the palette
/// so the key reads the same in dark mode and on paper.
Color dentColor(AppPalette p, DentSeverity s) => switch (s) {
  DentSeverity.scratch => const Color(0xFFE5484D),
  DentSeverity.dent => const Color(0xFFF2C744),
  DentSeverity.crack => const Color(0xFF30A46C),
  DentSeverity.rust => const Color(0xFF3E7BFA),
};

/// Every view of the vehicle on one sheet, painted on with a highlighter.
///
/// Damage is recorded by drawing over the panel it is on rather than dropping
/// a pin, because that is how it gets described at handover — a scrape along a
/// door, not a point on it. A stroke belongs to the view it was drawn on, so
/// the sheet never has to guess where a mark goes.
class DamageSheet extends StatefulWidget {
  const DamageSheet({
    super.key,
    required this.kind,
    required this.marks,
    required this.severity,
    required this.erasing,
    required this.onPainted,
    required this.onErased,
  });

  final VehicleKind kind;

  /// Every mark on the card. Ones belonging to another body are ignored here.
  final List<DentMark> marks;

  /// What a new stroke is recorded as.
  final DentSeverity severity;

  /// Whether a drag rubs marks out instead of painting them.
  final bool erasing;

  final void Function(DentMark) onPainted;
  final void Function(Set<String> ids) onErased;

  @override
  State<DamageSheet> createState() => _DamageSheetState();
}

class _DamageSheetState extends State<DamageSheet> {
  /// The stroke being drawn right now, before it is committed.
  String? _liveView;
  List<Offset> _live = const [];

  List<BlueprintView> get _views => kBlueprints[widget.kind]!;

  void _begin(BlueprintView v, Offset at) {
    if (widget.erasing) return _erase(v, at);
    setState(() {
      _liveView = viewId(widget.kind, v);
      _live = [at];
    });
  }

  void _extend(BlueprintView v, Offset at) {
    if (widget.erasing) return _erase(v, at);
    if (_liveView != viewId(widget.kind, v) || _live.isEmpty) return;
    // Thin the samples out — a drag fires far more often than the stroke needs.
    if ((at - _live.last).distance < 0.008) return;
    setState(() => _live = [..._live, at]);
  }

  void _commit() {
    if (_liveView == null || _live.isEmpty) return;
    final mark = DentMark.stroke(
      id: newId('d'),
      view: _liveView!,
      path: _live,
      severity: widget.severity,
    );
    setState(() {
      _liveView = null;
      _live = const [];
    });
    widget.onPainted(mark);
  }

  void _erase(BlueprintView v, Offset at) {
    final id = viewId(widget.kind, v);
    final hit = <String>{
      for (final m in widget.marks)
        if (m.view == id)
          for (final o in m.path)
            if ((o - at).distance < 0.05) m.id,
    };
    if (hit.isNotEmpty) widget.onErased(hit);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;

    // Front and rear share a row; everything else gets one to itself. Rows are
    // weighted by how tall their drawing is, so the sheet fills the space
    // without anything having to scroll under the brush.
    final rows = <List<BlueprintView>>[];
    for (var i = 0; i < _views.length; i++) {
      final v = _views[i];
      if (v.halfWidth && i + 1 < _views.length && _views[i + 1].halfWidth) {
        rows.add([v, _views[i + 1]]);
        i++;
      } else {
        rows.add([v]);
      }
    }

    return Column(
      children: [
        for (final row in rows)
          Expanded(
            flex:
                (row
                            .map((v) => v.height / v.width)
                            .reduce((a, b) => a > b ? a : b) *
                        100)
                    .round(),
            child: Row(
              children: [
                for (final v in row)
                  Expanded(
                    child: _View(
                      view: v,
                      id: viewId(widget.kind, v),
                      marks: widget.marks,
                      live: _liveView == viewId(widget.kind, v) ? _live : null,
                      liveColor: dentColor(p, widget.severity),
                      palette: p,
                      erasing: widget.erasing,
                      onBegin: (at) => _begin(v, at),
                      onExtend: (at) => _extend(v, at),
                      onEnd: _commit,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// One view's box: the drawing, the marks on it, and the brush.
class _View extends StatelessWidget {
  const _View({
    required this.view,
    required this.id,
    required this.marks,
    required this.live,
    required this.liveColor,
    required this.palette,
    required this.erasing,
    required this.onBegin,
    required this.onExtend,
    required this.onEnd,
  });

  final BlueprintView view;
  final String id;
  final List<DentMark> marks;
  final List<Offset>? live;
  final Color liveColor;
  final AppPalette palette;
  final bool erasing;
  final ValueChanged<Offset> onBegin;
  final ValueChanged<Offset> onExtend;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final mine = [
      for (final m in marks)
        if (m.view == id) m,
    ];

    return Padding(
      padding: const EdgeInsets.all(Gap.xs),
      child: Center(
        child: AspectRatio(
          // The child is exactly the drawing, so a touch on it maps straight
          // onto the drawing's own coordinates with nothing to correct for.
          aspectRatio: view.aspect,
          child: LayoutBuilder(
            builder: (context, box) {
              Offset norm(Offset local) => Offset(
                (local.dx / box.maxWidth).clamp(0.0, 1.0),
                (local.dy / box.maxHeight).clamp(0.0, 1.0),
              );
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => onBegin(norm(d.localPosition)),
                onTapUp: (_) => onEnd(),
                onPanStart: (d) => onBegin(norm(d.localPosition)),
                onPanUpdate: (d) => onExtend(norm(d.localPosition)),
                onPanEnd: (_) => onEnd(),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Highlighter goes under the ink, so the drawing stays
                    // readable through the colour.
                    CustomPaint(
                      painter: _MarksPainter(
                        marks: mine,
                        live: live,
                        liveColor: liveColor,
                        palette: palette,
                      ),
                    ),
                    // A bundled drawing wins over the built-in line art, so a
                    // proper technical illustration can be dropped in without
                    // touching anything else.
                    if (view.asset != null)
                      Image.asset(view.asset!, fit: BoxFit.fill)
                    else
                      CustomPaint(
                        painter: BlueprintPainter(
                          view: view,
                          line: palette.inkSoft,
                        ),
                      ),
                    Positioned(
                      left: 2,
                      top: 0,
                      child: Text(
                        view.label,
                        style: AppType.labelS.s(9).c(palette.inkFaint),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MarksPainter extends CustomPainter {
  _MarksPainter({
    required this.marks,
    required this.live,
    required this.liveColor,
    required this.palette,
  });

  final List<DentMark> marks;
  final List<Offset>? live;
  final Color liveColor;
  final AppPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    for (final m in marks) {
      _stroke(canvas, size, m.path, dentColor(palette, m.severity));
    }
    final l = live;
    if (l != null && l.isNotEmpty) _stroke(canvas, size, l, liveColor);
  }

  void _stroke(Canvas canvas, Size size, List<Offset> path, Color color) {
    if (path.isEmpty) return;
    final width = (size.width * 0.05).clamp(9.0, 30.0);
    // One translucent pass over the whole stroke, so overlaps inside a single
    // drag do not stack up into a darker blob.
    final paint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final pts = [
      for (final o in path) Offset(o.dx * size.width, o.dy * size.height),
    ];
    if (pts.length == 1) {
      canvas.drawCircle(
        pts.first,
        width / 2,
        Paint()..color = color.withValues(alpha: 0.55),
      );
      return;
    }
    final p = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final o in pts.skip(1)) {
      p.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(p, paint);
  }

  @override
  bool shouldRepaint(covariant _MarksPainter old) => true;
}
