// Lives outside test/, so the analyzer does not know it is test code.
// ignore_for_file: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:garagepro_admin/core/router/app_router.dart';
import 'package:garagepro_admin/core/theme/app_theme.dart';
import 'package:garagepro_admin/data/models/attendance.dart';
import 'package:garagepro_admin/data/models/entities.dart';
import 'package:garagepro_admin/data/models/enums.dart';
import 'package:garagepro_admin/data/repo/local_store.dart';
import 'package:garagepro_admin/state/admin_state.dart';
import 'package:garagepro_admin/state/auth_state.dart';

/// Renders whole console screens at phone size and writes them to
/// `tool/screens/out/`.
///
///   flutter test tool/screens --update-goldens
///
/// It lives outside `test/` on purpose: these are design renders for eyeballing
/// layout and spacing, not assertions, so a copy change should never fail CI.
/// The test renderer ships no fonts, so without this every glyph falls back to
/// a fixed-width box and the renders tell you nothing.
Future<void> loadAppFonts() async {
  final manifest =
      json.decode(await rootBundle.loadString('FontManifest.json'))
          as List<dynamic>;
  for (final entry in manifest) {
    final family = (entry as Map<String, dynamic>)['family'] as String;
    final loader = FontLoader(family);
    for (final font in entry['fonts'] as List<dynamic>) {
      loader.addFont(
        rootBundle.load((font as Map<String, dynamic>)['asset'] as String),
      );
    }
    await loader.load();
  }
}

Future<void> settleImages(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      final image = element.widget as Image;
      try {
        await precacheImage(image.image, element);
      } catch (_) {
        // A missing asset should not stop the rest of the screen rendering.
      }
    }
  });
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late String cardId;
  late String customerId;

  setUpAll(loadAppFonts);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    localStore = await LocalStore.open();

    container = ProviderContainer(
      overrides: [signedInProvider.overrideWithValue(true)],
    );
    final c = container.read(adminProvider.notifier);

    c.completeOnboarding();
    c.saveGarage(
      Garage(
        id: 'garage-test',
        name: 'Vikas Automobiles',
        phone: '9462153613',
        email: 'vikas@example.com',
        addressLine: 'Kuddleroo, Prem Sagar Nanda Marg',
        city: 'Chandigarh',
        state: 'Chandigarh',
        pin: '160015',
        upiId: 'vikas@upi',
        planExpiry: DateTime.now().add(const Duration(days: 10)),
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

    final customer = c.upsertCustomer(
      name: 'Tarun Sharma',
      phone: '9462153613',
    );
    customerId = customer.id;
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
      voices: const ['Brake Check', 'Mileage Check'],
      accessories: const ['Tool kit'],
    );
    cardId = card.id;
    c.addItem(
      card.id,
      kind: LineKind.job,
      name: 'Carburator Setting',
      rate: 70,
    );
    c.addItem(card.id, kind: LineKind.spare, name: 'Oil Filter', rate: 350);
    c.addPayment(card.id, amount: 100, mode: PayMode.cash);

    c.addExpense(title: 'Shop rent', amount: 8000, paid: 8000);
    c.addCash(
      party: 'Tarun Sharma',
      amount: 70,
      inward: true,
      reason: 'Jobcard Payment Advance',
    );
    c.addSupplier(name: 'Sharma Spares', phone: '9812300000');
    c.setOnlineGarage(true);
    c.addOnlineService(name: 'General Servicing', price: 1200);

    // --- attendance -------------------------------------------------------
    final fitter = c.addStaff(
      name: 'Sunil Verma',
      phone: '9812345671',
      skill: 'Denting',
    );
    c.upsertCustomer(name: 'Anita Rao', phone: '9812345672');
    c.upsertCustomer(name: 'Deepak Meena', phone: '9812345673');

    c.setAttendanceSite(
      const AttendanceSite(
        lat: 26.912434,
        lng: 75.787270,
        label: 'Main workshop',
      ),
    );

    // Punches cannot be minted through `punch()` here — that runs the gate,
    // and a test binding has no GPS behind it. The register is written
    // straight in so the renders show the screens as a working shop sees
    // them rather than as an empty state.
    final today = DateTime.now();
    DateTime at(int h, int m) =>
        DateTime(today.year, today.month, today.day, h, m);
    AttendancePunch punch(
      String id,
      Staff who,
      PunchKind kind,
      DateTime when, {
      bool accepted = true,
      PunchBlock block = PunchBlock.none,
      double distance = 2.4,
      double accuracy = 6,
      bool mocked = false,
      String note = '',
    }) => AttendancePunch(
      id: id,
      staffId: who.id,
      staffName: who.name,
      kind: kind,
      at: when,
      lat: 26.912434,
      lng: 75.787270,
      accuracyM: accuracy,
      distanceM: distance,
      mocked: mocked,
      accepted: accepted,
      block: block,
      verified: true,
      note: note,
    );

    c.state = c.state.copyWith(
      attendance: [
        punch(
          'at-5',
          fitter,
          PunchKind.punchIn,
          at(14, 2),
          accepted: false,
          block: PunchBlock.mocked,
          mocked: true,
          distance: 18400,
          accuracy: 4,
          note: 'device reported 2 m, server measured 18400 m',
        ),
        punch(
          'at-4',
          fitter,
          PunchKind.punchIn,
          at(13, 55),
          accepted: false,
          block: PunchBlock.tooFar,
          distance: 61.2,
        ),
        punch('at-3', staff, PunchKind.punchIn, at(13, 40), distance: 1.8),
        punch(
          'at-2',
          staff,
          PunchKind.punchOut,
          at(13, 2),
          distance: 3.1,
          accuracy: 7,
        ),
        punch(
          'at-1',
          staff,
          PunchKind.punchIn,
          at(9, 12),
          distance: 2.2,
          accuracy: 5,
        ),
      ],
    );
  });

  tearDown(() => container.dispose());

  Future<void> shoot(
    WidgetTester tester,
    String name,
    String location, {
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final router = container.read(routerProvider);
    router.go(location);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: brightness == Brightness.dark
              ? AppTheme.dark()
              : AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );

    // Let the staggered entrances land. pumpAndSettle would hang on the
    // looping pulses, which are designed never to settle.
    for (var i = 0; i < 14; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    // Synthetic pumps advance the widget clock but never the real event
    // loop, so a screen that reads the phone on the way in — Contacts — is
    // caught mid-skeleton. One real turn lets that land, and a plugin the
    // test binding has no implementation for still fails fast.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));

    await settleImages(tester);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('out/$name.png'),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  testWidgets('dashboard', (t) => shoot(t, '01-dashboard', '/home'));
  testWidgets(
    'dashboard dark',
    (t) => shoot(t, '02-dashboard-dark', '/home', brightness: Brightness.dark),
  );
  testWidgets('job list', (t) => shoot(t, '03-jobs', '/jobs?status=open'));
  testWidgets('job card', (t) => shoot(t, '04-job', '/job/$cardId'));
  testWidgets('create job card', (t) => shoot(t, '05-create', '/job/new'));
  testWidgets('inventory', (t) => shoot(t, '06-inventory', '/inventory'));
  testWidgets('reports', (t) => shoot(t, '07-reports', '/reports'));
  testWidgets('sms report', (t) => shoot(t, '08-sms', '/reports/sms'));
  testWidgets('cashbook', (t) => shoot(t, '09-cashbook', '/cashbook'));
  testWidgets(
    'online garage',
    (t) => shoot(t, '10-online-garage', '/online-garage'),
  );
  testWidgets('settings', (t) => shoot(t, '11-settings', '/settings'));
  testWidgets('support', (t) => shoot(t, '12-support', '/support'));
  testWidgets(
    'customer',
    (t) => shoot(t, '13-customer', '/customer/$customerId'),
  );
  testWidgets('pending', (t) => shoot(t, '14-pending', '/pending'));
  testWidgets('attendance', (t) => shoot(t, '15-attendance', '/attendance'));
  testWidgets(
    'attendance dark',
    (t) => shoot(
      t,
      '16-attendance-dark',
      '/attendance',
      brightness: Brightness.dark,
    ),
  );
  testWidgets(
    'attendance register',
    (t) => shoot(t, '17-attendance-register', '/attendance/register'),
  );
  testWidgets(
    'attendance location',
    (t) => shoot(t, '18-attendance-site', '/attendance/site'),
  );
  testWidgets('contacts', (t) => shoot(t, '19-contacts', '/contacts'));
}
