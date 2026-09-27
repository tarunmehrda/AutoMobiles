import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:garagepro_admin/core/theme/app_theme.dart';
import 'package:garagepro_admin/data/models/enums.dart';
import 'package:garagepro_admin/data/repo/local_store.dart';
import 'package:garagepro_admin/features/jobcard/billing/billing.dart';
import 'package:garagepro_admin/state/admin_state.dart';

/// The three billing screens, on a phone, with a catalogue behind them.
///
/// Each one is a different layout — a ledger, a two-column gallery and a
/// measured shelf — and the two things that break a layout like that are the
/// same two every time: a long name, and a row with every optional field
/// filled in. So the fixture has both, and the assertions are about arithmetic
/// and overflow rather than about pixels.
///
/// Photography is deliberately not exercised. Every picture here is fetched
/// over the network, `Image.network` answers a test binding with a 400, and
/// that is the case the screens are built for — what these tests prove is
/// that the fallback path lays out at the same size as the photograph would.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> seeded() async {
    SharedPreferences.setMockInitialValues({});
    localStore = await LocalStore.open();
    final container = ProviderContainer();
    final c = container.read(adminProvider.notifier);
    c.completeOnboarding();

    c.addMaster(
      kind: LineKind.job,
      name: 'Engine head repair',
      rate: 300,
      fits: const ['Splendor Plus'],
    );
    c.addMaster(
      kind: LineKind.job,
      // Long on purpose: the longest job name in the shipped preset list is
      // this shape, and it is what pushes a ledger row into two lines.
      name: 'O ring and overhaul labour and fitting charge, engine out',
      rate: 200,
      outsourced: true,
    );
    c.addMaster(
      kind: LineKind.spare,
      name: 'Front disc pad',
      partNo: '20220418164716700000',
      rate: 269,
      cost: 180,
      stock: 4,
      make: 'Bosch',
      rack: 'B-14',
      group: PartGroup.running,
    );
    c.addMaster(
      kind: LineKind.spare,
      name: 'Head light bulb',
      rate: 114,
      stock: 0,
      group: PartGroup.accessory,
    );
    c.addMaster(
      kind: LineKind.lube,
      name: 'Semi synthetic engine oil',
      rate: 450,
      cost: 360,
      stock: 3,
      unit: 'ltr',
      make: 'Yamalube',
    );
    c.addMaster(
      kind: LineKind.lube,
      name: 'Yamalube TFF oil 10W 500ml',
      rate: 188,
      stock: 400,
      unit: 'ml',
    );
    return container;
  }

  Future<void> pump(
    WidgetTester tester,
    ProviderContainer container,
    Widget page,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.light(), home: page),
      ),
    );
    // Not `pumpAndSettle`: the entrance cascade and the shimmer on the
    // loading tiles are both perpetual enough to time that out.
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('jobs: tapping a row puts it on the bill at its rate', (
    tester,
  ) async {
    final container = await seeded();
    addTearDown(container.dispose);
    await pump(tester, container, const BillJobsPage());

    expect(find.text('Engine head repair'), findsOneWidget);
    expect(find.text('In house'), findsWidgets);
    expect(find.text('Out sourced'), findsWidgets);

    await tester.tap(find.text('Engine head repair'));
    await tester.pump(const Duration(milliseconds: 400));

    // Three times over: the row's own rate panel, the masthead total and
    // the footer total — the two places the counter reads a total from, plus
    // the line it came from.
    expect(find.text('₹300'), findsNWidgets(3));
    expect(find.text('1 job'), findsOneWidget);

    // Tapping again takes it back off, rather than adding a second one.
    await tester.tap(find.text('Engine head repair'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Nothing yet'), findsOneWidget);
  });

  testWidgets('spare: the shelf filter narrows the gallery', (tester) async {
    final container = await seeded();
    addTearDown(container.dispose);
    await pump(tester, container, const BillSparePage());

    expect(find.text('Front disc pad'), findsOneWidget);
    expect(find.text('Head light bulb'), findsOneWidget);
    expect(find.text('Out of stock'), findsOneWidget);

    await tester.tap(find.text('Running'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Front disc pad'), findsOneWidget);
    expect(find.text('Head light bulb'), findsNothing);
  });

  testWidgets('lube: a litre steps in halves and prices to match', (
    tester,
  ) async {
    final container = await seeded();
    addTearDown(container.dispose);
    await pump(tester, container, const BillLubePage());

    expect(find.text('Semi synthetic engine oil'), findsOneWidget);
    expect(find.text('3 LTR in the store'), findsOneWidget);

    // The catalogue is sorted by name, so the first add button on the screen
    // belongs to the oil and not to the 500 ml bottle under it.
    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pump(const Duration(milliseconds: 400));

    // Half a litre of a ₹450/litre oil is ₹225 — the whole reason this
    // screen steps the way it does.
    expect(find.text('0.5 LTR'), findsOneWidget);
    expect(find.text('₹225'), findsWidgets);
  });

  testWidgets('the new-part form keeps a running margin', (tester) async {
    final container = await seeded();
    addTearDown(container.dispose);
    await pump(tester, container, const MasterFormPage(kind: LineKind.spare));

    expect(find.text('Running Items'), findsOneWidget);
    expect(find.text('Engine Part'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Clutch cable');
    await tester.pump();
    // Twice: in the field, and in the preview card at the top of the page
    // that is showing how the row will read.
    expect(find.text('Clutch cable'), findsNWidgets(2));

    // The money block is the last of four on a scrolling page, so on a phone
    // it is not built until it is reached.
    await tester.dragUntilVisible(
      find.text('What it costs'),
      find.byType(ListView),
      const Offset(0, -240),
    );
    await tester.pump();

    await tester.enterText(find.widgetWithText(TextFormField, 'You pay'), '60');
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'They pay *'),
      '100',
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('You keep'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
    expect(find.text('₹40'), findsOneWidget);
  });
}
