import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:garagepro_admin/data/models/entities.dart';
import 'package:garagepro_admin/data/repo/local_store.dart';
import 'package:garagepro_admin/state/admin_state.dart';

/// The console refetches when the counter comes back to it.
///
/// Realtime is supposed to make that unnecessary. On 22 Sep 2026 it did
/// not: the channel reported `subscribed` and then delivered no events at
/// all, for any table, so bookings reached the database and never reached
/// the front desk. Resuming the app now asks the server again, which is
/// what makes the console correct even when the socket is silent. That
/// path needs a backend, so it is covered on device rather than here (see
/// `qa-evidence/ADMIN_NEW/` 157–158: 7 waiting to 8, same process, no
/// pull).
///
/// What is worth locking here is the other half: the observer is wired up,
/// and with no backend configured it stays completely inert. A console
/// running offline must not fire network calls or throw every time it is
/// brought to the foreground, and `dispose()` must unhook it so a rebuilt
/// controller does not leave a dead observer behind.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AdminController> boot(ProviderContainer container) async {
    SharedPreferences.setMockInitialValues({});
    localStore = await LocalStore.open();
    final c = container.read(adminProvider.notifier);
    c.completeOnboarding();
    c.saveGarage(
      const Garage(
        id: 'garage-test',
        name: 'Hanuman',
        phone: '9000000000',
        addressLine: '1 Workshop Road',
        city: 'Mohali',
        state: 'Punjab',
        pin: '160055',
      ),
    );
    return c;
  }

  testWidgets('resuming with no backend changes nothing and does not throw', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final c = await boot(container);

    final before = c.state;

    // The real lifecycle path, not a direct method call: this only passes
    // while the controller is actually registered as an observer.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 600));

    expect(c.state, same(before));
  });

  testWidgets('a disposed controller stops listening', (tester) async {
    final container = ProviderContainer();
    final c = await boot(container);
    container.dispose();

    // Would throw on a StateNotifier used after dispose if the observer
    // were still hooked up.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 600));

    expect(c.mounted, isFalse);
  });
}
