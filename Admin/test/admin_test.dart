import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:garagepro_admin/core/utils/formatters.dart';
import 'package:garagepro_admin/core/utils/words.dart';
import 'package:garagepro_admin/data/models/entities.dart';
import 'package:garagepro_admin/data/models/enums.dart';
import 'package:garagepro_admin/data/repo/admin_data.dart';
import 'package:garagepro_admin/data/repo/device_contacts.dart';
import 'package:garagepro_admin/data/repo/garage_gateway.dart';
import 'package:garagepro_admin/data/repo/local_store.dart';
import 'package:garagepro_admin/data/repo/platform_gateway.dart';
import 'package:garagepro_admin/data/seed/seed.dart';
import 'package:garagepro_admin/features/search/search_page.dart';
import 'package:garagepro_admin/state/admin_state.dart';

/// A workshop behind a real provider container, built the way the console
/// builds one — profile, rate card, customer, car — so the tests exercise the
/// same wiring the app does rather than poking at the notifier's state.
class _Shop {
  _Shop(this._container);

  final ProviderContainer _container;

  AdminController get c => _container.read(adminProvider.notifier);
  AdminData get data => _container.read(adminProvider);

  JobCard card(String id) => data.jobById(id)!;

  /// Opens a fresh card against the workshop's first customer.
  JobCard open() => c.createJobCard(
    customerId: data.customers.first.id,
    vehicleId: data.vehicles.first.id,
    odometerKm: 50000,
    fuelPercent: 50,
  );
}

/// A rate card with one row of each kind, which is all any of these tests
/// need to bill against.
void _rateCard(AdminController c) {
  c.addMaster(kind: LineKind.job, name: 'General Service Labour', rate: 900);
  c.addMaster(
    kind: LineKind.spare,
    name: 'Brake Pad Set',
    partNo: 'BP-2204',
    rate: 1450,
    stock: 8,
  );
  c.addMaster(
    kind: LineKind.lube,
    name: 'Engine Oil',
    rate: 300,
    stock: 48,
    unit: 'ltr',
  );
}

/// Workshop ids as the server mints them (UUIDs), unlike the `garage-…` id
/// a workshop registered on the phone carries until its first sync.
const _serverA = '8f14e45f-ceea-4e67-a3c1-2b0e7d8c9a10';
const _serverB = '1c7a92d3-5b04-4f6e-9e2d-7a3b8c1d0e45';

Future<_Shop> _shop() async {
  SharedPreferences.setMockInitialValues({});
  localStore = await LocalStore.open();
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final shop = _Shop(container);

  shop.c.markSignedIn();
  shop.c.completeOnboarding();
  shop.c.saveGarage(
    const Garage(
      id: 'garage-test',
      name: 'Test Motors',
      phone: '9000000000',
      addressLine: '1 Workshop Road',
      city: 'Jaipur',
      state: 'Rajasthan',
      pin: '302020',
    ),
  );
  _rateCard(shop.c);
  shop.c.addStaff(name: 'Ramesh Kumar', phone: '9812345670', skill: 'Engine');

  final customer = shop.c.upsertCustomer(
    name: 'Vikas Gurjar',
    phone: '9696969696',
  );
  shop.c.upsertVehicle(
    customerId: customer.id,
    regNo: 'RJ14 4C 2626',
    brand: 'Maruti Suzuki',
    model: '800',
    year: 2004,
  );

  return shop;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The customer app prints the PIN beside every workshop's name, so a
  // registration cannot finish without a real one.
  group('workshop PIN', () {
    test('accepts six digits not starting with 0', () {
      expect(Fmt.isPin('302001'), isTrue);
      expect(Fmt.isPin(' 560001 '), isTrue);
      expect(Fmt.isPin(''), isFalse);
      expect(Fmt.isPin('30200'), isFalse);
      expect(Fmt.isPin('012345'), isFalse);
      expect(Fmt.isPin('302 001'), isFalse);
    });

    test('the partner register shows it with the place', () {
      const g = RegisteredGarage(
        id: 'g',
        name: 'Sharma Auto',
        city: 'Jaipur',
        state: 'Rajasthan',
        pin: '302001',
      );
      expect(g.where, 'Jaipur, Rajasthan 302001');
    });
  });

  group('money', () {
    test('formats with the Indian grouping', () {
      expect(Fmt.money(966), '₹966');
      expect(Fmt.money(1020700), '₹10,20,700');
    });

    test('line amounts round to paise, not float noise', () {
      const line = LineItem(
        id: 'l',
        kind: LineKind.spare,
        name: 'Filter',
        qty: 3,
        rate: 166.66,
      );
      expect(line.amount, 499.98);
    });

    test('spells a total out the Indian way', () {
      expect(Words.rupees(966), 'Nine Hundred Sixty Six Rupees Only');
      expect(Words.rupees(1), 'One Rupee Only');
      expect(Words.rupees(250000), 'Two Lakh Fifty Thousand Rupees Only');
      expect(
        Words.rupees(966.5),
        'Nine Hundred Sixty Six Rupees And Fifty Paise Only',
      );
    });
  });

  group('documents', () {
    test('the mechanic copy never carries pricing', () {
      expect(DocKind.mechanicCopy.showsPricing, isFalse);
      expect(DocKind.estimate.showsPricing, isTrue);
      expect(DocKind.invoice.showsPricing, isTrue);
    });

    test('job card numbers carry the day and the running count', () {
      final number = Seed.numberFor(DateTime(2026, 9, 14), 1);
      expect(number, 'A0914-001');
    });
  });

  group('lifecycle', () {
    test('an empty card cannot be completed', () async {
      final shop = await _shop();
      final card = shop.open();

      expect(shop.c.markComplete(card.id), isFalse);
      expect(shop.card(card.id).status, JobStatus.open);
    });

    test('a card cannot close before it completes', () async {
      final shop = await _shop();
      final card = shop.open();
      shop.c.addItem(card.id, kind: LineKind.job, name: 'Wash', rate: 300);

      expect(shop.c.closeJobCard(card.id), isFalse);
      expect(shop.card(card.id).status, JobStatus.open);

      expect(shop.c.markComplete(card.id), isTrue);
      expect(shop.c.closeJobCard(card.id), isTrue);
      expect(shop.card(card.id).status, JobStatus.closed);
    });

    test('the number is minted once and never changes', () async {
      final shop = await _shop();
      final card = shop.open();
      final number = card.number;

      shop.c.addItem(card.id, kind: LineKind.job, name: 'Wash', rate: 300);
      shop.c.markComplete(card.id);
      shop.c.closeJobCard(card.id);

      expect(shop.card(card.id).number, number);
    });

    test('closing schedules three service reminders', () async {
      final shop = await _shop();
      final card = shop.open();
      shop.c.addItem(card.id, kind: LineKind.job, name: 'Wash', rate: 300);
      shop.c.markComplete(card.id);
      shop.c.closeJobCard(card.id, nextServiceAt: DateTime(2027, 3, 1));

      // Reminders are the messages waiting on a future date; the check-in,
      // ready and closed notices are waiting too, but for today.
      final now = DateTime.now();
      final scheduled = shop
          .card(card.id)
          .sms
          .where((e) => e.state == SmsState.scheduled && e.at.isAfter(now))
          .toList();
      expect(scheduled.length, 3);
      // One before the date, one on it, one after.
      expect(scheduled.first.at.isBefore(scheduled.last.at), isTrue);
    });

    test('reopening drops reminders that have not gone out', () async {
      final shop = await _shop();
      final card = shop.open();
      shop.c.addItem(card.id, kind: LineKind.job, name: 'Wash', rate: 300);
      shop.c.markComplete(card.id);
      // The counter sends the "ready" text from the phone.
      final ready = shop.card(card.id).sms[1];
      shop.c.markSmsSent(card.id, ready.id);
      shop.c.closeJobCard(card.id);

      shop.c.reopenJobCard(card.id);
      final after = shop.card(card.id);
      expect(after.status, JobStatus.open);
      // Only the check-in notice is still waiting; the stale "closed"
      // notice and every reminder are gone.
      expect(
        after.sms.where((e) => e.state == SmsState.scheduled).length,
        1,
      );
      expect(after.sms.first.state, SmsState.scheduled);
      // A message that was actually sent stays on the record.
      expect(after.sms.any((e) => e.id == ready.id), isTrue);
      expect(
        after.sms.firstWhere((e) => e.id == ready.id).state,
        SmsState.delivered,
      );
    });

    test('nothing is marked sent until the phone sends it', () async {
      final shop = await _shop();
      final card = shop.open();
      expect(shop.card(card.id).sms.single.state, SmsState.scheduled);

      // One card can go without texts; the workshop setting stays on.
      final quiet = shop.c.createJobCard(
        customerId: shop.data.customers.first.id,
        vehicleId: shop.data.vehicles.first.id,
        sms: false,
      );
      expect(shop.card(quiet.id).sms.single.state, SmsState.skipped);
      expect(shop.data.smsEnabled, isTrue);
    });

    test('completion keeps the date the counter picked', () async {
      final shop = await _shop();
      final card = shop.open();
      shop.c.addItem(card.id, kind: LineKind.job, name: 'Wash', rate: 300);
      final picked = DateTime(2026, 9, 20, 17, 30);
      shop.c.markComplete(card.id, at: picked);
      expect(shop.card(card.id).completedAt, picked);
    });

    test('a closed card refuses further billing', () async {
      final shop = await _shop();
      final card = shop.open();
      shop.c.addItem(card.id, kind: LineKind.job, name: 'Wash', rate: 300);
      shop.c.markComplete(card.id);
      shop.c.closeJobCard(card.id);

      expect(
        shop.c.addItem(card.id, kind: LineKind.job, name: 'Extra', rate: 100),
        isNull,
      );
      expect(shop.card(card.id).items.length, 1);
    });
  });

  group('stock', () {
    test('a part comes off the shelf when it lands on a card', () async {
      final shop = await _shop();
      final master = shop.data.mastersOf(LineKind.spare).first;
      final before = master.stock;
      final card = shop.open();

      shop.c.addItem(
        card.id,
        kind: LineKind.spare,
        name: master.name,
        rate: master.rate,
        qty: 2,
        master: master,
      );

      expect(shop.data.masterById(master.id)!.stock, before - 2);
    });

    test('removing the line puts it back', () async {
      final shop = await _shop();
      final master = shop.data.mastersOf(LineKind.spare).first;
      final before = master.stock;
      final card = shop.open();

      final line = shop.c.addItem(
        card.id,
        kind: LineKind.spare,
        name: master.name,
        rate: master.rate,
        master: master,
      )!;
      shop.c.removeItem(card.id, line.id);

      expect(shop.data.masterById(master.id)!.stock, before);
    });

    test('a quantity change moves only the difference', () async {
      final shop = await _shop();
      final master = shop.data.mastersOf(LineKind.spare).first;
      final before = master.stock;
      final card = shop.open();

      final line = shop.c.addItem(
        card.id,
        kind: LineKind.spare,
        name: master.name,
        rate: master.rate,
        qty: 1,
        master: master,
      )!;
      expect(shop.data.masterById(master.id)!.stock, before - 1);

      shop.c.updateItem(card.id, line.copyWith(qty: 4));
      expect(shop.data.masterById(master.id)!.stock, before - 4);
    });

    test('deleting a card returns everything on it', () async {
      final shop = await _shop();
      final master = shop.data.mastersOf(LineKind.spare).first;
      final before = master.stock;
      final card = shop.open();

      shop.c.addItem(
        card.id,
        kind: LineKind.spare,
        name: master.name,
        rate: master.rate,
        qty: 3,
        master: master,
      );
      shop.c.deleteJobCard(card.id);

      expect(shop.data.masterById(master.id)!.stock, before);
      expect(shop.data.jobById(card.id), isNull);
    });

    test('labour never touches stock', () async {
      final shop = await _shop();
      final labour = shop.data.mastersOf(LineKind.job).first;
      final card = shop.open();

      shop.c.addItem(
        card.id,
        kind: LineKind.job,
        name: labour.name,
        rate: labour.rate,
        master: labour,
      );

      expect(shop.data.masterById(labour.id)!.stock, labour.stock);
    });
  });

  group('billing', () {
    test('totals split by kind and roll up', () async {
      final shop = await _shop();
      final card = shop.open();
      shop.c.addItem(card.id, kind: LineKind.job, name: 'Labour', rate: 500);
      shop.c.addItem(card.id, kind: LineKind.spare, name: 'Rubber', rate: 166);
      shop.c.addItem(card.id, kind: LineKind.lube, name: 'Oil', rate: 300);

      final after = shop.card(card.id);
      expect(after.totalOf(LineKind.job), 500);
      expect(after.totalOf(LineKind.spare), 166);
      expect(after.totalOf(LineKind.lube), 300);
      expect(after.subTotal, 966);
      expect(after.total, 966);
    });

    test('discount comes off before GST', () async {
      final shop = await _shop();
      final card = shop.open();
      shop.c.addItem(card.id, kind: LineKind.job, name: 'Labour', rate: 1000);
      shop.c.setDiscount(card.id, 100);
      shop.c.setTaxRate(card.id, 0.18);

      final after = shop.card(card.id);
      expect(after.taxable, 900);
      expect(after.taxAmount, 162);
      expect(after.total, 1062);
    });

    test('a discount cannot exceed the subtotal', () async {
      final shop = await _shop();
      final card = shop.open();
      shop.c.addItem(card.id, kind: LineKind.job, name: 'Labour', rate: 500);
      shop.c.setDiscount(card.id, 9999);

      expect(shop.card(card.id).discount, 500);
      expect(shop.card(card.id).total, 0);
    });

    test('a payment never exceeds the outstanding balance', () async {
      final shop = await _shop();
      final card = shop.open();
      shop.c.addItem(card.id, kind: LineKind.job, name: 'Labour', rate: 500);

      shop.c.addPayment(card.id, amount: 900, mode: PayMode.cash);
      final after = shop.card(card.id);
      expect(after.paid, 500);
      expect(after.balance, 0);
      expect(after.settled, isTrue);
    });

    test('a part payment leaves the card unsettled', () async {
      final shop = await _shop();
      final card = shop.open();
      shop.c.addItem(card.id, kind: LineKind.job, name: 'Labour', rate: 500);
      shop.c.addPayment(card.id, amount: 200, mode: PayMode.upi);

      final after = shop.card(card.id);
      expect(after.balance, 300);
      expect(after.settled, isFalse);
      expect(shop.data.pendingBalance.map((e) => e.id), contains(card.id));
    });

    test('a card closed with a balance stays on the pending list', () async {
      final shop = await _shop();
      final card = shop.open();
      shop.c.addItem(card.id, kind: LineKind.job, name: 'Labour', rate: 500);
      shop.c.markComplete(card.id);
      shop.c.closeJobCard(card.id);

      expect(shop.card(card.id).status, JobStatus.closed);
      expect(shop.data.pendingBalance.map((e) => e.id), contains(card.id));
    });
  });

  group('customers', () {
    test('the same phone maps to one customer', () async {
      final shop = await _shop();
      final before = shop.data.customers.length;

      final a = shop.c.upsertCustomer(name: 'Test One', phone: '9000000001');
      final b = shop.c.upsertCustomer(name: 'Test One', phone: '9000000001');

      expect(a.id, b.id);
      expect(shop.data.customers.length, before + 1);
    });

    test('a registration is matched regardless of spacing', () async {
      final shop = await _shop();
      expect(shop.data.vehicleByReg('rj144c2626'), isNotNull);
      expect(shop.data.vehicleByReg('RJ14 4C 2626'), isNotNull);
    });

    test('history excludes the card being viewed', () async {
      final shop = await _shop();
      final vehicleId = shop.data.vehicles.first.id;
      final earlier = shop.open();
      final card = shop.open();

      final history = shop.data.historyOf(vehicleId, excludeId: card.id);
      expect(history.any((e) => e.id == card.id), isFalse);
      expect(history.any((e) => e.id == earlier.id), isTrue);
    });
  });

  group('persistence', () {
    test('a full snapshot survives a JSON round trip', () async {
      final shop = await _shop();
      final card = shop.open();
      shop.c.addItem(card.id, kind: LineKind.spare, name: 'Rubber', rate: 166);
      shop.c.addDent(
        card.id,
        const DentMark(id: 'd1', dx: 0.3, dy: 0.4, severity: DentSeverity.dent),
      );
      shop.c.addPayment(card.id, amount: 100, mode: PayMode.cash);

      final before = shop.data;
      final after = AdminData.fromJson(before.toJson());

      expect(after.jobCards.length, before.jobCards.length);
      expect(after.customers.length, before.customers.length);
      expect(after.masters.length, before.masters.length);

      final restored = after.jobById(card.id)!;
      expect(restored.number, card.number);
      expect(restored.items.single.name, 'Rubber');
      expect(restored.dents.single.severity, DentSeverity.dent);
      expect(restored.paid, 100);
      expect(restored.total, 166);
    });

    test('a corrupt payload never brings back a broken snapshot', () {
      final data = AdminData.fromJson(const {});
      expect(data.jobCards, isEmpty);
      expect(data.garage, isNull);
      expect(data.signedIn, isFalse);
    });
  });

  group('a new workshop', () {
    test('starts empty — no cards, no customers, no rate card', () async {
      SharedPreferences.setMockInitialValues({});
      localStore = await LocalStore.open();
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(adminProvider.notifier).markSignedIn();

      final data = container.read(adminProvider);
      expect(data.jobCards, isEmpty);
      expect(data.customers, isEmpty);
      expect(data.vehicles, isEmpty);
      expect(data.masters, isEmpty);
      expect(data.bookings, isEmpty);
      expect(data.reviews, isEmpty);
      // No profile either, which is what sends the console to /setup.
      expect(data.garage, isNull);
    });

    test('every job card points at a real customer and vehicle', () async {
      final shop = await _shop();
      shop.open();
      for (final j in shop.data.jobCards) {
        expect(
          shop.data.customerById(j.customerId),
          isNotNull,
          reason: '${j.number} has no customer',
        );
        expect(
          shop.data.vehicleById(j.vehicleId),
          isNotNull,
          reason: '${j.number} has no vehicle',
        );
      }
    });

    test('every vehicle belongs to a real customer', () async {
      final shop = await _shop();
      for (final v in shop.data.vehicles) {
        expect(
          shop.data.customerById(v.customerId),
          isNotNull,
          reason: '${v.regNo} has no owner',
        );
      }
    });

    test('rate card rows only track stock where it makes sense', () async {
      final shop = await _shop();
      for (final m in shop.data.masters) {
        if (m.kind == LineKind.job) {
          expect(m.tracksStock, isFalse, reason: '${m.name} is labour');
        } else {
          expect(m.tracksStock, isTrue);
        }
      }
    });

    test('the counter picker presets are still there to pick from', () {
      expect(Seed.voices, isNotEmpty);
      expect(Seed.accessories, isNotEmpty);
      expect(Seed.terms, isNotEmpty);
    });
  });

  // Signing out clears the counter for the next person — but only of what
  // can be fetched again. These cases run with no backend configured, so
  // nothing has ever been synced and the workshop exists on this device
  // alone; wiping it there is not hygiene, it is losing the shop.
  group('signing out', () {
    test('keeps a workshop the backend has never seen', () async {
      final shop = await _shop();
      shop.open();
      expect(shop.data.garage, isNotNull);
      expect(shop.data.jobCards, isNotEmpty);

      shop.c.signOut();

      // The session is what sign-out is for.
      expect(shop.data.signedIn, isFalse);
      // The workshop is not, while it is the only copy in existence.
      expect(shop.data.garage, isNotNull);
      expect(shop.data.jobCards, isNotEmpty);
      // The tour is not the customer's data, so it does not replay.
      expect(shop.data.onboarded, isTrue);
    });

    test('does not send a returning owner back through registration', () async {
      final shop = await _shop();
      shop.c.signOut();
      // A garage still on the device is what keeps the router away from
      // /setup when the same owner signs back in.
      expect(shop.data.garage, isNotNull);
    });

    test('what it wrote is what a restart reads back', () async {
      final shop = await _shop();
      shop.c.signOut();
      await localStore.flush(shop.data);

      final reopened = LocalStore(await SharedPreferences.getInstance()).read();
      expect(reopened.garage, isNotNull);
      expect(reopened.signedIn, isFalse);
      expect(reopened.onboarded, isTrue);
    });

    // Signing out of the account drops the connection before this runs, so
    // "is it connected right now" read as never synced, and the whole
    // workshop stayed for whoever signed in next — whose console then tried
    // to upload its job cards as its own ("belongs to another garage").
    test('clears a workshop the server confirmed, even once disconnected',
        () async {
      final shop = await _shop();
      shop.c.saveGarage(const Garage(id: _serverA, name: 'Workshop A', phone: '9000000000'));
      shop.open();
      expect(shop.data.jobCards, isNotEmpty);

      shop.c.signOut();

      expect(shop.data.signedIn, isFalse);
      expect(shop.data.garage, isNull);
      expect(shop.data.jobCards, isEmpty);
      expect(shop.data.customers, isEmpty);
      expect(shop.data.onboarded, isTrue);
    });
  });

  // The test workshop's car is RJ14 4C 2626, owned by Vikas Gurjar.
  group('search', () {
    test('finds a closed card by its plate from the Open tab', () async {
      final shop = await _shop();
      final card = shop.open();
      shop.c.addItem(card.id, kind: LineKind.job, name: 'Wash', rate: 300);
      shop.c.markComplete(card.id);
      shop.c.closeJobCard(card.id);

      final found = searchWorkshop(shop.data, 'RJ14 4C 2626', JobStatus.open);
      expect(found.cards.map((c) => c.id), [card.id]);
    });

    test('a plate matches however it is typed', () async {
      final shop = await _shop();
      final card = shop.open();
      for (final typed in ['rj144c2626', 'RJ-14-4C-2626', 'rj.14.4c.2626', ' 4C 26 ']) {
        expect(
          searchWorkshop(shop.data, typed, JobStatus.open).cards,
          [isA<JobCard>().having((c) => c.id, 'id', card.id)],
          reason: typed,
        );
      }
    });

    test('the tab on screen comes first', () async {
      final shop = await _shop();
      final closed = shop.open();
      shop.c.addItem(closed.id, kind: LineKind.job, name: 'Wash', rate: 300);
      shop.c.markComplete(closed.id);
      shop.c.closeJobCard(closed.id);
      final open = shop.open();

      final ids = searchWorkshop(shop.data, 'vikas', JobStatus.closed)
          .cards
          .map((c) => c.id);
      expect(ids, [closed.id, open.id]);
    });

    test('finds a car that has never had a job card', () async {
      final shop = await _shop();
      final found = searchWorkshop(shop.data, 'RJ14 4C', JobStatus.open);
      expect(found.cards, isEmpty);
      expect(found.vehicles.map((v) => v.regNo), ['RJ14 4C 2626']);
    });

    test('an empty box lists the tab alone, as before', () async {
      final shop = await _shop();
      shop.open();
      expect(searchWorkshop(shop.data, '', JobStatus.open).cards, hasLength(1));
      expect(searchWorkshop(shop.data, '', JobStatus.closed).cards, isEmpty);
      expect(searchWorkshop(shop.data, '  ', JobStatus.open).vehicles, isEmpty);
    });
  });

  group('joining a workshop', () {
    test("another workshop's rows are not carried into this one", () async {
      final shop = await _shop();
      shop.c.saveGarage(const Garage(id: _serverA, name: 'Workshop A', phone: '9000000000'));
      shop.open();

      final next = AdminController.adoptWorkshop(
        shop.data,
        const Garage(id: _serverB, name: 'Workshop B', phone: '9000000000'),
      )!;

      expect(next.garage!.id, _serverB);
      expect(next.signedIn, isTrue);
      expect(next.jobCards, isEmpty);
      expect(next.customers, isEmpty);
      expect(next.vehicles, isEmpty);
    });

    test('a workshop registered here and never synced keeps its rows',
        () async {
      // Its id is still the one minted on this phone, and these rows exist
      // nowhere else — the first sync is what uploads them.
      final shop = await _shop();
      shop.open();

      final next = AdminController.adoptWorkshop(
        shop.data,
        const Garage(id: _serverA, name: 'Test Motors', phone: '9000000000'),
      )!;

      expect(next.garage!.id, _serverA);
      expect(next.jobCards, hasLength(shop.data.jobCards.length));
      expect(next.customers, hasLength(shop.data.customers.length));
    });

    test('the same workshop signing back in keeps what it has', () async {
      final shop = await _shop();
      const a = Garage(id: _serverA, name: 'Workshop A', phone: '9000000000');
      shop.c.saveGarage(a);
      shop.open();

      expect(AdminController.adoptWorkshop(shop.data, a), isNull);
      final renamed = AdminController.adoptWorkshop(
        shop.data,
        const Garage(id: _serverA, name: 'Workshop A Motors', phone: '9000000000'),
      )!;
      expect(renamed.jobCards, hasLength(shop.data.jobCards.length));
    });
  });

  // What stops two counters from pushing the same edit at each other all
  // afternoon: a row written here and the same row arriving back from
  // Postgres have to fingerprint identically, despite Postgres spelling
  // numbers and timestamps its own way.
  group('sync fingerprint', () {
    test('Postgres spelling of the same row fingerprints the same', () {
      final card = JobCard(
        id: 'j1',
        number: 'A0914-001',
        customerId: 'c1',
        vehicleId: 'v1',
        createdAt: DateTime.parse('2026-09-14T09:30:00Z'),
        odometerKm: 42300,
        items: const [
          LineItem(
            id: 'l1',
            kind: LineKind.spare,
            name: 'Disc',
            qty: 2,
            rate: 400,
          ),
        ],
      );

      // The same card as `job_card_json()` builds it: numeric(12,2) comes
      // back as 2.00 and 400.00, and timestamptz with a zone offset.
      final fromPostgres = {
        ...card.toJson(),
        'created_at': '2026-09-14T09:30:00+00:00',
        'discount': 0.00,
        'tax_rate': 0.0000,
        'items': [
          {
            'id': 'l1',
            'kind': 'spare',
            'name': 'Disc',
            'part_no': '',
            'qty': 2.00,
            'rate': 400.00,
            'mechanic_id': null,
            'state': 'pending',
            'remark': '',
            'master_id': null,
            // 35_jobcard_intake.sql's job_card_json() adds these two.
            'gst_rate': null,
            'unit': '',
          },
        ],
      };

      expect(
        GarageGateway.fingerprint(fromPostgres),
        GarageGateway.fingerprint(card.toJson()),
      );
    });

    test('a real edit fingerprints differently', () {
      const before = LineItem(
        id: 'l1',
        kind: LineKind.spare,
        name: 'Disc',
        qty: 2,
        rate: 400,
      );
      final after = before.copyWith(qty: 3);
      expect(
        GarageGateway.fingerprint(after.toJson()),
        isNot(GarageGateway.fingerprint(before.toJson())),
      );
    });

    test('the garage the row belongs to is not part of the comparison', () {
      final row = {'id': 'c1', 'name': 'Asha', 'phone': '9696969696'};
      expect(
        GarageGateway.fingerprint({...row, 'garage_id': 'g1'}),
        GarageGateway.fingerprint(row),
      );
    });
  });

  group('contact numbers', () {
    test('however the phone book spells it, the same ten digits come out', () {
      for (final spelling in [
        '9876543210',
        '+91 98765 43210',
        '098765 43210',
        '+91-98765-43210',
        '(98765) 43210',
      ]) {
        expect(DeviceContacts.mobile(spelling), '9876543210', reason: spelling);
      }
    });

    test('a landline or a short code is left out rather than half-filled', () {
      expect(DeviceContacts.mobile('112'), '');
      expect(DeviceContacts.mobile('26801234'), '');
      expect(DeviceContacts.mobile(''), '');
    });
  });

  group('money that used to go missing', () {
    test('an advance on an empty card is kept, not cut to zero', () async {
      final shop = await _shop();
      final card = shop.open();
      shop.c.addPayment(
        card.id,
        amount: 2000,
        mode: PayMode.cash,
        advance: true,
      );
      expect(shop.card(card.id).paid, 2000);
      expect(shop.data.cashBook.single.amount, 2000);

      // The work comes to less than the advance: the rest is owed back.
      shop.c.addItem(card.id, kind: LineKind.job, name: 'Wash', rate: 1500);
      expect(shop.card(card.id).balance, 0);
      expect(shop.card(card.id).excess, 500);
    });

    test('an ordinary payment still stops at the balance', () async {
      final shop = await _shop();
      final card = shop.open();
      shop.c.addItem(card.id, kind: LineKind.job, name: 'Wash', rate: 300);
      shop.c.addPayment(card.id, amount: 500, mode: PayMode.cash);
      expect(shop.card(card.id).paid, 300);
    });

    test('taking a payment back takes it out of the cash book', () async {
      final shop = await _shop();
      final card = shop.open();
      shop.c.addItem(card.id, kind: LineKind.job, name: 'Wash', rate: 300);
      shop.c.addPayment(card.id, amount: 300, mode: PayMode.upi);
      final payment = shop.card(card.id).payments.single;
      expect(shop.data.cashBook, hasLength(1));

      shop.c.removePayment(card.id, payment.id);
      expect(shop.card(card.id).payments, isEmpty);
      expect(shop.data.cashBook, isEmpty);
    });

    test('deleting a counter sale returns its stock and its cash', () async {
      final shop = await _shop();
      final pads = shop.data.masters.firstWhere((m) => m.name == 'Brake Pad Set');
      final sale = shop.c.addCounterSale(
        customer: 'Walk-in',
        items: [
          LineItem(
            id: 'li-1',
            kind: LineKind.spare,
            name: pads.name,
            qty: 2,
            rate: pads.rate,
            masterId: pads.id,
          ),
        ],
        paid: 2900,
      );
      expect(shop.data.masterById(pads.id)!.stock, 6);
      expect(shop.data.cashBook, hasLength(1));

      shop.c.removeCounterSale(sale.id);
      expect(shop.data.counterSales, isEmpty);
      expect(shop.data.masterById(pads.id)!.stock, 8);
      expect(shop.data.cashBook, isEmpty);
    });
  });
}
