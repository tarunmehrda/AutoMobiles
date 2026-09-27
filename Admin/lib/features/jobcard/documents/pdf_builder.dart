import '../../../core/i18n/strings.dart';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart' show networkImage;

import '../../../core/utils/formatters.dart';
import '../../../core/utils/image_bytes.dart';
import '../../../core/utils/upi_intent.dart';
import '../../../core/utils/words.dart';
import '../../../data/models/entities.dart';
import '../../../data/models/enums.dart';
import 'doc_sections.dart';
import 'invoice_format.dart';

/// Renders a job card as a document that can be printed, saved or shared.
///
/// Written against the pdf package's own widgets rather than by screenshotting
/// the UI, so the output stays crisp and the text stays selectable in whatever
/// the customer opens it with.
///
/// Five shapes come out of here — see [InvoiceFormat]. The A4 three share a
/// letterhead and a totals block and differ in what sits between them; the two
/// thermal rolls are a different document entirely, because 58mm of paper has
/// room for a list and nothing else.
class JobPdf {
  const JobPdf._();

  static const _accent = PdfColor.fromInt(0xFFD9410F);
  static const _accentSoft = PdfColor.fromInt(0xFFFFF1EB);
  static const _ink = PdfColor.fromInt(0xFF0D1117);
  static const _inkSoft = PdfColor.fromInt(0xFF39434F);
  static const _inkMuted = PdfColor.fromInt(0xFF6B7684);
  static const _line = PdfColor.fromInt(0xFFDDE3EA);
  static const _wash = PdfColor.fromInt(0xFFF7F8FA);

  /// The document's own typeface, loaded once and kept.
  ///
  /// The pdf package falls back to Helvetica, a Type1 font with no Unicode:
  /// every rupee sign and bullet was being dropped from the page without an
  /// error, so prices printed bare. Inter is already bundled for the app,
  /// carries both, and makes the document match the screen.
  static pw.ThemeData? _theme;

  static Future<pw.ThemeData> _typeface() async {
    if (_theme != null) return _theme!;
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Inter-400.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Inter-700.ttf'),
    );
    return _theme = pw.ThemeData.withFont(
      base: regular,
      bold: bold,
      italic: regular,
      boldItalic: bold,
    );
  }

  /// How many handover photographs will fit on a bill before it stops being
  /// a bill. Six is two rows of three, which is a page.
  static const _maxPhotos = 6;

  /// A picture bigger than this is not going on a document somebody has to
  /// send over WhatsApp. The picker already re-encodes at 80% quality, so
  /// anything past this came in some other way.
  static const _maxPhotoBytes = 6 * 1024 * 1024;

  /// How long one uploaded photograph gets to arrive before the document goes
  /// out without it.
  ///
  /// A photo on the card can now be a storage URL as well as a file on this
  /// phone, and a phone at the counter is often on one bar or none. Without a
  /// limit an offline download leaves the share sheet spinning until the
  /// socket gives up on its own, which can be minutes — and the customer is
  /// standing there. Ten seconds is long enough for a slow 4G connection to
  /// pull a re-encoded picture, and the photos are fetched side by side, so
  /// it is ten seconds for the whole wall, not ten per photo.
  static const _photoTimeout = Duration(seconds: 10);

  static Future<Uint8List> build({
    required DocKind kind,
    required JobCard card,
    required Garage garage,
    InvoiceFormat format = InvoiceFormat.simpleA4,
    Set<DocSection>? sections,
    Customer? customer,
    Vehicle? vehicle,
    List<Staff> staff = const [],
  }) async {
    final doc = pw.Document(
      title: '${kind.label} ${card.number}',
      theme: await _typeface(),
    );

    // What the caller asked for, minus anything this paper cannot carry.
    final on = DocSectionX.carryOver(
      sections ?? DocSectionX.defaultsFor(format, kind),
      format,
      kind,
    );

    final names = <String>[
      for (final id in card.mechanicIds)
        for (final s in staff)
          if (s.id == id) s.name,
    ];

    final photos = on.contains(DocSection.photos)
        ? await _loadPhotos(card)
        : const <pw.ImageProvider>[];

    if (format.isThermal) {
      doc.addPage(
        _roll(kind, card, garage, format, customer, vehicle, names, on),
      );
    } else {
      doc.addPage(
        _sheet(
          kind,
          card,
          garage,
          format,
          customer,
          vehicle,
          names,
          on,
          photos,
        ),
      );
    }
    return doc.save();
  }

  /// Pulls the card's photographs in, skipping any that have gone missing,
  /// grown too big or will not download.
  ///
  /// Every failure here is a skip, never a throw: a photo deleted from under
  /// the app three months later must not be the reason a bill will not print,
  /// and neither must a storage server the phone cannot reach right now.
  ///
  /// Fetched all at once rather than one after another, so a card with six
  /// uploaded photos on a dead connection costs one [_photoTimeout], not six
  /// of them back to back. [Future.wait] keeps the order the counter took
  /// them in, which is the order the wall numbers them.
  static Future<List<pw.ImageProvider>> _loadPhotos(JobCard card) async {
    final loaded = await Future.wait([
      for (final path in card.photos.take(_maxPhotos)) _loadPhoto(path),
    ]);
    return loaded.whereType<pw.ImageProvider>().toList();
  }

  /// One photograph, from wherever it lives, or null if it cannot be drawn.
  ///
  /// A path is one of two things now. Until the upload finishes it is a file
  /// on this phone; after that it is the https URL every other phone and the
  /// customer see, and the file on this one may already be gone. The screen
  /// makes the same split in `localImage`, so the preview and the PDF agree
  /// on which pictures are on the bill.
  static Future<pw.ImageProvider?> _loadPhoto(String path) async {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      try {
        // The printing package's own fetcher, which keeps what it downloads
        // for a while — the counter usually previews, then shares, then
        // prints the same bill, and only the first of those should wait on
        // the network.
        return await networkImage(path).timeout(_photoTimeout);
      } catch (_) {
        // Offline, timed out, a 404 for a photo removed from storage, or
        // bytes the pdf package cannot decode. Leave it out.
        return null;
      }
    }

    final bytes = await readImageBytes(path);
    if (bytes == null || bytes.lengthInBytes > _maxPhotoBytes) return null;
    try {
      return pw.MemoryImage(bytes);
    } catch (_) {
      // Not something the pdf package can draw — a HEIC, or a truncated
      // file. Leave it out.
      return null;
    }
  }

  // ===========================================================================
  // A4
  // ===========================================================================

  static pw.Page _sheet(
    DocKind kind,
    JobCard card,
    Garage garage,
    InvoiceFormat format,
    Customer? customer,
    Vehicle? vehicle,
    List<String> mechanics,
    Set<DocSection> on,
    List<pw.ImageProvider> photos,
  ) {
    final priced = kind.showsPricing;
    final taxed = format == InvoiceFormat.taxA4;

    return pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28, 26, 28, 22),
      footer: (context) => _footer(card, garage, context),
      build: (context) => [
        _letterhead(kind, card, garage, format, customer),
        pw.SizedBox(height: 12),
        _parties(card, customer, vehicle, mechanics, on),
        pw.SizedBox(height: 12),

        // The complaint before the work, because that is the order it
        // happened in and the order somebody reads the sheet in.
        ..._complaint(card, on),

        if (card.items.isNotEmpty) ...[
          if (taxed) _taxTable(card) else _plainTable(card, priced: priced),
          pw.SizedBox(height: 10),
        ] else
          _empty(),

        if (priced) _totals(card, taxed: taxed),

        ..._handover(card, on),

        if (photos.isNotEmpty) ...[
          pw.SizedBox(height: 12),
          _photoWall(photos, card),
        ],

        ..._ledger(card, garage, kind, on),

        if (card.nextServiceAt != null) ...[
          pw.SizedBox(height: 12),
          _note(
            "Next service due on ${Fmt.date(card.nextServiceAt!)}${card.nextServiceKm == null ? '' : ' or at ${Fmt.km(card.nextServiceKm!)}'}.",
          ),
        ],

        pw.SizedBox(height: 24),
        _signatures(garage),
      ],
    );
  }

  // --- letterhead -----------------------------------------------------------

  static pw.Widget _letterhead(
    DocKind kind,
    JobCard card,
    Garage garage,
    InvoiceFormat format,
    Customer? customer,
  ) {
    final title = switch (format) {
      InvoiceFormat.taxA4 => 'TAX INVOICE',
      InvoiceFormat.detailedA4 => 'JOB CARD',
      _ => kind.label.toUpperCase(),
    };

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    garage.name,
                    style: pw.TextStyle(
                      fontSize: 17,
                      color: _accent,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    [
                      garage.addressLine,
                      [
                        garage.city,
                        garage.state,
                        garage.pin,
                      ].where((e) => e.isNotEmpty).join(', '),
                    ].where((e) => e.isNotEmpty).join('\n'),
                    style: const pw.TextStyle(fontSize: 8.5, color: _inkMuted),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    [
                      garage.phone,
                      if (garage.email.isNotEmpty) garage.email,
                    ].join('  ·  '),
                    style: const pw.TextStyle(fontSize: 8.5, color: _inkSoft),
                  ),
                  if (garage.gstin.isNotEmpty)
                    pw.Text(
                      'GSTIN: {0}'.trf([garage.gstin]),
                      style: pw.TextStyle(
                        fontSize: 8.5,
                        color: _ink,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: const pw.BoxDecoration(
                color: _accentSoft,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(5)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    title,
                    style: pw.TextStyle(
                      fontSize: 13,
                      color: _accent,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  _meta('No.', card.number),
                  _meta('Date', Fmt.date(card.createdAt)),
                  _meta('Time', Fmt.time(card.createdAt)),
                  // Used to be on screen only, which is why a promised date
                  // never showed up on anything the customer was handed.
                  if (card.promisedAt != null)
                    _meta('Ready by', Fmt.fullDateTime(card.promisedAt!)),
                  if (card.completedAt != null)
                    _meta('Completed', Fmt.date(card.completedAt!)),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Container(height: 2, color: _accent),
      ],
    );
  }

  // --- who and what ---------------------------------------------------------

  static pw.Widget _parties(
    JobCard card,
    Customer? customer,
    Vehicle? vehicle,
    List<String> mechanics,
    Set<DocSection> on,
  ) {
    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(color: _line)),
      child: pw.Column(
        children: [
          pw.Row(
            children: [
              pw.Expanded(child: _band('BILL TO')),
              pw.Container(width: 1, height: 16, color: _line),
              pw.Expanded(child: _band('VEHICLE')),
            ],
          ),
          // No stretch-height divider here: an unbounded child inside a
          // MultiPage row asks for page after page and never settles.
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        customer?.name ?? 'Walk-in'.tr,
                        style: pw.TextStyle(
                          fontSize: 10.5,
                          color: _ink,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      if (customer != null && customer.phone.isNotEmpty)
                        pw.Text(
                          customer.phone,
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: _inkSoft,
                          ),
                        ),
                      if (customer != null && customer.address.isNotEmpty)
                        pw.Text(
                          customer.address,
                          style: const pw.TextStyle(
                            fontSize: 8.5,
                            color: _inkMuted,
                          ),
                        ),
                      // The buyer's GSTIN is what lets a business customer
                      // claim input tax on this bill; without it on the paper
                      // their accountant sends it back. Set like the shop's
                      // own in the letterhead, because it does the same job.
                      if (customer != null && customer.gstin.trim().isNotEmpty)
                        pw.Text(
                          'GSTIN: {0}'.trf([customer.gstin.trim()]),
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            color: _ink,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              pw.Expanded(
                child: pw.Container(
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(left: pw.BorderSide(color: _line)),
                  ),
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        Fmt.plate(vehicle?.regNo ?? '—'),
                        style: pw.TextStyle(
                          fontSize: 10.5,
                          color: _ink,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      if (vehicle != null)
                        pw.Text(
                          [
                            vehicle.brand,
                            vehicle.model,
                          ].where((e) => e.isNotEmpty).join(' '),
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: _inkSoft,
                          ),
                        ),
                      if (vehicle != null)
                        pw.Text(
                          _fuelAndGearbox(vehicle),
                          style: const pw.TextStyle(
                            fontSize: 8.5,
                            color: _inkMuted,
                          ),
                        ),
                      if (vehicle != null && _insurance(vehicle).isNotEmpty)
                        pw.Text(
                          _insurance(vehicle),
                          style: const pw.TextStyle(
                            fontSize: 8.5,
                            color: _inkMuted,
                          ),
                        ),
                      if (on.contains(DocSection.odometer))
                        pw.Text(
                          'Km: {0}   Fuel: {1}%'.trf([
                            Fmt.km(card.odometerKm),
                            card.fuelPercent,
                          ]),
                          style: const pw.TextStyle(
                            fontSize: 8.5,
                            color: _inkMuted,
                          ),
                        ),
                      if (on.contains(DocSection.mechanics) &&
                          mechanics.isNotEmpty)
                        pw.Text(
                          'Attended by: ${mechanics.join(', ')}',
                          style: const pw.TextStyle(
                            fontSize: 8.5,
                            color: _inkMuted,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// `Petrol · Manual` — what the vehicle burns and how it changes gear.
  ///
  /// The gearbox rides next to the fuel because the two together are what
  /// the floor needs before it quotes: an automatic takes a different fluid
  /// and a different service, and a customer who is charged for the wrong
  /// one argues the bill. It is left off when nobody recorded it rather than
  /// guessed — most vehicles predate the question, and every two-wheeler.
  /// Same order and same rule as the vehicle header in the app, so the
  /// document reads the way the screen does.
  static String _fuelAndGearbox(Vehicle vehicle) => [
    vehicle.fuel.label,
    if (vehicle.transmission != null) vehicle.transmission!.label,
  ].join(' · ');

  /// `Insurance: ICICI Lombard · Policy 3001/1234`, or empty when neither
  /// was taken down.
  ///
  /// An insurance claim job is filed against these two, and the surveyor
  /// reads them off the job card, so they go on the paper the moment the
  /// counter has them. Either half prints on its own — a policy number with
  /// no insurer is still the thing a claim is looked up by.
  static String _insurance(Vehicle vehicle) {
    final parts = [
      vehicle.insurer.trim(),
      if (vehicle.policyNo.trim().isNotEmpty)
        'Policy {0}'.trf([vehicle.policyNo.trim()]),
    ].where((e) => e.isNotEmpty);
    return parts.isEmpty ? '' : 'Insurance: {0}'.trf([parts.join(' · ')]);
  }

  // --- tables ---------------------------------------------------------------

  static pw.Widget _plainTable(JobCard card, {required bool priced}) {
    return pw.TableHelper.fromTextArray(
      border: pw.TableBorder.all(color: _line, width: 0.5),
      headerDecoration: const pw.BoxDecoration(color: _accentSoft),
      headerStyle: pw.TextStyle(
        fontSize: 8.5,
        color: _accent,
        fontWeight: pw.FontWeight.bold,
      ),
      cellStyle: const pw.TextStyle(fontSize: 9, color: _ink),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      headerAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
      },
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
      },
      columnWidths: priced
          ? {
              0: const pw.FixedColumnWidth(22),
              1: const pw.FlexColumnWidth(5),
              2: const pw.FixedColumnWidth(42),
              3: const pw.FixedColumnWidth(70),
              4: const pw.FixedColumnWidth(78),
            }
          : {
              0: const pw.FixedColumnWidth(22),
              1: const pw.FlexColumnWidth(5),
              2: const pw.FixedColumnWidth(90),
            },
      headers: priced
          ? ['#', 'Particulars', 'Qty', 'Rate', 'Amount']
          : ['#', 'Particulars', 'Status'],
      data: [
        for (var i = 0; i < card.items.length; i++)
          priced
              ? [
                  '${i + 1}',
                  _itemName(card.items[i]),
                  card.items[i].qtyLabel,
                  Fmt.money2(card.items[i].rate),
                  Fmt.money2(card.items[i].amount),
                ]
              : [
                  '${i + 1}',
                  _itemName(card.items[i]),
                  card.items[i].state.label,
                ],
      ],
    );
  }

  /// The compliant one: taxable value per line with the tax split out.
  static pw.Widget _taxTable(JobCard card) {
    final half = card.taxRate / 2;
    final halfPct = (half * 100).toStringAsFixed(half * 100 % 1 == 0 ? 0 : 2);

    return pw.TableHelper.fromTextArray(
      border: pw.TableBorder.all(color: _line, width: 0.5),
      headerDecoration: const pw.BoxDecoration(color: _accentSoft),
      headerStyle: pw.TextStyle(
        fontSize: 7.5,
        color: _accent,
        fontWeight: pw.FontWeight.bold,
      ),
      cellStyle: const pw.TextStyle(fontSize: 8, color: _ink),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
        6: pw.Alignment.centerRight,
        7: pw.Alignment.centerRight,
        8: pw.Alignment.centerRight,
      },
      headerAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
        6: pw.Alignment.centerRight,
        7: pw.Alignment.centerRight,
        8: pw.Alignment.centerRight,
      },
      columnWidths: {
        0: const pw.FixedColumnWidth(18),
        1: const pw.FlexColumnWidth(4),
        2: const pw.FixedColumnWidth(42),
        3: const pw.FixedColumnWidth(28),
        4: const pw.FixedColumnWidth(50),
        5: const pw.FixedColumnWidth(55),
        6: const pw.FixedColumnWidth(48),
        7: const pw.FixedColumnWidth(48),
        8: const pw.FixedColumnWidth(58),
      },
      headers: [
        '#',
        'Particulars',
        'HSN/SAC',
        'Qty',
        'Rate',
        'Taxable',
        'CGST $halfPct%',
        'SGST $halfPct%',
        'Total',
      ],
      data: [
        for (var i = 0; i < card.items.length; i++)
          _taxRow(i, card.items[i], card, half),
      ],
    );
  }

  static List<String> _taxRow(int i, LineItem item, JobCard card, double half) {
    // The card's discount is on the bill as a whole, so it comes off each
    // line in the same proportion before the tax is worked out — otherwise
    // the line tax and the invoice tax do not agree.
    final share = card.subTotal == 0 ? 0.0 : item.amount / card.subTotal;
    final taxable = card.taxable * share;
    final tax = taxable * half;
    return [
      '${i + 1}',
      _itemName(item),
      item.partNo.isEmpty ? '998729' : item.partNo,
      item.qtyLabel,
      Fmt.money2(item.rate),
      Fmt.money2(taxable),
      Fmt.money2(tax),
      Fmt.money2(tax),
      Fmt.money2(taxable + tax * 2),
    ];
  }

  static String _itemName(LineItem item) => [
    item.name,
    if (item.partNo.isNotEmpty) '(${item.partNo})',
    if (item.remark.isNotEmpty) '— ${item.remark}',
  ].join(' ');

  // --- totals ---------------------------------------------------------------

  static pw.Widget _totals(JobCard card, {required bool taxed}) {
    final half = card.taxAmount / 2;
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'AMOUNT IN WORDS'.tr,
                style: pw.TextStyle(
                  fontSize: 7.5,
                  color: _inkMuted,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                Words.rupees(card.total),
                style: pw.TextStyle(
                  fontSize: 10,
                  color: _ink,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Container(
          width: 216,
          decoration: pw.BoxDecoration(border: pw.Border.all(color: _line)),
          child: pw.Column(
            children: [
              _totalRow('Sub total', Fmt.money2(card.subTotal)),
              if (card.discount > 0)
                _totalRow('Discount', '− ${Fmt.money2(card.discount)}'),
              if (taxed && card.taxRate > 0) ...[
                _totalRow('Taxable value', Fmt.money2(card.taxable)),
                _totalRow('CGST', Fmt.money2(half)),
                _totalRow('SGST', Fmt.money2(half)),
              ] else if (card.taxAmount > 0)
                _totalRow('Tax', Fmt.money2(card.taxAmount)),
              _totalRow('Payable', Fmt.money2(card.total), strong: true),
              _totalRow('Paid', Fmt.money2(card.paid)),
              _totalRow('Balance', Fmt.money2(card.balance), strong: true),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _totalRow(
    String label,
    String value, {
    bool strong = false,
  }) => pw.Container(
    decoration: pw.BoxDecoration(
      color: strong ? _wash : null,
      border: const pw.Border(bottom: pw.BorderSide(color: _line, width: 0.5)),
    ),
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: strong ? 10 : 9,
            color: strong ? _ink : _inkSoft,
            fontWeight: strong ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: strong ? 11 : 9,
            color: strong ? _ink : _inkSoft,
            fontWeight: strong ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    ),
  );

  // --- the blocks the counter ticks on --------------------------------------

  /// A bordered block with a banded title and a bulleted body.
  static pw.Widget _listBlock(String title, List<String> rows) => pw.Container(
    width: double.infinity,
    margin: const pw.EdgeInsets.only(bottom: 8),
    decoration: pw.BoxDecoration(border: pw.Border.all(color: _line)),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _band(title),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              for (final r in rows)
                pw.Text(
                  '•  $r',
                  style: const pw.TextStyle(fontSize: 9, color: _inkSoft),
                ),
            ],
          ),
        ),
      ],
    ),
  );

  /// What the customer said and what came in with the vehicle.
  ///
  /// Side by side when both are on: they are both "what arrived", and on a
  /// bill with four lines on it two half-width blocks read better than two
  /// full-width ones with three words in each.
  static List<pw.Widget> _complaint(JobCard card, Set<DocSection> on) {
    final voices = on.contains(DocSection.voices)
        ? card.voices
        : const <String>[];
    final kit = on.contains(DocSection.accessories)
        ? card.accessories
        : const <String>[];
    if (voices.isEmpty && kit.isEmpty) return const [];

    return [
      if (voices.isNotEmpty && kit.isNotEmpty)
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: _listBlock('CUSTOMER VOICE', voices)),
            pw.SizedBox(width: 8),
            pw.Expanded(child: _listBlock('ACCESSORIES IN', kit)),
          ],
        )
      else if (voices.isNotEmpty)
        _listBlock('CUSTOMER VOICE', voices)
      else
        _listBlock('ACCESSORIES IN', kit),
      pw.SizedBox(height: 4),
    ];
  }

  /// The condition the vehicle came in, and the counter's own note.
  static List<pw.Widget> _handover(JobCard card, Set<DocSection> on) {
    final blocks = <pw.Widget>[
      if (on.contains(DocSection.dents) && card.dents.isNotEmpty)
        _listBlock('DAMAGE NOTED AT HANDOVER', [
          for (final d in card.dents)
            [
              d.severity.label,
              'on ${d.where}',
              if (d.note.isNotEmpty) '— ${d.note}',
            ].join(' '),
        ]),
      if (on.contains(DocSection.workNote) && card.workNote.trim().isNotEmpty)
        _listBlock('WORK NOTE', card.workNote.trim().split('\n')),
    ];
    if (blocks.isEmpty) return const [];
    return [pw.SizedBox(height: 14), ...blocks];
  }

  // --- photographs ----------------------------------------------------------

  /// The pictures taken at handover, two rows of three at most.
  ///
  /// The count printed underneath is the card's, not the wall's: a bill that
  /// quietly shows six of eleven photographs is a bill somebody will argue
  /// with, so it says how many were left off and where the rest are.
  static pw.Widget _photoWall(List<pw.ImageProvider> photos, JobCard card) {
    final left = card.photos.length - photos.length;
    return pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(border: pw.Border.all(color: _line)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _band('PHOTOGRAPHS AT HANDOVER'),
          pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < photos.length; i++)
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        width: 158,
                        height: 112,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: _line),
                        ),
                        child: pw.Image(photos[i], fit: pw.BoxFit.cover),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Photo {0}'.trf([i + 1]),
                        style: const pw.TextStyle(
                          fontSize: 7.5,
                          color: _inkMuted,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (left > 0)
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(8, 0, 8, 7),
              child: pw.Text(
                '{0} more on this job card in the app.'.trf([left]),
                style: const pw.TextStyle(fontSize: 7.5, color: _inkMuted),
              ),
            ),
        ],
      ),
    );
  }

  // --- the bottom of the bill ----------------------------------------------

  /// Money in, messages out, and the way to pay the rest.
  ///
  /// These three go together at the foot of the document because they are all
  /// answers to "and then what happened" — the part payments already made,
  /// the messages the shop sent about them, and the code for the balance.
  static List<pw.Widget> _ledger(
    JobCard card,
    Garage garage,
    DocKind kind,
    Set<DocSection> on,
  ) {
    final payments = on.contains(DocSection.payments)
        ? card.payments
        : const <Payment>[];
    final sms = on.contains(DocSection.sms) ? card.sms : const <SmsEvent>[];
    final pay =
        on.contains(DocSection.paymentQr) &&
        kind.showsPricing &&
        garage.upiId.trim().isNotEmpty;

    if (payments.isEmpty && sms.isEmpty && !pay) return const [];

    return [
      pw.SizedBox(height: 14),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (payments.isNotEmpty)
                  _miniTable(
                    'TRANSACTIONS',
                    const ['Date', 'Mode', 'Reference', 'Amount'],
                    [
                      for (final p in payments)
                        [
                          Fmt.dateTime(p.at),
                          p.mode.label,
                          p.note.isEmpty ? '—' : p.note,
                          Fmt.money2(p.amount),
                        ],
                      ['', '', 'Total paid', Fmt.money2(card.paid)],
                    ],
                    const {
                      0: pw.FixedColumnWidth(76),
                      1: pw.FixedColumnWidth(52),
                      2: pw.FlexColumnWidth(3),
                      3: pw.FixedColumnWidth(60),
                    },
                    const {3},
                  ),
                if (sms.isNotEmpty)
                  _miniTable(
                    'SMS DETAIL',
                    const ['Message', 'When', 'Status'],
                    [
                      for (final e in sms)
                        [e.label, Fmt.dateTime(e.at), e.state.label],
                    ],
                    const {
                      0: pw.FlexColumnWidth(3),
                      1: pw.FixedColumnWidth(76),
                      2: pw.FixedColumnWidth(54),
                    },
                    const <int>{},
                  ),
              ],
            ),
          ),
          if (pay) ...[pw.SizedBox(width: 10), _payBox(card, garage)],
        ],
      ),
    ];
  }

  /// A banded title over a compact table. The ledger blocks are columns of
  /// short facts rather than the bill itself, so they are set smaller.
  static pw.Widget _miniTable(
    String title,
    List<String> headers,
    List<List<String>> data,
    Map<int, pw.TableColumnWidth> widths,
    Set<int> rightAligned,
  ) {
    final align = {
      for (var i = 0; i < headers.length; i++)
        i: rightAligned.contains(i)
            ? pw.Alignment.centerRight
            : pw.Alignment.centerLeft,
    };
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _band(title),
          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: _line, width: 0.5),
            headerDecoration: const pw.BoxDecoration(color: _wash),
            headerStyle: pw.TextStyle(
              fontSize: 7.5,
              color: _inkMuted,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(fontSize: 8, color: _inkSoft),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 5,
              vertical: 3.5,
            ),
            columnWidths: widths,
            headerAlignments: align,
            cellAlignments: align,
            headers: headers,
            data: data,
          ),
        ],
      ),
    );
  }

  /// Scan-to-pay for whatever is still owed.
  ///
  /// A settled bill gets the same box with no code in it. Printing a live
  /// collection code on a receipt that is already paid is how a customer pays
  /// twice, and the shop finds out a week later.
  static pw.Widget _payBox(JobCard card, Garage garage) {
    final due = card.balance;
    final uri = upiIntent(
      upiId: garage.upiId,
      payee: garage.name,
      amount: due,
      note: 'Job card {0}'.trf([card.number]),
    );
    final live = due > 0 && uri.isNotEmpty;

    return pw.Container(
      width: 132,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: _wash,
        border: pw.Border.all(color: _line),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            live ? 'SCAN TO PAY'.tr : 'PAID IN FULL'.tr,
            style: pw.TextStyle(
              fontSize: 7.5,
              color: _accent,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          if (live)
            pw.Container(
              width: 96,
              height: 96,
              color: PdfColors.white,
              padding: const pw.EdgeInsets.all(4),
              child: pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: uri,
                drawText: false,
                color: _ink,
              ),
            )
          else
            pw.Container(
              width: 96,
              height: 44,
              alignment: pw.Alignment.center,
              child: pw.Text(
                'Nothing due'.tr,
                style: pw.TextStyle(
                  fontSize: 11,
                  color: _ink,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          pw.SizedBox(height: 5),
          if (live)
            pw.Text(
              Fmt.money2(due),
              style: pw.TextStyle(
                fontSize: 11,
                color: _ink,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          pw.SizedBox(height: 2),
          pw.Text(
            garage.upiId,
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 7, color: _inkMuted),
          ),
        ],
      ),
    );
  }

  // --- furniture ------------------------------------------------------------

  static pw.Widget _empty() => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.symmetric(vertical: 22),
    alignment: pw.Alignment.center,
    decoration: pw.BoxDecoration(border: pw.Border.all(color: _line)),
    child: pw.Text(
      'Nothing billed on this card yet.'.tr,
      style: const pw.TextStyle(fontSize: 9, color: _inkMuted),
    ),
  );

  static pw.Widget _note(String text) => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: const pw.BoxDecoration(color: _accentSoft),
    child: pw.Text(text, style: const pw.TextStyle(fontSize: 9, color: _ink)),
  );

  static pw.Widget _signatures(Garage garage) => pw.Row(
    children: [
      pw.Expanded(child: _signature('Customer signature')),
      pw.SizedBox(width: 40),
      pw.Expanded(child: _signature('For ${garage.name}')),
    ],
  );

  static pw.Widget _signature(String label) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(height: 0.8, color: _line),
      pw.SizedBox(height: 4),
      pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: _inkMuted)),
    ],
  );

  static pw.Widget _footer(JobCard card, Garage garage, pw.Context context) =>
      pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 8),
        child: pw.Text(
          '{0}  ·  {1}  ·  Page {2} of {3}'.trf([
            garage.name,
            card.number,
            context.pageNumber,
            context.pagesCount,
          ]),
          style: const pw.TextStyle(fontSize: 7.5, color: _inkMuted),
        ),
      );

  static pw.Widget _band(String text) => pw.Container(
    width: double.infinity,
    color: _wash,
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 7.5,
        color: _accent,
        fontWeight: pw.FontWeight.bold,
      ),
    ),
  );

  static pw.Widget _meta(String label, String value) => pw.Text(
    '$label: $value',
    style: const pw.TextStyle(fontSize: 8, color: _inkSoft),
  );

  // ===========================================================================
  // Thermal roll
  // ===========================================================================

  /// 58 and 80mm rolls, which are the same document at two widths.
  ///
  /// No tables and no rules: a thermal head prints dots, and anything finer
  /// than a dashed line comes out as a smudge. Everything is centred or in two
  /// columns, and the paper is as long as the bill needs.
  static pw.Page _roll(
    DocKind kind,
    JobCard card,
    Garage garage,
    InvoiceFormat format,
    Customer? customer,
    Vehicle? vehicle,
    List<String> mechanics,
    Set<DocSection> on,
  ) {
    final w = format.rollMm * PdfPageFormat.mm;
    final tight = format == InvoiceFormat.thermal58;
    final body = tight ? 7.0 : 8.0;
    final priced = kind.showsPricing;

    pw.Widget center(String t, {double? size, bool bold = false}) => pw.Text(
      t,
      textAlign: pw.TextAlign.center,
      style: pw.TextStyle(
        fontSize: size ?? body,
        color: PdfColors.black,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    );

    pw.Widget pair(String l, String r, {bool bold = false}) => pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Text(
            l,
            style: pw.TextStyle(
              fontSize: bold ? body + 1 : body,
              color: PdfColors.black,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ),
        pw.Text(
          r,
          style: pw.TextStyle(
            fontSize: bold ? body + 1 : body,
            color: PdfColors.black,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    );

    pw.Widget left(String t, {bool bold = false}) => pw.Text(
      t,
      style: pw.TextStyle(
        fontSize: body,
        color: PdfColors.black,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    );

    // A drawn hairline rather than a row of hyphens: the dashes depend on
    // the font's advance width lining up with the paper and came out ragged.
    final rule = pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Container(height: 0.7, color: PdfColors.black),
    );

    return pw.Page(
      pageFormat: PdfPageFormat(
        w,
        double.infinity,
        marginAll: (tight ? 5 : 8) * PdfPageFormat.mm,
      ),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          center(garage.name, size: tight ? 10 : 12, bold: true),
          if (garage.addressLine.isNotEmpty)
            center(
              [
                garage.addressLine,
                garage.city,
              ].where((e) => e.isNotEmpty).join(', '),
            ),
          center('Ph: ${garage.phone}'),
          if (garage.gstin.isNotEmpty) center('GSTIN: ${garage.gstin}'),
          rule,
          center(kind.label.toUpperCase(), bold: true),
          rule,
          pair('No.', card.number),
          pair('Date', Fmt.date(card.createdAt)),
          pair('Time', Fmt.time(card.createdAt)),
          if (customer != null) pair('Name', customer.name),
          if (customer != null && customer.phone.isNotEmpty)
            pair('Phone', customer.phone),
          if (customer != null && customer.gstin.trim().isNotEmpty)
            pair('GSTIN', customer.gstin.trim()),
          // The fuel and gearbox sit under the plate with no label of their
          // own: they describe the vehicle on the line above, and a second
          // "Fuel" row would read as the tank level printed twice. The
          // insurance line goes through left() rather than pair() because a
          // long insurer plus a policy number is wider than 58mm and needs
          // to wrap, which the right-hand side of a pair never does.
          if (vehicle != null) ...[
            pair('Vehicle', Fmt.plate(vehicle.regNo)),
            pair('', _fuelAndGearbox(vehicle)),
            if (_insurance(vehicle).isNotEmpty) left(_insurance(vehicle)),
          ],
          if (on.contains(DocSection.odometer)) ...[
            pair('Km', Fmt.km(card.odometerKm)),
            pair('Fuel', '${card.fuelPercent}%'),
          ],
          if (on.contains(DocSection.mechanics) && mechanics.isNotEmpty)
            pair('Attended by', mechanics.join(', ')),
          if (card.promisedAt != null)
            pair('Ready by', Fmt.dateTime(card.promisedAt!)),
          rule,

          // What came in, in the customer's words. Short lines only — 58mm
          // wraps anything longer into a paragraph nobody reads.
          if (on.contains(DocSection.voices) && card.voices.isNotEmpty) ...[
            left('CUSTOMER VOICE', bold: true),
            for (final v in card.voices) left('• $v'),
            rule,
          ],
          if (on.contains(DocSection.accessories) &&
              card.accessories.isNotEmpty) ...[
            left('ACCESSORIES IN', bold: true),
            for (final a in card.accessories) left('• $a'),
            rule,
          ],
          if (on.contains(DocSection.dents) && card.dents.isNotEmpty) ...[
            left('DAMAGE NOTED', bold: true),
            for (final d in card.dents)
              left(
                '• ${[d.severity.label, 'on ${d.where}', if (d.note.isNotEmpty) '— ${d.note}'].join(' ')}',
              ),
            rule,
          ],
          if (on.contains(DocSection.workNote) &&
              card.workNote.trim().isNotEmpty) ...[
            left('WORK NOTE', bold: true),
            for (final n in card.workNote.trim().split('\n')) left(n),
            rule,
          ],

          if (card.items.isEmpty)
            center('Nothing billed yet.')
          else
            for (final item in card.items) ...[
              pw.Text(
                item.name,
                style: pw.TextStyle(
                  fontSize: body,
                  color: PdfColors.black,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              if (priced)
                pair(
                  '  ${item.qtyLabel} × ${Fmt.money2(item.rate)}',
                  Fmt.money2(item.amount),
                )
              else
                pair('  ${item.state.label}', ''),
            ],

          if (priced) ...[
            rule,
            pair('Sub total', Fmt.money2(card.subTotal)),
            if (card.discount > 0)
              pair('Discount', '− ${Fmt.money2(card.discount)}'),
            if (card.taxAmount > 0) ...[
              pair('CGST', Fmt.money2(card.taxAmount / 2)),
              pair('SGST', Fmt.money2(card.taxAmount / 2)),
            ],
            rule,
            pair('TOTAL', Fmt.money2(card.total), bold: true),
            pair('Paid', Fmt.money2(card.paid)),
            pair('Balance', Fmt.money2(card.balance), bold: true),
            rule,
            center(Words.rupees(card.total)),
          ],

          if (on.contains(DocSection.payments) &&
              priced &&
              card.payments.isNotEmpty) ...[
            rule,
            left('TRANSACTIONS', bold: true),
            for (final p in card.payments)
              pair(
                '${Fmt.dateShort(p.at)} ${p.mode.label}',
                Fmt.money2(p.amount),
              ),
          ],

          if (on.contains(DocSection.sms) && card.sms.isNotEmpty) ...[
            rule,
            left('SMS DETAIL', bold: true),
            for (final e in card.sms)
              pair('${e.label} · ${Fmt.dateShort(e.at)}', e.state.label),
          ],

          // 80mm resolves a QR; 58mm does not, which is why the section is
          // never offered there — see DocSection.availableOn.
          if (on.contains(DocSection.paymentQr) &&
              priced &&
              card.balance > 0 &&
              garage.upiId.trim().isNotEmpty) ...[
            rule,
            center('SCAN TO PAY ${Fmt.money2(card.balance)}', bold: true),
            pw.SizedBox(height: 4),
            pw.Center(
              child: pw.Container(
                width: 118,
                height: 118,
                color: PdfColors.white,
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: upiIntent(
                    upiId: garage.upiId,
                    payee: garage.name,
                    amount: card.balance,
                    note: 'Job card {0}'.trf([card.number]),
                  ),
                  drawText: false,
                  color: PdfColors.black,
                ),
              ),
            ),
            pw.SizedBox(height: 3),
            center(garage.upiId),
          ],

          if (card.nextServiceAt != null) ...[
            rule,
            center('Next service: ${Fmt.date(card.nextServiceAt!)}'),
          ],
          rule,
          center('Thank you for choosing'),
          center(garage.name, bold: true),
          pw.SizedBox(height: 6),
        ],
      ),
    );
  }
}
