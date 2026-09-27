import 'package:flutter_test/flutter_test.dart';

import 'package:garagepro_admin/data/models/enums.dart';
import 'package:garagepro_admin/data/seed/vehicle_catalog.dart';
import 'package:garagepro_admin/data/seed/vehicle_media.dart';

/// The make picker offers whatever [VehicleCatalog.makesFor] says sells in the
/// body style the counter picked, and the model picker then asks the same
/// table for that make's models. Between the two, the job card form used to
/// re-derive the body style from the make's *name* through
/// [VehicleMedia.shapeFor] — a fallback meant for legacy records that never
/// recorded one.
///
/// That guess cannot see which list the make was taken off, so it overrode a
/// choice the counter had already made. Suzuki picked under Two Wheeler became
/// a car, the car table has no 'Suzuki' (only 'Maruti Suzuki'), and the model
/// list came back empty with nothing to pick.
///
/// These tests pin the two halves of the rule the form now follows: a make off
/// the list keeps the counter's body style, and a make typed free-hand — which
/// was on no list — still gets the guess.
void main() {
  test('every offered make has models in the style it was offered under', () {
    final blank = <String>[];
    for (final shape in VehicleShape.values) {
      for (final make in VehicleCatalog.makesFor(shape)) {
        if (VehicleCatalog.modelsOf(make, shape).isEmpty) {
          blank.add('$make under ${shape.name}');
        }
      }
    }
    expect(
      blank,
      isEmpty,
      reason: 'These makes are listed but lead to an empty model picker',
    );
  });

  test('shapeFor disagrees with the list a make came from', () {
    // Not a bug in [shapeFor] — it is guessing from a name and has no idea
    // which list was open. This is here so the day it stops disagreeing,
    // nobody mistakes the guard above for dead weight and deletes it.
    final clashes = <String>[];
    for (final shape in VehicleShape.values) {
      for (final make in VehicleCatalog.makesFor(shape)) {
        if (VehicleMedia.shapeFor(make) != shape) clashes.add(make);
      }
    }
    expect(clashes, contains('Suzuki'));
    expect(clashes, contains('Force Motors'));
  });

  test('Suzuki under Two Wheeler keeps its bikes', () {
    // The exact report: select the make, and no options come.
    const shape = VehicleShape.twoWheeler;
    expect(VehicleCatalog.makesFor(shape), contains('Suzuki'));
    expect(VehicleCatalog.modelsOf('Suzuki', shape), isNotEmpty);

    // What the form used to do instead.
    final guessed = VehicleMedia.shapeFor('Suzuki');
    expect(guessed, VehicleShape.fourWheeler);
    expect(VehicleCatalog.modelsOf('Suzuki', guessed), isEmpty);
  });

  test('a make typed free-hand is still placed by name', () {
    // Nothing offered it, so the guess is all there is — and for a bike
    // marque typed while the form sat on its Four Wheeler default, it is
    // right.
    expect(
      VehicleCatalog.makesFor(VehicleShape.fourWheeler),
      isNot(contains('Royal Enfield')),
    );
    expect(VehicleMedia.shapeFor('Royal Enfield'), VehicleShape.twoWheeler);
  });
}
