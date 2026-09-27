import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';

final partnerGatewayProvider =
    Provider<PartnerGateway>((ref) => PartnerGateway.instance);

/// What the customer app knows about a garage this account runs.
@immutable
class PartnerGarage {
  const PartnerGarage({
    required this.id,
    required this.name,
    this.phone = '',
    this.addressLine = '',
    this.city = '',
    this.state = '',
    this.pin = '',
    this.gstin = '',
    this.lat,
    this.lng,
    this.listed = false,
    this.verified = false,
  });

  final String id;
  final String name;
  final String phone;

  /// Carried so the edit form can show them back. `create_garage` writes
  /// every key it is sent, so a field the app never read would go back up
  /// blank on the next save and erase what the workshop had typed.
  final String addressLine;
  final String city;
  final String state;
  final String pin;
  final String gstin;
  final double? lat;
  final double? lng;

  /// In the customer-facing directory. Set by the platform, never by the
  /// partner — a workshop cannot list itself.
  final bool listed;
  final bool verified;

  // Commission is deliberately not read here. It is the platform's decision
  // alone, and nothing in the partner's view of their own workshop shows it.

  bool get located => lat != null && lng != null;

  /// Reads the garage row that `my_garage()` returns whole.
  factory PartnerGarage.fromJson(Map<String, dynamic> j) => PartnerGarage(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? '') as String,
        phone: (j['phone'] ?? '') as String,
        addressLine: (j['address_line'] ?? '') as String,
        city: (j['city'] ?? '') as String,
        state: (j['state'] ?? '') as String,
        pin: (j['pin'] ?? '') as String,
        gstin: (j['gstin'] ?? '') as String,
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        listed: (j['listed'] ?? false) as bool,
        verified: (j['verified'] ?? false) as bool,
      );
}

/// Registering a workshop, and keeping its pin on the map current.
///
/// A partner is not a different kind of account — it is a customer who also
/// owns a garage. Nothing here signs anybody out, and the customer side of
/// the app carries on working exactly as before for the same person.
class PartnerGateway {
  PartnerGateway._();

  static final PartnerGateway instance = PartnerGateway._();

  SupabaseClient? get _client =>
      AuthService.instance.enabled ? Supabase.instance.client : null;

  /// The garage this account already runs, if any.
  Future<PartnerGarage?> mine() async {
    final client = _client;
    if (client == null) return null;
    try {
      final res = await client.rpc('my_garage');
      if (res == null) return null;
      return PartnerGarage.fromJson(Map<String, dynamic>.from(res as Map));
    } catch (e) {
      debugPrint('my_garage failed: $e');
      return null;
    }
  }

  /// Registers the workshop, or updates it if this account already has one.
  ///
  /// `create_garage` is idempotent per owner by design: calling it twice
  /// updates the first garage rather than stranding the console on a second,
  /// empty one. Returns an error sentence, or null on success.
  Future<String?> register({
    required String name,
    required String phone,
    String addressLine = '',
    String city = '',
    String state = '',
    String pin = '',
    String gstin = '',
    double? lat,
    double? lng,
  }) async {
    final client = _client;
    if (client == null) {
      return 'No connection to the backend. Check the network and try again.';
    }
    if (AuthService.instance.userId == null) {
      return 'Sign in first, then register your workshop.';
    }
    try {
      final res = await client.rpc('create_garage', params: {
        'payload': {
          'name': name.trim(),
          'phone': phone.trim(),
          'address_line': addressLine.trim(),
          'city': city.trim(),
          'state': state.trim(),
          'pin': pin.trim(),
          'gstin': gstin.trim(),
        }
      });

      // The coordinate goes through its own call: `create_garage` predates
      // the directory and does not know about lat/lng, and widening it would
      // mean touching a function both apps already depend on.
      //
      // Its error is passed on rather than dropped. The pin is the part
      // that decides whether the workshop can show up in a distance search
      // at all, so "Workshop registered" over a pin that never saved would
      // be the one message on this screen that actively misleads.
      final id = res is Map ? (res['id'] ?? '').toString() : '';
      if (id.isNotEmpty && lat != null && lng != null) {
        return setLocation(garageId: id, lat: lat, lng: lng);
      }
      return null;
    } on PostgrestException catch (e) {
      debugPrint('create_garage failed (${e.code}): ${e.message}');
      if (e.code == 'PGRST202') {
        return 'Partner registration is not switched on for this project yet.';
      }
      return 'Could not register the workshop. ${e.message}';
    } catch (e) {
      debugPrint('create_garage failed: $e');
      return 'Could not register the workshop. Try again in a moment.';
    }
  }

  /// Moves the workshop's pin. Returns an error sentence, or null.
  Future<String?> setLocation({
    required String garageId,
    double? lat,
    double? lng,
    String? addressLine,
    String? city,
    String? state,
    String? pin,
  }) async {
    final client = _client;
    if (client == null) return 'No connection to the backend.';
    try {
      await client.rpc('set_garage_location', params: {
        // A field left out is a field left alone: `set_garage_location`
        // coalesces every absent key to the value already stored, so a
        // screen that only moves the pin does not have to resend the
        // address to avoid blanking it.
        'payload': {
          'garage_id': garageId,
          'lat': ?lat,
          'lng': ?lng,
          'address_line': ?addressLine,
          'city': ?city,
          'state': ?state,
          'pin': ?pin,
        }
      });
      return null;
    } catch (e) {
      debugPrint('set_garage_location failed: $e');
      return 'Could not save the location. Try again in a moment.';
    }
  }
}
