import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:garagepro_admin/core/theme/app_theme.dart';
import 'package:garagepro_admin/core/widgets/g_field.dart';
import 'package:garagepro_admin/data/models/entities.dart';
import 'package:garagepro_admin/data/models/enums.dart';
import 'package:garagepro_admin/data/repo/local_store.dart';
import 'package:garagepro_admin/features/jobcard/create_jobcard_page.dart';
import 'package:garagepro_admin/state/admin_state.dart';

/// A car booked from the customer app must open a card with everything the
/// customer typed.
///
/// Until 27 Sep 2026 the plate lookup on a new card searched the workshop's
/// own vehicles alone, and a booked car is not one of those until its first
/// card. So a counter who tapped + and typed the plate got "Vehicle not
/// registered yet", and the details step held the plate, the default body
/// type and nothing else — the make, the owner, the year, the reading and
/// what they asked for all had to be typed again. The booking was left
/// waiting on the Bookings list, answered by nothing.
Booking _booked({String regNo = 'RJ14CX4455'}) => Booking(
  id: 'req-bk-1',
  name: 'Amit Verma',
  phone: '9001122334',
  at: DateTime.now().add(const Duration(hours: 2)),
  regNo: regNo,
  vehicle: 'Hyundai Creta',
  note: 'General service, Wheel alignment',
  brand: 'Hyundai',
  model: 'Creta',
  variant: 'SX',
  fuel: FuelType.diesel,
  transmission: Transmission.manual,
  year: 2021,
  odometerKm: 42000,
  customerNote: 'AC not cooling',
);

Future<ProviderContainer> _shop(List<Booking> bookings) async {
  SharedPreferences.setMockInitialValues({});
  localStore = await LocalStore.open();
  final container = ProviderContainer();
  final c = container.read(adminProvider.notifier);
  c.completeOnboarding();
  c.setSmsEnabled(false);
  for (final b in bookings) {
    c.addBooking(b);
  }
  return container;
}

Future<void> _open(
  WidgetTester tester,
  ProviderContainer container, {
  String location = '/job/new',
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(
        path: '/job/new',
        builder: (_, s) =>
            CreateJobCardPage(bookingId: s.uri.queryParameters['booking']),
      ),
      GoRoute(
        path: '/job/:id',
        builder: (_, s) => Text('card ${s.pathParameters['id']}'),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

/// From the customer step: the plate typed into the one search box, then
/// carried to the vehicle step as a number nobody has on record yet.
Future<void> _searchFromStart(WidgetTester tester, String plate) async {
  await tester.enterText(find.byType(TextField).hitTestable().first, plate);
  await tester.pumpAndSettle();
  await tester.tap(find.text('New vehicle — use this number').hitTestable());
  await tester.pumpAndSettle();
}

/// On the vehicle step: typed into the plate field, then Search.
Future<void> _search(WidgetTester tester, String plate) async {
  final field = find.descendant(
    of: find.byWidgetPredicate(
      (w) => w is GField && (w.label ?? '').startsWith('Vehicle Number'),
    ),
    matching: find.byType(TextField),
  );
  await tester.enterText(field.hitTestable(), plate);
  await tester.pump();
  await tester.tap(find.text('Search').hitTestable());
  await tester.pumpAndSettle();
}

/// Next or Skip through damage, voice and services, then Open Job Card:
/// the handover and the bill left as they came.
Future<JobCard> _openCard(
  WidgetTester tester,
  ProviderContainer container,
) async {
  final open = find.textContaining('Open Job Card').hitTestable();
  for (var i = 0; i < 6 && open.evaluate().isEmpty; i++) {
    final next = find.text('Next').hitTestable();
    // The bottom bar comes after the form in the tree, so of the Skips on
    // the voice step — one per section heading, one in the bar — the last
    // is the bar's.
    await tester.tap(
      next.evaluate().isNotEmpty ? next : find.text('Skip').hitTestable().last,
    );
    await tester.pumpAndSettle();
  }
  await tester.tap(open);
  await tester.pumpAndSettle();
  // LocalStore debounces its write.
  await tester.pump(const Duration(seconds: 5));
  return container.read(adminProvider).jobCards.single;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('typing a booked plate on + fills the card from the booking', (
    tester,
  ) async {
    final container = await _shop([_booked()]);
    addTearDown(container.dispose);
    await _open(tester, container);

    // Typed the way a counter types it, into the one search box.
    await _searchFromStart(tester, 'rj 14 cx 4455');

    // On the vehicle step, with the booking in view and everything in it
    // carried over — the year included.
    expect(
      find.text('BOOKED IN THE CUSTOMER APP').hitTestable(),
      findsOneWidget,
    );
    expect(find.text('Vehicle not registered yet'), findsNothing);
    expect(find.text('Amit Verma').hitTestable(), findsOneWidget);
    expect(find.textContaining('AC not cooling').hitTestable(), findsWidgets);
    expect(find.textContaining('Manual  •  2021'), findsOneWidget);

    final card = await _openCard(tester, container);
    final data = container.read(adminProvider);
    final vehicle = data.vehicleById(card.vehicleId)!;
    final owner = data.customerById(card.customerId)!;

    expect(owner.name, 'Amit Verma');
    expect(owner.phone, '9001122334');
    expect(vehicle.regNo, 'rj 14 cx 4455'.toUpperCase());
    expect(
      (vehicle.brand, vehicle.model, vehicle.variant),
      ('Hyundai', 'Creta', 'SX'),
    );
    expect(vehicle.fuel, FuelType.diesel);
    expect(vehicle.transmission, Transmission.manual);
    expect(vehicle.year, 2021);
    expect(card.odometerKm, 42000);
    expect(
      card.voices,
      containsAll(['General service, Wheel alignment', 'AC not cooling']),
    );

    // Answered, so it leaves the Bookings list.
    final booking = data.bookings.single;
    expect(booking.accepted, isTrue);
    expect(booking.jobCardId, card.id);
  });

  testWidgets('searching on to another plate lets the booking go', (
    tester,
  ) async {
    final container = await _shop([_booked()]);
    addTearDown(container.dispose);
    await _open(tester, container);

    await _searchFromStart(tester, 'RJ14CX4455');
    expect(find.text('BOOKED IN THE CUSTOMER APP'), findsWidgets);

    await _search(tester, 'DL01AA0001');
    expect(find.text('BOOKED IN THE CUSTOMER APP'), findsNothing);
    expect(find.text('Vehicle not registered yet'), findsOneWidget);

    final card = await _openCard(tester, container);

    // Not this car's complaints, and not this car's booking.
    expect(card.voices, isEmpty);
    expect(container.read(adminProvider).bookings.single.accepted, isFalse);
  });

  testWidgets('a booking with no plate still opens on its details', (
    tester,
  ) async {
    final container = await _shop([_booked(regNo: '')]);
    addTearDown(container.dispose);
    await _open(tester, container, location: '/job/new?booking=req-bk-1');

    expect(find.text('ADD A NEW VEHICLE').hitTestable(), findsNothing);
    expect(
      find.text('BOOKED IN THE CUSTOMER APP').hitTestable(),
      findsOneWidget,
    );
    expect(find.text('Vehicle Details').hitTestable(), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  test('the booking a plate finds is an open one, nearest its slot', () async {
    final now = DateTime.now();
    final container = await _shop([
      Booking(
        id: 'done',
        name: 'A',
        phone: '9000000001',
        at: now,
        regNo: 'RJ14CX4455',
        accepted: true,
      ),
      Booking(
        id: 'last-week',
        name: 'A',
        phone: '9000000001',
        at: now.subtract(const Duration(days: 7)),
        regNo: 'RJ14CX4455',
      ),
      Booking(
        id: 'tomorrow',
        name: 'A',
        phone: '9000000001',
        at: now.add(const Duration(days: 1)),
        regNo: 'RJ 14 CX 4455',
      ),
    ]);
    addTearDown(container.dispose);
    final data = container.read(adminProvider);

    expect(data.openBookingByReg('rj14cx4455')?.id, 'tomorrow');
    expect(data.openBookingByReg('RJ14CX0000'), isNull);
    expect(data.openBookingByReg(''), isNull);
  });
}
