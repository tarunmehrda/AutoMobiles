import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/directory.dart';
import 'auth_service.dart';

final directoryGatewayProvider =
    Provider<DirectoryGateway>((ref) => DirectoryGateway.instance);

/// The result of a directory search: rows, or one sentence saying why not.
///
/// Searching is the one screen in this app with nothing on device to fall
/// back to — the register lives on the server by definition — so unlike the
/// rest of the gateway it cannot quietly degrade. It has to say so.
@immutable
class DirectoryResult {
  const DirectoryResult(this.rows, {this.error});

  const DirectoryResult.failed(String this.error) : rows = const [];

  final List<NearbyGarage> rows;
  final String? error;

  bool get ok => error == null;
}

/// Reads the customer-facing garage register.
///
/// Every call here is a `SECURITY DEFINER` function rather than a table
/// query, because the `garages` table does not let a customer read a
/// workshop they have never dealt with — and it should not start. The
/// functions return a fixed public subset instead. See
/// `supabase/08_platform.sql`.
class DirectoryGateway {
  DirectoryGateway._();

  static final DirectoryGateway instance = DirectoryGateway._();

  /// [AuthService] owns the client and its lifecycle, exactly as it does for
  /// [SupabaseGateway]; this one only ever reads through it.
  SupabaseClient? get _client =>
      AuthService.instance.enabled ? Supabase.instance.client : null;

  /// Garages near a point, nearest first.
  ///
  /// [lat]/[lng] null is the PIN-code path: the customer would not share a
  /// location, so [q] carries what they typed and every row comes back with
  /// a null distance. [radiusKm] null is "no limit", which is the state
  /// before they tap one of the 1 / 5 / 10 chips.
  Future<DirectoryResult> nearby({
    double? lat,
    double? lng,
    double? radiusKm,
    String query = '',
    int limit = 60,
  }) async {
    final client = _client;
    if (client == null) {
      return const DirectoryResult.failed(
          'No connection to the backend. Check the network and try again.');
    }
    try {
      final res = await client.rpc('nearby_garages', params: {
        'in_lat': lat,
        'in_lng': lng,
        'radius_km': radiusKm,
        'q': query.trim().isEmpty ? null : query.trim(),
        'max_rows': limit,
      });
      final rows = (res as List?) ?? const [];
      return DirectoryResult(rows
          .whereType<Map<String, dynamic>>()
          .map(NearbyGarage.fromJson)
          .toList(growable: false));
    } on PostgrestException catch (e) {
      debugPrint('nearby_garages failed (${e.code}): ${e.message}');
      // PostgREST has no function by that name it is allowed to call, which
      // means the database has not had `supabase/08_platform.sql` run on it.
      // No amount of retrying or retyping fixes that, so it must not read as
      // "no garages near you".
      if (e.code == 'PGRST202') {
        return const DirectoryResult.failed(
            'Garage search is not switched on for this project yet.');
      }
      return const DirectoryResult.failed(
          'Could not search right now. Try again in a moment.');
    } catch (e) {
      debugPrint('nearby_garages failed: $e');
      return DirectoryResult.failed(_offline(e)
          ? 'No connection to the backend. Check the network and try again.'
          : 'Could not search right now. Try again in a moment.');
    }
  }

  /// One garage's public page, with whatever it has published.
  Future<GarageCard?> card(String garageId) async {
    final client = _client;
    if (client == null) return null;
    try {
      final res = await client.rpc('garage_card', params: {'gid': garageId});
      if (res == null) return null;
      return GarageCard.fromJson(Map<String, dynamic>.from(res as Map));
    } catch (e) {
      debugPrint('garage_card failed: $e');
      return null;
    }
  }

  static bool _offline(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('socketexception') ||
        s.contains('clientexception') ||
        s.contains('failed host lookup');
  }
}
