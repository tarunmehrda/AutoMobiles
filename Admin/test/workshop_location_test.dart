import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:garagepro_admin/data/models/entities.dart';
import 'package:garagepro_admin/data/repo/local_store.dart';
import 'package:garagepro_admin/features/settings/workshop_page.dart';
import 'package:garagepro_admin/state/admin_state.dart';

/// A workshop can be filled in perfectly and still be findable by nobody.
///
/// `nearby_garages()` measures distance off `garages.lat`/`lng` and drops a
/// row with no coordinate from every radius filter — "within 10 km" cannot
/// honestly include a workshop of unknown place. Setup reads a real fix off
/// the phone to fill the address in, and used to throw the numbers away the
/// moment the geocoder had finished with them, so every garage registered
/// through the console reached the register with an address and no pin. The
/// customer app then searched from the same room and found nothing.
///
/// Nothing here can dial the GPS, so this does not test the fix itself. It
/// holds the thing whose absence was the bug: somewhere in the console that
/// asks for a coordinate at all. A workshop screen with no way to drop a pin
/// is how the first one went unnoticed.
void main() {
  testWidgets('the workshop screen offers a way to drop its pin', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    localStore = await LocalStore.open();

    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(adminProvider.notifier).saveGarage(
      const Garage(
        id: 'garage-test',
        name: 'Balaji Automobiles',
        phone: '9000000000',
        addressLine: '1 Workshop Road',
        city: 'Chandigarh',
        state: 'Chandigarh',
        pin: '160001',
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: WorkshopPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Use current location'), findsOneWidget);

    // LocalStore writes behind a 320ms debounce; leaving it pending fails
    // the test on a timer that has nothing to do with what it asserts.
    await tester.pump(const Duration(milliseconds: 400));
  });
}
