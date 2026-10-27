import '../../../core/i18n/strings.dart';
import '../../../data/models/enums.dart';
import 'invoice_format.dart';

/// The blocks a document can carry, over and above the letterhead, the line
/// table and the totals that every one of them has.
///
/// Kept as a set rather than a row of flags so the on-screen preview, the PDF
/// and the switch list on the share sheet all read the same thing: what is on
/// this document is exactly what is in the set, and nothing decides it twice.
enum DocSection {
  odometer,
  mechanics,
  voices,
  accessories,
  workNote,
  dents,
  photos,
  sms,
  payments,
  paymentQr,
}

extension DocSectionX on DocSection {
  String get label => switch (this) {
    DocSection.odometer => 'Odometer & fuel'.tr,
    DocSection.mechanics => 'Mechanics'.tr,
    DocSection.voices => 'Customer voice'.tr,
    DocSection.accessories => 'Accessories'.tr,
    DocSection.workNote => 'Work note'.tr,
    DocSection.dents => 'Damage marks'.tr,
    DocSection.photos => 'Photos'.tr,
    DocSection.sms => 'SMS detail'.tr,
    DocSection.payments => 'Transactions'.tr,
    DocSection.paymentQr => 'Payment QR'.tr,
  };

  String get blurb => switch (this) {
    DocSection.odometer => 'Kilometres in and fuel level'.tr,
    DocSection.mechanics => 'Who worked on it'.tr,
    DocSection.voices => 'What the customer reported'.tr,
    DocSection.accessories => 'What came in with the vehicle'.tr,
    DocSection.workNote => 'The counter note on the card'.tr,
    DocSection.dents => 'Scratches and dents logged at handover'.tr,
    DocSection.photos => 'Pictures taken at handover'.tr,
    DocSection.sms => 'Which messages went out, and when'.tr,
    DocSection.payments => 'Every part payment against this card'.tr,
    DocSection.paymentQr => 'Scan-to-pay for whatever is still due'.tr,
  };

  /// Whether this block can go on that shape of paper at all.
  ///
  /// A thermal head prints dots, so photographs and the fine grid of a QR
  /// come out as a smear on 58mm — the QR earns its place at 80mm and not
  /// below. And the mechanic copy carries no money by design, so the money
  /// blocks are not offered on it.
  bool availableOn(InvoiceFormat format, DocKind kind) => switch (this) {
    DocSection.photos => format.canCarryPhotos,
    DocSection.paymentQr =>
      kind.showsPricing && format != InvoiceFormat.thermal58,
    DocSection.payments => kind.showsPricing,
    _ => true,
  };

  /// What the template starts with ticked.
  ///
  /// The bills — estimate and invoice — never start with the intake story:
  /// the customer voice, the accessories and the damage marks are what came
  /// in at the counter, and a customer (or the company paying) wants a bill,
  /// not a diary. They stay one switch away on the share sheet. Beyond that
  /// the detailed template starts with everything else on, and the rolls stay
  /// short because the paper is.
  ///
  /// Handover photographs ride on every A4 bill from the start. Somebody who
  /// has stood in front of a vehicle and shot it has already decided the
  /// pictures belong on the paperwork, and a bill that quietly leaves them
  /// off reads as the camera having failed. A card with no photographs on it
  /// prints no block, so this costs the shops that do not use them nothing.
  ///
  /// The floor copy comes in two flavours on one [DocKind]: the mechanic's
  /// carries the work and nothing else, and the job card copy handed to the
  /// customer at check-in carries the intake story too — see [jobCardCopy].
  bool defaultOn(
    InvoiceFormat format,
    DocKind kind, {
    bool jobCardCopy = false,
  }) {
    if (!availableOn(format, kind)) return false;
    if (kind == DocKind.mechanicCopy) {
      if (jobCardCopy) return this != DocSection.sms;
      return const {
        DocSection.odometer,
        DocSection.mechanics,
        DocSection.voices,
        DocSection.workNote,
      }.contains(this);
    }
    if (const {
      DocSection.voices,
      DocSection.accessories,
      DocSection.dents,
    }.contains(this)) {
      return false;
    }
    return switch (format) {
      InvoiceFormat.detailedA4 => true,
      InvoiceFormat.taxA4 || InvoiceFormat.simpleA4 => const {
        DocSection.odometer,
        DocSection.mechanics,
        DocSection.photos,
        DocSection.payments,
        DocSection.paymentQr,
      }.contains(this),
      InvoiceFormat.thermal80 => const {
        DocSection.odometer,
        DocSection.paymentQr,
      }.contains(this),
      InvoiceFormat.thermal58 => const {DocSection.odometer}.contains(this),
    };
  }

  /// Every block this template starts with.
  static Set<DocSection> defaultsFor(
    InvoiceFormat format,
    DocKind kind, {
    bool jobCardCopy = false,
  }) => {
    for (final s in DocSection.values)
      if (s.defaultOn(format, kind, jobCardCopy: jobCardCopy)) s,
  };

  /// The blocks that can be offered at all on this template.
  static List<DocSection> offeredOn(InvoiceFormat format, DocKind kind) => [
    for (final s in DocSection.values)
      if (s.availableOn(format, kind)) s,
  ];

  /// Drops anything the new template cannot carry, and keeps the rest of the
  /// counter's choices.
  ///
  /// Switching from the detailed A4 to a 58mm roll should not silently hand
  /// back a document with photographs on it, and should not forget that the
  /// counter wanted the customer voice either.
  static Set<DocSection> carryOver(
    Set<DocSection> chosen,
    InvoiceFormat format,
    DocKind kind,
  ) => {
    for (final s in chosen)
      if (s.availableOn(format, kind)) s,
  };
}
