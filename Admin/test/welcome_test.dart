import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:garagepro_admin/core/theme/app_theme.dart';
import 'package:garagepro_admin/core/widgets/cinematic_hero.dart';
import 'package:garagepro_admin/features/auth/login_page.dart';

/// The welcome screen, laid out the way a phone would.
///
/// [CinematicBackground] is a single still under a drift, so what the test is
/// really asking is: does the screen hold together over that one frame, at the
/// sizes real phones come in?
void main() {
  Future<void> pumpWelcome(WidgetTester tester, Size size) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.light(), home: const LoginPage()),
      ),
    );

    // Long enough for the staggered entrances to finish, but never
    // `pumpAndSettle` — the background drift runs forever by design, and
    // settling would wait on it until it timed out.
    await tester.pump(const Duration(milliseconds: 900));
  }

  /// Takes the tree down so the drift controller is disposed before the
  /// test ends.
  Future<void> teardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  const sizes = <String, Size>{
    'small phone': Size(360, 640),
    'common phone': Size(390, 844),
    'tall phone': Size(412, 915),
  };

  for (final entry in sizes.entries) {
    testWidgets('lays out with no overflow on a ${entry.key}', (tester) async {
      await pumpWelcome(tester, entry.value);

      // A RenderFlex overflow reports itself through the same channel as any
      // other framework error, so an empty exception slot is the assertion.
      expect(tester.takeException(), isNull);

      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Continue with email'), findsOneWidget);

      await teardown(tester);
    });
  }

  testWidgets('paints the hero still full-bleed', (tester) async {
    await pumpWelcome(tester, const Size(390, 844));

    // The still is the whole background — it must actually be painted, not
    // merely constructed, and it must cover rather than letterbox.
    final still = tester.widget<Image>(
      find.descendant(
        of: find.byType(CinematicBackground),
        matching: find.byType(Image),
      ),
    );
    expect((still.image as AssetImage).assetName, HeroStill.image);
    expect(still.fit, BoxFit.cover);
    expect(tester.takeException(), isNull);

    await teardown(tester);
  });
}
