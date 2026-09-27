import 'package:flutter/foundation.dart';

import 'workshop.dart';

/// One row of the garage directory — a workshop the customer has not
/// necessarily dealt with yet.
///
/// Deliberately smaller than [Workshop]. The directory is served by
/// `nearby_garages()`, which returns a fixed public subset of the garages
/// table: no UPI id, no GSTIN, no plan expiry. What the customer gets after
/// they book is the fuller [Workshop]; this is the shop window.
@immutable
class NearbyGarage {
  const NearbyGarage({
    required this.id,
    required this.name,
    this.phone = '',
    this.addressLine = '',
    this.city = '',
    this.state = '',
    this.pin = '',
    this.lat,
    this.lng,
    this.logoPath,
    this.verified = false,
    this.km,
  });

  final String id;
  final String name;
  final String phone;
  final String addressLine;
  final String city;
  final String state;
  final String pin;
  final double? lat;
  final double? lng;
  final String? logoPath;

  /// The platform has checked this workshop is real. Shown as a tick.
  final bool verified;

  /// Distance from where the customer is, in kilometres. Null when they
  /// searched by PIN or name instead of sharing a location — the row is still
  /// perfectly usable, it just cannot say how far.
  final double? km;

  /// "Balaji-333503" — how the app names a workshop on screen.
  String get label => workshopLabel(name, pin);

  /// "Sector 15, Jaipur - 302001" — the one line under the name.
  ///
  /// The PIN is always on it. It used to appear only when the address and
  /// city were both blank, so almost no workshop ever showed one.
  String get where {
    final place = [
      addressLine,
      city,
    ].map((s) => s.trim()).where((s) => s.isNotEmpty).join(', ');
    final code = pin.trim();
    if (code.isEmpty) return place;
    return place.isEmpty ? 'PIN $code' : '$place - $code';
  }

  /// "1.2 km" below a kilometre and a half, "4 km" above it. Nobody reading a
  /// list of workshops needs a second decimal place, and "0.85 km" reads as
  /// precision the GPS does not have.
  String get distanceLabel {
    final d = km;
    if (d == null) return '';
    if (d < 1) return '${(d * 1000).round()} m';
    if (d < 10) return '${d.toStringAsFixed(1)} km';
    return '${d.round()} km';
  }

  /// Two letters for the avatar when the workshop has no logo.
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts[1].substring(0, 1))
        .toUpperCase();
  }

  factory NearbyGarage.fromJson(Map<String, dynamic> j) => NearbyGarage(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? '') as String,
        phone: (j['phone'] ?? '') as String,
        addressLine: (j['address_line'] ?? '') as String,
        city: (j['city'] ?? '') as String,
        state: (j['state'] ?? '') as String,
        pin: (j['pin'] ?? '') as String,
        lat: _num(j['lat']),
        lng: _num(j['lng']),
        logoPath: j['logo_path'] as String?,
        verified: (j['verified'] ?? false) as bool,
        km: _num(j['km']),
      );
}

/// The full public page of one directory garage, with what it has published.
/// Served by `garage_card()`, which a customer may call before they have any
/// dealings with the workshop at all.
@immutable
class GarageCard {
  const GarageCard({required this.garage, this.services = const []});

  final NearbyGarage garage;
  final List<WorkshopService> services;

  factory GarageCard.fromJson(Map<String, dynamic> j) => GarageCard(
        garage: NearbyGarage.fromJson(j),
        services: ((j['services'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(WorkshopService.fromJson)
            .toList(growable: false),
      );
}

double? _num(Object? v) => switch (v) {
      null => null,
      final num n => n.toDouble(),
      final String s => double.tryParse(s),
      _ => null,
    };
