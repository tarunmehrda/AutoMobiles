import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:garagepro_admin/core/theme/app_theme.dart';
import 'package:garagepro_admin/core/widgets/g_feedback.dart';
import 'package:garagepro_admin/core/widgets/g_field.dart';
import 'package:garagepro_admin/data/models/entities.dart';
import 'package:garagepro_admin/data/repo/local_store.dart';
import 'package:garagepro_admin/features/online/online_garage_page.dart';
import 'package:garagepro_admin/state/admin_state.dart';

/// Two ways the console used to put a red screen over itself, both of which
/// ended in the same unhelpful line:
///
///   'package:flutter/src/widgets/framework.dart': Failed assertion:
///   '_dependents.isEmpty': is not true.
///
/// That assertion is never the bug. It is what the framework says *next*,
/// after something else has already thrown in the middle of a build and left
/// a subtree half torn down. Both tests here go after the something else.
///
/// Both need the same thing to show up: a second action inside the few hundred
/// milliseconds a transition takes. That is why neither surfaced in ordinary
/// use and why both are easy to hit at a busy counter.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// A sheet's future completes when it *starts* closing. The route keeps
  /// rebuilding for the length of its exit transition, and a `TextField`
  /// resubscribes to its controller on every one of those rebuilds — so a
  /// controller disposed on the line after the `await` is read after it is
  /// dead.
  testWidgets('a sheet outlives the await that opened it', (tester) async {
    final controller = TextEditingController(text: '10');
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                // The shape every sheet in this app is opened with: build the
                // controllers, await the sheet, dispose on the way out.
                onPressed: () async {
                  await GFeedback.sheet<void>(
                    context,
                    title: 'Receive stock',
                    disposing: [controller],
                    child: Builder(
                      builder: (context) => Padding(
                        // Every sheet in this app does this, so that the fields
                        // sit above the keyboard. It also means the sheet
                        // rebuilds on every frame of the keyboard sliding away
                        // — including the frames after the caller has disposed.
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.viewInsetsOf(context).bottom,
                        ),
                        child: GField(
                          label: 'Quantity',
                          controller: controller,
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    // Keyboard up, the way it is whenever somebody has just typed into the
    // sheet they are now closing.
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);

    Navigator.of(tester.element(find.byType(TextField))).pop();

    // Frame by frame through the exit transition, with the keyboard sliding
    // away underneath it — the window in which the field is still on screen,
    // still rebuilding, and reading a controller the caller has finished with.
    for (var i = 0; i < 20; i++) {
      tester.view.viewInsets = FakeViewPadding(bottom: 900 - i * 45.0);
      await tester.pump(const Duration(milliseconds: 20));
      expect(
        tester.takeException(),
        isNull,
        reason: 'threw during the sheet exit transition',
      );
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  /// `AnimatedSwitcher.defaultTransitionBuilder` keys its `FadeTransition` off
  /// the child's key, and the switcher keys each entry off the transition. Give
  /// two children fixed keys and swap back before the first has finished
  /// leaving, and both copies land in the same `Stack` under the same key.
  testWidgets('the online garage switch survives being flipped twice', (
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
        id: 'g',
        name: 'Vikas Automobiles',
        phone: '9000000000',
        addressLine: '1 Workshop Road',
        city: 'Jaipur',
        state: 'Rajasthan',
        pin: '302020',
      ),
    );

    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const OnlineGaragePage(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    // On, off, on, off — each flip well inside the 320ms the last one needs
    // to finish fading. Somebody deciding whether to go live does exactly
    // this.
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byType(Switch), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.takeException(), isNull, reason: 'threw on flip ${i + 1}');
    }

    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}
