import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../models/entities.dart';
import '../models/workshop.dart';
import 'app_data.dart';
import 'auth_service.dart';

final supabaseGatewayProvider =
    Provider<SupabaseGateway>((ref) => SupabaseGateway.instance);

/// Thin, failure-tolerant bridge to Supabase.
///
/// Every method is a no-op until [AppConfig.supabaseUrl] and
/// [AppConfig.supabaseAnonKey] are filled in, and every call is wrapped so a
/// network or schema problem degrades to the on-device store instead of
/// breaking a user flow. Table definitions live in `supabase/schema.sql`.
class SupabaseGateway {
  SupabaseGateway._();

  static final SupabaseGateway instance = SupabaseGateway._();

  static const String remoteOtpSent = '__remote__';

  Timer? _debounce;
  Timer? _pingDebounce;
  RealtimeChannel? _workshop;

  /// table/id -> fingerprint of the row as this device last wrote or read
  /// it. What makes a push send three rows instead of three hundred.
  final Map<String, String> _written = {};

  /// [AuthService] owns the client and its lifecycle; this gateway only ever
  /// reads and writes rows through it.
  bool get enabled => AuthService.instance.enabled;

  SupabaseClient? get _client =>
      enabled ? Supabase.instance.client : null;

  String? get userId => AuthService.instance.userId;

  // -------------------------------------------------------------------------
  // Sync
  // -------------------------------------------------------------------------

  /// Pulls the signed-in customer's rows and rebuilds an [AppData] from them.
  /// Returns null when Supabase is off or has nothing for this user.
  Future<AppData?> hydrate(AppData local) async {
    if (!enabled) return null;
    final uid = userId;
    if (uid == null) return null;

    try {
      final client = _client!;
      final profile = await client
          .from('profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();
      if (profile == null) return null;

      final vehicles = await client.from('vehicles').select().eq('user_id', uid);
      final addresses =
          await client.from('addresses').select().eq('user_id', uid);
      final bookings = await client
          .from('bookings')
          .select()
          .eq('user_id', uid)
          .order('slot', ascending: false);
      final inspections =
          await client.from('inspections').select().eq('user_id', uid);
      final estimates = await client
          .from('estimates')
          .select()
          .eq('user_id', uid)
          .order('version');
      final invoices = await client.from('invoices').select().eq('user_id', uid);
      final notifications = await client
          .from('notifications')
          .select()
          .eq('user_id', uid)
          .order('at', ascending: false);

      final estimateMap = <String, List<Estimate>>{};
      for (final row in (estimates as List)) {
        final e = Estimate.fromJson(Map<String, dynamic>.from(row as Map));
        (estimateMap[e.bookingId] ??= []).add(e);
      }

      final next = local.copyWith(
        user: AppUser.fromJson(Map<String, dynamic>.from(profile)),
        vehicles: [
          for (final r in (vehicles as List))
            Vehicle.fromJson(Map<String, dynamic>.from(r as Map))
        ],
        addresses: [
          for (final r in (addresses as List))
            Address.fromJson(Map<String, dynamic>.from(r as Map))
        ],
        bookings: [
          for (final r in (bookings as List))
            Booking.fromJson(Map<String, dynamic>.from(r as Map))
        ],
        inspections: {
          for (final r in (inspections as List))
            (r as Map)['booking_id'] as String:
                Inspection.fromJson(Map<String, dynamic>.from(r))
        },
        estimates: estimateMap,
        invoices: {
          for (final r in (invoices as List))
            (r as Map)['booking_id'] as String:
                Invoice.fromJson(Map<String, dynamic>.from(r))
        },
        notifications: [
          for (final r in (notifications as List))
            AppNotification.fromJson(Map<String, dynamic>.from(r as Map))
        ],
      );

      // Everything upstream is now known-good; none of it needs pushing back.
      _rememberAll(next);
      return next;
    } catch (e) {
      debugPrint('hydrate failed, staying local: $e');
      return null;
    }
  }

  /// Mirrors the local snapshot upstream. Debounced — the UI never waits on it.
  void push(AppData data) {
    if (!enabled) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 900), () {
      unawaited(_pushNow(data));
    });
  }

  Future<void> _pushNow(AppData data) async {
    final uid = userId;
    final client = _client;
    if (uid == null || client == null || data.user == null) return;

    try {
      final profile = {...data.user!.toJson(), 'id': uid};
      if (_changed('profiles', uid, profile)) {
        await client.from('profiles').upsert(profile);
        _remember('profiles', uid, profile);
      }

      await _sync(client, 'vehicles', uid, data.vehicles,
          id: (e) => e.id, json: (e) => e.toJson());
      await _sync(client, 'addresses', uid, data.addresses,
          id: (e) => e.id, json: (e) => e.toJson());
      await _sync(client, 'bookings', uid, data.bookings,
          id: (e) => e.id, json: (e) => e.toJson());
      await _sync(client, 'inspections', uid, data.inspections.values.toList(),
          id: (e) => e.id, json: (e) => e.toJson());
      await _sync(
          client, 'estimates', uid, data.estimates.values.expand((e) => e).toList(),
          id: (e) => e.id, json: (e) => e.toJson());
      await _sync(client, 'invoices', uid, data.invoices.values.toList(),
          id: (e) => e.id, json: (e) => e.toJson());
      await _sync(client, 'notifications', uid, data.notifications.take(50).toList(),
          id: (e) => e.id, json: (e) => e.toJson());
    } catch (e) {
      debugPrint('push failed (local state is still authoritative): $e');
    }
  }

  /// Upserts only the rows whose contents actually differ from what was last
  /// written or read.
  ///
  /// The whole snapshot used to go up on every change — every vehicle, every
  /// booking, every notification, each time a checkbox moved. On a phone
  /// connection that is the difference between a sync you never notice and
  /// one you watch happen.
  Future<void> _sync<T>(
    SupabaseClient client,
    String table,
    String uid,
    List<T> rows, {
    required String Function(T) id,
    required Map<String, dynamic> Function(T) json,
  }) async {
    final changed = <Map<String, dynamic>>[];
    for (final row in rows) {
      final body = json(row);
      if (!_changed(table, id(row), body)) continue;
      changed.add({...body, 'user_id': uid});
    }
    if (changed.isEmpty) return;
    await client.from(table).upsert(changed);
    for (final row in rows) {
      _remember(table, id(row), json(row));
    }
  }

  // --- what we last wrote ---------------------------------------------------

  String _key(String table, String id) => '$table/$id';

  bool _changed(String table, String id, Map<String, dynamic> body) =>
      _written[_key(table, id)] != _stamp(body);

  void _remember(String table, String id, Map<String, dynamic> body) {
    _written[_key(table, id)] = _stamp(body);
  }

  void _rememberAll(AppData data) {
    _written.clear();
    final u = data.user;
    if (u != null) _remember('profiles', u.id, {...u.toJson(), 'id': u.id});
    for (final e in data.vehicles) {
      _remember('vehicles', e.id, e.toJson());
    }
    for (final e in data.addresses) {
      _remember('addresses', e.id, e.toJson());
    }
    for (final e in data.bookings) {
      _remember('bookings', e.id, e.toJson());
    }
    for (final e in data.inspections.values) {
      _remember('inspections', e.id, e.toJson());
    }
    for (final list in data.estimates.values) {
      for (final e in list) {
        _remember('estimates', e.id, e.toJson());
      }
    }
    for (final e in data.invoices.values) {
      _remember('invoices', e.id, e.toJson());
    }
    for (final e in data.notifications) {
      _remember('notifications', e.id, e.toJson());
    }
  }

  /// A stable fingerprint of a row: keys sorted, timestamps trimmed to the
  /// second, so two spellings of the same row compare equal.
  static String _stamp(Map<String, dynamic> body) {
    final buf = StringBuffer();
    void write(Object? v) {
      if (v is Map) {
        final keys = v.keys.map((e) => e.toString()).toList()..sort();
        for (final k in keys) {
          if (k == 'user_id') continue;
          buf..write(k)..write(':');
          write(v[k]);
          buf.write(';');
        }
      } else if (v is List) {
        for (final e in v) {
          write(e);
          buf.write(',');
        }
      } else if (v is String && v.length >= 19 && v[10] == 'T') {
        final at = DateTime.tryParse(v);
        buf.write(at == null
            ? v
            : (at.toUtc().millisecondsSinceEpoch ~/ 1000).toString());
      } else if (v is num) {
        buf.write(v == v.roundToDouble() ? v.toInt().toString() : v.toString());
      } else {
        buf.write(v);
      }
    }

    write(body);
    return buf.toString();
  }

  // -------------------------------------------------------------------------
  // The workshop's side
  // -------------------------------------------------------------------------

  /// The garage's own job cards for this customer.
  ///
  /// Read from the `my_job_cards` view, which is filtered to `auth.uid()` in
  /// the database itself — there is no client-side filter to get wrong, and
  /// no way to ask for somebody else's car.
  Future<List<WorkshopCard>> workshopCards() async {
    final client = _client;
    if (client == null || userId == null) return const [];
    try {
      final rows = await client
          .from('my_job_cards')
          .select()
          .order('opened_at', ascending: false);
      return [
        for (final r in (rows as List))
          WorkshopCard.fromJson(Map<String, dynamic>.from(r as Map))
      ];
    } catch (e) {
      debugPrint('workshop cards unavailable: $e');
      return const [];
    }
  }

  /// Watches the garage's job cards for this customer and calls [onChange]
  /// whenever one moves.
  ///
  /// The subscription is filtered on `customer_profile_id` server-side, so
  /// the socket only ever carries this customer's rows. The view is re-read
  /// on each ping rather than patched from the payload, because the row that
  /// arrives is the bare job card without the garage, vehicle and line items
  /// joined onto it.
  void watchWorkshop(void Function() onChange) {
    final client = _client;
    final uid = userId;
    if (client == null || uid == null) return;
    if (_workshop != null) return;

    final channel = client.channel('my_job_cards:$uid');
    for (final table in const [
      'job_cards',
      'line_items',
      'payments',
      'garage_bookings',
    ]) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        // job_cards carries the owner as customer_profile_id and
        // garage_bookings as profile_id; the line items and payments are
        // reached through the card, and row level security already keeps
        // other people's rows off this socket.
        filter: switch (table) {
          'job_cards' => PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'customer_profile_id',
              value: uid,
            ),
          'garage_bookings' => PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'profile_id',
              value: uid,
            ),
          _ => null,
        },
        callback: (_) => _ping(onChange),
      );
    }
    channel.subscribe();
    _workshop = channel;
  }

  /// One `save_job_card` at the counter lands as several row events. Waiting
  /// a beat turns that burst into a single refresh.
  void _ping(void Function() onChange) {
    _pingDebounce?.cancel();
    _pingDebounce = Timer(const Duration(milliseconds: 300), onChange);
  }

  /// The garage this customer is linked to, as that garage filled it in.
  ///
  /// `garages` is readable here only for a workshop the account has actually
  /// dealt with — the policy is `deals_with_garage(id)`, not a directory —
  /// so this returns the one they were handed a code by, or nothing.
  Future<Workshop?> linkedWorkshop() async {
    final client = _client;
    if (client == null || userId == null) return null;
    try {
      final rows = await client.from('garages').select().limit(1);
      final list = rows as List;
      if (list.isEmpty) return null;
      return Workshop.fromJson(Map<String, dynamic>.from(list.first as Map));
    } catch (e) {
      debugPrint('linked workshop unavailable: $e');
      return null;
    }
  }

  /// This customer's own booking requests, as the workshop left them: an
  /// `accepted` flag and, once the counter has opened one, the id of the job
  /// card it became.
  ///
  /// Keyed by request id, which is `req-<bookingId>` — the same id the app
  /// sent up, so a row here maps straight back onto a booking.
  Future<Map<String, Map<String, dynamic>>> myBookingRequests() async {
    final client = _client;
    if (client == null || userId == null) return const {};
    try {
      final rows = await client
          .from('garage_bookings')
          .select('id, garage_id, accepted, job_card_id, at');
      return {
        for (final r in (rows as List))
          ((r as Map)['id'] ?? '').toString(): Map<String, dynamic>.from(r),
      };
    } catch (e) {
      debugPrint('booking requests unavailable: $e');
      return const {};
    }
  }

  /// The workshops this customer has been linked to, as
  /// `{garage_id, customer_id}` pairs.
  ///
  /// The list comes straight from `garage_customers`, which row level
  /// security filters to `profile_id = auth.uid()` — so it can only ever be
  /// the workshops that handed this person a code.
  Future<List<Map<String, String>>> linkedWorkshops() async {
    final client = _client;
    if (client == null || userId == null) return const [];
    try {
      final rows = await client.from('garage_customers').select('id, garage_id');
      return [
        for (final r in (rows as List))
          {
            'customer_id': ((r as Map)['id'] ?? '').toString(),
            'garage_id': (r['garage_id'] ?? '').toString(),
          }
      ];
    } catch (e) {
      debugPrint('linked workshops unavailable: $e');
      return const [];
    }
  }

  /// Puts a booking on the workshop's front desk, where it appears as an
  /// unaccepted request the counter can turn into a job card.
  ///
  /// It can only ever be a request: the insert policy refuses a row that
  /// arrives already accepted or already pointing at a job card, so the
  /// customer app cannot book itself into the workshop's floor.
  Future<void> requestWorkshopBooking({
    required String garageId,
    required String id,
    required String name,
    required String phone,
    required DateTime at,
    String regNo = '',
    String vehicle = '',
    String note = '',
  }) async {
    final client = _client;
    final uid = userId;
    if (client == null || uid == null) return;
    try {
      await client.from('garage_bookings').insert({
        'id': id,
        'garage_id': garageId,
        'profile_id': uid,
        'name': name,
        'phone': phone,
        'at': at.toUtc().toIso8601String(),
        'reg_no': regNo,
        'vehicle': vehicle,
        'note': note,
        'accepted': false,
      });
    } catch (e) {
      // The booking itself is already saved; the workshop copy is a courtesy
      // and must never fail the flow the customer just completed.
      debugPrint('workshop booking request failed: $e');
    }
  }

  /// Redeems the six-digit code the workshop hands over, which is what links
  /// this account to the garage's record of the customer.
  ///
  /// Returns null on success, or a sentence to show the person.
  Future<String?> redeemWorkshopCode(String code) async {
    final client = _client;
    if (client == null) {
      return 'No connection to the backend. Check the network and try again.';
    }
    try {
      final res = await client
          .rpc('redeem_customer_code', params: {'entered': code.trim()});
      final map = Map<String, dynamic>.from(res as Map);
      if (map['ok'] == true) return null;
      return (map['message'] ?? 'That code did not work.') as String;
    } catch (e) {
      debugPrint('redeem failed: $e');
      return 'That code did not work. Ask the workshop for a new one.';
    }
  }

  /// Drops the subscription on sign-out, so the next account does not
  /// inherit this one's socket.
  Future<void> reset() async {
    _debounce?.cancel();
    _pingDebounce?.cancel();
    _written.clear();
    final channel = _workshop;
    _workshop = null;
    if (channel != null) {
      try {
        await _client?.removeChannel(channel);
      } catch (_) {
        // A torn-down socket is already what we wanted.
      }
    }
  }
}
