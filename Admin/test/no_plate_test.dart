import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:garagepro_admin/core/theme/app_theme.dart';
import 'package:garagepro_admin/core/widgets/g_field.dart';
import 'package:garagepro_admin/data/models/entities.dart';
import 'package:garagepro_admin/data/repo/local_store.dart';
import 'package:garagepro_admin/features/jobcard/create_jobcard_page.dart';
import 'package:garagepro_admin/state/admin_state.dart';

/// Switching on "No Vehicle Number" used to disable the registration field on
/// *both* steps of the intake. The toggle that undid it lived on step one, so
/// a counter who reached the details form and only then found a plate — on
/// the chassis, on the insurance paper, in the owner's hand — had no way to
/// type it without backing out of the form they had just filled in.
///
/// The field is now never disabled: "no plate" is a statement about what is
/// in the box, not a lock on the box.
Future<ProviderContainer> _shop() async {
  SharedPreferences.setMockInitialValues({});
  localStore = await LocalStore.open();
  final container = ProviderContainer();
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
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a walk-in with no plate can still be given one later', (
    tester,
  ) async {
    final container = await _shop();
    addTearDown(container.dispose);

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

    // The counter declares the vehicle unnumbered.
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    // Straight on to the details form, the way the onboarding button goes.
    tester.widget<PageView>(find.byType(PageView)).controller!.jumpToPage(1);
    await tester.pumpAndSettle();

    // GField puts its label in a Text above the input, so the field is found
    // through the GField rather than by the label on the TextField itself.
    Finder plateField(String label) => find.descendant(
      of: find.byWidgetPredicate((w) => w is GField && w.label == label),
      matching: find.byType(TextField),
    );

    final plate = plateField('Vehicle Number');
    expect(
      plate,
      findsOneWidget,
      reason: 'the field is labelled without an asterisk while optional',
    );
    expect(
      tester.widget<TextField>(plate).enabled,
      isNot(false),
      reason: 'the plate field must never be locked',
    );

    // A plate turns up after all.
    await tester.enterText(plate, 'RJ18CC1390');
    await tester.pumpAndSettle();

    expect(
      find.text('RJ18CC1390'),
      findsWidgets,
      reason: 'what was typed has to survive',
    );

    // And once there is one, it is required again rather than optional.
    expect(plateField('Vehicle Number *'), findsOneWidget);
  });

  testWidgets('the search box stays usable after the toggle is flipped', (
    tester,
  ) async {
    final container = await _shop();
    addTearDown(container.dispose);

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

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    final lookup = find.byType(TextField).first;
    expect(
      tester.widget<TextField>(lookup).enabled,
      isNot(false),
      reason: 'flipping the toggle by mistake must not lock the search',
    );

    await tester.enterText(lookup, 'RJ18CC1390');
    await tester.pumpAndSettle();
    expect(find.text('RJ18CC1390'), findsWidgets);
  });
}
