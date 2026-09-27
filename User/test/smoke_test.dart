import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:garagepro/core/router/app_router.dart';
import 'package:garagepro/core/theme/app_theme.dart';
import 'package:garagepro/data/models/entities.dart';
import 'package:garagepro/data/models/enums.dart';
import 'package:garagepro/data/models/workshop.dart';
import 'package:garagepro/data/repo/local_store.dart';
import 'package:garagepro/state/app_state.dart';

/// Opens every screen in the customer app against an account that has a
/// workshop, a car and a job card behind it.
///
/// Not a golden test and not an assertion about layout: it is the cheapest way
/// to catch the screen that throws the moment it is built, which is the kind
/// of thing that only ever shows up as "the app crashed".
Future<ProviderContainer> _account() async {
  SharedPreferences.setMockInitialValues({});
  localStore = await LocalStore.open();

  final container = ProviderContainer();
  final c = container.read(appControllerProvider.notifier);

  c.completeOnboarding();
  c.adoptSession(id: 'auth-1', phone: '+919876543210', name: 'Tarun Sharma');
  c.saveProfile(name: 'Tarun Sharma', email: 'tarun@example.com');
  c.addVehicle(const Vehicle(
    id: 'v1',
    brand: 'Suzuki',
    model: 'Swish',
    regNumber: 'RJ18CC1390',
    fuel: FuelType.petrol,
    transmission: Transmission.manual,
    year: 2021,
    odometerKm: 41000,
  ));

  c.applyWorkshop(
    [
      WorkshopCard.fromJson({
        'id': 'j1',
        'number': 'A0916-001',
        'status': 'complete',
        'opened_at': DateTime.now().toIso8601String(),
        'garage_id': 'g1',
        'garage_name': 'Vikas Automobiles',
        'garage_phone': '9462153613',
        'reg_no': 'RJ18CC1390',
        'vehicle_title': 'Suzuki Swish',
        'odometer_km': 41000,
        'voices': ['Brake Check'],
        'items': [
          {
            'id': 'l1',
            'kind': 'job',
            'name': 'Carburator Setting',
            'qty': 1,
            'rate': 70,
            'state': 'done',
          },
        ],
      })
    ],
    shop: const Workshop(
      id: 'g1',
      name: 'Vikas Automobiles',
      phone: '9462153613',
      email: 'vikas@example.com',
      addressLine: 'Kuddleroo, Prem Sagar Nanda Marg',
      city: 'Chandigarh',
      state: 'Chandigarh',
      pin: '160015',
    ),
  );

  return container;
}

const _routes = [
  '/home',
  '/bookings',
  '/garage',
  '/account',
  '/book',
  '/book?vehicle=v1',
  '/vehicle/v1',
  '/vehicle/add',
  '/workshop/j1/invoice',
  '/profile',
  '/privacy',
  '/help',
  '/notifications',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('every screen opens without throwing', (tester) async {
    final container = await _account();
    addTearDown(container.dispose);

    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final router = container.read(routerProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light(),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );

    final broken = <String>[];
    for (final route in _routes) {
      router.go(route);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
      final failure = tester.takeException();
      if (failure != null) broken.add('$route -> $failure');
    }

    expect(broken, isEmpty, reason: '\n${broken.join('\n')}');
  });
}
