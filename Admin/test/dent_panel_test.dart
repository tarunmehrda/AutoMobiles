import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:path_drawing/path_drawing.dart';
import 'package:garagepro_admin/data/models/entities.dart';
import 'package:garagepro_admin/data/models/enums.dart';
import 'package:garagepro_admin/features/jobcard/widgets/draft_dents_page.dart';
import 'package:garagepro_admin/features/jobcard/widgets/component_sheet.dart';
import 'package:garagepro_admin/features/jobcard/widgets/vehicle_blueprint.dart';
import 'package:garagepro_admin/features/jobcard/widgets/vehicle_parts.dart';

void main() {
  group('a mark is a stroke on one view of one body', () {
    test('a drag is kept as the whole stroke, not just where it started', () {
      final mark = DentMark.stroke(
        id: 'd1',
        view: 'fourWheeler.side',
        path: const [Offset(0.2, 0.3), Offset(0.25, 0.32), Offset(0.3, 0.31)],
        severity: DentSeverity.dent,
      );

      expect(mark.path.length, 3);
      expect(mark.path.last, const Offset(0.3, 0.31));
      // The start is held separately for anything that wants one position.
      expect(mark.dx, 0.2);
      expect(mark.dy, 0.3);
    });

    test('a single dab is a stroke of one point', () {
      final mark = DentMark.stroke(
        id: 'd2',
        view: 'twoWheeler.top',
        path: const [Offset(0.5, 0.5)],
      );

      expect(mark.path, const [Offset(0.5, 0.5)]);
    });

    test('the stroke survives storage', () {
      final mark = DentMark.stroke(
        id: 'd3',
        view: 'threeWheeler.rear',
        path: const [Offset(0.1, 0.2), Offset(0.4, 0.6)],
        severity: DentSeverity.rust,
        note: 'bubbling along the seam',
      );

      final back = DentMark.fromJson(mark.toJson());

      expect(back.view, 'threeWheeler.rear');
      expect(back.path, const [Offset(0.1, 0.2), Offset(0.4, 0.6)]);
      expect(back.severity, DentSeverity.rust);
      expect(back.note, 'bubbling along the seam');
    });

    test('a mark saved before the sheet existed still loads', () {
      final back = DentMark.fromJson({
        'id': 'old',
        'dx': 0.3,
        'dy': 0.4,
        'severity': 'scratch',
        'note': '',
      });

      expect(back.view, '');
      expect(back.path, isEmpty);
      expect(back.dx, 0.3);
      expect(back.severity, DentSeverity.scratch);
    });

    test('editing a mark leaves the stroke and its view alone', () {
      final mark = DentMark.stroke(
        id: 'd4',
        view: 'fourWheeler.roofless',
        path: const [Offset(0.1, 0.1), Offset(0.2, 0.2)],
      );
      final edited = mark.copyWith(severity: DentSeverity.crack, note: 'deep');

      expect(edited.view, mark.view);
      expect(edited.path, mark.path);
      expect(edited.severity, DentSeverity.crack);
      expect(edited.note, 'deep');
    });
  });

  group('marks stay with the body they were drawn on', () {
    test('a view id names both the body and the view', () {
      final side = kBlueprints[VehicleKind.fourWheeler]!.first;
      expect(viewId(VehicleKind.fourWheeler, side), 'fourWheeler.side');
    });

    test('the body is read back off the marks', () {
      final marks = [
        DentMark.stroke(
          id: 'a',
          view: 'threeWheeler.side',
          path: const [Offset(0.5, 0.5)],
        ),
      ];
      expect(kindOfMarks(marks), VehicleKind.threeWheeler);
    });

    test('no marks means nothing to infer, so the caller decides', () {
      expect(kindOfMarks(const []), isNull);
      // A mark from before the sheet has no body to report either.
      expect(kindOfMarks([const DentMark(id: 'old')]), isNull);
    });
  });

  group('every body has a drawable sheet', () {
    test('each kind has views, and each view has line art and a size', () {
      for (final kind in VehicleKind.values) {
        final views = kBlueprints[kind];
        expect(views, isNotNull, reason: '${kind.name} has no sheet');
        expect(views!, isNotEmpty);
        for (final v in views) {
          expect(v.paths, isNotEmpty, reason: '${kind.name}.${v.key} is blank');
          expect(v.width, greaterThan(0));
          expect(v.height, greaterThan(0));
        }
      }
    });

    test('front and rear are paired so they share a row', () {
      for (final kind in VehicleKind.values) {
        final half = kBlueprints[kind]!.where((v) => v.halfWidth).length;
        expect(
          half.isEven,
          isTrue,
          reason: '${kind.name} has a half-width view with no partner',
        );
      }
    });
  });

  group('damage can be pinned to the panel it is on', () {
    test('a pinned mark keeps the part, its name and one point', () {
      final mark = DentMark.spot(
        id: 'p1',
        view: 'fourWheeler.side',
        part: 'fourWheeler.driver.door_front_right',
        label: 'Front door · Driver',
        at: const Offset(0.41, 0.56),
        severity: DentSeverity.dent,
      );

      expect(mark.isSpot, isTrue);
      expect(mark.path, const [Offset(0.41, 0.56)]);
      expect(mark.where, 'Front door · Driver');
    });

    test('a pinned mark survives storage', () {
      final mark = DentMark.spot(
        id: 'p2',
        view: 'sixWheeler.rear',
        part: 'sixWheeler.rear.tail_light_left',
        label: 'LH tail lamp · Rear',
        at: const Offset(0.825, 0.654),
        severity: DentSeverity.crack,
        note: 'lens gone',
      );

      final back = DentMark.fromJson(mark.toJson());

      expect(back.part, 'sixWheeler.rear.tail_light_left');
      expect(back.label, 'LH tail lamp · Rear');
      expect(back.path, const [Offset(0.825, 0.654)]);
      expect(back.note, 'lens gone');
    });

    test('a brush stroke names the drawing, not a panel', () {
      final mark = DentMark.stroke(
        id: 'b1',
        view: 'fourWheeler.side',
        path: const [Offset(0.2, 0.3)],
      );

      expect(mark.isSpot, isFalse);
      expect(mark.where, 'side view');
    });

    test('editing a pinned mark leaves the panel it is on alone', () {
      final mark = DentMark.spot(
        id: 'p3',
        view: 'twoWheeler.front',
        part: 'twoWheeler.front.head_light',
        label: 'Headlamp · Front',
        at: const Offset(0.5, 0.371),
      );
      final edited = mark.copyWith(severity: DentSeverity.crack, note: 'star');

      expect(edited.part, mark.part);
      expect(edited.label, mark.label);
      expect(edited.severity, DentSeverity.crack);
    });
  });

  group('every body has a component catalog', () {
    test('each face carries parts, and each one sits on the drawing', () {
      for (final kind in VehicleKind.values) {
        for (final area in VehicleArea.values) {
          final parts = partsFor(kind, area);
          expect(
            parts,
            isNotEmpty,
            reason: '${kind.name}.${area.name} has no components',
          );
          for (final part in parts) {
            expect(part.x, inInclusiveRange(0.0, 1.0));
            expect(part.y, inInclusiveRange(0.0, 1.0));
            expect(part.area, area);
          }
        }
      }
    });

    test('a face never lists the same component twice', () {
      for (final kind in VehicleKind.values) {
        for (final area in VehicleArea.values) {
          final ids = partsFor(kind, area).map((p) => p.id).toList();
          expect(
            ids.toSet().length,
            ids.length,
            reason: '${kind.name}.${area.name} repeats a component id',
          );
        }
      }
    });

    test('every plotted face has a drawing to plot onto', () {
      for (final kind in VehicleKind.values) {
        for (final area in VehicleArea.values) {
          final view = viewFor(kind, area);
          if (area == VehicleArea.interior) {
            expect(view, isNull, reason: 'the inside has no drawing');
          } else {
            expect(
              view,
              isNotNull,
              reason: '${kind.name} has no ${area.view} view',
            );
          }
        }
      }
    });

    test('the two flanks are told apart, panel by panel', () {
      final driver = partsFor(VehicleKind.fourWheeler, VehicleArea.driver);
      final passenger = partsFor(
        VehicleKind.fourWheeler,
        VehicleArea.passenger,
      );

      expect(driver.length, passenger.length);
      final door = driver.firstWhere((p) => p.name == 'Front door');
      final otherDoor = passenger.firstWhere((p) => p.name == 'Front door');
      expect(door.id, 'door_front_right');
      expect(otherDoor.id, 'door_front_left');

      // A panel there is only one of keeps one id on both flanks, so a dent
      // on the front bumper is not recorded twice for being seen twice.
      final bumper = driver.firstWhere((p) => p.id == 'bumper_front');
      expect(passenger.any((p) => p.id == bumper.id), isTrue);
    });

    test('the passenger flank is the side drawing flipped', () {
      // Right-hand drive: the nose-left drawing is the driver's flank, so it
      // is the other one that gets turned round.
      expect(
        areaMirrored(VehicleKind.fourWheeler, VehicleArea.driver),
        isFalse,
      );
      expect(
        areaMirrored(VehicleKind.fourWheeler, VehicleArea.passenger),
        isTrue,
      );
      // The bike is penned nose-right, so the flip goes the other way round.
      expect(areaMirrored(VehicleKind.twoWheeler, VehicleArea.driver), isTrue);
      expect(
        areaMirrored(VehicleKind.twoWheeler, VehicleArea.passenger),
        isFalse,
      );
      // Nothing else is ever flipped.
      for (final kind in VehicleKind.values) {
        for (final area in [
          VehicleArea.front,
          VehicleArea.rear,
          VehicleArea.roof,
          VehicleArea.interior,
        ]) {
          expect(areaMirrored(kind, area), isFalse);
        }
      }
    });

    test('a stored component id finds its way back to the component', () {
      for (final kind in VehicleKind.values) {
        for (final part in allPartsFor(kind)) {
          final id = partId(kind, part);
          final back = partOf(id);
          expect(back, isNotNull, reason: '$id went missing');
          expect(back!.name, part.name);
          expect(back.area, part.area);
        }
      }
    });

    test('an id from a catalog that has moved on is not guessed at', () {
      expect(partOf('fourWheeler.driver.tail_fin'), isNull);
      expect(partOf('hovercraft.driver.door_front_right'), isNull);
      expect(partOf('rubbish'), isNull);
    });

    test('a face names itself for the body it is on', () {
      expect(VehicleArea.driver.label(VehicleKind.fourWheeler), 'Driver');
      // Nobody sits beside you on a bike, so it has a left and a right.
      expect(VehicleArea.driver.label(VehicleKind.twoWheeler), 'Right');
      expect(VehicleArea.passenger.label(VehicleKind.twoWheeler), 'Left');
      expect(VehicleArea.roof.label(VehicleKind.twoWheeler), 'Top');
      expect(VehicleArea.interior.label(VehicleKind.twoWheeler), 'Controls');
    });

    test('a truck is marked up on a truck, not on a car', () {
      expect(VehicleShape.sixWheeler.sheet, VehicleKind.sixWheeler);
      expect(VehicleShape.fourWheeler.sheet, VehicleKind.fourWheeler);
    });
  });

  group('a hotspot sits on the panel it names', () {
    /// Points along every line of a drawing, close enough together to measure
    /// against.
    List<Offset> inkOf(BlueprintView view) {
      final pts = <Offset>[];
      for (final ink in view.paths) {
        for (final metric in parseSvgPathData(ink.d).computeMetrics()) {
          final steps = math.max(2, metric.length.ceil());
          for (var i = 0; i <= steps; i++) {
            final t = metric.getTangentForOffset(metric.length * i / steps);
            if (t != null) pts.add(t.position);
          }
        }
      }
      return pts;
    }

    test('no hotspot is left floating in the white space', () {
      for (final kind in VehicleKind.values) {
        for (final area in VehicleArea.values) {
          final view = viewFor(kind, area);
          if (view == null) continue;

          final ink = inkOf(view);
          expect(ink, isNotEmpty);

          // The drawing's own extent, so a dot cannot sit off the vehicle.
          var minX = double.infinity, minY = double.infinity;
          var maxX = -double.infinity, maxY = -double.infinity;
          for (final q in ink) {
            minX = math.min(minX, q.dx);
            minY = math.min(minY, q.dy);
            maxX = math.max(maxX, q.dx);
            maxY = math.max(maxY, q.dy);
          }

          final diag = math.sqrt(
            view.width * view.width + view.height * view.height,
          );

          for (final part in partsFor(kind, area)) {
            final at = Offset(part.x * view.width, part.y * view.height);
            final where = '${kind.name}.${area.name}.${part.id}';

            expect(
              at.dx,
              inInclusiveRange(minX - 2, maxX + 2),
              reason: '$where sits off the side of the drawing',
            );
            expect(
              at.dy,
              inInclusiveRange(minY - 2, maxY + 2),
              reason: '$where sits above or below the drawing',
            );

            // Dead centre of a big panel is a long way from any line, which is
            // right; a dot adrift in the gap between two panels is not. The
            // bound is loose enough to allow the first and tight enough to
            // catch the second.
            var near = double.infinity;
            for (final q in ink) {
              near = math.min(near, (q - at).distance);
            }
            expect(
              near / diag,
              lessThan(0.12),
              reason: '$where is nowhere near a drawn line',
            );
          }
        }
      }
    });

    test('two hotspots on one face are never on top of each other', () {
      for (final kind in VehicleKind.values) {
        for (final area in VehicleArea.values) {
          if (viewFor(kind, area) == null) continue;
          final parts = partsFor(kind, area);
          for (var i = 0; i < parts.length; i++) {
            for (var j = i + 1; j < parts.length; j++) {
              final gap = (parts[i].at - parts[j].at).distance;
              expect(
                gap,
                greaterThan(0.03),
                reason:
                    '${kind.name}.${area.name}: ${parts[i].id} and '
                    '${parts[j].id} would be one tap target',
              );
            }
          }
        }
      }
    });
  });
}
