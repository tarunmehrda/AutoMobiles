import 'package:flutter_test/flutter_test.dart';

import 'package:garagepro_admin/data/models/entities.dart';
import 'package:garagepro_admin/data/models/enums.dart';
import 'package:garagepro_admin/data/repo/admin_data.dart';
import 'package:garagepro_admin/data/seed/vehicle_catalog.dart';

/// A booked car must reach the counter as the customer described it.
///
/// Until 23 Sep 2026 a booking carried one string, "Brand Model", and the
/// console split it on the first space: a customer who booked a Maruti
/// Suzuki Swift, Manual, 60,000 km got a job card for brand "Maruti", model
/// "Suzuki Swift", petrol, no gearbox, 0 km. These pin the shape that
/// replaced it (supabase/18_booking_vehicle_details.sql).
void main() {
  final makes = VehicleCatalog.models.keys;

  Booking row(Map<String, dynamic> extra) => Booking.fromJson({
        'id': 'req-bk-1',
        'name': 'Rohit',
        'phone': '9812345678',
        'at': '2026-09-24T04:30:00Z',
        'reg_no': 'RJ14AB1234',
        'vehicle': 'Maruti Suzuki Swift',
        'note': 'General service',
        'accepted': false,
        ...extra,
      });

  group('a booking from the new customer app', () {
    final b = row({
      'brand': 'Maruti Suzuki',
      'model': 'Swift',
      'variant': 'VXi',
      'fuel': 'petrol',
      'transmission': 'manual',
      'year': 2021,
      'odometer_km': 60000,
      'mode': 'pickup',
      'customer_note': 'Brakes squeak',
    });

    test('carries every detail the customer typed', () {
      expect(b.brandModel(makes), (brand: 'Maruti Suzuki', model: 'Swift'));
      expect(b.variant, 'VXi');
      expect(b.fuel, FuelType.petrol);
      expect(b.transmission, Transmission.manual);
      expect(b.year, 2021);
      expect(b.odometerKm, 60000);
      expect(b.pickup, isTrue);
      expect(b.customerNote, 'Brakes squeak');
    });

    test('survives the on-device store', () {
      final again = Booking.fromJson(b.toJson());
      expect(again.odometerKm, 60000);
      expect(again.transmission, Transmission.manual);
      expect(again.brandModel(makes).brand, 'Maruti Suzuki');
      expect(again.pickup, isTrue);
    });

    test('is never written back by the console', () {
      // An upsert only sets the columns it is sent. Leaving the customer's
      // columns out is what keeps accepting a booking from blanking them.
      final pushed = b.copyWith(accepted: true, jobCardId: 'jc-1').toRow();
      expect(pushed['accepted'], isTrue);
      expect(pushed['job_card_id'], 'jc-1');
      for (final key in const [
        'brand', 'model', 'variant', 'fuel', 'transmission', 'year',
        'odometer_km', 'mode', 'customer_note',
      ]) {
        expect(pushed.containsKey(key), isFalse, reason: key);
      }
    });
  });

  group('a booking from an older app, with only the one string', () {
    test('splits on the longest make it knows, not the first space', () {
      final b = row({});
      expect(b.brandModel(makes), (brand: 'Maruti Suzuki', model: 'Swift'));
      expect(b.fuel, isNull, reason: 'no guess that would overwrite the record');
      expect(b.transmission, isNull);
      expect(b.odometerKm, isNull);
    });

    test('falls back to the first space for a make it does not know', () {
      final b = row({'vehicle': 'Zorbo Q7 Turbo'});
      expect(b.brandModel(makes), (brand: 'Zorbo', model: 'Q7 Turbo'));
    });

    test('copes with no vehicle at all', () {
      final b = row({'vehicle': ''});
      expect(b.brandModel(makes), (brand: '', model: ''));
    });
  });

  group('a vehicle', () {
    test('keeps its gearbox through JSON, and sends "" when unknown', () {
      const v = Vehicle(
        id: 'v1',
        customerId: 'c1',
        regNo: 'RJ14AB1234',
        brand: 'Maruti Suzuki',
        model: 'Swift',
        transmission: Transmission.automatic,
      );
      expect(Vehicle.fromJson(v.toJson()).transmission,
          Transmission.automatic);

      const bare = Vehicle(
        id: 'v2',
        customerId: 'c1',
        regNo: 'RJ14AB9999',
        brand: 'Honda',
        model: 'City',
      );
      expect(bare.toJson()['transmission'], '');
      expect(Vehicle.fromJson(bare.toJson()).transmission, isNull);
    });
  });

  group('a customer', () {
    test('is found by phone however the number was written', () {
      final data = const AdminData().copyWith(
        customers: [
          Customer(
            id: 'c1',
            name: 'Rohit',
            phone: '+91 98123 45678',
            createdAt: DateTime(2026, 9, 1),
          ),
        ],
      );
      expect(data.customerByPhone('9812345678')?.id, 'c1');
      expect(data.customerByPhone('919812345678')?.id, 'c1');
      expect(data.customerByPhone('98123 45678')?.id, 'c1');
      expect(data.customerByPhone('9812345679'), isNull);
      expect(data.customerByPhone(''), isNull);
    });
  });
}
