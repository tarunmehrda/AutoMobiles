// Lives outside test/, so the analyzer does not know it is test code.
// ignore_for_file: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:garagepro/core/theme/app_theme.dart';
import 'package:garagepro/data/models/entities.dart';
import 'package:garagepro/data/models/workshop.dart';
import 'package:garagepro/data/models/enums.dart';
import 'package:garagepro/data/repo/supabase_gateway.dart';
import 'package:garagepro/features/account/account_page.dart';
import 'package:garagepro/features/vehicle/add_vehicle_page.dart';
import 'package:garagepro/features/booking/appointment_page.dart';
import 'package:garagepro/features/history/bookings_page.dart';
import 'package:garagepro/features/home/home_page.dart';
import 'package:garagepro/features/invoice/invoice_page.dart';
import 'package:garagepro/features/vehicle/garage_page.dart';
import 'package:garagepro/state/app_state.dart';

/// Renders whole screens at phone size and writes them to `tool/screens/out/`.
///
///   flutter test tool/screens --update-goldens
///
/// It lives outside `test/` on purpose: these are design renders for eyeballing
/// layout and spacing, not assertions, so a copy change should never fail CI.
/// The test renderer ships no fonts, so without this every glyph falls back to
/// a fixed-width box and the renders tell you nothing. Loading the real
/// FontManifest gives pixel-accurate screens — Sora, Inter and Material icons.
Future<void> loadAppFonts() async {
  final manifest = json.decode(
      await rootBundle.loadString('FontManifest.json')) as List<dynamic>;
  for (final entry in manifest) {
    final family = (entry as Map<String, dynamic>)['family'] as String;
    final loader = FontLoader(family);
    for (final font in entry['fonts'] as List<dynamic>) {
      loader.addFont(
          rootBundle.load((font as Map<String, dynamic>)['asset'] as String));
    }
    await loader.load();
  }
}

/// Asset images decode asynchronously, which fake-async pumps never let
/// finish — so without this every photo renders blank in a golden.
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

  late AppController controller;

  setUpAll(loadAppFonts);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await initLocalStore();
    // SupabaseGateway is inert without credentials, so nothing hits the network.
    controller = AppController(localStore, SupabaseGateway.instance);
    controller.signInOffline(phone: '+919876543210');
    controller.saveProfile(name: 'Rohit Verma', email: 'rohit@example.com');
    controller.addVehicle(Vehicle(
      id: 'v1',
      brand: 'Hyundai',
      model: 'Creta',
      regNumber: 'PB65 AB 1234',
      fuel: FuelType.diesel,
      transmission: Transmission.automatic,
      year: 2021,
      body: BodyType.suv,
      variant: 'SX(O)',
      odometerKm: 42300,
      insuranceExpiry: DateTime.now().add(const Duration(days: 26)),
      pucExpiry: DateTime.now().add(const Duration(days: 9)),
      lastServiceDate: DateTime.now().subtract(const Duration(days: 186)),
      lastServiceKm: 31000,
    ));
    // A booking, and the job card a workshop has opened against it. Every
    // screen below is drawn from those two — there is no sample data any
    // more, so the shots have to build the same state a real visit does.
    final booking = controller.createBooking(
      vehicleId: 'v1',
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
      slot: DateTime.now().add(const Duration(hours: 3)),
    );
    controller.applyWorkshop([
      WorkshopCard.fromJson({
        'id': 'j1',
        'number': 'A0914-001',
        'status': 'open',
        'opened_at': DateTime.now()
            .subtract(const Duration(hours: 2))
            .toIso8601String(),
        'garage_id': 'g1',
        'garage_name': 'Sharma Motors',
        'garage_phone': '9876543210',
        'reg_no': 'PB65 AB 1234',
        'vehicle_title': 'Hyundai Creta SX(O)',
        'mechanic': 'Rakesh Kumar',
        'odometer_km': 42300,
        'fuel_percent': 40,
        'voices': ['Brake noise', 'Periodic service'],
        'accessories': ['Stepney', 'Tool Kit'],
        'photos': <String>[],
        'work_note': 'Front pads down to 2 mm. Replacing both sides.',
        'discount': 0,
        'tax_rate': 0.18,
        'paid': 0,
        'items': [
          {'id': 'l1', 'kind': 'job', 'name': 'Brake pad replacement',
           'qty': 1, 'rate': 450, 'state': 'running'},
          {'id': 'l2', 'kind': 'spare', 'name': 'Brake pad set',
           'qty': 1, 'rate': 1450, 'state': 'done'},
          {'id': 'l3', 'kind': 'lube', 'name': 'Engine oil',
           'qty': 3, 'rate': 300, 'state': 'pending'},
        ],
      })
    ], requests: {
      'req-${booking.id}': {'job_card_id': 'j1', 'accepted': true},
    });
  });

  Future<void> shoot(
    WidgetTester tester,
    String name,
    Widget page, {
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appControllerProvider.overrideWith((ref) => controller),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme:
              brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
          home: page,
        ),
      ),
    );

    // Let the staggered entrances land. pumpAndSettle would hang on the
    // looping "live" pulses, which are designed never to settle.
    for (var i = 0; i < 14; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    await settleImages(tester);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('out/$name.png'),
    );

    // Tear the tree down inside the test so the repeating "live" pulses are
    // disposed before the binding checks for leaks.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  testWidgets('home', (t) => shoot(t, '01-home', const HomePage()));

  testWidgets(
      'home dark',
      (t) => shoot(t, '02-home-dark', const HomePage(),
          brightness: Brightness.dark));

  testWidgets(
      'bookings', (t) => shoot(t, '03-bookings', const BookingsPage()));

  testWidgets('garage', (t) => shoot(t, '04-garage', const GaragePage()));

  testWidgets(
      'appointment', (t) => shoot(t, '05-appointment', const AppointmentPage()));

  testWidgets('invoice',
      (t) => shoot(t, '06-invoice', const InvoicePage(cardId: 'j1')));

  testWidgets('account', (t) => shoot(t, '07-account', const AccountPage()));

  // Drive the wizard to step 2 so the render shows the photo grid people
  // actually pick their car from.
  testWidgets('model picker', (t) async {
    t.view.physicalSize = const Size(1170, 2532);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(
      ProviderScope(
        overrides: [appControllerProvider.overrideWith((ref) => controller)],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: const AddVehiclePage(),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 120));
    }

    await t.tap(find.text('Hyundai').first);
    for (var i = 0; i < 14; i++) {
      await t.pump(const Duration(milliseconds: 120));
    }
    await settleImages(t);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('out/12-model-picker.png'),
    );

    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
  });
}
