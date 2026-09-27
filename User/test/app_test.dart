import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:garagepro/core/utils/formatters.dart';
import 'package:garagepro/data/models/entities.dart';
import 'package:garagepro/data/models/enums.dart';
import 'package:garagepro/data/repo/app_data.dart';
import 'package:garagepro/data/repo/local_store.dart';
import 'package:garagepro/data/models/workshop.dart';
import 'package:garagepro/data/repo/supabase_gateway.dart';
import 'package:garagepro/data/seed/catalog_seed.dart';
import 'package:garagepro/data/seed/media.dart';
import 'package:garagepro/state/app_state.dart';

Future<AppController> _controller() async {
  SharedPreferences.setMockInitialValues({});
  final store = await LocalStore.open();
  final c = AppController(store, SupabaseGateway.instance);
  // The constructor kicks off `restoreAccount()` without waiting for it.
  // Let that settle before a test starts asserting, otherwise what passes
  // depends on how many awaits happen to sit above the assertion — which
  // is how removing one unrelated `await` broke six tests at once.
  await Future<void>.delayed(Duration.zero);
  return c;
}

Vehicle _vehicle() => Vehicle(
      id: 'v1',
      brand: 'Hyundai',
      model: 'Creta',
      regNumber: 'PB65AB1234',
      fuel: FuelType.diesel,
      transmission: Transmission.automatic,
      year: 2021,
      odometerKm: 42300,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('formatting', () {
    test('money uses the Indian grouping', () {
      expect(Fmt.money(3032), '₹3,032');
      expect(Fmt.money(1020700), '₹10,20,700');
    });

    test('duration reads naturally', () {
      expect(Fmt.duration(0.5), '30 mins');
      expect(Fmt.duration(6), '6 hrs');
      expect(Fmt.duration(1.5), '1 hr 30 min');
      expect(Fmt.duration(48), '2 days');
    });

    test('initials handle one and two word names', () {
      expect(Fmt.initials('Rohit'), 'R');
      expect(Fmt.initials('Rohit Verma'), 'RV');
    });
  });

  group('catalogue', () {
    test('every package belongs to a real category', () {
      for (final p in Seed.packages) {
        expect(Seed.categoryById(p.categoryId), isNotNull,
            reason: '${p.id} points at a missing category');
      }
    });

    test('offer price never exceeds MRP', () {
      for (final p in Seed.packages) {
        expect(p.price <= p.mrp, isTrue, reason: p.id);
      }
    });

    test('model ids are unique', () {
      final ids = Seed.models.map((m) => m.id).toList();
      expect(ids.toSet().length, ids.length,
          reason: 'two models share an id, so they would share a photo');
    });

    test('the catalogue covers the brands a garage in India actually sees', () {
      final names = Seed.brands.map((b) => b.name).toSet();
      // Discontinued here, but still on the road in large numbers.
      for (final legacy in [
        'Chevrolet',
        'Ford',
        'Fiat',
        'Datsun',
        'Hindustan Motors',
      ]) {
        expect(names, contains(legacy),
            reason: 'workshops still service $legacy every week');
      }
      expect(Seed.models.length, greaterThan(250));
    });

    test('every model with a declared photo is a real model', () {
      final ids = Seed.models.map((m) => m.id).toSet();
      for (final id in Media.carsWithPhotos) {
        expect(ids, contains(id),
            reason: '$id has a photo but no model to show it on');
      }
    });

    test('a model without its own photo still gets a picture', () {
      final noPhoto = Seed.models
          .firstWhere((m) => !Media.carsWithPhotos.contains(m.id));
      final path = Media.carPhoto(noPhoto.id, body: noPhoto.body);
      expect(path, isNot(contains('/${noPhoto.id}.jpg')));
      expect(path, startsWith('assets/'));
    });

    test('every model belongs to a real brand', () {
      for (final m in Seed.models) {
        expect(Seed.brandById(m.brandId), isNotNull, reason: m.id);
      }
    });
  });

  // The cart is gone: a booking is now made in one pass from the appointment
  // wizard, so the only totals worth testing are the ones on the booking.
  group('appointment', () {
    test('a booking with no services still confirms at zero', () async {
      final c = await _controller();
      c.signInOffline(phone: '+919876543210');
      c.saveProfile(name: 'Test User');
      final v = c.addVehicle(_vehicle());

      final booking = c.createBooking(
        vehicleId: v.id,
        lines: const [],
        mode: ServiceMode.garage,
        slot: DateTime(2026, 9, 17, 10),
      );

      expect(booking.lines, isEmpty);
      expect(booking.total, 0);
      expect(booking.status, BookingStatus.upcoming);
      expect(booking.slot, DateTime(2026, 9, 17, 10));
    });

    test('pick and drop carries its fee onto the booking', () async {
      final c = await _controller();
      c.signInOffline(phone: '+919876543210');
      c.saveProfile(name: 'Test User');
      final v = c.addVehicle(_vehicle());

      final booking = c.createBooking(
        vehicleId: v.id,
        lines: const [
          CartLine(
            id: 's1',
            name: 'General Servicing',
            price: 2000,
            mrp: 2000,
            isAddOn: false,
          ),
        ],
        mode: ServiceMode.pickup,
        slot: DateTime(2026, 9, 17, 10),
      );

      expect(booking.pickupFee, Seed.pickupFee);
      expect(booking.taxable, 2000 + Seed.pickupFee);
      expect(booking.total, booking.taxable + booking.gst);
    });
  });

  // What the whole app now hangs on: a booking is an appointment until the
  // workshop opens a job card against it, and from then on every stage, line
  // and rupee the customer sees is the workshop's.
  group('the workshop drives the booking', () {
    /// One instant, shared by the booking slot and the job card.
    ///
    /// These used to be two separate `DateTime.now()` calls three hours
    /// apart, and `_cardFor` binds a card to a booking only when the two
    /// fall on the same day — so every run after 21:00 local time failed
    /// six tests and every run before it passed. Anchoring both to the same
    /// instant is what makes "the same day" mean something.
    final slot = DateTime.now().add(const Duration(hours: 3));

    /// A signed-in customer with one car and one booking for it today.
    Future<(AppController, Booking)> booked() async {
      final c = await _controller();
      c.signInOffline(phone: '+919876543210');
      c.saveProfile(name: 'Test User');
      final v = c.addVehicle(_vehicle());
      final booking = c.createBooking(
        vehicleId: v.id,
        lines: const [
          CartLine(
            id: 'standard-service',
            name: 'Standard service',
            price: 3499,
            mrp: 4299,
            isAddOn: false,
          ),
        ],
        mode: ServiceMode.garage,
        slot: slot,
      );
      return (c, booking);
    }

    /// A job card in the shape `my_job_cards` hands back.
    WorkshopCard card({
      String status = 'open',
      List<Map<String, dynamic>> items = const [],
      double paid = 0,
      DateTime? openedAt,
    }) =>
        WorkshopCard.fromJson({
          'id': 'j1',
          'number': 'A0914-001',
          'status': status,
          'opened_at': (openedAt ?? slot).toIso8601String(),
          'completed_at': status == 'open' ? null : DateTime.now().toIso8601String(),
          'closed_at': status == 'closed' ? DateTime.now().toIso8601String() : null,
          'garage_id': 'g1',
          'garage_name': 'Sharma Motors',
          'reg_no': 'PB65AB1234',
          'vehicle_title': 'Hyundai Creta SX',
          'mechanic': 'Rakesh',
          'odometer_km': 42300,
          'fuel_percent': 40,
          'voices': ['Brake noise'],
          'accessories': ['Stepney'],
          'photos': <String>[],
          'work_note': 'Front pads down to 2mm',
          'discount': 0,
          'tax_rate': '0.1800',
          'paid': paid,
          'items': items,
        });

    test('a fresh account starts with nothing on it', () async {
      final c = await _controller();
      c.signInOffline(phone: '+919876543210');
      c.saveProfile(name: 'Test User');
      c.addVehicle(_vehicle());

      expect(c.state.bookings, isEmpty);
      expect(c.state.invoices, isEmpty);
      expect(c.state.estimates, isEmpty);
      expect(c.state.inspections, isEmpty);
      expect(c.state.notifications, isEmpty);
      expect(c.state.chat, isEmpty);
      expect(c.state.workshop.isLinked, isFalse);

      c.dispose();
    });

    test('a booking the counter has not touched stays an appointment',
        () async {
      final (c, booking) = await booked();

      expect(c.state.bookingById(booking.id)!.stage, JobStage.confirmed);
      expect(c.state.bookingById(booking.id)!.status, BookingStatus.upcoming);

      // No job cards upstream — nothing moves.
      c.applyWorkshop(const []);
      expect(c.state.bookingById(booking.id)!.stage, JobStage.confirmed);

      c.dispose();
    });

    test('the request the workshop accepted binds the booking to its card',
        () async {
      final (c, booking) = await booked();

      c.applyWorkshop([card(openedAt: DateTime(2000))], requests: {
        'req-${booking.id}': {'job_card_id': 'j1', 'accepted': true},
      });

      final after = c.state.bookingById(booking.id)!;
      expect(after.status, BookingStatus.active);
      expect(after.jobCard, isNotNull);
      expect(after.jobCard!.number, 'A0914-001');
      expect(after.jobCard!.workNote, 'Front pads down to 2mm');
      expect(after.technician, 'Rakesh');

      c.dispose();
    });

    test('a card opened on the day for the same car is the same visit',
        () async {
      final (c, booking) = await booked();

      // No request row at all — the counter opened a card directly.
      c.applyWorkshop([card()]);

      expect(c.state.bookingById(booking.id)!.jobCard!.number, 'A0914-001');

      c.dispose();
    });

    test('the stage follows the card, from received to delivered', () async {
      final (c, booking) = await booked();
      JobStage stage() => c.state.bookingById(booking.id)!.stage;

      c.applyWorkshop([card()]);
      expect(stage(), JobStage.received,
          reason: 'a card with no lines on it is only an open card');

      c.applyWorkshop([
        card(items: const [
          {'id': 'l1', 'kind': 'job', 'name': 'Brake pads', 'qty': '1',
           'rate': '400.00', 'state': 'pending'},
        ])
      ]);
      expect(stage(), JobStage.estimateSent);

      c.applyWorkshop([
        card(items: const [
          {'id': 'l1', 'kind': 'job', 'name': 'Brake pads', 'qty': '1',
           'rate': '400.00', 'state': 'running'},
        ])
      ]);
      expect(stage(), JobStage.repairInProgress);

      c.applyWorkshop([
        card(status: 'complete', items: const [
          {'id': 'l1', 'kind': 'job', 'name': 'Brake pads', 'qty': '1',
           'rate': '400.00', 'state': 'done'},
        ])
      ]);
      expect(stage(), JobStage.readyForDelivery);

      c.applyWorkshop([
        card(status: 'closed', paid: 472, items: const [
          {'id': 'l1', 'kind': 'job', 'name': 'Brake pads', 'qty': '1',
           'rate': '400.00', 'state': 'done'},
        ])
      ]);
      expect(stage(), JobStage.delivered);
      expect(c.state.bookingById(booking.id)!.status, BookingStatus.completed);

      c.dispose();
    });

    test('nothing moves on its own once the workshop has stopped', () async {
      final (c, booking) = await booked();
      c.applyWorkshop([
        card(items: const [
          {'id': 'l1', 'kind': 'job', 'name': 'Brake pads', 'qty': '1',
           'rate': '400.00', 'state': 'running'},
        ])
      ]);
      final stage = c.state.bookingById(booking.id)!.stage;

      // The old build advanced the tracker on a timer. Give it longer than
      // that timer ever waited and the stage must be exactly where the
      // workshop left it.
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(c.state.bookingById(booking.id)!.stage, stage);

      c.dispose();
    });

    test('the quote is the workshop line items, split parts and labour',
        () async {
      final (c, booking) = await booked();
      c.applyWorkshop([
        card(items: const [
          {'id': 'l1', 'kind': 'job', 'name': 'Brake labour', 'qty': '1',
           'rate': '400.00', 'state': 'pending'},
          {'id': 'l2', 'kind': 'spare', 'name': 'Disc', 'qty': '2',
           'rate': '300.00', 'state': 'pending'},
        ])
      ]);

      final quote = c.state.latestEstimate(booking.id)!;
      expect(quote.items.length, 2);
      expect(quote.items.first.labour, 400);
      expect(quote.items.first.parts, 0);
      expect(quote.items.last.parts, 600);
      expect(quote.total, 1000);

      c.dispose();
    });

    test('the bill is the workshop bill, at the workshop tax rate', () async {
      final (c, booking) = await booked();
      c.applyWorkshop([
        card(status: 'complete', items: const [
          {'id': 'l1', 'kind': 'job', 'name': 'Brake labour', 'qty': '1',
           'rate': '1000.00', 'state': 'done'},
        ])
      ]);

      final bill = c.state.invoices[booking.id]!;
      expect(bill.number, 'A0914-001');
      expect(bill.jobCardNumber, 'A0914-001');
      expect(bill.subtotal, 1000);
      expect(bill.taxRate, 0.18);
      expect(bill.gst, 180);
      expect(bill.total, 1180);
      expect(bill.paid, isFalse);

      c.dispose();
    });

    test('the workshop settling the card marks the bill paid', () async {
      final (c, booking) = await booked();
      c.applyWorkshop([
        card(status: 'closed', paid: 1180, items: const [
          {'id': 'l1', 'kind': 'job', 'name': 'Brake labour', 'qty': '1',
           'rate': '1000.00', 'state': 'done'},
        ])
      ]);

      expect(c.state.invoices[booking.id]!.paid, isTrue);

      c.dispose();
    });

    test('a payment made in the app is never un-paid by the workshop',
        () async {
      final (c, booking) = await booked();
      final items = const [
        {'id': 'l1', 'kind': 'job', 'name': 'Brake labour', 'qty': '1',
         'rate': '1000.00', 'state': 'done'},
      ];
      c.applyWorkshop([card(status: 'complete', items: items)]);

      final paid = await c.payInvoice(booking.id, PaymentMethod.upi);
      expect(paid!.paid, isTrue);

      // The counter has not recorded the money yet — the app's own record of
      // it still stands.
      c.applyWorkshop([card(status: 'complete', items: items)]);
      expect(c.state.invoices[booking.id]!.paid, isTrue);
      expect(c.state.invoices[booking.id]!.method, PaymentMethod.upi);

      c.dispose();
    });

    test('a stage only ever announces itself once', () async {
      final (c, booking) = await booked();
      final cards = [card()];

      c.applyWorkshop(cards);
      final first = c.state.notifications.length;
      c.applyWorkshop(cards);
      c.applyWorkshop(cards);

      expect(c.state.notifications.length, first,
          reason: 're-reading the same card must not re-notify');

      c.dispose();
    });

    test('a cancelled booking is left alone', () async {
      final (c, booking) = await booked();
      await c.cancelBooking(booking.id, 'Plan changed');

      c.applyWorkshop([card()]);

      final after = c.state.bookingById(booking.id)!;
      expect(after.status, BookingStatus.cancelled);
      expect(after.jobCard, isNull);

      c.dispose();
    });

    test('cancelling keeps the booking on record', () async {
      final (c, booking) = await booked();
      final before = c.state.bookings.length;
      await c.cancelBooking(booking.id, 'Plan changed');

      expect(c.state.bookings.length, before);
      expect(c.state.bookingById(booking.id)!.status, BookingStatus.cancelled);
      expect(c.state.bookingById(booking.id)!.cancelReason, 'Plan changed');

      c.dispose();
    });

    test('removing a vehicle keeps its service history', () async {
      final (c, booking) = await booked();
      final before = c.state.bookings.length;

      c.removeVehicle(c.state.vehicles.first.id);

      expect(c.state.vehicles, isEmpty);
      expect(c.state.bookings.length, before);
      expect(c.state.bookingById(booking.id), isNotNull);

      c.dispose();
    });
  });

  group('persistence', () {
    test('a full snapshot survives a JSON round trip', () async {
      final c = await _controller();
      c.signInOffline(phone: '+919876543210');
      c.saveProfile(name: 'Test User', email: 'test@example.com');
      c.addVehicle(_vehicle());

      final restored = AppData.fromJson(c.state.toJson());

      expect(restored.user!.name, 'Test User');
      expect(restored.vehicles.length, 1);
      expect(restored.vehicles.first.regNumber, 'PB65AB1234');
      expect(restored.bookings.length, c.state.bookings.length);
      expect(restored.inspections.length, c.state.inspections.length);
      expect(restored.estimates.length, c.state.estimates.length);
      expect(restored.invoices.length, c.state.invoices.length);

      c.dispose();
    });
  });

  group('workshop cards', () {
    // Exactly the shape `my_job_cards` returns: numerics as strings, arrays
    // as lists, timestamps with an offset.
    Map<String, dynamic> row({String status = 'open'}) => {
          'id': 'j1',
          'number': 'A0914-001',
          'status': status,
          'opened_at': '2026-09-14T09:30:00+00:00',
          'garage_id': 'g1',
          'garage_name': 'Sharma Motors',
          'reg_no': 'PB65AB1234',
          'vehicle_title': 'Hyundai Creta SX',
          'mechanic': 'Rakesh',
          'odometer_km': 42300,
          'fuel_percent': 40,
          'voices': ['Brake noise'],
          'accessories': ['Stepney'],
          'photos': <String>[],
          'work_note': '',
          'discount': '100.00',
          'tax_rate': '0.1800',
          'paid': '500.00',
          'items': [
            {'id': 'l1', 'kind': 'job', 'name': 'Brake pads', 'qty': '2',
             'rate': '400.00', 'state': 'done'},
            {'id': 'l2', 'kind': 'spare', 'name': 'Disc', 'qty': '1',
             'rate': '300.00', 'state': 'pending'},
          ],
        };

    test('the bill matches what the workshop billed', () {
      final card = WorkshopCard.fromJson(row());
      expect(card.subTotal, 1100);
      // Discount comes off before tax, exactly as on the garage's copy.
      expect(card.taxable, 1000);
      expect(card.tax, 180);
      expect(card.total, 1180);
      expect(card.paid, 500);
      expect(card.balance, 680);
      expect(card.settled, isFalse);
    });

    test('progress counts the lines the workshop has finished', () {
      final card = WorkshopCard.fromJson(row());
      // One of two done: 0.15 + 0.7 * 0.5
      expect(card.progress, closeTo(0.5, 0.001));
      expect(WorkshopCard.fromJson(row(status: 'closed')).progress, 1);
    });

    test('only open and complete cards are live', () {
      expect(WorkshopCard.fromJson(row()).isLive, isTrue);
      expect(WorkshopCard.fromJson(row(status: 'complete')).isLive, isTrue);
      expect(WorkshopCard.fromJson(row(status: 'closed')).isLive, isFalse);
    });

    test('a card survives the round trip through the on-device store', () {
      final card = WorkshopCard.fromJson(row());
      final back = WorkshopCard.fromJson(card.toJson());
      expect(back.number, card.number);
      expect(back.total, card.total);
      expect(back.items.length, 2);
      expect(back.voices, ['Brake noise']);
      expect(back.openedAt, card.openedAt);
    });

    test('a snapshot keeps the workshop cards it was given', () {
      final data = const AppData()
          .copyWith(workshopCards: [WorkshopCard.fromJson(row())]);
      final back = AppData.fromJson(data.toJson());
      expect(back.workshopCards.single.number, 'A0914-001');
      expect(back.liveWorkshopCards, hasLength(1));
    });
  });

  group('coupons', () {
    test('percentage coupons respect the cap', () {
      final coupon = Seed.coupons().firstWhere((c) => c.code == 'SAVE10');
      expect(coupon.discountFor(5000), 500);
      expect(coupon.discountFor(100000), coupon.maxDiscount);
    });

    test('a coupon below its minimum order gives nothing', () {
      final coupon = Seed.coupons().firstWhere((c) => c.code == 'FIRST500');
      expect(coupon.discountFor(500), 0);
      expect(coupon.discountFor(3000), 500);
    });
  });
}
