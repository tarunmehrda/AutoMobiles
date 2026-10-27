import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:garagepro_admin/core/theme/app_theme.dart';
import 'package:garagepro_admin/core/widgets/g_button.dart';
import 'package:garagepro_admin/data/models/entities.dart';
import 'package:garagepro_admin/data/repo/local_store.dart';
import 'package:garagepro_admin/features/shared/delete_account.dart';
import 'package:garagepro_admin/state/admin_state.dart';

/// Settings → Delete account. An owner is told the whole workshop goes, and
/// nothing can be deleted by a tap: DELETE has to be typed first.
void main() {
  testWidgets('an owner sees what goes, and must type DELETE', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    localStore = await LocalStore.open();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(adminProvider.notifier)
        .saveGarage(
          const Garage(
            id: 'garage-test',
            name: 'Wipe Motors',
            phone: '9000000000',
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => confirmDeleteAccount(context, ref),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Wipe Motors'), findsOneWidget);
    expect(find.text('Your login'), findsOneWidget);

    GButton deleteButton() =>
        tester.widget<GButton>(find.widgetWithText(GButton, 'Delete forever'));
    expect(deleteButton().onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'delete');
    await tester.pump();
    expect(deleteButton().onPressed, isNotNull);

    await tester.tap(find.text('Keep my account'));
    await tester.pumpAndSettle();
    // Nothing happened: the workshop is still on the phone.
    expect(container.read(adminProvider).garage?.name, 'Wipe Motors');
    await tester.pump(const Duration(milliseconds: 400));
  });
}
