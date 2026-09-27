import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:garagepro_admin/data/models/attendance.dart';
import 'package:garagepro_admin/data/models/entities.dart';
import 'package:garagepro_admin/data/repo/admin_data.dart';
import 'package:garagepro_admin/data/repo/attendance_gate.dart';
import 'package:garagepro_admin/data/repo/garage_gateway.dart';
import 'package:garagepro_admin/data/repo/local_store.dart';
import 'package:garagepro_admin/state/admin_state.dart';

const _garage = Garage(
  id: 'garage-test',
  name: 'Test Motors',
  phone: '9000000000',
);

Future<ProviderContainer> _shop() async {
  SharedPreferences.setMockInitialValues({});
  localStore = await LocalStore.open();
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final c = container.read(adminProvider.notifier);
  c.markSignedIn();
  c.completeOnboarding();
  c.saveGarage(_garage);
  return container;
}

/// A punch built straight, for the arithmetic tests. Nothing here goes near
/// the gate — these are the rules the register is read by, and they have to
/// hold whatever the GPS said.
AttendancePunch _p(
  String staffId,
  PunchKind kind,
  DateTime at, {
  bool accepted = true,
  PunchBlock block = PunchBlock.none,
}) => AttendancePunch(
  id: '$staffId-${at.millisecondsSinceEpoch}-${kind.wire}',
  staffId: staffId,
  staffName: staffId.toUpperCase(),
  kind: kind,
  at: at,
  accepted: accepted,
  block: block,
);

DateTime _at(int hour, [int minute = 0]) => DateTime(2026, 9, 19, hour, minute);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('shift arithmetic', () {
    test('pairs each in with the out that follows it', () {
      final day = [
        _p('a', PunchKind.punchIn, _at(9)),
        _p('a', PunchKind.punchOut, _at(13)),
        _p('a', PunchKind.punchIn, _at(14)),
        _p('a', PunchKind.punchOut, _at(18, 30)),
      ];
      expect(Shift.worked(day, 'a'), const Duration(hours: 8, minutes: 30));
    });

    test('an unmatched punch in counts for nothing, not until midnight', () {
      final day = [_p('a', PunchKind.punchIn, _at(9))];
      expect(Shift.worked(day, 'a'), Duration.zero);
      expect(Shift.onDuty(day, 'a'), isTrue);
      expect(Shift.next(day, 'a'), PunchKind.punchOut);
    });

    test('a refused punch is not a shift', () {
      final day = [
        _p(
          'a',
          PunchKind.punchIn,
          _at(9),
          accepted: false,
          block: PunchBlock.mocked,
        ),
        _p('a', PunchKind.punchIn, _at(10)),
        _p('a', PunchKind.punchOut, _at(12)),
      ];
      expect(Shift.worked(day, 'a'), const Duration(hours: 2));
      // ...and it must not be what the button reads either, or somebody
      // refused for faking their location would find the app offering to
      // punch them out of a shift they were never let into.
      expect(Shift.onDuty(day, 'a'), isFalse);
    });

    test('somebody else\'s punches are nobody\'s shift', () {
      final day = [
        _p('a', PunchKind.punchIn, _at(9)),
        _p('b', PunchKind.punchOut, _at(17)),
      ];
      expect(Shift.worked(day, 'a'), Duration.zero);
      expect(Shift.onDuty(day, 'b'), isFalse);
    });

    test('the last punch is the latest one, not the first in the list', () {
      // The register arrives newest-first from the server and grows
      // newest-first on the device, but the button must not depend on that
      // holding — a merge that appends would otherwise flip In and Out.
      final jumbled = [
        _p('a', PunchKind.punchIn, _at(9)),
        _p('a', PunchKind.punchOut, _at(17)),
        _p('a', PunchKind.punchIn, _at(14)),
      ];
      expect(Shift.lastAccepted(jumbled, 'a')!.at, _at(17));
      expect(Shift.next(jumbled, 'a'), PunchKind.punchIn);
    });
  });

  group('the designated location', () {
    test('rides on the garage row and survives a round trip', () {
      const site = AttendanceSite(
        lat: 26.912434,
        lng: 75.787270,
        radiusM: 5,
        maxAccuracyM: 25,
        label: 'Main workshop',
      );
      final back = Garage.fromJson(
        _garage.copyWith(attendanceSite: site).toJson(),
      );
      expect(back.attendanceSite, site);
    });

    test('a garage with no pin is not a garage pinned at the equator', () {
      final row = _garage.toJson();
      expect(row['attendance_lat'], isNull);
      expect(Garage.fromJson(row).attendanceSite, isNull);
      // A row from a database that has never had 05_attendance.sql run on
      // it has no such columns at all, which must read the same way.
      expect(siteFromJson(const {'id': 'g', 'name': 'x'}), isNull);
    });

    test('the radius defaults to the five metres the brief asks for', () {
      const site = AttendanceSite(lat: 1, lng: 1);
      expect(site.radiusM, 5);
      expect(site.maxAccuracyM, 25);
    });

    test('un-pinning actually clears it', () async {
      final container = await _shop();
      final c = container.read(adminProvider.notifier);

      c.setAttendanceSite(const AttendanceSite(lat: 26.9, lng: 75.7));
      expect(container.read(adminProvider).attendanceSite, isNotNull);

      c.setAttendanceSite(null);
      expect(container.read(adminProvider).attendanceSite, isNull);
      // And on the wire, not just in memory — `??` in copyWith would have
      // kept the old pin and left the shop unable to turn attendance off.
      expect(
        container.read(adminProvider).garage!.toJson()['attendance_lat'],
        isNull,
      );
    });
  });

  group('the client and the database agree on the refusal codes', () {
    test('every block has a wire code, and every code parses back', () {
      final seen = <String>{};
      for (final block in PunchBlock.values) {
        expect(
          seen.add(block.wire),
          isTrue,
          reason: '${block.name} shares a wire code with another block',
        );
        expect(PunchBlockX.parse(block.wire), block);
        expect(block.short, isNotEmpty);
      }
    });

    test('a code this build has never heard of is a refusal, not a pass', () {
      // The database is deployed separately from the app, so a newer
      // `punch_attendance` can return a code an older console does not
      // know. Reading that as anything but "refused" would be a backend
      // tightening the rules and a client quietly ignoring it.
      expect(
        PunchBlockX.parse('something_new_from_the_server'),
        PunchBlock.refused,
      );
      expect(PunchBlock.refused.isAbuse, isFalse);
    });

    test('the abuse codes are the ones worth an owner\'s attention', () {
      expect(PunchBlock.mocked.isAbuse, isTrue);
      expect(PunchBlock.providerMismatch.isAbuse, isTrue);
      expect(PunchBlock.jumped.isAbuse, isTrue);
      expect(PunchBlock.clockOff.isAbuse, isTrue);
      // A phone with no signal is not somebody cheating.
      expect(PunchBlock.noFix.isAbuse, isFalse);
      expect(PunchBlock.tooFar.isAbuse, isFalse);
      expect(PunchBlock.inaccurate.isAbuse, isFalse);
    });

    test('every block has a sentence somebody can act on', () {
      const site = AttendanceSite(lat: 1, lng: 1);
      for (final block in PunchBlock.values) {
        final said = AttendanceGate.explain(block, site: site);
        expect(said, isNotEmpty, reason: 'no sentence for ${block.name}');
        expect(
          said.length,
          greaterThan(20),
          reason: '${block.name} is explained too thinly to act on',
        );
      }
    });
  });

  group('a punch on the wire', () {
    test('round trips, refusal and all', () {
      final punch = AttendancePunch(
        id: 'at-1',
        staffId: 'st-1',
        staffName: 'Ramesh Kumar',
        kind: PunchKind.punchOut,
        at: _at(18),
        lat: 26.912434,
        lng: 75.787270,
        accuracyM: 8.5,
        distanceM: 42.25,
        mocked: true,
        accepted: false,
        block: PunchBlock.mocked,
        verified: true,
        note: 'device reported 3 m, server measured 42 m',
      );
      final back = AttendancePunch.fromJson(punch.toJson());
      expect(back.toJson(), punch.toJson());
      expect(back.block, PunchBlock.mocked);
      expect(back.accepted, isFalse);
    });

    test('a row from the database is verified by construction', () {
      // `fromServer` is the difference between "the backend checked this"
      // and "a phone said so". Only rows that came through
      // `punch_attendance` may claim the first.
      final server = AttendancePunch.fromServer(const {
        'id': 'at-2',
        'staff_id': 'st-1',
        'kind': 'in',
        'accepted': true,
        'block': 'ok',
      });
      expect(server.verified, isTrue);

      final device = AttendancePunch.fromJson(const {
        'id': 'at-3',
        'staff_id': 'st-1',
        'kind': 'in',
      });
      expect(device.verified, isFalse);
    });
  });

  group('the register on the device', () {
    test('survives being written out and read back', () async {
      final container = await _shop();
      final data = container
          .read(adminProvider)
          .copyWith(
            attendance: [
              _p('a', PunchKind.punchIn, _at(9)),
              _p(
                'a',
                PunchKind.punchOut,
                _at(17),
                accepted: false,
                block: PunchBlock.tooFar,
              ),
            ],
          );
      final back = AdminData.fromJson(data.toJson());
      expect(back.attendance, hasLength(2));
      expect(back.attendance.last.block, PunchBlock.tooFar);
    });

    test('goes with the session on sign-out', () {
      // The console is single-tenant and the register names people. It must
      // not be sitting there for whoever signs in next.
      final data = const AdminData().copyWith(
        attendance: [_p('a', PunchKind.punchIn, _at(9))],
      );
      expect(data.attendance, hasLength(1));
      expect(data.signedOut().attendance, isEmpty);
    });

    test('a punch with no location still says where it thinks it was', () {
      final punch = _p('a', PunchKind.punchIn, _at(9));
      expect(punch.lat, 0);
      expect(punch.distanceM, 0);
      expect(punch.verified, isFalse);
    });
  });

  group('distance', () {
    test(
      'agrees with the database formula closely enough for a 5 m circle',
      () {
        // Two points about eleven metres apart in Jaipur. The client uses an
        // ellipsoidal formula and `geo_distance_m` a spherical one; at these
        // ranges the two must not disagree by anything that matters to a
        // five metre decision.
        final d = AttendanceGate.distanceM(
          26.912434,
          75.787270,
          26.912534,
          75.787270,
        );
        expect(d, closeTo(11.1, 0.5));
      },
    );

    test('reads out in units somebody standing outside can use', () {
      expect(AttendanceGate.metres(3.24), '3.2 m');
      expect(AttendanceGate.metres(42.4), '42 m');
      expect(AttendanceGate.metres(1500), '1.5 km');
    });
  });

  group('the gate', () {
    test(
      'refuses before touching the GPS when nowhere has been pinned',
      () async {
        final reading = await AttendanceGate.read(site: null);
        expect(reading.block, PunchBlock.noSite);
        expect(reading.located, isFalse);
      },
    );

    test('a plugin that cannot answer is no fix, not a crash', () async {
      // There is no location plugin behind a test binding, so this is the
      // same shape as a handset whose location service has fallen over:
      // the gate has to come back with a verdict rather than an exception,
      // or the punch screen goes white on exactly the phones least able to
      // afford it.
      final reading = await AttendanceGate.read(
        site: const AttendanceSite(lat: 26.912434, lng: 75.787270),
      );
      expect(reading.ok, isFalse);
      expect(reading.located, isFalse);
    });
  });

  test('the garage fingerprint is unmoved by pinning a location twice', () {
    // Two encodings of the same workshop must fingerprint the same, or the
    // console and the backend push the same row at each other forever.
    const site = AttendanceSite(lat: 26.912434, lng: 75.787270, radiusM: 5);
    final once = _garage.copyWith(attendanceSite: site);
    final twice = Garage.fromJson(once.toJson());
    expect(
      GarageGateway.fingerprint(twice.toJson()),
      GarageGateway.fingerprint(once.toJson()),
    );
  });
}
