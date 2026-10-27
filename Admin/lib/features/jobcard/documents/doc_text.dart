/// The few strings and figures the on-screen document and the PDF both print.
///
/// Worked out once, here, so the preview and the paper cannot drift: the
/// counter reads the preview to decide the bill is right, and the customer
/// reads the PDF. If the two did their own arithmetic for the advance or the
/// GST column, they would one day disagree in front of somebody.
library;

import '../../../core/i18n/strings.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/books.dart';
import '../../../data/models/entities.dart';
import '../../../data/models/enums.dart';
import 'invoice_format.dart';

/// What goes in the title box of the document.
///
/// The floor copy comes in two flavours that share one [DocKind]: the
/// mechanic's, and the one handed to the customer at check-in, which carries
/// the intake story (accessories, damage, promised delivery) and a signature
/// line for them. The tax template says TAX INVOICE because the rule asks
/// for that wording.
String docTitle(
  DocKind kind,
  InvoiceFormat format, {
  bool jobCardCopy = false,
}) {
  if (kind == DocKind.mechanicCopy) {
    return jobCardCopy ? 'Job Card Copy'.tr : 'Mechanic Copy'.tr;
  }
  return switch (format) {
    InvoiceFormat.taxA4 => 'Tax Invoice',
    InvoiceFormat.detailedA4 => 'Job Card',
    _ => kind.label,
  };
}

/// `2015 Honda Amaze` — the year first, the way a workshop says it.
String vehicleMake(Vehicle v) => [
  if (v.year != null) '${v.year}',
  v.title,
].where((e) => e.trim().isNotEmpty).join(' ');

/// `2 ltr`, or just `2` when the line has no unit.
String qtyWithUnit(LineItem line) {
  final unit = line.unit.trim();
  return unit.isEmpty ? line.qtyLabel : '${line.qtyLabel} $unit';
}

/// `18%`, `5%`, `12.5%` — a GST fraction as it is printed.
String gstPct(double rate) {
  final v = rate * 100;
  final whole = (v - v.roundToDouble()).abs() < 0.001;
  return '${whole ? v.round() : v.toStringAsFixed(1)}%';
}

/// The GST a line is billed at on this card, as printed in its column.
String lineGst(LineItem line, JobCard card) => gstPct(line.gstOn(card.taxRate));

/// The single rate every line on the card is billed at, or null when the
/// lines differ. A bill at one rate says `GST 18%`; a mixed one just `GST`,
/// because the per-line column already says which line is at what.
double? uniformGst(JobCard card) {
  if (card.items.isEmpty) return card.taxRate;
  final first = card.items.first.gstOn(card.taxRate);
  for (final e in card.items) {
    if ((e.gstOn(card.taxRate) - first).abs() > 0.0001) return null;
  }
  return first;
}

/// The tax line's label on a bill that does not split CGST and SGST.
String taxLabel(JobCard card) {
  final r = uniformGst(card);
  return r == null ? 'GST'.tr : 'GST {0}'.trf([gstPct(r)]);
}

/// One line's share of the bill-level discount taken off, before its tax.
///
/// The discount is on the bill as a whole, so it comes off each line in the
/// same proportion — otherwise the line taxes and `JobCard.taxAmount` would
/// not add up to the same figure.
double lineTaxable(LineItem line, JobCard card) {
  final sub = card.subTotal;
  if (sub <= 0) return 0;
  return line.amount * (card.taxable / sub);
}

/// What is left to pay once the advance is taken off the total.
double payableAfterAdvance(JobCard card) =>
    money((card.total - card.advancePaid).clamp(0, double.infinity));

/// What was paid at or after delivery — everything except the advance, which
/// the invoice prints on its own line above.
double paidExcludingAdvance(JobCard card) =>
    money((card.paid - card.advancePaid).clamp(0, double.infinity));

/// The accounts the shop has asked to print at the foot of the invoice,
/// primary first (the order `AdminData.banks` already keeps).
List<BankAccount> invoiceBanks(List<BankAccount> banks) => [
  for (final b in banks)
    if (!b.cash && b.printOnInvoice) b,
];

/// `HDFC Bank, A/c holder: Test Motors, A/c No: 1234, IFSC: HDFC0001234,
/// Branch: Jaipur` — the line a customer types into their bank app.
String bankLine(BankAccount b) => [
  b.name.trim(),
  if (b.holder.trim().isNotEmpty) 'A/c holder: {0}'.trf([b.holder.trim()]),
  if (b.accountNo.trim().isNotEmpty) 'A/c No: {0}'.trf([b.accountNo.trim()]),
  if (b.ifsc.trim().isNotEmpty) 'IFSC: {0}'.trf([b.ifsc.trim().toUpperCase()]),
  if (b.branch.trim().isNotEmpty) 'Branch: {0}'.trf([b.branch.trim()]),
].where((e) => e.isNotEmpty).join(', ');

/// Where the scan-to-pay code sends the money.
///
/// A bank account the shop has marked "print UPI QR" wins over the UPI id in
/// Settings: that is the account they have said they want paid into. With
/// none, it falls back to the garage's own id as it always did.
({String upiId, String payee}) payTarget(
  Garage garage,
  List<BankAccount> banks,
) {
  for (final b in banks) {
    if (!b.cash && b.printUpiQr && b.upiId.trim().isNotEmpty) {
      return (
        upiId: b.upiId.trim(),
        payee: b.holder.trim().isNotEmpty ? b.holder.trim() : garage.name,
      );
    }
  }
  return (upiId: garage.upiId.trim(), payee: garage.name);
}

/// The insurance facts a claim invoice is billed against, label first,
/// leaving out whatever the counter did not take down.
List<(String, String)> insuranceRows(Vehicle v) => [
  if (v.insurer.trim().isNotEmpty) ('Insurer'.tr, v.insurer.trim()),
  if (v.policyNo.trim().isNotEmpty) ('Policy No'.tr, v.policyNo.trim()),
  if (v.insuranceFrom != null) ('Policy Date'.tr, Fmt.date(v.insuranceFrom!)),
  if (v.insuranceExpiry != null) ('Expiry'.tr, Fmt.date(v.insuranceExpiry!)),
  if (v.insurerAddress.trim().isNotEmpty)
    ('Insurer Address'.tr, v.insurerAddress.trim()),
  if (v.insurerGstin.trim().isNotEmpty)
    ('Insurer GSTIN'.tr, v.insurerGstin.trim().toUpperCase()),
];

/// `Brake pads  × 2 nos` — a line on the floor copy, which carries no price.
String floorLine(LineItem line) => '${line.name}  × ${qtyWithUnit(line)}';
