import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:garagepro_admin/core/theme/app_theme.dart';
import 'package:garagepro_admin/data/models/entities.dart';
import 'package:garagepro_admin/data/repo/local_store.dart';
import 'package:garagepro_admin/features/bookings/bookings_page.dart';
import 'package:garagepro_admin/state/admin_state.dart';

/// The front desk must be able to ask again.
///
/// The console is realtime-first, and on 21 Sep 2026 realtime was not
/// delivering: a customer confirmed four bookings, every row reached
/// `garage_bookings` immediately, and this screen showed one. The table was
/// missing from the realtime publication (see
/// `supabase/16_fix_realtime_publication.sql`), so no event ever arrived.
///
/// What made that a lost booking rather than a slow one is that the screen
/// had no [RefreshIndicator]. There was no way to ask the server again short
/// of force-stopping the app, which is not something a counter will think to
/// do. The gesture has to be there on the empty state too — an empty list is
/// exactly when somebody reaches for it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pump(WidgetTester tester, ProviderContainer container) =>
      tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const BookingsPage(),
          ),
        ),
      );

  Future<ProviderContainer> boot() async {
    SharedPreferences.setMockInitialValues({});
    localStore = await LocalStore.open();
    final container = ProviderContainer();
    container.read(adminProvider.notifier).completeOnboarding();
    return container;
  }

  testWidgets('a waiting list can be pulled to refresh', (tester) async {
    final container = await boot();
    addTearDown(container.dispose);

    container.read(adminProvider.notifier).addBooking(
      Booking(
        id: 'bk-1',
        name: 'Amit Verma',
        phone: '9001122334',
        at: DateTime(2026, 9, 22, 10),
        regNo: 'PB65AB1234',
        vehicle: 'Maruti Suzuki Swift',
      ),
    );

    await pump(tester, container);
    await tester.pumpAndSettle();

    expect(find.text('Amit Verma'), findsOneWidget);
    expect(find.byType(RefreshIndicator), findsOneWidget);

    // The gesture actually reaches the indicator rather than being eaten by
    // a list that will not overscroll.
    await tester.fling(find.text('Amit Verma'), const Offset(0, 320), 1000);
    await tester.pump();
    expect(find.byType(RefreshProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('the empty state can be pulled to refresh too', (tester) async {
    final container = await boot();
    addTearDown(container.dispose);

    await pump(tester, container);
    await tester.pumpAndSettle();

    expect(find.byType(RefreshIndicator), findsOneWidget);

    // Scrollable despite having nothing in it: without
    // AlwaysScrollableScrollPhysics the pull does nothing at all here.
    final list = tester.widget<ListView>(find.byType(ListView));
    expect(list.physics, isA<AlwaysScrollableScrollPhysics>());

    // LocalStore debounces its write; let it fire so the test does not end
    // holding a pending timer.
    await tester.pump(const Duration(milliseconds: 400));
  });
}
