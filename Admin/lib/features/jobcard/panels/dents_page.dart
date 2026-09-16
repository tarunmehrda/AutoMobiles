import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/widgets/g_appbar.dart';
import '../../../core/widgets/g_button.dart';
import '../../../core/widgets/g_feedback.dart';
import '../../../core/widgets/g_field.dart';
import '../../../core/widgets/g_state.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/models/entities.dart';
import '../../../data/models/enums.dart';
import '../../../state/admin_state.dart';
import '../../../state/providers.dart';

/// Existing damage, plotted on a body outline at handover.
///
/// The diagram is painted rather than an image so it stays sharp, works in
/// both themes, and the marks can be stored as a fraction of the box — they
/// land in the same place on any screen size and on the printed copy.
class DentsPage extends ConsumerStatefulWidget {
  const DentsPage({super.key, required this.id});

  final String id;

  @override
  ConsumerState<DentsPage> createState() => _DentsPageState();
}

class _DentsPageState extends ConsumerState<DentsPage> {
  DentSeverity _severity = DentSeverity.scratch;

  Color _colorOf(AppPalette p, DentSeverity s) => switch (s) {
        DentSeverity.scratch => p.warning,
        DentSeverity.dent => p.accent,
        DentSeverity.crack => p.danger,
        DentSeverity.rust => p.info,
      };

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final card = ref.watch(jobCardProvider(widget.id));
    if (card == null) {
      return const Scaffold(
        appBar: GHeader(title: 'Dent marks'),
        body: GEmptyState(
          icon: Icons.car_crash_outlined,
          title: 'Job card not found',
          message: 'Nothing to attach this to.',
        ),
      );
    }

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Dent marks',
        subtitle: '${card.dents.length} recorded',
      ),
      body: ListView(
        padding:
            const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.h2),
        children: [
          Text(
            'Tap the diagram where the damage is. Pick the kind first — the '
            'colour carries onto the printed copy.',
            style: AppType.bodyM.c(p.inkMuted),
          ),
          const SizedBox(height: Gap.lg),

          // --- kind picker ------------------------------------------------
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              for (final s in DentSeverity.values)
                Pressable(
                  onTap: () => setState(() => _severity = s),
                  scale: 0.95,
                  child: AnimatedContainer(
                    duration: Motion.fast,
                    padding: const EdgeInsets.symmetric(
                        horizontal: Gap.md, vertical: Gap.sm),
                    decoration: BoxDecoration(
                      color: _severity == s
                          ? _colorOf(p, s).withValues(alpha: 0.16)
                          : p.surface,
                      borderRadius: R.all(R.pill),
                      border: Border.all(
                        color: _severity == s ? _colorOf(p, s) : p.line,
                        width: _severity == s ? 1.6 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          height: 9,
                          width: 9,
                          decoration: BoxDecoration(
                            color: _colorOf(p, s),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(s.label,
                            style: AppType.labelM.c(
                                _severity == s ? p.ink : p.inkSoft)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Gap.lg),

          // --- the diagram -------------------------------------------------
          AspectRatio(
            aspectRatio: 0.72,
            child: LayoutBuilder(
              builder: (context, box) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) => _add(
                    details.localPosition.dx / box.maxWidth,
                    details.localPosition.dy / box.maxHeight,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: R.all(R.lg),
                      border: Border.all(color: p.line),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _BodyPainter(
                              line: p.inkFaint,
                              fill: p.surfaceSunken,
                            ),
                          ),
                        ),
                        for (final d in card.dents)
                          Positioned(
                            left: d.dx * box.maxWidth - 13,
                            top: d.dy * box.maxHeight - 13,
                            child: Pressable(
                              onTap: () => _edit(card, d),
                              scale: 0.85,
                              child: Container(
                                height: 26,
                                width: 26,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _colorOf(p, d.severity),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: p.surface, width: 2),
                                  boxShadow: Shadows.soft(p),
                                ),
                                child: Text(
                                  d.severity.label
                                      .substring(0, 1)
                                      .toUpperCase(),
                                  style: AppType.labelS.s(10).c(Colors.white),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: Gap.lg),
          if (card.dents.isEmpty)
            Text('No damage recorded. Tap the diagram to add the first mark.',
                textAlign: TextAlign.center,
                style: AppType.bodyS.c(p.inkFaint))
          else
            for (final d in card.dents)
              Container(
                margin: const EdgeInsets.only(bottom: Gap.sm),
                padding: const EdgeInsets.symmetric(
                    horizontal: Gap.lg, vertical: Gap.md),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: R.all(R.md),
                  border: Border.all(color: p.line),
                ),
                child: Row(
                  children: [
                    Container(
                      height: 12,
                      width: 12,
                      decoration: BoxDecoration(
                        color: _colorOf(p, d.severity),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d.severity.label,
                              style: AppType.labelL.c(p.ink)),
                          if (d.note.isNotEmpty)
                            Text(d.note,
                                style: AppType.bodyS.c(p.inkMuted)),
                        ],
                      ),
                    ),
                    GButton(
                      label: 'Edit',
                      kind: GButtonKind.ghost,
                      size: GButtonSize.sm,
                      expand: false,
                      onPressed: () => _edit(card, d),
                    ),
                    const SizedBox(width: Gap.sm),
                    Pressable(
                      onTap: () => ref
                          .read(adminProvider.notifier)
                          .removeDent(widget.id, d.id),
                      scale: 0.88,
                      child: Icon(Icons.delete_outline_rounded,
                          size: 20, color: p.danger),
                    ),
                  ],
                ),
              ),
        ],
      ),
      bottomNavigationBar: GBottomBar(
        child: GButton.accent(
          label: 'Done',
          onPressed: () => context.pop(),
        ),
      ),
    );
  }

  void _add(double dx, double dy) {
    ref.read(adminProvider.notifier).addDent(
          widget.id,
          DentMark(
            id: newId('d'),
            dx: dx.clamp(0.02, 0.98),
            dy: dy.clamp(0.02, 0.98),
            severity: _severity,
          ),
        );
  }

  Future<void> _edit(JobCard card, DentMark mark) async {
    final note = TextEditingController(text: mark.note);
    var severity = mark.severity;

    await GFeedback.sheet<void>(
      context,
      title: 'Mark detail',
      subtitle: 'Where and what, for the record',
      child: StatefulBuilder(
        builder: (context, setSheet) {
          final p = context.c;
          return Padding(
            padding: EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page,
                MediaQuery.of(context).viewInsets.bottom + Gap.h1),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: Gap.sm,
                  children: [
                    for (final s in DentSeverity.values)
                      Pressable(
                        onTap: () => setSheet(() => severity = s),
                        scale: 0.95,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: Gap.md, vertical: Gap.sm),
                          decoration: BoxDecoration(
                            color: severity == s ? p.ink : p.surface,
                            borderRadius: R.all(R.pill),
                            border: Border.all(
                                color: severity == s ? p.ink : p.line),
                          ),
                          child: Text(
                            s.label,
                            style: AppType.labelM.c(severity == s
                                ? (p.isDark ? p.canvas : Colors.white)
                                : p.inkSoft),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: Gap.lg),
                GField(
                  label: 'Note',
                  hint: 'Front left door, rear bumper…',
                  controller: note,
                ),
                const SizedBox(height: Gap.xxl),
                Row(
                  children: [
                    Expanded(
                      child: GButton(
                        label: 'Remove',
                        kind: GButtonKind.danger,
                        size: GButtonSize.md,
                        onPressed: () {
                          ref
                              .read(adminProvider.notifier)
                              .removeDent(widget.id, mark.id);
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: GButton.accent(
                        label: 'Save',
                        size: GButtonSize.md,
                        onPressed: () {
                          ref.read(adminProvider.notifier).updateDent(
                                widget.id,
                                mark.copyWith(
                                  severity: severity,
                                  note: note.text.trim(),
                                ),
                              );
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
    note.dispose();
  }
}

/// A plan view of a car: roof, bonnet, boot, four doors and the wheels.
/// Enough to point at a panel without pretending to be a specific model.
class _BodyPainter extends CustomPainter {
  _BodyPainter({required this.line, required this.fill});

  final Color line;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round;
    final body = Paint()
      ..color = fill
      ..style = PaintingStyle.fill;

    // Outer shell.
    final shell = RRect.fromRectAndCorners(
      Rect.fromLTWH(w * 0.18, h * 0.06, w * 0.64, h * 0.88),
      topLeft: Radius.circular(w * 0.22),
      topRight: Radius.circular(w * 0.22),
      bottomLeft: Radius.circular(w * 0.16),
      bottomRight: Radius.circular(w * 0.16),
    );
    canvas.drawRRect(shell, body);
    canvas.drawRRect(shell, stroke);

    // Windscreen, roof and rear screen.
    final glass = Paint()
      ..color = line.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.26, h * 0.17, w * 0.48, h * 0.10),
        Radius.circular(w * 0.06),
      ),
      glass,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.24, h * 0.30, w * 0.52, h * 0.26),
        Radius.circular(w * 0.05),
      ),
      glass,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.26, h * 0.60, w * 0.48, h * 0.10),
        Radius.circular(w * 0.06),
      ),
      glass,
    );

    // Panel splits.
    for (final y in [0.30, 0.43, 0.56, 0.70]) {
      canvas.drawLine(
        Offset(w * 0.18, h * y),
        Offset(w * 0.82, h * y),
        stroke..strokeWidth = 0.9,
      );
    }

    // Wheels.
    final wheel = Paint()
      ..color = line.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;
    for (final spot in [
      [0.14, 0.24],
      [0.86, 0.24],
      [0.14, 0.70],
      [0.86, 0.70],
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(w * spot[0], h * spot[1]),
            width: w * 0.09,
            height: h * 0.11,
          ),
          Radius.circular(w * 0.02),
        ),
        wheel,
      );
    }

    // Nose and tail markers, so front is never ambiguous.
    final label = TextPainter(
      text: TextSpan(
        text: 'FRONT',
        style: TextStyle(
          color: line,
          fontSize: w * 0.045,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, Offset(w / 2 - label.width / 2, h * 0.005));
  }

  @override
  bool shouldRepaint(covariant _BodyPainter old) =>
      old.line != line || old.fill != fill;
}
