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
        BillRow('Sub total', card.subTotal),
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
        BillRow('Advance', card.paid),
        BillRow('Balance', card.balance, strong: true),
      ],
    );
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
