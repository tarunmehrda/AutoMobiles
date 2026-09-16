import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:garagepro_admin/core/theme/app_theme.dart';
import 'package:garagepro_admin/core/widgets/cinematic_hero.dart';
import 'package:garagepro_admin/features/auth/login_page.dart';

/// The welcome screen, laid out the way a phone would.
///
/// There is no video plugin behind a widget test, so every pump here goes
/// down [CinematicBackground]'s no-decoder path — which is exactly the branch
/// worth guarding, because it is the one that runs on any device whose
/// platform cannot give us a decoder. What the test is really asking is: does
/// the screen still hold together with only the poster frame under it, at the
/// sizes real phones come in?
void main() {
  Future<void> pumpWelcome(WidgetTester tester, Size size) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const LoginPage(),
        ),
      ),
    );

    // Long enough for the staggered entrances to finish, but never
    // `pumpAndSettle` — the ticker and the poster drift both run forever by
    // design, and settling would wait on them until it timed out.
    await tester.pump(const Duration(milliseconds: 900));
  }

  /// Takes the tree down so the ticker's timer and the drift controller are
  /// disposed before the test ends.
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
    testWidgets('lays out with no overflow on a ${entry.key}',
        (tester) async {
      await pumpWelcome(tester, entry.value);

      // A RenderFlex overflow reports itself through the same channel as any
      // other framework error, so an empty exception slot is the assertion.
      expect(tester.takeException(), isNull);

      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Continue with email'), findsOneWidget);

      await teardown(tester);
    });
  }

  testWidgets('falls back to the poster when there is no decoder',
      (tester) async {
    await pumpWelcome(tester, const Size(390, 844));

    // The reel never initialises here, so the still is what is on screen —
    // and it must actually be painted, not merely constructed.
    final poster = tester.widget<Image>(
      find.descendant(
        of: find.byType(CinematicBackground),
        matching: find.byType(Image),
      ),
    );
    expect((poster.image as AssetImage).assetName, HeroReel.poster);
    expect(poster.fit, BoxFit.cover);
    expect(tester.takeException(), isNull);

    await teardown(tester);
  });
}
