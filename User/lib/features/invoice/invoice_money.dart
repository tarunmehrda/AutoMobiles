/// The "Bill Amount Details" block, worked out once.
///
/// The screen and the downloaded PDF both render from this, so the copy the
/// customer keeps cannot disagree with the copy on their screen — or with
/// the one the workshop printed, since both apps bill through the same
/// engine.
///
/// GST is optional. When the workshop does not charge it, [taxed] is false
/// and there are no tax rows at all: the document is a Bill, not a Tax
/// Invoice, and saying otherwise on a document with no GSTIN would be a
/// misrepresentation.
library;

import 'package:flutter/foundation.dart';

import '../../core/tax/gst.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/workshop.dart';

@immutable
class BillRow {
  const BillRow(this.label, this.value, {this.strong = false});

  final String label;
  final double value;

  /// The balance — the one figure that matters to the person paying.
  final bool strong;
}

@immutable
class BillBlock {
  const BillBlock({
    required this.rows,
    required this.taxed,
    required this.interState,
  });

  final List<BillRow> rows;
  final bool taxed;
  final bool interState;

  factory BillBlock.of(WorkshopCard card) {
    final bill = card.bill;
    final slabs = <double>{
      for (var i = 0; i < bill.lines.length; i++)
        if (bill.lines[i].gstRate > 0 && bill.lineBreakups[i].tax > 0)
          bill.lines[i].gstRate,
    };
    String half() {
      if (slabs.length != 1) return '';
      final v = slabs.first / 2;
      return v == v.roundToDouble()
          ? ' ${v.toInt()}%'
          : ' ${v.toStringAsFixed(1)}%';
    }

    String full() {
      if (slabs.length != 1) return '';
      final v = slabs.first;
      return v == v.roundToDouble()
          ? ' ${v.toInt()}%'
          : ' ${v.toStringAsFixed(1)}%';
    }

    return BillBlock(
      taxed: card.taxed,
      interState: card.interState,
      rows: [
        BillRow('Subtotal', card.subTotal),
        if (card.discount > 0) BillRow('Discount', bill.billDiscount),
        if (card.taxed) ...[
          BillRow('Taxable value', bill.taxable),
          if (card.interState)
            BillRow('IGST${full()}', bill.igst)
          else ...[
            BillRow('CGST${half()}', bill.cgst),
            BillRow('SGST${half()}', bill.sgst),
          ],
        ],
        if (card.roundOff.abs() >= 0.005)
          BillRow('Round off', card.roundOff),
        BillRow('Total', card.total),
        // Advance is only what was taken when the card was opened. This row
        // used to print everything paid as "Advance", so a customer who
        // settled at pickup was told they had paid it all up front.
        BillRow('Advance', card.advance),
        BillRow('Payable', card.payable),
        BillRow('Paid', card.paidAfterAdvance),
        BillRow('Balance', card.balance, strong: true),
      ],
    );
  }

  /// The GST column for one line: "18%", or a dash on an untaxed bill.
  static String gstOf(WorkshopCard card, WorkshopLine line) {
    if (!card.taxed) return '—';
    final v = card.gstPercentOf(line);
    return v == v.roundToDouble()
        ? '${v.toInt()}%'
        : '${v.toStringAsFixed(1)}%';
  }

  /// What the document calls itself.
  String get title => taxed ? 'Tax Invoice' : 'Invoice';

  /// "08 - Rajasthan", or empty when there is nothing to print.
  static String placeOfSupply(String stateCode) {
    final code = stateCode.trim();
    if (code.isEmpty) return '';
    final name = Gstin.stateName(code);
    return name.isEmpty ? code : '$code - $name';
  }
}

/// Who is billing — the lines printed under the title — worked out once for
/// the screen and the PDF alike.
///
/// The card's own letterhead comes first. It used to be the linked
/// workshop's address, email and terms under the card's garage name, and a
/// customer of two garages got one garage's details printed under the
/// other's. The linked workshop is only a stand-in for a card that does not
/// carry its letterhead yet (older rows, before the database was brought
/// up to date), and only when it is the same garage: a blank line is
/// better than another business's address on a bill.
@immutable
class Letterhead {
  const Letterhead({
    this.name = '',
    this.where = '',
    this.phone = '',
    this.email = '',
    this.gstin = '',
    this.terms = '',
  });

  final String name;
  final String where;
  final String phone;
  final String email;
  final String gstin;
  final String terms;

  factory Letterhead.of(WorkshopCard card, Workshop linked) {
    final same = card.garageId.isEmpty || card.garageId == linked.id;
    String pick(String own, String fallback) {
      final mine = own.trim();
      if (mine.isNotEmpty) return mine;
      return same ? fallback.trim() : '';
    }

    return Letterhead(
      // The name keeps its old fallback: it is what the screen has always
      // shown, and an invoice with no name at the top at all is worse.
      name: card.garageName.trim().isEmpty
          ? linked.name.trim()
          : card.garageName.trim(),
      where: pick(card.garageWhere, linked.address),
      phone: pick(card.garagePhone, linked.phone),
      email: pick(card.garageEmail, linked.email),
      gstin: pick(card.garageGstin, linked.gstin),
      terms: pick(card.garageTerms, linked.terms),
    );
  }
}

/// The other side of the bill, and the vehicle's insurance under it, as
/// lines ready to print — the same for the screen and the PDF.
///
/// The workshop's customer record comes first: it is who the bill is made
/// out to, which may be a firm rather than whoever holds this phone. The
/// profile's name and number only stand in for a card that does not carry
/// them yet.
@immutable
class BillParty {
  const BillParty({this.billTo = const [], this.insurance = const []});

  final List<String> billTo;
  final List<String> insurance;

  factory BillParty.of(
    WorkshopCard card, {
    String name = '',
    String phone = '',
  }) {
    String pick(String own, String fallback) =>
        own.trim().isNotEmpty ? own.trim() : fallback.trim();
    final who = pick(card.billName, name);
    final mobile = pick(card.billPhone, phone);
    String? on(DateTime? d) => d == null ? null : Fmt.date(d);

    return BillParty(
      billTo: [
        if (who.isNotEmpty) who,
        if (mobile.isNotEmpty) 'Mobile No: $mobile',
        if (card.billEmail.trim().isNotEmpty) 'Email: ${card.billEmail.trim()}',
        if (card.billAddress.trim().isNotEmpty) card.billAddress.trim(),
        if (card.billGstin.trim().isNotEmpty)
          'GSTIN: ${card.billGstin.trim()}',
      ],
      insurance: !card.hasInsurance
          ? const []
          : [
              for (final (label, value) in [
                ('Insurer', card.insurer),
                ('Policy No', card.policyNo),
                ('Policy Date', on(card.insuranceFrom)),
                ('Expiry', on(card.insuranceExpiry)),
                ('Insurer Address', card.insurerAddress),
                ('Insurer GSTIN', card.insurerGstin),
              ])
                if ((value ?? '').trim().isNotEmpty)
                  '$label: ${value!.trim()}',
            ],
    );
  }
}
