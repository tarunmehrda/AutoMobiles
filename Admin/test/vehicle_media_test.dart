import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:garagepro_admin/data/models/enums.dart';
import 'package:garagepro_admin/data/seed/vehicle_catalog.dart';
import 'package:garagepro_admin/data/seed/vehicle_media.dart';

/// The promise this file exists to keep: **every vehicle in the catalogue
/// shows a photograph.**
///
/// It is a promise that is easy to break by accident and impossible to see
/// breaking. A typo in a body-style set, a model added to the catalogue, a
/// photo file renamed — none of it fails a build, and none of it fails a
/// screen. It just quietly puts a line drawing, or worse a car, in front of
/// somebody who brought a bike in.
///
/// So the check is mechanical: walk the whole catalogue, ask for the picture,
/// and insist there is a real file at the other end of it.
void main() {
  /// Everything in the catalogue, as (shape, make, model).
  final everything = <({VehicleShape shape, String make, String model})>[
    for (final shape in VehicleShape.values)
      for (final make in VehicleCatalog.makesFor(shape))
        for (final model in VehicleCatalog.modelsOf(make, shape))
          (shape: shape, make: make, model: model),
  ];

  group('every vehicle has a photograph', () {
    test('the catalogue covers all four bodies', () {
      for (final shape in VehicleShape.values) {
        expect(
          VehicleCatalog.makesFor(shape),
          isNotEmpty,
          reason: 'nothing can be picked for ${shape.label}',
        );
      }
      // A guard against the two-wheeler tables being quietly dropped again:
      // this is the bulk of what a neighbourhood workshop actually sees.
      expect(
        everything.where((e) => e.shape == VehicleShape.twoWheeler).length,
        greaterThan(100),
      );
      expect(everything.length, greaterThan(400));
    });

    test('no model anywhere resolves to nothing', () {
      final missing = [
        for (final e in everything)
          if (VehicleMedia.photoFor(e.make, e.model, e.shape) == null)
            '${e.shape.short} ${e.make} ${e.model}',
      ];
      expect(missing, isEmpty);
    });

    test('every picture it hands out is a file that ships', () {
      final broken = <String>{};
      for (final e in everything) {
        final path = VehicleMedia.photoFor(e.make, e.model, e.shape)!;
        if (!File(path).existsSync()) {
          broken.add('$path  (${e.make} ${e.model})');
        }
      }
      expect(broken, isEmpty);
    });

    test('a bike never gets shown a car, and a car never a bike', () {
      for (final e in everything) {
        final path = VehicleMedia.photoFor(e.make, e.model, e.shape)!;
        // A model with its own photograph is right by definition; the body
        // fallback is the part that can silently pick the wrong family.
        if (VehicleMedia.exactPhotoFor(e.model) != null) continue;
        final family = switch (e.shape) {
          VehicleShape.twoWheeler => ['motorcycle', 'scooter'],
          VehicleShape.threeWheeler => ['auto'],
          VehicleShape.sixWheeler => ['truck'],
          VehicleShape.fourWheeler => [
            'hatchback',
            'sedan',
            'suv',
            'muv',
            'luxury',
            'ev',
          ],
        };
        expect(
          family.any((f) => path.endsWith('/$f.jpg')),
          isTrue,
          reason: '${e.shape.label} ${e.make} ${e.model} -> $path',
        );
      }
    });
  });

  group('the bundled sets are consistent', () {
    test('every model photo the lookup can name is on disk', () {
      // Reached through the public door rather than the private set, so this
      // also proves the alias table does not point at anything absent.
      final broken = <String>{};
      for (final e in everything) {
        final exact = VehicleMedia.exactPhotoFor(e.model);
        if (exact != null && !File(exact).existsSync()) broken.add(exact);
      }
      expect(broken, isEmpty);
    });

    test('every marque logo is on disk', () {
      final broken = <String>{};
      for (final shape in VehicleShape.values) {
        for (final make in VehicleCatalog.makesFor(shape)) {
          final logo = VehicleMedia.logoFor(make);
          if (logo != null && !File(logo).existsSync()) {
            broken.add('$make $logo');
          }
        }
      }
      expect(broken, isEmpty);
    });

    test('no photo file ships without something reaching it', () {
      final reachable = {
        for (final e in everything)
          VehicleMedia.photoFor(e.make, e.model, e.shape),
      };
      final orphans = <String>[];
      for (final dir in ['assets/models', 'assets/bodies']) {
        for (final f in Directory(dir).listSync().whereType<File>()) {
          final path = f.path.replaceAll(r'\', '/');
          if (!path.endsWith('.jpg')) continue;
          if (!reachable.contains(path)) orphans.add(path);
        }
      }
      expect(
        orphans,
        isEmpty,
        reason: 'dead weight in the bundle — no catalogue entry shows these',
      );
    });
  });

  group('the body a picture is chosen for', () {
    test('a scooter is not drawn as a motorcycle', () {
      for (final model in ['Activa 6G', 'Jupiter', 'Access 125', 'Dio']) {
        expect(
          VehicleMedia.bodyPhotoFor('Honda', model, VehicleShape.twoWheeler),
          endsWith('scooter.jpg'),
          reason: model,
        );
      }
      for (final model in ['Splendor Plus', 'Pulsar 150', 'Classic 350']) {
        expect(
          VehicleMedia.bodyPhotoFor('Hero', model, VehicleShape.twoWheeler),
          endsWith('motorcycle.jpg'),
          reason: model,
        );
      }
    });

    test('the same marque means different things on 2W and 4W', () {
      expect(
        VehicleCatalog.modelsOf('Honda', VehicleShape.twoWheeler),
        contains('Activa 6G'),
      );
      expect(
        VehicleCatalog.modelsOf('Honda', VehicleShape.fourWheeler),
        contains('City'),
      );
      expect(
        VehicleCatalog.modelsOf('Honda', VehicleShape.twoWheeler),
        isNot(contains('City')),
      );
    });

    test('a car sorts into its own body', () {
      expect(
        VehicleMedia.bodyPhotoFor('Tata', 'Indigo', VehicleShape.fourWheeler),
        endsWith('sedan.jpg'),
      );
      expect(
        VehicleMedia.bodyPhotoFor('Toyota', 'Qualis', VehicleShape.fourWheeler),
        endsWith('muv.jpg'),
      );
      expect(
        VehicleMedia.bodyPhotoFor('Jeep', 'Wrangler', VehicleShape.fourWheeler),
        endsWith('suv.jpg'),
      );
      expect(
        VehicleMedia.bodyPhotoFor('BMW', 'X3', VehicleShape.fourWheeler),
        endsWith('luxury.jpg'),
      );
      expect(
        VehicleMedia.bodyPhotoFor(
          'Maruti Suzuki',
          'Zen',
          VehicleShape.fourWheeler,
        ),
        endsWith('hatchback.jpg'),
      );
    });

    test('an exact photograph wins over its body', () {
      expect(
        VehicleMedia.photoFor(
          'Maruti Suzuki',
          'Swift',
          VehicleShape.fourWheeler,
        ),
        'assets/models/swift.jpg',
      );
    });

    test('nothing typed yet is the one case that draws instead', () {
      expect(VehicleMedia.photoFor('', '', VehicleShape.fourWheeler), isNull);
      expect(
        VehicleMedia.photoFor(null, null, VehicleShape.twoWheeler),
        isNull,
      );
    });
  });
}
