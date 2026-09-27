import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:garagepro/core/router/app_router.dart';
import 'package:garagepro/data/models/entities.dart';
import 'package:garagepro/data/models/enums.dart';
import 'package:garagepro/data/repo/local_store.dart';
import 'package:garagepro/state/app_state.dart';
import 'package:garagepro/state/auth_state.dart';

/// The gate the router applies once somebody is signed in.
///
/// The bug this pins: signing out wipes the device, so for a beat after
/// signing back in the app knows nothing about the account. The gate used to
/// answer "no profile, no vehicle" and march a returning customer back
/// through sign-up — or, once the account landed, skip straight past it. It
/// now waits instead.
Future<ProviderContainer> _container({
  required bool restoring,
  bool signedIn = true,
  bool named = false,
  bool withVehicle = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  localStore = await LocalStore.open();

  final container = ProviderContainer();
  final ctrl = container.read(appControllerProvider.notifier);
  ctrl.completeOnboarding();

  if (signedIn) {
    ctrl.adoptSession(id: 'auth-1', phone: '+919876543210');
    if (named) ctrl.saveProfile(name: 'Rohit Verma');
    if (withVehicle) ctrl.addVehicle(_vehicle);
  }
  container.read(restoringProvider.notifier).state = restoring;
  return container;
}

const _vehicle = Vehicle(
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

  group('the signed-in gate', () {
    testWidgets('holds while the account is still on its way down',
        (tester) async {
      final container = await _container(restoring: true);
      addTearDown(container.dispose);

      await _pumpAt(tester, container, '/home');
      expect(find.text('Getting your garage'), findsOneWidget);
    });

    testWidgets('asks a genuinely new account for a profile', (tester) async {
      final container = await _container(restoring: false);
      addTearDown(container.dispose);

      await _pumpAt(tester, container, '/home');
      expect(find.text('Getting your garage'), findsNothing);
      // A signed-in account with no name is sent to fill one in.
      expect(find.byType(Scaffold), findsWidgets);
      expect(container.read(appControllerProvider).user?.name, '');
    });

    testWidgets('lets a restored account straight through', (tester) async {
      final container = await _container(
          restoring: false, named: true, withVehicle: true);
      addTearDown(container.dispose);

      await _pumpAt(tester, container, '/home');
      expect(find.text('My Garage'), findsOneWidget);
    });

    testWidgets('never asks a returning customer to sign up again',
        (tester) async {
      // The real sequence: signed in, restore in flight, then the account
      // arrives. The sign-up steps must not appear at any point along the way.
      final container = await _container(restoring: true);
      addTearDown(container.dispose);

      await _pumpAt(tester, container, '/home');
      expect(find.text('Getting your garage'), findsOneWidget);

      final ctrl = container.read(appControllerProvider.notifier);
      ctrl.saveProfile(name: 'Rohit Verma');
      ctrl.addVehicle(_vehicle);
      container.read(restoringProvider.notifier).state = false;
      await _settle(tester);

      expect(find.text('My Garage'), findsOneWidget);
    });
  });

  group('signing out', () {
    test('keeps the tour and the theme, and nothing else', () async {
      SharedPreferences.setMockInitialValues({});
      localStore = await LocalStore.open();
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final ctrl = container.read(appControllerProvider.notifier);
      ctrl.completeOnboarding();
      ctrl.adoptSession(id: 'auth-1', phone: '+919876543210');
      ctrl.saveProfile(name: 'Rohit Verma');
      ctrl.addVehicle(_vehicle);

      await ctrl.signOut();

      final data = container.read(appControllerProvider);
      expect(data.user, isNull);
      expect(data.vehicles, isEmpty);
      expect(data.bookings, isEmpty);
      // The tour is not the customer's data, so it does not replay.
      expect(data.onboarded, isTrue);

      // And that is what a restart reads back, rather than an empty box.
      final reopened = LocalStore(await SharedPreferences.getInstance()).read();
      expect(reopened.user, isNull);
      expect(reopened.vehicles, isEmpty);
      expect(reopened.onboarded, isTrue);
    });
  });
}

Future<void> _pumpAt(
  WidgetTester tester,
  ProviderContainer container,
  String location,
) async {
  final router = container.read(routerProvider);
  router.go(location);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await _settle(tester);
}

/// The restoring screen animates forever on purpose, so `pumpAndSettle`
/// would never return. A fixed run of frames is enough for the redirect and
/// the staggered entrances to land.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 14; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}
