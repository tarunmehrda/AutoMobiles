import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:garagepro_admin/core/theme/app_theme.dart';
import 'package:garagepro_admin/data/models/entities.dart';
import 'package:garagepro_admin/data/models/enums.dart';
import 'package:garagepro_admin/features/jobcard/documents/doc_sections.dart';
import 'package:garagepro_admin/features/jobcard/documents/invoice_format.dart';
import 'package:garagepro_admin/features/jobcard/documents/job_document.dart';
import 'invoice_fixture.dart';

/// The document on screen.
///
/// This is what the counter reads before pressing anything, and what "Share
/// image" captures, so it has to answer to the same template and the same
/// ticks the PDF does. A preview that ignores either is worse than no
/// preview: it tells somebody the bill is right when it is not.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ({
    JobCard card,
    Garage garage,
    Customer customer,
    Vehicle vehicle,
    List<Staff> staff,
    dynamic dir,
  })
  f;

  setUp(() async => f = await fullCard());

  /// Laid out in a Column inside a scroll view rather than the page's own
  /// ListView: a sliver builds lazily, so half the document would simply not
  /// be in the tree to look for.
  Future<void> pump(
    WidgetTester tester, {
    required InvoiceFormat format,
    required Set<DocSection> sections,
    DocKind kind = DocKind.invoice,
  }) async {
    tester.view.physicalSize = const Size(1170, 4000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: SingleChildScrollView(
            child: JobDocument(
              kind: kind,
              card: f.card,
              garage: f.garage,
              customer: f.customer,
              vehicle: f.vehicle,
              staff: f.staff,
              format: format,
              sections: sections,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('the template decides the shape', () {
    testWidgets('an A4 sheet signs off; a roll thanks you and does not', (
      tester,
    ) async {
      await pump(
        tester,
        format: InvoiceFormat.simpleA4,
        sections: DocSectionX.defaultsFor(
          InvoiceFormat.simpleA4,
          DocKind.invoice,
        ),
      );
      expect(find.text('Customer signature'), findsOneWidget);
      expect(find.text('Thank you for choosing'), findsNothing);

      await pump(
        tester,
        format: InvoiceFormat.thermal58,
        sections: DocSectionX.defaultsFor(
          InvoiceFormat.thermal58,
          DocKind.invoice,
        ),
      );
      expect(find.text('Thank you for choosing'), findsOneWidget);
      expect(find.text('Customer signature'), findsNothing);
    });

    testWidgets(
      'the tax template splits CGST and SGST, the simple one does not',
      (tester) async {
        await pump(tester, format: InvoiceFormat.taxA4, sections: const {});
        expect(find.text('Tax Invoice'), findsOneWidget);
        expect(find.text('CGST'), findsOneWidget);
        expect(find.text('SGST'), findsOneWidget);
        expect(find.text('Taxable value'), findsOneWidget);

        await pump(tester, format: InvoiceFormat.simpleA4, sections: const {});
        expect(find.text('CGST'), findsNothing);
        expect(find.text('GST 18%'), findsOneWidget);
      },
    );

    testWidgets('the detailed template is titled as a job card', (
      tester,
    ) async {
      await pump(tester, format: InvoiceFormat.detailedA4, sections: const {});
      expect(find.text('Job Card'), findsOneWidget);
    });
  });

  group('each block appears only when it is ticked', () {
    Future<void> check(
      WidgetTester tester,
      DocSection section,
      Finder marker,
    ) async {
      await pump(tester, format: InvoiceFormat.detailedA4, sections: {section});
      expect(marker, findsWidgets, reason: '${section.label} did not draw');

      await pump(tester, format: InvoiceFormat.detailedA4, sections: const {});
      expect(
        marker,
        findsNothing,
        reason: '${section.label} drew with its switch off',
      );
    }

    testWidgets('odometer and fuel', (tester) async {
      await check(tester, DocSection.odometer, find.textContaining('Km read:'));
    });

    testWidgets('mechanics', (tester) async {
      await check(
        tester,
        DocSection.mechanics,
        find.textContaining('Assigned:'),
      );
    });

    testWidgets('customer voice', (tester) async {
      await check(tester, DocSection.voices, find.text('Engine Noise'));
    });

    testWidgets('accessories', (tester) async {
      await check(tester, DocSection.accessories, find.text('Tool Kit'));
    });

    testWidgets('work note', (tester) async {
      await check(tester, DocSection.workNote, find.text('WORK NOTE'));
    });

    testWidgets('damage marks', (tester) async {
      await check(
        tester,
        DocSection.dents,
        find.text('DAMAGE NOTED AT HANDOVER'),
      );
    });

    testWidgets('photographs', (tester) async {
      await check(
        tester,
        DocSection.photos,
        find.text('PHOTOGRAPHS AT HANDOVER'),
      );
    });

    testWidgets('transactions', (tester) async {
      await check(tester, DocSection.payments, find.text('TRANSACTIONS'));
    });

    testWidgets('sms detail', (tester) async {
      await check(tester, DocSection.sms, find.text('SMS DETAIL'));
    });

    testWidgets('the payment code', (tester) async {
      await check(tester, DocSection.paymentQr, find.byType(QrImageView));
    });
  });

  group('the photographs really are on it', () {
    testWidgets('a picture is drawn for each one attached', (tester) async {
      await pump(
        tester,
        format: InvoiceFormat.detailedA4,
        sections: const {DocSection.photos},
      );
      // The fixture attaches two paths, one of which is not there — both get
      // a frame, and the missing one falls back rather than blowing up.
      expect(find.byType(Image), findsNWidgets(f.card.photos.length));
      expect(tester.takeException(), isNull);
    });
  });

  group('the mechanic copy stays the mechanic copy', () {
    testWidgets('no money reaches it, whatever is ticked', (tester) async {
      await pump(
        tester,
        kind: DocKind.mechanicCopy,
        format: InvoiceFormat.detailedA4,
        sections: DocSection.values.toSet(),
      );
      expect(find.text('TRANSACTIONS'), findsNothing);
      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('No pricing on this copy'), findsOneWidget);
      // What it does carry is the work.
      expect(find.text('Engine Noise'), findsOneWidget);
    });
  });
}
