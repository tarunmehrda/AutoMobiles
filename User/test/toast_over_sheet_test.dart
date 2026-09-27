import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:garagepro/core/theme/app_theme.dart';
import 'package:garagepro/core/widgets/g_feedback.dart';

/// A SnackBar belongs to the page's Scaffold, which sits under every modal
/// route — so "Enter an amount first." raised on the payment sheet used to
/// land behind that sheet, and the button looked dead. These pin down where
/// a toast is drawn now.
void main() {
  Widget host(Widget Function(BuildContext) body) => MaterialApp(
    theme: AppTheme.light(),
    home: Builder(builder: (context) => Scaffold(body: body(context))),
  );

  testWidgets('a toast raised inside a sheet is drawn above the sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        (context) => Center(
          child: ElevatedButton(
            onPressed: () => GFeedback.sheet<void>(
              context,
              title: 'Record payment',
              child: Builder(
                builder: (context) => SizedBox(
                  // Tall enough to cover where a SnackBar would sit.
                  height: 700,
                  child: Center(
                    child: ElevatedButton(
                      onPressed: () =>
                          GFeedback.error(context, 'Enter an amount first.'),
                      child: const Text('record'),
                    ),
                  ),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('record'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Enter an amount first.').hitTestable(), findsOneWidget);

    // And it goes away on its own clock.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Enter an amount first.'), findsNothing);
  });

  testWidgets('a toast from the page itself is still a SnackBar', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        (context) => Center(
          child: ElevatedButton(
            onPressed: () => GFeedback.success(context, 'Saved'),
            child: const Text('save'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('save'));
    await tester.pump();
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('a toast over a dialog leaves no timer behind', (tester) async {
    await tester.pumpWidget(
      host(
        (context) => Center(
          child: ElevatedButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => Dialog(
                child: ElevatedButton(
                  onPressed: () => GFeedback.info(context, 'hi'),
                  child: const Text('go'),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    // Twice: the second replaces the first rather than stacking on it.
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.tap(find.text('go'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('hi'), findsOneWidget);
    // Torn down mid-toast: the test binding fails on any pending timer.
    await tester.pumpWidget(const SizedBox());
  });
}
