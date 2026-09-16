import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/formatters.dart';
import '../../../core/utils/words.dart';
import '../../../data/models/entities.dart';
import '../../../data/models/enums.dart';

/// Renders the same document the screen shows, as an A4 page that can be
/// printed, saved or shared.
///
/// It is written against the pdf package's own widgets rather than by
/// screenshotting the UI, so the output stays crisp and the text stays
/// selectable in whatever the customer opens it with.
class JobPdf {
  const JobPdf._();

  static const _accent = PdfColor.fromInt(0xFFD9410F);
  static const _accentSoft = PdfColor.fromInt(0xFFFFEDE5);
  static const _ink = PdfColor.fromInt(0xFF0D1117);
  static const _inkSoft = PdfColor.fromInt(0xFF39434F);
  static const _inkMuted = PdfColor.fromInt(0xFF6B7684);
  static const _line = PdfColor.fromInt(0xFFE2E6EC);
  static const _wash = PdfColor.fromInt(0xFFFAFAFC);

  static Future<Uint8List> build({
    required DocKind kind,
    required JobCard card,
    required Garage garage,
    Customer? customer,
    Vehicle? vehicle,
    List<Staff> staff = const [],
  }) async {
    final doc = pw.Document(title: '${kind.label} ${card.number}');
    final priced = kind.showsPricing;

    String mechanicName(String? id) {
      if (id == null) return '';
      for (final s in staff) {
        if (s.id == id) return s.name;
      }
      return '';
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          _letterhead(kind, card, garage),
          pw.SizedBox(height: 14),
          _parties(kind, card, customer, vehicle,
              card.mechanicIds.map(mechanicName).where((e) => e.isNotEmpty)),
          if (kind == DocKind.mechanicCopy) ...[
            pw.SizedBox(height: 12),
            _twoLists(card),
            if (card.workNote.trim().isNotEmpty) ...[
              pw.SizedBox(height: 12),
              _band('Work note'),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8, vertical: 6),
                child: pw.Text(card.workNote,
                    style: const pw.TextStyle(fontSize: 9, color: _inkSoft)),
              ),
            ],
          ],
          pw.SizedBox(height: 12),
          _table(kind, card, mechanicName),
          pw.SizedBox(height: 12),
          if (priced) ...[
            _totals(kind, card),
            pw.SizedBox(height: 10),
            _words(card),
          ],
          if (card.nextServiceAt != null) ...[
            pw.SizedBox(height: 12),
            pw.Container(
              width: double.infinity,
              color: const PdfColor.fromInt(0xFFE8F0FE),
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: pw.Text(
                'Next service due on ${Fmt.date(card.nextServiceAt!)}'
                '${card.nextServiceKm == null ? '' : ' or at ${Fmt.km(card.nextServiceKm!)}'}'
                ', whichever is earlier.',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(
                    fontSize: 8.5, color: PdfColor.fromInt(0xFF2F6FED)),
              ),
            ),
          ],
          if (priced && garage.terms.trim().isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text('TERMS',
                style: pw.TextStyle(
                    fontSize: 7.5,
                    color: _inkMuted,
                    fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 2),
            for (final t in garage.terms
                .split('\n')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty))
              pw.Text('- $t',
                  style: const pw.TextStyle(fontSize: 8, color: _inkMuted)),
          ],
          pw.SizedBox(height: 34),
          pw.Row(
            children: [
              pw.Expanded(
                child: _signature(kind == DocKind.mechanicCopy
                    ? 'Mechanic signature'
                    : 'Customer signature'),
              ),
              pw.SizedBox(width: 28),
              pw.Expanded(child: _signature('Authorised signature')),
            ],
          ),
        ],
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            '${garage.name} • ${kind.label} ${card.number} • '
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 7.5, color: _inkMuted),
          ),
        ),
      ),
    );

    return doc.save();
  }

  // --- pieces --------------------------------------------------------------

  static pw.Widget _letterhead(DocKind kind, JobCard card, Garage garage) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(garage.name,
                  style: pw.TextStyle(
                      fontSize: 15,
                      color: _accent,
                      fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 2),
              pw.Text(garage.phone,
                  style: const pw.TextStyle(fontSize: 9, color: _inkSoft)),
              if (garage.postal.isNotEmpty)
                pw.Text(garage.postal,
                    style: const pw.TextStyle(fontSize: 8, color: _inkMuted)),
              if (garage.email.isNotEmpty)
                pw.Text(garage.email,
                    style: const pw.TextStyle(fontSize: 8, color: _inkMuted)),
              if (garage.gstin.isNotEmpty)
                pw.Text('GSTIN ${garage.gstin}',
                    style: const pw.TextStyle(fontSize: 8, color: _inkMuted)),
            ],
          ),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(kind.label.toUpperCase(),
                style: pw.TextStyle(
                    fontSize: 13,
                    color: _ink,
                    fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            _meta('Number', card.number),
            _meta('Date', Fmt.date(card.createdAt)),
            _meta('Time', Fmt.time(card.createdAt)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _meta(String label, String value) => pw.Text(
        '$label: $value',
        style: const pw.TextStyle(fontSize: 8.5, color: _inkSoft),
      );

  static pw.Widget _band(String left, [String? right]) => pw.Container(
        width: double.infinity,
        color: _accentSoft,
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(left.toUpperCase(),
                  style: pw.TextStyle(
                      fontSize: 8,
                      color: _accent,
                      fontWeight: pw.FontWeight.bold)),
            ),
            if (right != null)
              pw.Expanded(
                child: pw.Text(right.toUpperCase(),
                    style: pw.TextStyle(
                        fontSize: 8,
                        color: _accent,
                        fontWeight: pw.FontWeight.bold)),
              ),
          ],
        ),
      );

  static pw.Widget _parties(
    DocKind kind,
    JobCard card,
    Customer? customer,
    Vehicle? vehicle,
    Iterable<String> mechanics,
  ) {
    final billTo = kind != DocKind.mechanicCopy;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _band(billTo ? 'Bill to' : 'Vehicle info',
            billTo ? 'Vehicle info' : null),
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _line, width: 0.5),
          ),
          padding: const pw.EdgeInsets.all(8),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (billTo) ...[
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(customer?.name ?? '-',
                          style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: _ink)),
                      pw.Text(customer?.phone ?? '',
                          style: const pw.TextStyle(
                              fontSize: 9, color: _inkSoft)),
                      if ((customer?.address ?? '').isNotEmpty)
                        pw.Text(customer!.address,
                            style: const pw.TextStyle(
                                fontSize: 8, color: _inkMuted)),
                    ],
                  ),
                ),
                pw.SizedBox(width: 12),
              ],
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Veh. No: ${vehicle?.regNo ?? '-'}',
                        style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: _ink)),
                    pw.Text(vehicle?.title ?? '',
                        style:
                            const pw.TextStyle(fontSize: 9, color: _inkSoft)),
                    pw.Text(
                      'Km read: ${Fmt.km(card.odometerKm)}   Fuel: ${card.fuelPercent}%',
                      style:
                          const pw.TextStyle(fontSize: 8, color: _inkMuted),
                    ),
                    if (mechanics.isNotEmpty)
                      pw.Text('Assigned: ${mechanics.join(', ')}',
                          style: const pw.TextStyle(
                              fontSize: 8, color: _inkMuted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _twoLists(JobCard card) {
    pw.Widget list(List<String> items, String empty) {
      if (items.isEmpty) {
        return pw.Text(empty,
            style: const pw.TextStyle(fontSize: 8.5, color: _inkMuted));
      }
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < items.length; i++)
            pw.Text('${i + 1}.  ${items[i]}',
                style: const pw.TextStyle(fontSize: 9, color: _inkSoft)),
        ],
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _band('Customer voice', 'Accessories'),
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _line, width: 0.5),
          ),
          padding: const pw.EdgeInsets.all(8),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: list(card.voices, 'Nothing noted')),
              pw.SizedBox(width: 12),
              pw.Expanded(child: list(card.accessories, 'None recorded')),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _table(
    DocKind kind,
    JobCard card,
    String Function(String?) mechanicName,
  ) {
    final priced = kind.showsPricing;
    final headers = priced
        ? ['#', 'Particulars', 'Qty', 'Rate', 'Amount']
        : ['#', 'Particulars', 'Status', 'Mechanic', 'Remark'];

    final rows = <List<String>>[
      for (var i = 0; i < card.items.length; i++)
        priced
            ? [
                '${i + 1}',
                card.items[i].partNo.isEmpty
                    ? card.items[i].name
                    : '${card.items[i].name}\n${card.items[i].partNo}',
                card.items[i].qtyLabel,
                Fmt.money2(card.items[i].rate),
                Fmt.money2(card.items[i].amount),
              ]
            : [
                '${i + 1}',
                card.items[i].partNo.isEmpty
                    ? card.items[i].name
                    : '${card.items[i].name}\n${card.items[i].partNo}',
                card.items[i].state.label,
                mechanicName(card.items[i].mechanicId),
                card.items[i].remark,
              ],
    ];

    if (rows.isEmpty) {
      rows.add(priced
          ? ['', 'Nothing billed on this card yet', '', '', '']
          : ['', 'No work listed yet', '', '', '']);
    }

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      border: pw.TableBorder.all(color: _line, width: 0.5),
      headerStyle: pw.TextStyle(
          fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: _accent),
      headerDecoration: const pw.BoxDecoration(color: _accentSoft),
      cellStyle: const pw.TextStyle(fontSize: 9, color: _inkSoft),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      columnWidths: priced
          ? {
              0: const pw.FixedColumnWidth(22),
              1: const pw.FlexColumnWidth(4),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(1.4),
              4: const pw.FlexColumnWidth(1.6),
            }
          : {
              0: const pw.FixedColumnWidth(22),
              1: const pw.FlexColumnWidth(3.4),
              2: const pw.FlexColumnWidth(1.4),
              3: const pw.FlexColumnWidth(1.6),
              4: const pw.FlexColumnWidth(2.4),
            },
      cellAlignments: priced
          ? {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
            }
          : const {},
    );
  }

  static pw.Widget _totals(DocKind kind, JobCard card) {
    final invoice = kind == DocKind.invoice;
    pw.Widget line(String label, String value, {bool bold = false}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label,
                  style: pw.TextStyle(
                      fontSize: bold ? 10 : 9,
                      color: bold ? _ink : _inkMuted,
                      fontWeight:
                          bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
              pw.Text(value,
                  style: pw.TextStyle(
                      fontSize: bold ? 11 : 9,
                      color: bold ? _ink : _inkSoft,
                      fontWeight:
                          bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
            ],
          ),
        );

    return pw.Row(
      children: [
        pw.Spacer(flex: 3),
        pw.Expanded(
          flex: 4,
          child: pw.Container(
            color: _wash,
            padding: const pw.EdgeInsets.all(8),
            child: pw.Column(
              children: [
                line('Sub total', Fmt.money2(card.subTotal)),
                if (card.discount > 0)
                  line('Discount', '- ${Fmt.money2(card.discount)}'),
                if (card.taxRate > 0)
                  line('GST ${(card.taxRate * 100).toStringAsFixed(0)}%',
                      Fmt.money2(card.taxAmount)),
                pw.Divider(color: _line, height: 10),
                line(invoice ? 'Payable' : 'Estimated total',
                    Fmt.money2(card.total),
                    bold: true),
                if (invoice) ...[
                  line('Paid', Fmt.money2(card.paid)),
                  line('Balance', Fmt.money2(card.balance), bold: true),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _words(JobCard card) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('AMOUNT IN WORDS',
              style: pw.TextStyle(
                  fontSize: 7.5,
                  color: _inkMuted,
                  fontWeight: pw.FontWeight.bold)),
          pw.Text(Words.rupees(card.total),
              style: pw.TextStyle(
                  fontSize: 9.5,
                  color: _inkSoft,
                  fontWeight: pw.FontWeight.bold)),
        ],
      );

  static pw.Widget _signature(String label) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(height: 26),
          pw.Container(height: 0.7, color: _line),
          pw.SizedBox(height: 3),
          pw.Text(label,
              style: const pw.TextStyle(fontSize: 8, color: _inkMuted)),
        ],
      );
}
