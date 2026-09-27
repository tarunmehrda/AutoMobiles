/// The shapes a document can be printed in.
///
/// Separate from [DocKind], which says *what* the document is (estimate,
/// job card, mechanic copy). This says what paper it lands on and how much
/// detail it carries — a counter handing over a scooter wants 58mm of thermal
/// roll, the same job billed to a company wants a full tax invoice.
library;

import '../../../core/i18n/strings.dart';

enum InvoiceFormat {
  /// Compliant GST tax invoice: HSN/SAC, taxable value, CGST/SGST split.
  taxA4,

  /// Clean A4 with no tax breakdown — the cash-job bill.
  simpleA4,

  /// Everything on the card: condition, voices, accessories, work note.
  detailedA4,

  /// 80mm counter-printer roll.
  thermal80,

  /// 58mm pocket-printer roll.
  thermal58,
}

extension InvoiceFormatX on InvoiceFormat {
  String get label => switch (this) {
    InvoiceFormat.taxA4 => 'GST Tax Invoice'.tr,
    InvoiceFormat.simpleA4 => 'Simple Bill'.tr,
    InvoiceFormat.detailedA4 => 'Detailed Job Card'.tr,
    InvoiceFormat.thermal80 => 'Thermal 80mm'.tr,
    InvoiceFormat.thermal58 => 'Thermal 58mm'.tr,
  };

  String get blurb => switch (this) {
    InvoiceFormat.taxA4 => 'A4 · GSTIN, HSN and tax split'.tr,
    InvoiceFormat.simpleA4 => 'A4 · no tax breakdown'.tr,
    InvoiceFormat.detailedA4 => 'A4 · condition and work notes too'.tr,
    InvoiceFormat.thermal80 => 'Roll · counter printer'.tr,
    InvoiceFormat.thermal58 => 'Roll · pocket printer'.tr,
  };

  bool get isThermal =>
      this == InvoiceFormat.thermal80 || this == InvoiceFormat.thermal58;

  /// A one-word name for the paper, for the template picker.
  String get paper => isThermal ? 'Roll' : 'A4';

  /// Whether the complaint the customer came in with rides along by default.
  ///
  /// The detailed card is the one built to carry it. Everywhere else it is
  /// off to begin with and one switch away on the share sheet, because a
  /// company being billed for a service wants a bill, not a diary.
  bool get voicesByDefault => this == InvoiceFormat.detailedA4;

  /// Whether the handover photographs are attached by default.
  ///
  /// Same reasoning, with one extra: a thermal head prints dots, so a
  /// photograph on a roll is a grey smear. The rolls cannot carry them at
  /// all — see [canCarryPhotos].
  bool get photosByDefault => this == InvoiceFormat.detailedA4;

  /// Photographs need halftones, which 58 and 80mm thermal paper does not do.
  bool get canCarryPhotos => !isThermal;

  /// Roll width in millimetres, for the thermal formats.
  double get rollMm => this == InvoiceFormat.thermal58 ? 58 : 80;

  static InvoiceFormat parse(String? v) => InvoiceFormat.values.firstWhere(
    (e) => e.name == v,
    orElse: () => InvoiceFormat.simpleA4,
  );
}
