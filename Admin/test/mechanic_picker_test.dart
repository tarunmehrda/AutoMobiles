import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:garagepro_admin/core/theme/app_theme.dart';
import 'package:garagepro_admin/data/models/entities.dart';
import 'package:garagepro_admin/data/repo/local_store.dart';
import 'package:garagepro_admin/features/jobcard/create_jobcard_page.dart';
import 'package:garagepro_admin/state/admin_state.dart';

/// The Select Mechanic dialog on the bill step used to be an [AlertDialog],
/// whose action bar measures its buttons before laying them out. A [GButton]
/// cannot be measured that way, so the dialog threw on every layout pass: the
/// list never appeared and the screen sat there dead behind the barrier.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the mechanic dialog opens, takes a pick and closes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    localStore = await LocalStore.open();
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final c = container.read(adminProvider.notifier);
    c.completeOnboarding();
    c.saveGarage(
      const Garage(
        id: 'garage-test',
        name: 'Vikas Automobiles',
        phone: '9000000000',
        addressLine: '1 Workshop Road',
        city: 'Jaipur',
        state: 'Rajasthan',
        pin: '302020',
      ),
    );
    // A full team, because the crash only showed once the dialog had to lay
    // itself out against a phone-sized screen.
    for (var i = 1; i <= 8; i++) {
      c.addStaff(
        name: 'Mechanic Number $i',
        phone: '981234567$i',
        skill: 'Engine',
      );
    }

    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const CreateJobCardPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Straight to the bill step, which is where the floor is assigned.
    tester.widget<PageView>(find.byType(PageView)).controller!.jumpToPage(3);
    await tester.pumpAndSettle();

    // The step's masthead carries a four-node stepper now, so the mechanic
    // field starts below the fold on a phone and has to be scrolled to before
    // it can be tapped.
    await tester.ensureVisible(find.text('Select Mechanic').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select Mechanic').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(CheckboxListTile), findsNWidgets(8));

    await tester.tap(find.text('Mechanic Number 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DONE'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(CheckboxListTile), findsNothing);
    // The pick comes back as a chip you can take off where it stands,
    // not as a line of text reading `Selected Mech: [...]`.
    expect(find.text('Mechanic Number 2'), findsOneWidget);
    expect(find.text('Add another'), findsOneWidget);
  });
}
