import 'package:flutter/foundation.dart';

/// How far along a "I need this part" request is.
enum RequestStatus { pending, processing, completed, cancelled }

extension RequestStatusX on RequestStatus {
  String get label => switch (this) {
        RequestStatus.pending => 'Pending',
        RequestStatus.processing => 'Looking for it',
        RequestStatus.completed => 'Found',
        RequestStatus.cancelled => 'Cancelled',
      };

  /// What the customer should understand by it, in one line.
  String get blurb => switch (this) {
        RequestStatus.pending =>
          'We have your request and will come back with a price.',
        RequestStatus.processing => 'We are sourcing this part now.',
        RequestStatus.completed => 'Sourced. Check the quote below.',
        RequestStatus.cancelled => 'This request was closed.',
      };

  static RequestStatus parse(String? s) => switch (s) {
        'processing' => RequestStatus.processing,
        'completed' => RequestStatus.completed,
        'cancelled' => RequestStatus.cancelled,
        _ => RequestStatus.pending,
      };
}

/// Where a listing is in the approval queue.
enum ListingStatus { pending, approved, rejected, sold, withdrawn }

extension ListingStatusX on ListingStatus {
  String get label => switch (this) {
        ListingStatus.pending => 'In review',
        ListingStatus.approved => 'Live',
        ListingStatus.rejected => 'Not approved',
        ListingStatus.sold => 'Sold',
        ListingStatus.withdrawn => 'Withdrawn',
      };

  static ListingStatus parse(String? s) => switch (s) {
        'approved' => ListingStatus.approved,
        'rejected' => ListingStatus.rejected,
        'sold' => ListingStatus.sold,
        'withdrawn' => ListingStatus.withdrawn,
        _ => ListingStatus.pending,
      };
}

enum PartCondition { newPart, used, refurbished }

extension PartConditionX on PartCondition {
  /// The value the database column takes. `new` is a Dart keyword, which is
  /// why the enum name and the wire name differ for exactly one of these.
  String get wire => switch (this) {
        PartCondition.newPart => 'new',
        PartCondition.used => 'used',
        PartCondition.refurbished => 'refurbished',
      };

  String get label => switch (this) {
        PartCondition.newPart => 'New',
        PartCondition.used => 'Used',
        PartCondition.refurbished => 'Refurbished',
      };

  static PartCondition parse(String? s) => switch (s) {
        'new' => PartCondition.newPart,
        'refurbished' => PartCondition.refurbished,
        _ => PartCondition.used,
      };
}

/// A part somebody is looking for.
@immutable
class PartRequest {
  const PartRequest({
    required this.id,
    required this.code,
    this.vehicleId,
    this.vehicleText = '',
    this.partName = '',
    this.detail = '',
    this.photos = const [],
    this.status = RequestStatus.pending,
    this.quote,
    this.note = '',
    required this.createdAt,
  });

  final String id;

  /// The short code the platform quotes back — "R7K2M9". What the customer
  /// reads out on the phone, and the only handle either side needs.
  final String code;

  final String? vehicleId;
  final String vehicleText;
  final String partName;
  final String detail;
  final List<String> photos;
  final RequestStatus status;

  /// What the platform came back with, once it has. Null until then, which
  /// is not the same as zero.
  final double? quote;
  final String note;
  final DateTime createdAt;

  factory PartRequest.fromJson(Map<String, dynamic> j) => PartRequest(
        id: (j['id'] ?? '') as String,
        code: (j['code'] ?? '') as String,
        vehicleId: j['vehicle_id'] as String?,
        vehicleText: (j['vehicle_text'] ?? '') as String,
        partName: (j['part_name'] ?? '') as String,
        detail: (j['detail'] ?? '') as String,
        photos: _strings(j['photos']),
        status: RequestStatusX.parse(j['status'] as String?),
        quote: (j['quote'] as num?)?.toDouble(),
        note: (j['note'] ?? '') as String,
        createdAt: DateTime.tryParse((j['created_at'] ?? '') as String) ??
            DateTime.now(),
      );
}

/// A part somebody is selling.
@immutable
class PartListing {
  const PartListing({
    required this.id,
    this.vehicleId,
    this.vehicleText = '',
    this.title = '',
    this.detail = '',
    this.partNo = '',
    this.condition = PartCondition.used,
    this.price = 0,
    this.photos = const [],
    this.city = '',
    this.pin = '',
    this.status = ListingStatus.pending,
    this.rejectNote = '',
    this.garageId,
    required this.createdAt,
  });

  final String id;

  /// The workshop selling it, when it is a workshop's listing rather than a
  /// private seller's. `browse_listings()` only carries it once the
  /// database is up to date, so it is optional: a question about a listing
  /// without it goes to the platform instead of to the shop.
  final String? garageId;

  final String? vehicleId;
  final String vehicleText;
  final String title;
  final String detail;
  final String partNo;
  final PartCondition condition;
  final double price;
  final List<String> photos;
  final String city;
  final String pin;
  final ListingStatus status;

  /// Why the platform turned it down. Shown to the seller, nobody else.
  final String rejectNote;
  final DateTime createdAt;

  factory PartListing.fromJson(Map<String, dynamic> j) => PartListing(
        id: (j['id'] ?? '') as String,
        vehicleId: j['vehicle_id'] as String?,
        vehicleText: (j['vehicle_text'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        detail: (j['detail'] ?? '') as String,
        partNo: (j['part_no'] ?? '') as String,
        condition: PartConditionX.parse(j['condition'] as String?),
        price: (j['price'] as num?)?.toDouble() ?? 0,
        photos: _strings(j['photos']),
        city: (j['city'] ?? '') as String,
        pin: (j['pin'] ?? '') as String,
        status: ListingStatusX.parse(j['status'] as String?),
        rejectNote: (j['reject_note'] ?? '') as String,
        garageId: switch (j['garage_id']) {
          final String g when g.isNotEmpty => g,
          _ => null,
        },
        createdAt: DateTime.tryParse((j['created_at'] ?? '') as String) ??
            DateTime.now(),
      );
}

List<String> _strings(Object? v) => switch (v) {
      final List l => l.map((e) => e.toString()).toList(growable: false),
      _ => const [],
    };
