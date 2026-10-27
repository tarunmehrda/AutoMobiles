import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/utils/formatters.dart';
import '../../core/utils/words.dart';
import '../../data/models/workshop.dart';
import 'invoice_money.dart';

/// The workshop's invoice as an A4 page that can be printed, saved or sent on.
///
/// It is drawn with the pdf package's own widgets rather than by
/// screenshotting the screen, so the type stays crisp at any zoom and stays
/// selectable in whatever the customer opens it with.
class InvoicePdf {
  const InvoicePdf._();

  static const _accent = PdfColor.fromInt(0xFFD9410F);
  static const _ink = PdfColor.fromInt(0xFF0D1117);
  static const _inkSoft = PdfColor.fromInt(0xFF39434F);
  static const _inkMuted = PdfColor.fromInt(0xFF6B7684);
  static const _line = PdfColor.fromInt(0xFFE2E6EC);
  static const _wash = PdfColor.fromInt(0xFFF4F7FE);
  static const _info = PdfColor.fromInt(0xFF2F6FED);

  /// What the saved file is called. Readable at a glance in a Downloads list.
  static String fileName(WorkshopCard card) =>
      'Invoice-${card.number.replaceAll(RegExp('[^A-Za-z0-9-]'), '')}.pdf';

  static Future<Uint8List> build({
    required WorkshopCard card,
    required Workshop shop,
    String customerName = '',
    String customerPhone = '',
  }) async {
    final money = BillBlock.of(card);
    final doc = pw.Document(title: '${money.title} ${card.number}');
    final head = Letterhead.of(card, shop);
    final party =
        BillParty.of(card, name: customerName, phone: customerPhone);
    final shopName = head.name;

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Center(
              // "Tax Invoice" only when tax was actually charged.
              child: pw.Text(money.title,
                  style: pw.TextStyle(
                      fontSize: 20,
                      color: _info,
                      fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 10),

            // --- who is billing --------------------------------------
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(shopName,
                      style: pw.TextStyle(
                          fontSize: 13,
                          color: _accent,
                          fontWeight: pw.FontWeight.bold)),
                  if (head.where.isNotEmpty)
                    pw.Text(head.where,
                        textAlign: pw.TextAlign.right,
                        style: const pw.TextStyle(
                            fontSize: 8, color: _inkMuted)),
                  if (head.phone.isNotEmpty)
                    pw.Text('Phone: ${head.phone}',
                        style: const pw.TextStyle(
                            fontSize: 8, color: _inkMuted)),
                  if (head.email.isNotEmpty)
                    pw.Text('Mail: ${head.email}',
                        style: const pw.TextStyle(
                            fontSize: 8, color: _inkMuted)),
                  if (head.gstin.isNotEmpty)
                    pw.Text('GSTIN: ${head.gstin}',
                        style: const pw.TextStyle(
                            fontSize: 8, color: _inkMuted)),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // --- the three headers ------------------------------------
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: _block('Bill To:', party.billTo),
                ),
                pw.SizedBox(width: 6),
                pw.Expanded(
                  child: _block('Vehicle Details:', [
                    card.vehicleLine,
                    if (card.odometerKm > 0)
                      'KM Reading: ${Fmt.km(card.odometerKm)}',
                  ]),
                ),
                pw.SizedBox(width: 6),
                pw.Expanded(
                  child: _block('Invoice Details:', [
                    'Number: ${card.number}',
                    'Date: ${Fmt.date(card.openedAt)}',
                    Fmt.time(card.openedAt),
                  ]),
                ),
              ],
            ),
            if (party.insurance.isNotEmpty) ...[
              pw.SizedBox(height: 6),
              _block('Insurance Details:', party.insurance),
            ],
            pw.SizedBox(height: 14),

            // --- the lines --------------------------------------------
            pw.Table(
              border: pw.TableBorder.all(color: _line, width: 0.5),
              columnWidths: const {
                0: pw.FixedColumnWidth(24),
                1: pw.FlexColumnWidth(4),
                2: pw.FixedColumnWidth(38),
                3: pw.FixedColumnWidth(48),
                4: pw.FixedColumnWidth(66),
                5: pw.FixedColumnWidth(76),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: _wash),
                  children: [
                    _head('#'),
                    _head('Particulars'),
                    _head('GST', align: pw.TextAlign.center),
                    _head('Qty', align: pw.TextAlign.center),
                    _head('Rate', align: pw.TextAlign.right),
                    _head('Amount', align: pw.TextAlign.right),
                  ],
                ),
                for (var i = 0; i < card.items.length; i++)
                  pw.TableRow(children: [
                    _cell('${i + 1}'),
                    _cell(card.items[i].name),
                    _cell(BillBlock.gstOf(card, card.items[i]),
                        align: pw.TextAlign.center),
                    _cell(card.items[i].qtyLabel,
                        align: pw.TextAlign.center),
                    _cell(Fmt.money(card.items[i].rate),
                        align: pw.TextAlign.right),
                    _cell(Fmt.money(card.items[i].amount),
                        align: pw.TextAlign.right, bold: true),
                  ]),
                if (card.items.isEmpty)
                  pw.TableRow(children: [
                    _cell(''),
                    _cell('Nothing billed on this card.'),
                    _cell(''),
                    _cell(''),
                    _cell(''),
                    _cell(''),
                  ]),
              ],
            ),
            pw.SizedBox(height: 14),

            // --- the money ---------------------------------------------
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Total In Words:',
                          style: const pw.TextStyle(
                              fontSize: 8, color: _inkMuted)),
                      pw.SizedBox(height: 2),
                      pw.Text(Words.rupees(card.total),
                          style: pw.TextStyle(
                              fontSize: 10,
                              color: _ink,
                              fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),
                pw.SizedBox(width: 14),
                pw.Container(
                  width: 190,
                  padding: const pw.EdgeInsets.all(8),
                  decoration: const pw.BoxDecoration(color: _wash),
                  child: pw.Column(children: [
                    pw.Text('Bill Amount Details:',
                        style: pw.TextStyle(
                            fontSize: 9,
                            color: _info,
                            fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    for (final row in money.rows)
                      if (!row.strong) _money(row.label, row.value),
                    pw.Divider(color: _line, height: 8),
                    _money('Balance', card.balance, strong: true),
                  ]),
                ),
              ],
            ),

            if (card.bank != null && card.bank!.rows.isNotEmpty) ...[
              pw.SizedBox(height: 12),
              _block('Bank Details:', [
                for (final (label, value) in card.bank!.rows) '$label: $value',
              ]),
            ],

            pw.SizedBox(height: 22),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('Authorized Signature',
                  style: const pw.TextStyle(fontSize: 9, color: _inkMuted)),
            ),

            if (head.terms.isNotEmpty) ...[
              pw.SizedBox(height: 16),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(8),
                decoration: const pw.BoxDecoration(color: _wash),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Terms and Conditions',
                        style: pw.TextStyle(
                            fontSize: 9,
                            color: _ink,
                            fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 2),
                    pw.Text(head.terms,
                        style: const pw.TextStyle(
                            fontSize: 8, color: _inkMuted)),
                  ],
                ),
              ),
            ],

            if (card.nextServiceAt != null) ...[
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text(
                  'Your next service is due on '
                  '${Fmt.date(card.nextServiceAt!)}'
                  '${card.nextServiceKm == null ? '' : ' or at ${Fmt.km(card.nextServiceKm!)}'}',
                  style: pw.TextStyle(
                      fontSize: 9,
                      color: _info,
                      fontWeight: pw.FontWeight.bold),
                ),
              ),
            ],

            pw.Spacer(),
            pw.Center(
              child: pw.Text('$shopName  •  Thank you for your business',
                  style: const pw.TextStyle(fontSize: 8, color: _inkMuted)),
            ),
          ],
        ),
      ),
    );

    return doc.save();
  }

  static pw.Widget _block(String title, List<String> rows) => pw.Container(
        padding: const pw.EdgeInsets.all(6),
        decoration: const pw.BoxDecoration(color: _wash),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title,
                style: pw.TextStyle(
                    fontSize: 8,
                    color: _info,
                    fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 2),
            for (final r in rows)
              if (r.trim().isNotEmpty)
                pw.Text(r,
                    style: const pw.TextStyle(fontSize: 8, color: _ink)),
          ],
        ),
      );

  static pw.Widget _head(String text,
          {pw.TextAlign align = pw.TextAlign.left}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
        child: pw.Text(text,
            textAlign: align,
            style: pw.TextStyle(
                fontSize: 8.5,
                color: _info,
                fontWeight: pw.FontWeight.bold)),
      );

  static pw.Widget _cell(String text,
          {pw.TextAlign align = pw.TextAlign.left, bool bold = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
        child: pw.Text(text,
            textAlign: align,
            style: pw.TextStyle(
                fontSize: 9,
                color: bold ? _ink : _inkSoft,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );

  static pw.Widget _money(String label, double value,
          {bool strong = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
        child: pw.Row(children: [
          pw.Expanded(
            child: pw.Text(label,
                style: pw.TextStyle(
                    fontSize: strong ? 10 : 8.5,
                    color: strong ? _ink : _inkMuted,
                    fontWeight:
                        strong ? pw.FontWeight.bold : pw.FontWeight.normal)),
          ),
          pw.Text(Fmt.money(value),
              style: pw.TextStyle(
                  fontSize: strong ? 11 : 9,
                  color: strong ? _accent : _ink,
                  fontWeight: pw.FontWeight.bold)),
        ]),
      );
}
