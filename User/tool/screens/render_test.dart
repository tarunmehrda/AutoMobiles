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
import 'package:garagepro/data/models/enums.dart';
import 'package:garagepro/data/repo/supabase_gateway.dart';
import 'package:garagepro/data/seed/catalog_seed.dart';
import 'package:garagepro/features/account/account_page.dart';
import 'package:garagepro/features/vehicle/add_vehicle_page.dart';
import 'package:garagepro/features/booking/cart_page.dart';
import 'package:garagepro/features/catalog/book_page.dart';
import 'package:garagepro/features/catalog/service_detail_page.dart';
import 'package:garagepro/features/estimate/estimate_page.dart';
import 'package:garagepro/features/home/home_page.dart';
import 'package:garagepro/features/invoice/invoice_page.dart';
import 'package:garagepro/features/tracking/inspection_page.dart';
import 'package:garagepro/features/tracking/tracking_page.dart';
import 'package:garagepro/features/vehicle/garage_page.dart';
import 'package:garagepro/state/app_state.dart';
import 'package:garagepro/state/draft_state.dart';

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
  late String liveBookingId;

  setUpAll(loadAppFonts);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await initLocalStore();
    // SupabaseGateway is inert without credentials, so nothing hits the network.
    controller = AppController(localStore, SupabaseGateway.instance);
    await controller.verifyOtp(
        phone: '+919876543210', entered: '123456', expected: null);
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
    liveBookingId = controller.state.bookings
        .firstWhere((b) => b.stage == JobStage.awaitingApproval)
        .id;
  });

  Future<void> shoot(
    WidgetTester tester,
    String name,
    Widget page, {
    Brightness brightness = Brightness.light,
    DraftController? draft,
  }) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appControllerProvider.overrideWith((ref) => controller),
          if (draft != null) draftProvider.overrideWith((ref) => draft),
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

    // Tear the tree down inside the test so the repeating "live" pulses and
    // the job-progress timer are disposed before the binding checks for leaks.
    controller.stopLiveTracking(liveBookingId);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  testWidgets('home', (t) => shoot(t, '01-home', const HomePage()));

  testWidgets(
      'home dark',
      (t) => shoot(t, '02-home-dark', const HomePage(),
          brightness: Brightness.dark));

  testWidgets('book', (t) => shoot(t, '03-book', const BookPage()));

  testWidgets(
      'service detail',
      (t) => shoot(t, '04-service',
          const ServiceDetailPage(packageId: 'standard-service')));

  testWidgets('garage', (t) => shoot(t, '05-garage', const GaragePage()));

  testWidgets('tracking',
      (t) => shoot(t, '06-tracking', TrackingPage(bookingId: liveBookingId)));

  testWidgets(
      'inspection',
      (t) =>
          shoot(t, '07-inspection', InspectionPage(bookingId: liveBookingId)));

  testWidgets('estimate',
      (t) => shoot(t, '08-estimate', EstimatePage(bookingId: liveBookingId)));

  testWidgets('cart', (t) async {
    final draft = DraftController()
      ..clear()
      ..togglePackage(Seed.packageById('comprehensive-service')!)
      ..togglePackage(Seed.packageById('ac-gas-refill')!)
      ..toggleAddOn(Seed.addOns.first);
    await shoot(t, '09-cart', const CartPage(), draft: draft);
  });

  testWidgets('invoice', (t) async {
    controller.approveEstimate(liveBookingId, const {});
    controller.ensureInvoice(liveBookingId);
    await shoot(t, '10-invoice', InvoicePage(bookingId: liveBookingId));
  });

  testWidgets('account', (t) => shoot(t, '11-account', const AccountPage()));

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
