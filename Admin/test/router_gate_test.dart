import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:garagepro_admin/core/config/app_config.dart';
import 'package:garagepro_admin/core/router/app_router.dart';
import 'package:garagepro_admin/data/models/entities.dart';
import 'package:garagepro_admin/data/repo/local_store.dart';
import 'package:garagepro_admin/state/admin_state.dart';
import 'package:garagepro_admin/state/auth_state.dart';

/// The gate the router applies once somebody is signed in.
///
/// The bug this pins: signing back in on an existing account briefly looks
/// like a brand new one, because the workshop is still on its way down from
/// the backend. The gate used to answer "no workshop, send them to
/// registration" and then yank them to the dashboard a beat later. It now
/// waits instead.
Future<ProviderContainer> _container({
  required bool signedIn,
  required bool restoring,
  Garage? garage,
}) async {
  SharedPreferences.setMockInitialValues({});
  localStore = await LocalStore.open();

  final container = ProviderContainer(
    overrides: [signedInProvider.overrideWithValue(signedIn)],
  );
  final ctrl = container.read(adminProvider.notifier);
  ctrl.completeOnboarding();
  if (garage != null) ctrl.saveGarage(garage);
  container.read(restoringProvider.notifier).state = restoring;
  return container;
}

const _garage = Garage(
  id: 'garage-test',
  name: 'Test Motors',
  phone: '9000000000',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the signed-in gate', () {
    testWidgets('holds while the workshop is still on its way down', (
      tester,
    ) async {
      final container = await _container(
        signedIn: true,
        restoring: true,
        garage: null,
      );
      addTearDown(container.dispose);

      await _pumpAt(tester, container, '/home');
      expect(find.text('Opening your workshop'), findsOneWidget);
    });

    testWidgets('asks a genuinely new account to register', (tester) async {
      final container = await _container(
        signedIn: true,
        restoring: false,
        garage: null,
      );
      addTearDown(container.dispose);

      await _pumpAt(tester, container, '/home');
      expect(find.text('Registration'), findsOneWidget);
    });

    testWidgets('lets a restored account straight through', (tester) async {
      final container = await _container(
        signedIn: true,
        restoring: false,
        garage: _garage,
      );
      addTearDown(container.dispose);

      await _pumpAt(tester, container, '/home');
      // The dashboard leads with the workshop's own name.
      expect(find.text('Test Motors'), findsOneWidget);
    });

    testWidgets('never shows registration to a returning owner', (
      tester,
    ) async {
      // The real sequence: signed in, restore in flight, then the workshop
      // arrives. Registration must not appear at any point along the way.
      final container = await _container(
        signedIn: true,
        restoring: true,
        garage: null,
      );
      addTearDown(container.dispose);

      await _pumpAt(tester, container, '/home');
      expect(find.text('Registration'), findsNothing);

      container.read(adminProvider.notifier).saveGarage(_garage);
      container.read(restoringProvider.notifier).state = false;
      await _settle(tester);

      expect(find.text('Registration'), findsNothing);
      expect(find.text('Test Motors'), findsOneWidget);
    });

    testWidgets('holds a blocked workshop at the support number', (
      tester,
    ) async {
      final container = await _container(
        signedIn: true,
        restoring: false,
        garage: _garage.copyWith(blocked: true),
      );
      addTearDown(container.dispose);

      await _pumpAt(tester, container, '/jobs');
      expect(find.text('Your workshop is blocked'), findsOneWidget);
      expect(find.text('+91 ${AppConfig.supportPhone}'), findsOneWidget);

      // Unblocked upstream: the console lets them back in by itself.
      container.read(adminProvider.notifier).saveGarage(_garage);
      await _settle(tester);
      expect(find.text('Your workshop is blocked'), findsNothing);
      expect(find.text('Test Motors'), findsOneWidget);
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
