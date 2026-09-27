import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:garagepro_admin/core/i18n/app_language.dart';
import 'package:garagepro_admin/core/i18n/strings.dart';
import 'package:garagepro_admin/core/router/app_router.dart';
import 'package:garagepro_admin/core/theme/app_theme.dart';
import 'package:garagepro_admin/data/models/attendance.dart';
import 'package:garagepro_admin/data/models/entities.dart';
import 'package:garagepro_admin/data/models/enums.dart';
import 'package:garagepro_admin/data/repo/local_store.dart';
import 'package:garagepro_admin/state/admin_state.dart';
import 'package:garagepro_admin/state/auth_state.dart';

/// Opens every screen in the console against a workshop with real rows in it.
///
/// Not a golden test and not an assertion about layout: it is the cheapest way
/// to catch the screen that throws the moment it is built, which is the kind
/// of thing that only shows up as "the app crashed" from the floor.
Future<ProviderContainer> _shop() async {
  SharedPreferences.setMockInitialValues({});
  localStore = await LocalStore.open();

  final container = ProviderContainer(
    overrides: [signedInProvider.overrideWithValue(true)],
  );
  final c = container.read(adminProvider.notifier);

  c.completeOnboarding();
  c.saveGarage(
    const Garage(
      id: 'garage-test',
      name: 'Vikas Automobiles',
      phone: '9000000000',
      email: 'vikas@example.com',
      addressLine: '1 Workshop Road',
      city: 'Jaipur',
      state: 'Rajasthan',
      pin: '302020',
      upiId: 'vikas@upi',
    ),
  );

  c.addMaster(kind: LineKind.job, name: 'General Service Labour', rate: 900);
  c.addMaster(
    kind: LineKind.spare,
    name: 'Oil Filter',
    partNo: 'OF-11',
    rate: 350,
    stock: 6,
  );
  c.addMaster(
    kind: LineKind.lube,
    name: 'Engine Oil 5W30',
    rate: 620,
    stock: 9,
  );
  final staff = c.addStaff(
    name: 'Ramesh Kumar',
    phone: '9812345670',
    skill: 'Engine',
  );

  final customer = c.upsertCustomer(name: 'Tarun Sharma', phone: '9462153613');
  final vehicle = c.upsertVehicle(
    customerId: customer.id,
    regNo: 'RJ18CC1390',
    brand: 'Suzuki',
    model: 'Swish',
  );

  final card = c.createJobCard(
    customerId: customer.id,
    vehicleId: vehicle.id,
    odometerKm: 41000,
    fuelPercent: 60,
    mechanicIds: [staff.id],
    voices: const ['Brake Check'],
    accessories: const ['Tool kit'],
  );
  c.addItem(card.id, kind: LineKind.job, name: 'Carburator Setting', rate: 70);
  c.addPayment(card.id, amount: 20, mode: PayMode.cash);
  c.addExpense(title: 'Shop rent', amount: 8000, paid: 8000);
  c.addCash(party: 'Walk-in', amount: 500, inward: true, reason: 'Counter');
  c.addSupplier(name: 'Sharma Spares', phone: '9812300000');
  c.setOnlineGarage(true);
  c.addOnlineService(name: 'General Servicing', price: 1200);
  // Pinned so the attendance screens render their real state — the dial,
  // the radius, the punch button — rather than the "no location set" empty
  // state, which is the one arrangement that exercises none of them.
  c.setAttendanceSite(
    const AttendanceSite(
      lat: 26.912434,
      lng: 75.787270,
      label: 'Main workshop',
    ),
  );

  return container;
}

/// Every place the console can navigate to, with a live card behind the ones
/// that need one.
List<String> _routes(ProviderContainer container) {
  final card = container.read(adminProvider).jobCards.first;
  final customer = container.read(adminProvider).customers.first;
  return [
    '/home',
    '/search',
    '/settings',
    '/settings/options',
    '/settings/language',
    '/settings/greetings',
    '/settings/privacy',
    '/settings/credits',
    '/jobs?status=open',
    '/jobs?status=complete',
    '/jobs?status=closed',
    '/job/new',
    '/job/${card.id}',
    '/job/${card.id}/items',
    '/job/${card.id}/voices',
    '/job/${card.id}/accessories',
    '/job/${card.id}/note',
    '/job/${card.id}/dents',
    '/job/${card.id}/photos',
    '/job/${card.id}/mechanics',
    '/inventory',
    '/inventory/master?kind=spare',
    '/inventory/master?kind=lube',
    '/inventory/master?kind=job',
    '/inventory/suppliers',
    '/inventory/counter-sales',
    '/inventory/counter-sale/new',
    '/inventory/purchase-orders',
    '/inventory/purchase-order/new',
    '/analytics',
    '/analytics/revenue',
    '/analytics/vehicle',
    '/online-garage',
    '/expenses',
    '/cashbook',
    '/service-due',
    '/reports',
    '/reports/sms',
    '/reports/stock',
    '/reports/sale',
    '/reports/counter-sales',
    '/reports/general',
    '/reports/customer',
    '/reports/mechanic',
    '/bookings',
    '/notifications',
    '/pending',
    '/feedback',
    '/customers',
    '/customer/${customer.id}',
    '/support',
    '/workshop',
    '/staff',
    // These three place the phone on the way in. With no location plugin
    // behind a widget test the gate answers "no fix", which is exactly the
    // path that must not throw on a handset whose GPS is having a bad day.
    '/attendance',
    '/attendance/register',
    '/attendance/site',
    '/contacts',
  ];
}

/// One device shape to walk every route in.
typedef _Shape = ({
  String name,
  double width,
  double dpr,
  bool dark,
  AppLanguage language,
});

/// The shapes worth checking, and why each earns its place.
///
/// 360pt is the narrowest phone still sold in volume and is where almost
/// every overflow shows up first. 390pt is the modern baseline. The tablet
/// catches layouts that only work because they were cramped. Dark is here
/// because half the palette swaps under it, and a colour that resolves to
/// transparent on one theme resolves to a solid block on the other.
/// Hindi earns its rows for the same reason as dark: the copy is longer in
/// places, the dates come from another locale, and a template whose
/// placeholders were mistranslated throws where the English one does not.
const en = AppLanguage.en;
const hi = AppLanguage.hi;
const _shapes = <_Shape>[
  (name: 'narrow phone', width: 1080, dpr: 3.0, dark: false, language: en),
  (name: 'phone', width: 1170, dpr: 3.0, dark: false, language: en),
  (name: 'phone, dark', width: 1170, dpr: 3.0, dark: true, language: en),
  (name: 'tablet', width: 1600, dpr: 2.0, dark: false, language: en),
  (
    name: 'narrow phone, Hindi',
    width: 1080,
    dpr: 3.0,
    dark: false,
    language: hi,
  ),
  (name: 'phone, dark, Hindi', width: 1170, dpr: 3.0, dark: true, language: hi),
  (name: 'tablet, Hindi', width: 1600, dpr: 2.0, dark: false, language: hi),
];

Future<List<String>> _walk(WidgetTester tester, _Shape shape) async {
  final container = await _shop();
  addTearDown(container.dispose);

  Tr.use(shape.language);
  addTearDown(() => Tr.use(AppLanguage.en));

  tester.view.physicalSize = Size(shape.width, 2532);
  tester.view.devicePixelRatio = shape.dpr;
  addTearDown(tester.view.reset);

  final router = container.read(routerProvider);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        theme: shape.dark ? AppTheme.dark() : AppTheme.light(),
        debugShowCheckedModeBanner: false,
      ),
    ),
  );

  final broken = <String>[];
  for (final route in _routes(container)) {
    router.go(route);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    final failure = tester.takeException();
    if (failure != null) {
      broken.add('[${shape.name}] $route -> $failure');
      // ignore: avoid_print
      print('BROKEN [${shape.name}] $route');
    }
  }
  return broken;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The Hindi shapes format dates through a non-default locale, which
  // throws unless its symbols are loaded first — exactly as main() does.
  setUpAll(initializeDateFormatting);

  testWidgets('every screen opens without throwing, on every shape', (
    tester,
  ) async {
    final broken = <String>[];
    for (final shape in _shapes) {
      broken.addAll(await _walk(tester, shape));
    }
    expect(broken, isEmpty, reason: broken.join('\n'));
  });
}
