import 'package:flutter/material.dart';

enum FuelType { petrol, diesel, cng, hybrid, electric }

extension FuelTypeX on FuelType {
  String get label => switch (this) {
        FuelType.petrol => 'Petrol',
        FuelType.diesel => 'Diesel',
        FuelType.cng => 'CNG',
        FuelType.hybrid => 'Hybrid',
        FuelType.electric => 'Electric',
      };

  IconData get icon => switch (this) {
        FuelType.petrol => Icons.local_gas_station_rounded,
        FuelType.diesel => Icons.local_gas_station_rounded,
        FuelType.cng => Icons.propane_tank_rounded,
        FuelType.hybrid => Icons.eco_rounded,
        FuelType.electric => Icons.bolt_rounded,
      };

  static FuelType parse(String? v) => FuelType.values.firstWhere(
        (e) => e.name == v,
        orElse: () => FuelType.petrol,
      );
}

enum Transmission { manual, automatic, amt, cvt, dct }

extension TransmissionX on Transmission {
  String get label => switch (this) {
        Transmission.manual => 'Manual',
        Transmission.automatic => 'Automatic',
        Transmission.amt => 'AMT',
        Transmission.cvt => 'CVT',
        Transmission.dct => 'DCT',
      };

  static Transmission parse(String? v) => Transmission.values.firstWhere(
        (e) => e.name == v,
        orElse: () => Transmission.manual,
      );
}

enum BodyType { hatchback, sedan, suv, muv, luxury, ev }

extension BodyTypeX on BodyType {
  String get label => switch (this) {
        BodyType.hatchback => 'Hatchback',
        BodyType.sedan => 'Sedan',
        BodyType.suv => 'SUV',
        BodyType.muv => 'MUV',
        BodyType.luxury => 'Luxury',
        BodyType.ev => 'EV',
      };

  static BodyType parse(String? v) => BodyType.values.firstWhere(
        (e) => e.name == v,
        orElse: () => BodyType.hatchback,
      );
}

/// Where the vehicle is handed over.
enum ServiceMode { garage, pickup }

extension ServiceModeX on ServiceMode {
  String get label =>
      this == ServiceMode.garage ? 'Garage visit' : 'Pickup & drop';
  String get blurb => this == ServiceMode.garage
      ? 'Drive in at your slot time'
      : 'We collect and return your car';
  IconData get icon => this == ServiceMode.garage
      ? Icons.store_mall_directory_rounded
      : Icons.local_shipping_rounded;

  static ServiceMode parse(String? v) =>
      v == 'pickup' ? ServiceMode.pickup : ServiceMode.garage;
}

/// The full job lifecycle. Order matters — the tracker renders it in sequence.
enum JobStage {
  confirmed,
  pickupAssigned,
  received,
  inspectionStarted,
  inspectionComplete,
  estimateSent,
  awaitingApproval,
  repairInProgress,
  qualityCheck,
  readyForDelivery,
  delivered,
}

extension JobStageX on JobStage {
  String get label => switch (this) {
        JobStage.confirmed => 'Booking confirmed',
        JobStage.pickupAssigned => 'Pickup assigned',
        JobStage.received => 'Vehicle received',
        JobStage.inspectionStarted => 'Inspection started',
        JobStage.inspectionComplete => 'Inspection complete',
        JobStage.estimateSent => 'Estimate sent',
        JobStage.awaitingApproval => 'Awaiting your approval',
        JobStage.repairInProgress => 'Repair in progress',
        JobStage.qualityCheck => 'Quality check',
        JobStage.readyForDelivery => 'Ready for delivery',
        JobStage.delivered => 'Delivered',
      };

  String get blurb => switch (this) {
        JobStage.confirmed => 'Your slot is locked in',
        JobStage.pickupAssigned => 'A driver is on the way',
        JobStage.received => 'Job card opened at the garage',
        JobStage.inspectionStarted => '38-point digital inspection underway',
        JobStage.inspectionComplete => 'Findings are ready to review',
        JobStage.estimateSent => 'Costs shared for your approval',
        JobStage.awaitingApproval => 'Work starts once you approve',
        JobStage.repairInProgress => 'Technicians are on the job',
        JobStage.qualityCheck => 'Final road test and checks',
        JobStage.readyForDelivery => 'Washed, checked and ready',
        JobStage.delivered => 'Handed back to you',
      };

  IconData get icon => switch (this) {
        JobStage.confirmed => Icons.event_available_rounded,
        JobStage.pickupAssigned => Icons.person_pin_circle_rounded,
        JobStage.received => Icons.garage_rounded,
        JobStage.inspectionStarted => Icons.search_rounded,
        JobStage.inspectionComplete => Icons.fact_check_rounded,
        JobStage.estimateSent => Icons.receipt_long_rounded,
        JobStage.awaitingApproval => Icons.how_to_reg_rounded,
        JobStage.repairInProgress => Icons.build_rounded,
        JobStage.qualityCheck => Icons.verified_rounded,
        JobStage.readyForDelivery => Icons.local_car_wash_rounded,
        JobStage.delivered => Icons.flag_rounded,
      };

  static JobStage parse(String? v) => JobStage.values.firstWhere(
        (e) => e.name == v,
        orElse: () => JobStage.confirmed,
      );
}

enum BookingStatus { upcoming, active, completed, cancelled }

extension BookingStatusX on BookingStatus {
  String get label => switch (this) {
        BookingStatus.upcoming => 'Upcoming',
        BookingStatus.active => 'In service',
        BookingStatus.completed => 'Completed',
        BookingStatus.cancelled => 'Cancelled',
      };

  static BookingStatus parse(String? v) => BookingStatus.values.firstWhere(
        (e) => e.name == v,
        orElse: () => BookingStatus.upcoming,
      );
}

/// Inspection verdict per checked item.
enum Condition { good, monitor, replace }

extension ConditionX on Condition {
  String get label => switch (this) {
        Condition.good => 'Good',
        Condition.monitor => 'Monitor',
        Condition.replace => 'Replace',
      };

  String get advice => switch (this) {
        Condition.good => 'No action needed',
        Condition.monitor => 'Keep an eye on this',
        Condition.replace => 'Recommended now',
      };

  double get score => switch (this) {
        Condition.good => 1.0,
        Condition.monitor => 0.55,
        Condition.replace => 0.15,
      };

  static Condition parse(String? v) => Condition.values.firstWhere(
        (e) => e.name == v,
        orElse: () => Condition.good,
      );
}

enum EstimateStatus { pending, approved, partiallyApproved, rejected }

extension EstimateStatusX on EstimateStatus {
  String get label => switch (this) {
        EstimateStatus.pending => 'Awaiting approval',
        EstimateStatus.approved => 'Approved',
        EstimateStatus.partiallyApproved => 'Partially approved',
        EstimateStatus.rejected => 'Declined',
      };

  static EstimateStatus parse(String? v) => EstimateStatus.values.firstWhere(
        (e) => e.name == v,
        orElse: () => EstimateStatus.pending,
      );
}

enum PaymentMethod { upi, card, netbanking, cash, payAtGarage }

extension PaymentMethodX on PaymentMethod {
  String get label => switch (this) {
        PaymentMethod.upi => 'UPI',
        PaymentMethod.card => 'Credit / Debit card',
        PaymentMethod.netbanking => 'Net banking',
        PaymentMethod.cash => 'Cash',
        PaymentMethod.payAtGarage => 'Pay at garage',
      };

  String get blurb => switch (this) {
        PaymentMethod.upi => 'GPay, PhonePe, Paytm, any UPI app',
        PaymentMethod.card => 'Visa, Mastercard, RuPay, Amex',
        PaymentMethod.netbanking => 'All major banks',
        PaymentMethod.cash => 'Settle in cash on delivery',
        PaymentMethod.payAtGarage => 'Card or cash at the counter',
      };

  IconData get icon => switch (this) {
        PaymentMethod.upi => Icons.qr_code_2_rounded,
        PaymentMethod.card => Icons.credit_card_rounded,
        PaymentMethod.netbanking => Icons.account_balance_rounded,
        PaymentMethod.cash => Icons.payments_rounded,
        PaymentMethod.payAtGarage => Icons.storefront_rounded,
      };

  bool get isOnline =>
      this == PaymentMethod.upi ||
      this == PaymentMethod.card ||
      this == PaymentMethod.netbanking;

  static PaymentMethod parse(String? v) => PaymentMethod.values.firstWhere(
        (e) => e.name == v,
        orElse: () => PaymentMethod.upi,
      );
}

enum NotifyKind { booking, service, approval, payment, maintenance, offer }

extension NotifyKindX on NotifyKind {
  String get label => switch (this) {
        NotifyKind.booking => 'Booking',
        NotifyKind.service => 'Service',
        NotifyKind.approval => 'Approval',
        NotifyKind.payment => 'Payment',
        NotifyKind.maintenance => 'Maintenance',
        NotifyKind.offer => 'Offers',
      };

  IconData get icon => switch (this) {
        NotifyKind.booking => Icons.event_note_rounded,
        NotifyKind.service => Icons.build_circle_rounded,
        NotifyKind.approval => Icons.how_to_reg_rounded,
        NotifyKind.payment => Icons.receipt_rounded,
        NotifyKind.maintenance => Icons.timer_rounded,
        NotifyKind.offer => Icons.local_offer_rounded,
      };

  static NotifyKind parse(String? v) => NotifyKind.values.firstWhere(
        (e) => e.name == v,
        orElse: () => NotifyKind.service,
      );
}

/// Damage the workshop recorded on the body diagram when the car was handed
/// over. Mirrors what the garage console plots on its job card, so the same
/// mark reads the same on both sides.
enum MarkKind { scratch, dent, crack, rust }

extension MarkKindX on MarkKind {
  String get label => switch (this) {
        MarkKind.scratch => 'Scratch',
        MarkKind.dent => 'Dent',
        MarkKind.crack => 'Crack',
        MarkKind.rust => 'Rust',
      };

  IconData get icon => switch (this) {
        MarkKind.scratch => Icons.horizontal_rule_rounded,
        MarkKind.dent => Icons.radio_button_unchecked_rounded,
        MarkKind.crack => Icons.polyline_rounded,
        MarkKind.rust => Icons.grain_rounded,
      };

  static MarkKind parse(String? v) => MarkKind.values.firstWhere(
        (e) => e.name == v,
        orElse: () => MarkKind.scratch,
      );
}
