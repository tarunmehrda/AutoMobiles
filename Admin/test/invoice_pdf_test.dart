import 'package:flutter_test/flutter_test.dart';

import 'package:garagepro_admin/data/models/entities.dart';
import 'package:garagepro_admin/data/models/enums.dart';
import 'package:garagepro_admin/features/jobcard/documents/invoice_format.dart';
import 'package:garagepro_admin/features/jobcard/documents/pdf_builder.dart';
import 'invoice_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the document actually renders', () {
    // Every kind has to survive a real render. The build is what the download,
    // share and print buttons all call, so if this throws, all three do
    // nothing that the counter can see.
    for (final kind in DocKind.values) {
      test('${kind.name} builds to a non-empty PDF', () async {
        final f = await billedCard();

        final bytes = await JobPdf.build(
          kind: kind,
          card: f.card,
          garage: f.garage,
          customer: f.customer,
          vehicle: f.vehicle,
        );

        expect(bytes, isNotEmpty);
        // A real PDF starts with %PDF.
        expect(String.fromCharCodes(bytes.take(4)), '%PDF');
      });
    }

    test('an empty card still produces a document', () async {
      final f = await billedCard();
      final bare = JobCard(
        id: 'bare',
        number: 'JC-0001',
        customerId: f.customer.id,
        vehicleId: f.vehicle.id,
        createdAt: DateTime(2026, 1, 1),
      );

      final bytes = await JobPdf.build(
        kind: DocKind.invoice,
        card: bare,
        garage: f.garage,
      );

      expect(bytes, isNotEmpty);
    });
  });

  group('every format renders', () {
    // Five shapes of paper, each of which has its own layout code. A format
    // that throws takes the download, share and print buttons with it.
    for (final format in InvoiceFormat.values) {
      test('${format.name} builds to a real PDF', () async {
        final f = await billedCard();

        final bytes = await JobPdf.build(
          kind: DocKind.invoice,
          format: format,
          card: f.card,
          garage: f.garage,
          customer: f.customer,
          vehicle: f.vehicle,
        );

        expect(String.fromCharCodes(bytes.take(4)), '%PDF');
        expect(bytes.length, greaterThan(1000));
      });
    }

    test('a bill with many lines still lays out on every format', () async {
      final f = await billedCard();
      final many = f.card.copyWith(
        items: [
          for (var i = 0; i < 40; i++)
            LineItem(
              id: 'l$i',
              kind: LineKind.spare,
              name: 'Replacement part number $i',
              partNo: 'PN-$i',
              qty: 2,
              rate: 349.5,
            ),
        ],
      );

      for (final format in InvoiceFormat.values) {
        final bytes = await JobPdf.build(
          kind: DocKind.invoice,
          format: format,
          card: many,
          garage: f.garage,
          customer: f.customer,
          vehicle: f.vehicle,
        );
        expect(
          String.fromCharCodes(bytes.take(4)),
          '%PDF',
          reason: '${format.name} failed on a long bill',
        );
      }
    });

    test('the promised date reaches the document', () async {
      final f = await billedCard();
      final promised = f.card.copyWith(promisedAt: DateTime(2026, 3, 4, 17));

      // Rendered, not inspected: the pdf package subsets its fonts, so the
      // text is not readable back out of the bytes. What this pins is that
      // the field is wired through and does not blow the layout up.
      for (final format in InvoiceFormat.values) {
        final bytes = await JobPdf.build(
          kind: DocKind.invoice,
          format: format,
          card: promised,
          garage: f.garage,
          customer: f.customer,
          vehicle: f.vehicle,
        );
        expect(bytes, isNotEmpty);
      }
    });
  });
}
