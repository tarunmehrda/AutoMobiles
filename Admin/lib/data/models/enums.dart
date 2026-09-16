import 'package:flutter/material.dart';

/// Where a job card sits in the workshop. The three dashboard counters and the
/// three list screens map one-to-one onto these.
enum JobStatus { open, complete, closed }

extension JobStatusX on JobStatus {
  String get label => switch (this) {
        JobStatus.open => 'Open',
        JobStatus.complete => 'Complete',
        JobStatus.closed => 'Closed',
      };

  /// Title used by the list screens.
  String get listTitle => switch (this) {
        JobStatus.open => 'Open Job Cards',
        JobStatus.complete => 'Complete Job Cards',
        JobStatus.closed => 'Close Job Cards',
      };

  String get blurb => switch (this) {
        JobStatus.open => 'Work in progress on the floor',
        JobStatus.complete => 'Work done, awaiting settlement',
        JobStatus.closed => 'Settled and handed over',
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
        LineKind.job => 'Jobs',
        LineKind.spare => 'Spare',
        LineKind.lube => 'Lube',
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

/// Per-line progress the mechanic ticks off on the mechanic copy.
enum WorkState { pending, running, done, skipped }

extension WorkStateX on WorkState {
  String get label => switch (this) {
        WorkState.pending => 'Pending',
        WorkState.running => 'Running',
        WorkState.done => 'Done',
        WorkState.skipped => 'Skipped',
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
        DocKind.estimate => 'Estimate',
        DocKind.invoice => 'Invoice',
        DocKind.mechanicCopy => 'Mechanic Copy',
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
        PayMode.cash => 'Cash',
        PayMode.upi => 'UPI',
        PayMode.card => 'Card',
        PayMode.netbanking => 'Net banking',
        PayMode.cheque => 'Cheque',
      };

  IconData get icon => switch (this) {
        PayMode.cash => Icons.payments_rounded,
        PayMode.upi => Icons.qr_code_2_rounded,
        PayMode.card => Icons.credit_card_rounded,
        PayMode.netbanking => Icons.account_balance_rounded,
        PayMode.cheque => Icons.receipt_long_rounded,
      };

  static PayMode parse(String? v) => PayMode.values.firstWhere(
        (e) => e.name == v,
        orElse: () => PayMode.cash,
      );
}

/// Delivery state of one message in the job card's SMS trail.
enum SmsState { delivered, scheduled, failed, skipped }

extension SmsStateX on SmsState {
  String get label => switch (this) {
        SmsState.delivered => 'Delivered',
        SmsState.scheduled => 'Scheduled',
        SmsState.failed => 'Failed',
        SmsState.skipped => 'Not sent',
      };

  static SmsState parse(String? v) => SmsState.values.firstWhere(
        (e) => e.name == v,
        orElse: () => SmsState.scheduled,
      );
}

enum FuelType { petrol, diesel, cng, hybrid, electric }

extension FuelTypeX on FuelType {
  String get label => switch (this) {
        FuelType.petrol => 'Petrol',
        FuelType.diesel => 'Diesel',
        FuelType.cng => 'CNG',
        FuelType.hybrid => 'Hybrid',
        FuelType.electric => 'Electric',
      };

  static FuelType parse(String? v) => FuelType.values.firstWhere(
        (e) => e.name == v,
        orElse: () => FuelType.petrol,
      );
}

/// Severity of a mark plotted on the body diagram.
enum DentSeverity { scratch, dent, crack, rust }

extension DentSeverityX on DentSeverity {
  String get label => switch (this) {
        DentSeverity.scratch => 'Scratch',
        DentSeverity.dent => 'Dent',
        DentSeverity.crack => 'Crack',
        DentSeverity.rust => 'Rust',
      };

  static DentSeverity parse(String? v) => DentSeverity.values.firstWhere(
        (e) => e.name == v,
        orElse: () => DentSeverity.scratch,
      );
}
