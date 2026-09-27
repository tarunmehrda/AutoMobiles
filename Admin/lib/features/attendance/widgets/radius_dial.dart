import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/widgets/g_badge.dart';
import '../../../data/models/attendance.dart';
import '../../../data/repo/attendance_gate.dart';

/// Where the phone is, drawn against the circle it has to be inside.
///
/// A number on its own — "11 m" — does not tell somebody whether to walk, or
/// which way, or how close eleven metres is to enough. The ring does: the
/// circle is the allowed radius, the dot is the phone, and the pale halo
/// around the dot is how sure the fix is. When the halo is wider than the
/// circle, the picture says the thing that is hardest to say in words —
/// that the fix is too vague to place anybody, and no amount of standing
/// still will change it.
class RadiusDial extends StatelessWidget {
  const RadiusDial({
    super.key,
    required this.site,
    required this.reading,
    required this.busy,
    required this.settled,
  });

  final AttendanceSite site;
  final GateReading? reading;
  final bool busy;

  /// Whether a check has finished at least once. Before that the dial is
  /// deliberately blank rather than showing a confident zero.
  final bool settled;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final r = reading;
    final inside = r != null && r.located && r.distanceM <= site.radiusM;
    final tone = r == null || !r.located
        ? GTone.neutral
        : r.ok
        ? GTone.success
        : r.block.isAbuse
        ? GTone.danger
        : GTone.warning;
    final t = toneOf(context, tone);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.xl),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: R.all(R.xl),
        border: Border.all(color: p.line),
        boxShadow: Shadows.soft(p),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 168,
            width: 168,
            child: AnimatedBuilder(
              // Nothing animates yet, but the painter is cheap and this
              // keeps the repaint boundary honest when the reading changes.
              animation: const AlwaysStoppedAnimation(0),
              builder: (context, _) => CustomPaint(
                painter: _DialPainter(
                  radiusM: site.radiusM,
                  distanceM: r?.located == true ? r!.distanceM : null,
                  accuracyM: r?.located == true ? r!.accuracyM : null,
                  ring: t.fg,
                  face: t.bg,
                  grid: p.line,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (busy && r == null)
                        SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: p.inkFaint,
                          ),
                        )
                      else
                        Text(
                          r == null || !r.located
                              ? (settled ? '—' : '·')
                              : AttendanceGate.metres(r.distanceM),
                          style: AppType.d2.s(28).c(p.ink).w(FontWeight.w800),
                        ),
                      const SizedBox(height: 2),
                      Text(
                        r == null || !r.located
                            ? 'not placed'.tr
                            : inside
                            ? 'inside the circle'.tr
                            : 'from the workshop'.tr,
                        textAlign: TextAlign.center,
                        style: AppType.bodyS.s(11).c(p.inkMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: Gap.lg),
          // Three stats on one line, and every label is a word that grows
          // when the console is not in English. Sharing the width equally
          // is what keeps the third one on the card.
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'Allowed'.tr,
                  value: AttendanceGate.metres(site.radiusM),
                  icon: Icons.adjust_rounded,
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'Fix accuracy'.tr,
                  value: r == null || !r.located
                      ? '—'
                      : '±${r.accuracyM.round()} m',
                  icon: Icons.blur_circular_rounded,
                  // A fix vaguer than the ceiling is the single most common
                  // reason an honest person is turned away, so it is called
                  // out here rather than left to be inferred from the ring.
                  warn:
                      r != null &&
                      r.located &&
                      (r.accuracyM <= 0 || r.accuracyM > site.maxAccuracyM),
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'Source'.tr,
                  value: r == null
                      ? '—'
                      : r.mocked
                      ? 'Mocked'
                      : 'Device GPS',
                  icon: r?.mocked == true
                      ? Icons.gpp_bad_rounded
                      : Icons.satellite_alt_rounded,
                  warn: r?.mocked == true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.icon,
    this.warn = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final fg = warn ? p.danger : p.ink;
    return Column(
      children: [
        Icon(icon, size: 17, color: warn ? p.danger : p.inkFaint),
        const SizedBox(height: 5),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppType.labelL.s(13).c(fg),
        ),
        Text(
          label,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: AppType.bodyS.s(10.5).c(p.inkFaint),
        ),
      ],
    );
  }
}

class _DialPainter extends CustomPainter {
  const _DialPainter({
    required this.radiusM,
    required this.distanceM,
    required this.accuracyM,
    required this.ring,
    required this.face,
    required this.grid,
  });

  final double radiusM;
  final double? distanceM;
  final double? accuracyM;
  final Color ring;
  final Color face;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final edge = size.shortestSide / 2;

    // The allowed circle always sits at 44% of the dial, whatever it is in
    // metres, so the picture reads the same at five metres and at fifty.
    // Everything else is scaled against it.
    final allowed = edge * 0.44;
    final perMetre = allowed / math.max(radiusM, 0.5);

    // How far out the dial can show before it stops meaning anything. A
    // phone two kilometres away and a phone two hundred metres away are
    // both simply "outside", and drawing them differently would only be
    // drawing noise.
    final far = edge * 0.94;

    canvas.drawCircle(
      centre,
      edge * 0.95,
      Paint()..color = face.withValues(alpha: 0.45),
    );

    // Faint rings for scale, so the allowed circle is read as a measurement
    // rather than as decoration.
    final hair = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = grid;
    for (final f in const [0.66, 0.88]) {
      canvas.drawCircle(centre, edge * f, hair);
    }

    canvas.drawCircle(
      centre,
      allowed,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = ring,
    );
    canvas.drawCircle(
      centre,
      allowed,
      Paint()..color = ring.withValues(alpha: 0.10),
    );

    // The workshop itself.
    canvas.drawCircle(centre, 3.4, Paint()..color = ring);

    final d = distanceM;
    if (d == null) return;

    // The phone is drawn straight up from the centre. The bearing is not
    // shown because it is not known — the site is a point, not a map, and
    // an arbitrary direction would invite somebody to walk the wrong way.
    final offset = math.min(d * perMetre, far);
    final dot = centre.translate(0, -offset);

    final acc = accuracyM;
    if (acc != null && acc > 0) {
      canvas.drawCircle(
        dot,
        math.min(acc * perMetre, far),
        Paint()..color = ring.withValues(alpha: 0.16),
      );
    }

    canvas.drawCircle(dot, 7, Paint()..color = ring);
    canvas.drawCircle(
      dot,
      7,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = face,
    );
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.radiusM != radiusM ||
      old.distanceM != distanceM ||
      old.accuracyM != accuracyM ||
      old.ring != ring ||
      old.face != face ||
      old.grid != grid;
}
