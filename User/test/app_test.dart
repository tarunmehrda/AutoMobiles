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
import 'package:garagepro/state/draft_state.dart';

Future<AppController> _controller() async {
  SharedPreferences.setMockInitialValues({});
  final store = await LocalStore.open();
  return AppController(store, SupabaseGateway.instance);
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

  group('booking draft', () {
    test('totals add tax on top of the discounted subtotal', () {
      final pkg = Seed.packageById('standard-service')!;
      var draft = const BookingDraft();
      draft = draft.copyWith(lines: [
        CartLine(
          id: pkg.id,
          name: pkg.name,
          price: pkg.price,
          mrp: pkg.mrp,
          isAddOn: false,
          durationHours: pkg.durationHours,
        ),
      ]);

      expect(draft.subtotal, pkg.price);
      expect(draft.itemSavings, pkg.mrp - pkg.price);
      expect(draft.gst, (draft.taxable * 0.18).round());
      expect(draft.total, draft.taxable + draft.gst);
    });

    test('pickup adds the fee before tax', () {
      final pkg = Seed.packageById('basic-service')!;
      final draft = BookingDraft(
        mode: ServiceMode.pickup,
        lines: [
          CartLine(
            id: pkg.id,
            name: pkg.name,
            price: pkg.price,
            mrp: pkg.mrp,
            isAddOn: false,
          ),
        ],
      );
      expect(draft.pickupFee, Seed.pickupFee);
      expect(draft.taxable, pkg.price + Seed.pickupFee);
    });

    test('slot merges the chosen date and time', () {
      final draft = BookingDraft(
        slotDate: DateTime(2026, 9, 14),
        slotTime: '02:00 PM',
      );
      expect(draft.slot, DateTime(2026, 9, 14, 14));
      expect(draft.slotReady, isTrue);
    });
  });

  group('business rules', () {
    test('repair cannot start before the customer approves', () async {
      final c = await _controller();
      await c.verifyOtp(phone: '+919876543210', entered: '123456', expected: null);
      c.saveProfile(name: 'Test User');
      c.addVehicle(_vehicle());

      final booking = c.state.bookings
          .firstWhere((b) => b.stage == JobStage.awaitingApproval);

      c.advanceBooking(booking.id);
      expect(c.state.bookingById(booking.id)!.stage, JobStage.awaitingApproval,
          reason: 'the tracker must not move past approval on its own');

      c.dispose();
    });

    test('approving only some items records exactly those', () async {
      final c = await _controller();
      await c.verifyOtp(phone: '+919876543210', entered: '123456', expected: null);
      c.saveProfile(name: 'Test User');
      c.addVehicle(_vehicle());

      final booking = c.state.bookings
          .firstWhere((b) => b.stage == JobStage.awaitingApproval);
      final estimate = c.state.latestEstimate(booking.id)!;
      final chosen = {estimate.items.first.id};

      c.approveEstimate(booking.id, chosen);

      final after = c.state.latestEstimate(booking.id)!;
      expect(after.status, EstimateStatus.partiallyApproved);
      expect(after.approvedCount, 1);
      expect(after.approvedTotal, estimate.items.first.total);
      expect(after.approvedAt, isNotNull);
      expect(after.approvedBy, 'Test User');
      expect(c.state.bookingById(booking.id)!.stage, JobStage.repairInProgress);

      c.dispose();
    });

    test('declining everything skips repair entirely', () async {
      final c = await _controller();
      await c.verifyOtp(phone: '+919876543210', entered: '123456', expected: null);
      c.saveProfile(name: 'Test User');
      c.addVehicle(_vehicle());

      final booking = c.state.bookings
          .firstWhere((b) => b.stage == JobStage.awaitingApproval);
      c.approveEstimate(booking.id, const {});

      expect(c.state.latestEstimate(booking.id)!.status,
          EstimateStatus.rejected);
      expect(c.state.bookingById(booking.id)!.stage, JobStage.qualityCheck);

      c.dispose();
    });

    test('a revision keeps the old version and re-gates the job', () async {
      final c = await _controller();
      await c.verifyOtp(phone: '+919876543210', entered: '123456', expected: null);
      c.saveProfile(name: 'Test User');
      c.addVehicle(_vehicle());

      final booking = c.state.bookings
          .firstWhere((b) => b.stage == JobStage.awaitingApproval);
      c.approveEstimate(booking.id, {c.state.latestEstimate(booking.id)!.items.first.id});
      c.issueRevisedEstimate(booking.id, reason: 'Found a worn bush');

      final versions = c.state.estimatesFor(booking.id);
      expect(versions.length, 2);
      expect(versions.first.version, 1);
      expect(versions.last.version, 2);
      expect(versions.last.items.any((i) => i.isNew), isTrue);
      expect(c.state.bookingById(booking.id)!.stage, JobStage.awaitingApproval);

      c.dispose();
    });

    test('cancelling keeps the booking on record', () async {
      final c = await _controller();
      await c.verifyOtp(phone: '+919876543210', entered: '123456', expected: null);
      c.saveProfile(name: 'Test User');
      c.addVehicle(_vehicle());

      final booking = c.state.bookings.first;
      final before = c.state.bookings.length;
      c.cancelBooking(booking.id, 'Plan changed');

      expect(c.state.bookings.length, before);
      expect(c.state.bookingById(booking.id)!.status, BookingStatus.cancelled);
      expect(c.state.bookingById(booking.id)!.cancelReason, 'Plan changed');

      c.dispose();
    });

    test('removing a vehicle keeps its service history', () async {
      final c = await _controller();
      await c.verifyOtp(phone: '+919876543210', entered: '123456', expected: null);
      c.saveProfile(name: 'Test User');
      final v = c.addVehicle(_vehicle());

      final historyBefore = c.state.bookings.length;
      c.removeVehicle(v.id);

      expect(c.state.vehicles, isEmpty);
      expect(c.state.bookings.length, historyBefore);

      c.dispose();
    });

    test('payment attaches to the invoice and closes the job', () async {
      final c = await _controller();
      await c.verifyOtp(phone: '+919876543210', entered: '123456', expected: null);
      c.saveProfile(name: 'Test User');
      c.addVehicle(_vehicle());

      final booking = c.state.bookings
          .firstWhere((b) => b.stage == JobStage.awaitingApproval);
      c.approveEstimate(booking.id, const {});
      final invoice = c.ensureInvoice(booking.id);
      expect(invoice, isNotNull);
      expect(invoice!.paid, isFalse);

      final paid = await c.payInvoice(booking.id, PaymentMethod.upi);
      expect(paid!.paid, isTrue);
      expect(paid.method, PaymentMethod.upi);
      expect(paid.transactionId, isNotNull);
      expect(paid.bookingId, booking.id);

      c.completeBooking(booking.id);
      expect(c.state.bookingById(booking.id)!.status, BookingStatus.completed);

      c.dispose();
    });
  });

  group('persistence', () {
    test('a full snapshot survives a JSON round trip', () async {
      final c = await _controller();
      await c.verifyOtp(phone: '+919876543210', entered: '123456', expected: null);
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
