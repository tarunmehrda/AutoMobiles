import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:garagepro_admin/core/theme/app_theme.dart';
import 'package:garagepro_admin/data/repo/local_store.dart';
import 'package:garagepro_admin/state/admin_state.dart';
import 'package:garagepro_admin/features/reports/stock_jobs_report_page.dart';
import 'package:garagepro_admin/features/reports/widgets/date_range_bar.dart';
import 'package:garagepro_admin/state/auth_state.dart';

/// The Stock & Jobs report came back from the floor as a blank white page
/// with its footer drawn over the status bar. Nothing threw, so the smoke
/// test could not see it: the page is laid out, it is just laid out wrong.
///
/// The one thing the smoke test never supplies is a status bar. Every phone
/// has one; `tester.view` has none unless it is asked for. This pins the
/// inset in place so the arithmetic that goes wrong here goes wrong in a
/// test too.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeDateFormatting);

  testWidgets('the report fills the screen under a status bar', (tester) async {
    SharedPreferences.setMockInitialValues({});
    localStore = await LocalStore.open();

    tester.view.physicalSize = const Size(1220, 2712);
    tester.view.devicePixelRatio = 3.0;
    // A Redmi in portrait: 122 physical px of status bar, 0 at the bottom
    // because the phone is on gesture navigation.
    tester.view.padding = const FakeViewPadding(top: 122);
    tester.view.viewPadding = const FakeViewPadding(top: 122);
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [signedInProvider.overrideWithValue(true)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          debugShowCheckedModeBanner: false,
          home: const StockJobsReportPage(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    final exception = tester.takeException();
    // ignore: avoid_print
    print('exception: $exception');

    Size sizeOf(Finder f) {
      final box = tester.renderObject<RenderBox>(f.first);
      return box.size;
    }

    Offset topLeftOf(Finder f) {
      final box = tester.renderObject<RenderBox>(f.first);
      return box.localToGlobal(Offset.zero);
    }

    for (final entry in <String, Finder>{
      'Scaffold': find.byType(Scaffold),
      'DateRangeBar': find.byType(DateRangeBar),
      'ReportFooter': find.byType(ReportFooter),
    }.entries) {
      if (entry.value.evaluate().isEmpty) {
        // ignore: avoid_print
        print('${entry.key}: NOT FOUND');
        continue;
      }
      // ignore: avoid_print
      print('${entry.key}: size=${sizeOf(entry.value)} '
          'at=${topLeftOf(entry.value)}');
    }

    // The footer belongs at the bottom of the screen, not over the clock.
    final footerTop = topLeftOf(find.byType(ReportFooter)).dy;
    expect(
      footerTop,
      greaterThan(400),
      reason: 'the totals bar is drawn at the top of the screen',
    );
  });
}
