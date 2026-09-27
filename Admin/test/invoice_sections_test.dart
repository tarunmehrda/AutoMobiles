import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:garagepro_admin/data/models/enums.dart';
import 'package:garagepro_admin/features/jobcard/documents/doc_sections.dart';
import 'package:garagepro_admin/features/jobcard/documents/invoice_format.dart';
import 'package:garagepro_admin/features/jobcard/documents/pdf_builder.dart';
import 'invoice_fixture.dart';

/// The optional blocks on a document.
///
/// Each one only draws when there is something behind it, so a card with
/// empty lists exercises none of their layout — which is how a block can be
/// wired up, ticked on, and still throw the first time a real shop uses it.
/// Everything here runs against a card that has all of them filled in.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<int> render(
    InvoiceFormat format, {
    Set<DocSection>? sections,
    DocKind kind = DocKind.invoice,
  }) async {
    final f = await fullCard();
    final bytes = await JobPdf.build(
      kind: kind,
      format: format,
      sections: sections,
      card: f.card,
      garage: f.garage,
      customer: f.customer,
      vehicle: f.vehicle,
      staff: f.staff,
    );
    expect(
      String.fromCharCodes(bytes.take(4)),
      '%PDF',
      reason: '${format.name} did not produce a PDF',
    );
    return bytes.length;
  }

  group('every block renders on every template', () {
    for (final format in InvoiceFormat.values) {
      test('${format.name} carries everything it is offered', () async {
        // Everything available on this paper, ticked on at once — the
        // combination no default ever produces and the one most likely to
        // run a row or a table past the edge of the page.
        await render(
          format,
          sections: DocSectionX.offeredOn(format, DocKind.invoice).toSet(),
        );
      });

      test('${format.name} survives every block being off', () async {
        await render(format, sections: const {});
      });
    }

    for (final kind in DocKind.values) {
      test('${kind.name} renders with its own defaults', () async {
        for (final format in InvoiceFormat.values) {
          await render(
            format,
            kind: kind,
            sections: DocSectionX.defaultsFor(format, kind),
          );
        }
      });
    }
  });

  group('what each template is allowed to carry', () {
    test('photographs never reach a thermal roll', () {
      for (final format in InvoiceFormat.values) {
        final kept = DocSectionX.carryOver(
          DocSection.values.toSet(),
          format,
          DocKind.invoice,
        );
        expect(
          kept.contains(DocSection.photos),
          !format.isThermal,
          reason: '${format.name} handled photos wrongly',
        );
      }
    });

    test('58mm is never offered a QR, and 80mm is', () {
      expect(
        DocSectionX.offeredOn(InvoiceFormat.thermal58, DocKind.invoice),
        isNot(contains(DocSection.paymentQr)),
      );
      expect(
        DocSectionX.offeredOn(InvoiceFormat.thermal80, DocKind.invoice),
        contains(DocSection.paymentQr),
      );
    });

    test('the mechanic copy is offered no money blocks', () {
      final offered = DocSectionX.offeredOn(
        InvoiceFormat.detailedA4,
        DocKind.mechanicCopy,
      );
      expect(offered, isNot(contains(DocSection.payments)));
      expect(offered, isNot(contains(DocSection.paymentQr)));
      expect(offered, contains(DocSection.voices));
    });

    test('the detailed template starts with everything it can carry on', () {
      final on = DocSectionX.defaultsFor(
        InvoiceFormat.detailedA4,
        DocKind.invoice,
      );
      expect(
        on,
        DocSectionX.offeredOn(
          InvoiceFormat.detailedA4,
          DocKind.invoice,
        ).toSet(),
      );
    });

    test('every A4 invoice starts with handover photographs ticked', () {
      // Somebody who shot the vehicle expects the pictures on the paperwork.
      // They used to be off on the two bill templates, so a counter that had
      // just taken a photo got an invoice with no sign of it and read that
      // as the camera having failed.
      for (final format in InvoiceFormat.values) {
        expect(
          DocSectionX.defaultsFor(
            format,
            DocKind.invoice,
          ).contains(DocSection.photos),
          !format.isThermal,
          reason: '${format.name} started with the wrong photo default',
        );
      }
    });
  });

  group('photographs', () {
    test('a real photo makes the document bigger than no photo', () async {
      final without = await render(
        InvoiceFormat.detailedA4,
        sections: const {DocSection.odometer},
      );
      final with_ = await render(
        InvoiceFormat.detailedA4,
        sections: const {DocSection.odometer, DocSection.photos},
      );
      // The fixture attaches one real file and one path that is not there.
      // If the image never reached the page these would be the same size.
      expect(
        with_,
        greaterThan(without),
        reason: 'the photo block added nothing to the PDF',
      );
    });

    test('the default invoice carries the photo without being asked', () async {
      // The whole complaint in one assertion: no sections passed at all, the
      // template the counter lands on, and the picture still has to be in
      // the bytes that go out.
      final bare = await render(InvoiceFormat.simpleA4);
      final f = await fullCard();
      final noPhotos = await JobPdf.build(
        kind: DocKind.invoice,
        format: InvoiceFormat.simpleA4,
        card: f.card.copyWith(photos: const []),
        garage: f.garage,
        customer: f.customer,
        vehicle: f.vehicle,
        staff: f.staff,
      );
      expect(
        bare,
        greaterThan(noPhotos.length),
        reason: 'the default invoice left the photo off',
      );
    });

    test('a photo that has been deleted does not break the bill', () async {
      final f = await fullCard();
      final gone = f.card.copyWith(
        photos: [
          '${f.dir.path}${Platform.pathSeparator}never-existed.png',
          '${f.dir.path}${Platform.pathSeparator}nor-this.jpg',
        ],
      );

      final bytes = await JobPdf.build(
        kind: DocKind.invoice,
        format: InvoiceFormat.detailedA4,
        sections: const {DocSection.photos},
        card: gone,
        garage: f.garage,
        customer: f.customer,
        vehicle: f.vehicle,
      );
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });

    test('a file that is not an image at all is skipped, not thrown', () async {
      final f = await fullCard();
      final junk = File('${f.dir.path}${Platform.pathSeparator}notes.txt');
      await junk.writeAsString('this is not a picture');

      final bytes = await JobPdf.build(
        kind: DocKind.invoice,
        format: InvoiceFormat.detailedA4,
        sections: const {DocSection.photos},
        card: f.card.copyWith(photos: [junk.path]),
        garage: f.garage,
        customer: f.customer,
        vehicle: f.vehicle,
      );
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });
  });
}
