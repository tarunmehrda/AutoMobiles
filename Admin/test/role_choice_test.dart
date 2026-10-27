import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:garagepro_admin/core/theme/app_theme.dart';
import 'package:garagepro_admin/features/auth/role_choice.dart';

/// The first screen after a new sign-in: owner, manager or staff, and
/// never Super Admin, which is set on the server and cannot be chosen.
void main() {
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  testWidgets('offers owner, manager and staff; never super admin', (
    tester,
  ) async {
    // 320 dp wide: the narrowest phone this has to fit.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    JoinAs? picked;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: RoleChoiceView(
            email: 'ravi@gmail.com',
            onPick: (r) => picked = r,
          ),
        ),
      ),
    );
    await settle(tester);

    expect(find.text('Workshop owner'), findsOneWidget);
    expect(find.text('Manager'), findsOneWidget);
    expect(find.text('Staff'), findsOneWidget);
    expect(find.textContaining('Super'), findsNothing);
    expect(find.text('ravi@gmail.com'), findsOneWidget);

    await tester.tap(find.text('Manager'));
    await settle(tester);
    expect(picked, JoinAs.manager);
  });

  testWidgets('a manager is told to ask the owner, with their email', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: JoinWorkshopView(
              role: JoinAs.manager,
              email: 'ravi@gmail.com',
              onJoined: () async {},
              onSignOut: () {},
            ),
          ),
        ),
      ),
    );
    await settle(tester);

    expect(find.text('Waiting for the owner'), findsOneWidget);
    expect(find.text('ravi@gmail.com'), findsOneWidget);
    expect(find.text('Check now'), findsOneWidget);
    expect(find.text('Use a different email'), findsOneWidget);

    // Stops the poll and the pulse before the test ends.
    await tester.pumpWidget(const SizedBox());
  });
}
