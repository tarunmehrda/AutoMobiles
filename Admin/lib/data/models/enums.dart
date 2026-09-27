import 'package:flutter/material.dart';

import '../../core/i18n/strings.dart';

/// Where a job card sits in the workshop. The three dashboard counters and the
/// three list screens map one-to-one onto these.
enum JobStatus { open, complete, closed }

extension JobStatusX on JobStatus {
  String get label => switch (this) {
    JobStatus.open => 'Open'.tr,
    JobStatus.complete => 'Complete'.tr,
    JobStatus.closed => 'Closed'.tr,
  };

  /// Title used by the list screens.
  String get listTitle => switch (this) {
    JobStatus.open => 'Open Job Cards'.tr,
    JobStatus.complete => 'Complete Job Cards'.tr,
    JobStatus.closed => 'Close Job Cards'.tr,
  };

  String get blurb => switch (this) {
    JobStatus.open => 'Work in progress on the floor'.tr,
    JobStatus.complete => 'Work done, awaiting settlement'.tr,
    JobStatus.closed => 'Settled and handed over'.tr,
  };

  IconData get icon => switch (this) {
    JobStatus.open => Icons.build_circle_rounded,
    JobStatus.complete => Icons.task_alt_rounded,
    JobStatus.closed => Icons.lock_rounded,
  };

  static JobStatus parse(String? v) => JobStatus.values.firstWhere(
    (e) => e.name == v,
    orElse: () => JobStatus.open,
  );
}

/// The three billing buckets. The item editor is one tab per kind and the
/// invoice groups by the same split.
enum LineKind { job, spare, lube }

extension LineKindX on LineKind {
  String get label => switch (this) {
    LineKind.job => 'Jobs'.tr,
    LineKind.spare => 'Spare'.tr,
    LineKind.lube => 'Lube'.tr,
  };

  String get singular => switch (this) {
    LineKind.job => 'Job',
    LineKind.spare => 'Spare part',
    LineKind.lube => 'Lubricant',
  };

  /// Labour is billed as a service; spares and lubes come out of stock.
  bool get isStocked => this != LineKind.job;

  IconData get icon => switch (this) {
    LineKind.job => Icons.handyman_rounded,
    LineKind.spare => Icons.settings_rounded,
    LineKind.lube => Icons.water_drop_rounded,
  };

  static LineKind parse(String? v) => LineKind.values.firstWhere(
    (e) => e.name == v,
    orElse: () => LineKind.job,
  );
}

/// Which shelf a spare lives on.
///
/// A label, not a rule: nothing downstream behaves differently per group.
/// It exists because a storeman looking for a clutch cable thinks "running
/// item" long before they think of its part number, and the billing screen
/// filters on exactly that instinct.
enum PartGroup { running, engine, accessory }

extension PartGroupX on PartGroup {
  String get label => switch (this) {
    PartGroup.running => 'Running Items'.tr,
    PartGroup.engine => 'Engine Part'.tr,
    PartGroup.accessory => 'Accessories'.tr,
  };

  /// Fits a filter chip, where three of them share the width.
  String get short => switch (this) {
    PartGroup.running => 'Running'.tr,
    PartGroup.engine => 'Engine'.tr,
    PartGroup.accessory => 'Fitments'.tr,
  };

  IconData get icon => switch (this) {
    PartGroup.running => Icons.autorenew_rounded,
    PartGroup.engine => Icons.settings_suggest_rounded,
    PartGroup.accessory => Icons.auto_awesome_rounded,
  };

  static PartGroup parse(String? v) => PartGroup.values.firstWhere(
    (e) => e.name == v,
    orElse: () => PartGroup.running,
  );
}

/// How a stocked line is counted out of the store.
///
/// Lubes are the reason this exists — engine oil is sold by the litre and
/// grease by the gram, so a bare count would bill a 500 ml top-up as one
/// whole can.
const List<String> kStockUnits = ['nos', 'ltr', 'ml', 'gm', 'can', 'set'];

/// Per-line progress the mechanic ticks off on the mechanic copy.
enum WorkState { pending, running, done, skipped }

extension WorkStateX on WorkState {
  String get label => switch (this) {
    WorkState.pending => 'Pending'.tr,
    WorkState.running => 'Running'.tr,
    WorkState.done => 'Done'.tr,
    WorkState.skipped => 'Skipped'.tr,
  };

  static WorkState parse(String? v) => WorkState.values.firstWhere(
    (e) => e.name == v,
    orElse: () => WorkState.pending,
  );
}

/// Which document the detail screen is rendering.
enum DocKind { estimate, invoice, mechanicCopy }

extension DocKindX on DocKind {
  String get label => switch (this) {
    DocKind.estimate => 'Estimate'.tr,
    DocKind.invoice => 'Jobcard'.tr,
    DocKind.mechanicCopy => 'Mechanic Copy'.tr,
  };

  /// Money is deliberately hidden from the copy that goes to the floor.
  bool get showsPricing => this != DocKind.mechanicCopy;

  static DocKind parse(String? v) => DocKind.values.firstWhere(
    (e) => e.name == v,
    orElse: () => DocKind.estimate,
  );
}

enum PayMode { cash, upi, card, netbanking, cheque }

extension PayModeX on PayMode {
  String get label => switch (this) {
    PayMode.cash => 'Cash'.tr,
    PayMode.upi => 'UPI',
    PayMode.card => 'Card'.tr,
    PayMode.netbanking => 'Net banking'.tr,
    PayMode.cheque => 'Cheque'.tr,
  };

  IconData get icon => switch (this) {
    PayMode.cash => Icons.payments_rounded,
    PayMode.upi => Icons.qr_code_2_rounded,
    PayMode.card => Icons.credit_card_rounded,
    PayMode.netbanking => Icons.account_balance_rounded,
    PayMode.cheque => Icons.receipt_long_rounded,
  };

  static PayMode parse(String? v) =>
      PayMode.values.firstWhere((e) => e.name == v, orElse: () => PayMode.cash);
}

/// State of one message in the job card's SMS trail.
///
/// There is no SMS gateway behind this app: a message goes out from the
/// counter phone's own SMS app, one tap at a time. So the names mean:
/// `scheduled` — written and waiting (ready now, or a reminder due later);
/// `delivered` — handed to the phone's SMS app to send ("Sent"). The trail
/// used to stamp "Delivered" on every event the moment it happened, for
/// messages nothing had ever sent. (The stored names are kept because the
/// database's check constraint lists them.)
enum SmsState { delivered, scheduled, failed, skipped }

extension SmsStateX on SmsState {
  String get label => switch (this) {
    SmsState.delivered => 'Sent'.tr,
    SmsState.scheduled => 'Ready to send'.tr,
    SmsState.failed => 'Failed'.tr,
    SmsState.skipped => 'Not sent'.tr,
  };

  static SmsState parse(String? v) => SmsState.values.firstWhere(
    (e) => e.name == v,
    orElse: () => SmsState.scheduled,
  );
}

enum FuelType { petrol, diesel, cng, hybrid, electric }

extension FuelTypeX on FuelType {
  String get label => switch (this) {
    FuelType.petrol => 'Petrol'.tr,
    FuelType.diesel => 'Diesel'.tr,
    FuelType.cng => 'CNG',
    FuelType.hybrid => 'Hybrid'.tr,
    FuelType.electric => 'Electric'.tr,
  };

  static FuelType parse(String? v) => FuelType.values.firstWhere(
    (e) => e.name == v,
    orElse: () => FuelType.petrol,
  );

  /// Null for a value this console does not know, where [parse] would say
  /// petrol. A booking that says nothing about fuel must not overwrite what
  /// the counter already has on record with a guess.
  static FuelType? tryParse(String? v) {
    for (final e in FuelType.values) {
      if (e.name == v) return e;
    }
    return null;
  }
}

/// The gearbox. Same names as the customer app's, because that is where a
/// booked car's gearbox comes from.
enum Transmission { manual, automatic, amt, cvt, dct }

extension TransmissionX on Transmission {
  String get label => switch (this) {
    Transmission.manual => 'Manual'.tr,
    Transmission.automatic => 'Automatic'.tr,
    Transmission.amt => 'AMT',
    Transmission.cvt => 'CVT',
    Transmission.dct => 'DCT',
  };

  /// Null when nothing was recorded — most vehicles opened before the
  /// console asked, and every two-wheeler.
  static Transmission? tryParse(String? v) {
    for (final e in Transmission.values) {
      if (e.name == v) return e;
    }
    return null;
  }
}

/// Severity of a mark plotted on the body diagram.
enum DentSeverity { scratch, dent, crack, rust }

extension DentSeverityX on DentSeverity {
  String get label => switch (this) {
    DentSeverity.scratch => 'Scratch'.tr,
    DentSeverity.dent => 'Dent'.tr,
    DentSeverity.crack => 'Break'.tr,
    DentSeverity.rust => 'Rust'.tr,
  };

  static DentSeverity parse(String? v) => DentSeverity.values.firstWhere(
    (e) => e.name == v,
    orElse: () => DentSeverity.scratch,
  );
}

/// What the vehicle physically is — a bike, an auto, a car or a truck.
///
/// Separate from [FuelType] and from the make: the counter picks this on the
/// job card, and it decides which silhouette is drawn, which damage sheet the
/// dent marks go on, and which icon the vehicle carries through the app. A
/// workshop that does bikes and cars needs the two to be told apart on sight.
enum VehicleShape { twoWheeler, threeWheeler, fourWheeler, sixWheeler }

extension VehicleShapeX on VehicleShape {
  /// The short form used on chips, where the row has to fit four of them.
  String get short => switch (this) {
    VehicleShape.twoWheeler => '2W',
    VehicleShape.threeWheeler => '3W',
    VehicleShape.fourWheeler => '4W',
    VehicleShape.sixWheeler => '6W',
  };

  String get label => switch (this) {
    VehicleShape.twoWheeler => '2 Wheeler'.tr,
    VehicleShape.threeWheeler => '3 Wheeler'.tr,
    VehicleShape.fourWheeler => '4 Wheeler'.tr,
    VehicleShape.sixWheeler => '6 Wheeler'.tr,
  };

  IconData get icon => switch (this) {
    VehicleShape.twoWheeler => Icons.two_wheeler_rounded,
    VehicleShape.threeWheeler => Icons.electric_rickshaw_rounded,
    VehicleShape.fourWheeler => Icons.directions_car_rounded,
    VehicleShape.sixWheeler => Icons.local_shipping_rounded,
  };

  static VehicleShape parse(String? v) => VehicleShape.values.firstWhere(
    (e) => e.name == v,
    orElse: () => VehicleShape.fourWheeler,
  );

  /// Matches the labels the setup screen stores against a workshop, so the
  /// two never have to be kept in step by hand.
  static VehicleShape? fromLabel(String label) {
    for (final s in VehicleShape.values) {
      if (s.label == label) return s;
    }
    return null;
  }
}
