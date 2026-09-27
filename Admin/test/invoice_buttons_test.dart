import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:garagepro_admin/core/theme/app_theme.dart';
import 'package:garagepro_admin/features/jobcard/documents/doc_sections.dart';
import 'package:garagepro_admin/features/jobcard/documents/invoice_format.dart';
import 'package:garagepro_admin/features/jobcard/jobcard_detail_page.dart';
import 'package:garagepro_admin/features/jobcard/widgets/share_sheet.dart';
import 'package:garagepro_admin/features/jobcard/widgets/template_picker.dart';
import 'package:garagepro_admin/data/models/entities.dart';
import 'package:garagepro_admin/data/models/enums.dart';
import 'package:garagepro_admin/data/repo/local_store.dart';
import 'package:garagepro_admin/state/admin_state.dart';
import 'package:garagepro_admin/state/auth_state.dart';

/// The download and share buttons on a job card.
///
/// These are the two things the counter presses most, and when they fail they
/// fail silently — the PDF is built, shared and saved behind a `try`, so a
/// broken step just looks like a dead button. These tests press the real
/// buttons and insist something visible comes back.
Future<(ProviderContainer, String)> _shop() async {
  SharedPreferences.setMockInitialValues({});
  localStore = await LocalStore.open();

  final container = ProviderContainer(
    overrides: [signedInProvider.overrideWithValue(true)],
  );
  final c = container.read(adminProvider.notifier);
  c.markSignedIn();
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
  c.addMaster(kind: LineKind.job, name: 'General Service Labour', rate: 900);
  final customer = c.upsertCustomer(name: 'Tarun Sharma', phone: '9462153613');
  final vehicle = c.upsertVehicle(
    customerId: customer.id,
    regNo: 'RJ18CC1390',
    brand: 'Suzuki',
    model: 'Swish',
  );
  final card = c.createJobCard(
    customerId: customer.id,
    vehicleId: vehicle.id,
    odometerKm: 41000,
    fuelPercent: 60,
  );
  c.addItem(card.id, kind: LineKind.job, name: 'Carburator Setting', rate: 70);
  // The optional blocks only draw when there is something behind them, so a
  // bare card would exercise none of them through the buttons.
  c.setVoices(card.id, ['Engine Noise']);
  c.setAccessories(card.id, ['Tool Kit']);
  c.setWorkNote(card.id, 'Road test before handing over.');
  return (container, card.id);
}

/// Opens the card straight, rather than through the router: the console
/// redirects on a dozen conditions and none of them are what is under test.
Future<void> _open(
  WidgetTester tester,
  ProviderContainer container,
  String cardId, {
  DocKind doc = DocKind.invoice,
}) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        debugShowCheckedModeBanner: false,
        home: JobCardDetailPage(id: cardId, initialDoc: doc),
      ),
    ),
  );
  await _settle(tester);
}

/// Lets any toast run out its three seconds, so its timer does not fire into
/// a torn-down tree once the test ends.
Future<void> _drainToasts(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 4));
  await tester.pump();
}

/// The dashboard keeps a looping animation running, so `pumpAndSettle` never
/// returns. Pump a fixed stretch of frames instead.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Stands in for the Android side of the Downloads channel.
  late List<MethodCall> saves;

  setUp(() {
    // The template choice is remembered for the session, so a test that
    // picked a thermal roll would otherwise decide what the next one opens
    // on. Each test starts from the same paper.
    ShareSheet.lastFormat = InvoiceFormat.simpleA4;
    saves = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('garagepro/downloads'), (
          call,
        ) async {
          saves.add(call);
          return 'Downloads/${call.arguments['name']}';
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('garagepro/downloads'),
          null,
        );
  });

  testWidgets('the download button always reports what happened', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    final (container, cardId) = await _shop();
    addTearDown(container.dispose);
    await _open(tester, container, cardId);

    // The PDF is built off real async I/O (the bundled font), which the
    // fake-async zone a widget test runs in never completes on its own.
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Download PDF'));
      await Future<void>.delayed(const Duration(seconds: 2));
    });
    await _settle(tester);

    // Whatever the platform does with the file, the counter must be told
    // something. A button that silently does nothing is the bug.
    final said = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .where(
          (d) =>
              d.contains('Saved to') ||
              d.contains('Choose where') ||
              d.startsWith('Could not'),
        )
        .toList();
    expect(
      said,
      isNotEmpty,
      reason: 'the download button gave no feedback at all',
    );
    await _drainToasts(tester);
  });

  testWidgets('the share button opens the sheet with every route on it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    final (container, cardId) = await _shop();
    addTearDown(container.dispose);
    await _open(tester, container, cardId);

    await tester.tap(find.text('Share'));
    await _settle(tester);

    for (final label in [
      'WhatsApp',
      'Email',
      'Print',
      'Download PDF',
      'Share image',
      'Copy text',
    ]) {
      expect(find.text(label), findsOneWidget, reason: '$label is missing');
    }
  });

  testWidgets('every document kind builds a PDF the buttons can hand on', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    final (container, cardId) = await _shop();
    addTearDown(container.dispose);

    for (final kind in DocKind.values) {
      await _open(tester, container, cardId, doc: kind);
      expect(
        find.text(kind.label),
        findsWidgets,
        reason: '${kind.label} did not open',
      );
      await tester.runAsync(() async {
        await tester.tap(find.byTooltip('Download PDF'));
        await Future<void>.delayed(const Duration(seconds: 2));
      });
      await _settle(tester);
      expect(
        tester.takeException(),
        isNull,
        reason: '${kind.label} threw on download',
      );
      await _drainToasts(tester);
    }
  });

  testWidgets('all five templates and every block are on the card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    final (container, cardId) = await _shop();
    addTearDown(container.dispose);
    await _open(tester, container, cardId);

    final strip = find.descendant(
      of: find.byType(TemplatePicker),
      matching: find.byType(Scrollable),
    );
    for (final format in InvoiceFormat.values) {
      await tester.dragUntilVisible(
        find.text(format.label),
        strip,
        const Offset(-120, 0),
      );
      expect(
        find.text(format.label),
        findsOneWidget,
        reason: '${format.label} is not on the picker',
      );
    }

    for (final section in DocSectionX.offeredOn(
      InvoiceFormat.simpleA4,
      DocKind.invoice,
    )) {
      expect(
        find.text(section.label),
        findsWidgets,
        reason: '${section.label} is missing from the picker',
      );
    }
  });

  testWidgets('every template downloads from the card it is picked on', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    final (container, cardId) = await _shop();
    addTearDown(container.dispose);
    await _open(tester, container, cardId);

    final strip = find.descendant(
      of: find.byType(TemplatePicker),
      matching: find.byType(Scrollable),
    );

    for (final format in InvoiceFormat.values) {
      // dragUntilVisible stops as soon as the tile is in the tree, which on
      // a horizontal strip can still be past the right edge of the screen.
      // A tap there lands on nothing and reports no failure, so bring it
      // properly into view before pressing it.
      await tester.dragUntilVisible(
        find.text(format.label),
        strip,
        const Offset(-120, 0),
      );
      await tester.ensureVisible(find.text(format.label));
      await _settle(tester);
      await tester.tap(find.text(format.label));
      await _settle(tester);

      // Tapping the template is what the download reads, so this is the
      // link worth pinning: the button and the picker cannot drift apart.
      expect(
        ShareSheet.lastFormat,
        format,
        reason: '${format.label} did not become the chosen template',
      );

      await tester.runAsync(() async {
        await tester.tap(find.byTooltip('Download PDF'));
        await Future<void>.delayed(const Duration(seconds: 3));
      });
      await _settle(tester);

      expect(
        tester.takeException(),
        isNull,
        reason: '${format.label} threw on download',
      );
      // Whatever the platform did with the file, the counter must be told.
      // A button that silently does nothing is the bug.
      final said = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .where(
            (d) =>
                d.contains('Saved to') ||
                d.contains('Choose where') ||
                d.startsWith('Could not'),
          )
          .toList();
      expect(
        said,
        isNotEmpty,
        reason: '${format.label} gave no feedback at all',
      );
      await _drainToasts(tester);
    }
  });

  testWidgets('the share sheet opens on the template the card is showing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    final (container, cardId) = await _shop();
    addTearDown(container.dispose);
    await _open(tester, container, cardId);

    final strip = find.descendant(
      of: find.byType(TemplatePicker),
      matching: find.byType(Scrollable),
    );
    await tester.dragUntilVisible(
      find.text(InvoiceFormat.taxA4.label),
      strip,
      const Offset(-120, 0),
    );
    await tester.ensureVisible(find.text(InvoiceFormat.taxA4.label));
    await _settle(tester);
    await tester.tap(find.text(InvoiceFormat.taxA4.label));
    await _settle(tester);

    await tester.tap(find.text('Share'));
    await _settle(tester);

    // The sheet carries the same picker, and opens on the choice already
    // made rather than resetting to the default template.
    expect(find.byType(TemplatePicker), findsNWidgets(2));
    expect(ShareSheet.lastFormat, InvoiceFormat.taxA4);

    for (final label in [
      'WhatsApp',
      'Email',
      'Print',
      'Download PDF',
      'Share image',
      'Copy text',
    ]) {
      expect(find.text(label), findsOneWidget, reason: '$label is missing');
    }
  });
}
