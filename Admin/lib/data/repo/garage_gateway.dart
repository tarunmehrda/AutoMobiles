import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/entities.dart';
import 'admin_data.dart';
import 'auth_service.dart';

final garageGatewayProvider =
    Provider<GarageGateway>((ref) => GarageGateway.instance);

/// The workshop's half of the wire.
///
/// The console stays offline-first: every edit lands in the on-device
/// snapshot and paints immediately, and this pushes what actually changed a
/// moment later. Nothing here ever blocks a frame, and a failed call leaves
/// local state authoritative — it will be pushed again on the next edit or
/// the next hydrate.
///
/// Two rules keep it honest:
///
/// - **Diff, don't dump.** A snapshot push would rewrite every row on every
///   keystroke. This keeps a fingerprint of each row as it was last written
///   or read, and sends only the ones that no longer match.
/// - **A job card is one write.** Header, lines, payments and messages go
///   through `save_job_card()` in a single transaction, so a dropped
///   connection can never leave half a bill in the database.
class GarageGateway {
  GarageGateway._();

  static final GarageGateway instance = GarageGateway._();

  /// Coalesces a burst of edits — dragging a quantity stepper, typing in the
  /// work note — into one round trip.
  static const Duration _pushDelay = Duration(milliseconds: 600);

  /// Realtime events arrive one per table; this lets a single
  /// `save_job_card` from another device settle before we refetch.
  static const Duration _echoDelay = Duration(milliseconds: 250);

  Timer? _debounce;
  RealtimeChannel? _channel;
  String? _garageId;

  /// Rows this device has just written, by table and id, with the JSON it
  /// wrote. A realtime event matching one of these is our own echo and is
  /// dropped rather than re-applied.
  final Map<String, String> _echo = {};

  /// Queued while a push is in flight, so edits made during a slow round
  /// trip are not lost.
  AdminData? _pending;
  bool _pushing = false;

  bool get enabled => AuthService.instance.enabled;

  SupabaseClient? get _client => enabled ? Supabase.instance.client : null;

  String? get garageId => _garageId;

  // -------------------------------------------------------------------------
  // Session
  // -------------------------------------------------------------------------

  /// The garage this account works at, creating it from [local] the first
  /// time. Returns null when the backend is off — the console then runs
  /// exactly as it does today, on its own store.
  ///
  /// `create_garage()` is idempotent per owner, so a retry after a dropped
  /// connection updates the workshop rather than opening a second one.
  Future<Garage?> ensureGarage(Garage? local) async {
    final client = _client;
    if (client == null) return null;
    try {
      final mine = await client.rpc('my_garage');
      if (mine != null) {
        final g = Garage.fromJson(Map<String, dynamic>.from(mine as Map));
        _garageId = g.id;
        return g;
      }
      if (local == null) return null;

      final made = await client.rpc('create_garage', params: {
        'payload': local.toJson()..remove('id'),
      });
      if (made == null) return null;
      final g = Garage.fromJson(Map<String, dynamic>.from(made as Map));
      _garageId = g.id;
      return g;
    } catch (e) {
      debugPrint('ensureGarage failed, staying local: $e');
      return null;
    }
  }

  /// Pulls the whole workshop in one round trip and rebuilds the snapshot
  /// from it. Returns null when there is nothing upstream yet, so the
  /// console keeps whatever it already had.
  Future<AdminData?> hydrate(AdminData local) async {
    final client = _client;
    final gid = _garageId;
    if (client == null || gid == null) return null;
    try {
      final raw = await client.rpc('garage_snapshot', params: {'gid': gid});
      if (raw == null) return null;
      final j = Map<String, dynamic>.from(raw as Map);

      List<T> list<T>(String key, T Function(Map<String, dynamic>) parse) =>
          ((j[key] as List?) ?? const [])
              .map((e) => parse(Map<String, dynamic>.from(e as Map)))
              .toList();

      final garage = j['garage'] == null
          ? local.garage
          : Garage.fromJson(Map<String, dynamic>.from(j['garage'] as Map));

      final next = local.copyWith(
        garage: garage,
        staff: list('staff', Staff.fromJson),
        customers: list('customers', Customer.fromJson),
        vehicles: list('vehicles', Vehicle.fromJson),
        masters: list('masters', MasterItem.fromJson),
        bookings: list('bookings', Booking.fromJson),
        reviews: list('reviews', Review.fromJson),
        jobCards: list('job_cards', JobCard.fromJson),
      );

      // Everything upstream is now known-good; nothing needs pushing back.
      _rememberAll(next);
      return next;
    } catch (e) {
      debugPrint('hydrate failed, staying local: $e');
      return null;
    }
  }

  /// Issues the six-digit code that lets a customer claim this record in
  /// their own app. Returns null when the backend could not be reached.
  ///
  /// This is the only way an account gets to read a garage's job cards: a
  /// phone number typed into a profile proves nothing, so the workshop
  /// vouches for the person at the counter instead.
  Future<String?> issueLinkCode(String customerId) async {
    final client = _client;
    if (client == null) return null;
    try {
      final code =
          await client.rpc('issue_customer_code', params: {'cid': customerId});
      return code as String?;
    } catch (e) {
      debugPrint('issueLinkCode failed: $e');
      return null;
    }
  }

  /// Forgets the session. Called on sign-out, before the next account
  /// hydrates into a console that must not show the last one's rows.
  Future<void> reset() async {
    _debounce?.cancel();
    _debounce = null;
    _pending = null;
    _echo.clear();
    _garageId = null;
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      try {
        await _client?.removeChannel(channel);
      } catch (_) {
        // A torn-down socket is already what we wanted.
      }
    }
  }

  // -------------------------------------------------------------------------
  // Push
  // -------------------------------------------------------------------------

  /// Mirrors [next] upstream, sending only the rows that have changed.
  /// Debounced, and never awaited by the UI.
  void push(AdminData next) {
    if (!enabled || _garageId == null) return;
    _pending = next;
    _debounce?.cancel();
    _debounce = Timer(_pushDelay, () {
      final data = _pending;
      _pending = null;
      if (data != null) unawaited(_pushNow(data));
    });
  }

  Future<void> _pushNow(AdminData data) async {
    if (_pushing) {
      // A round trip is already running; fold this into the next one rather
      // than interleaving two writes of the same rows.
      _pending = data;
      return;
    }
    final client = _client;
    final gid = _garageId;
    if (client == null || gid == null) return;

    _pushing = true;
    try {
      await _syncTable(client, 'staff', gid, data.staff,
          id: (e) => e.id, json: (e) => e.toJson());
      await _syncTable(client, 'garage_customers', gid, data.customers,
          id: (e) => e.id, json: (e) => e.toJson());
      await _syncTable(client, 'garage_vehicles', gid, data.vehicles,
          id: (e) => e.id, json: (e) => e.toJson());
      await _syncTable(client, 'masters', gid, data.masters,
          id: (e) => e.id, json: (e) => e.toJson());
      await _syncTable(client, 'garage_bookings', gid, data.bookings,
          id: (e) => e.id, json: (e) => e.toJson());

      // The workshop's own letterhead.
      final garage = data.garage;
      if (garage != null && _changed('garages', garage.id, garage.toJson())) {
        await client
            .from('garages')
            .update(garage.toJson()..remove('id'))
            .eq('id', gid);
        _remember('garages', garage.id, garage.toJson());
      }

      // Job cards: one transaction each, and only the ones that moved.
      for (final card in data.jobCards) {
        final body = card.toJson();
        if (!_changed('job_cards', card.id, body)) continue;
        await client.rpc('save_job_card', params: {
          'payload': {...body, 'garage_id': gid},
        });
        _remember('job_cards', card.id, body);
      }
      await _deleteMissing(client, 'job_cards', gid,
          {for (final c in data.jobCards) c.id});
    } catch (e) {
      // Local state stays authoritative and the rows stay marked dirty, so
      // the next edit — or the next hydrate — carries them up.
      debugPrint('push failed (local state is still authoritative): $e');
    } finally {
      _pushing = false;
      final queued = _pending;
      if (queued != null) {
        _pending = null;
        unawaited(_pushNow(queued));
      }
    }
  }

  /// Upserts the rows of one garage-scoped table that differ from what we
  /// last wrote, and deletes the ones that have gone.
  Future<void> _syncTable<T>(
    SupabaseClient client,
    String table,
    String gid,
    List<T> rows, {
    required String Function(T) id,
    required Map<String, dynamic> Function(T) json,
  }) async {
    final changed = <Map<String, dynamic>>[];
    for (final row in rows) {
      final body = json(row);
      if (!_changed(table, id(row), body)) continue;
      changed.add({...body, 'garage_id': gid}
        // A record with no date on it wants the column's default, not an
        // explicit null into a NOT NULL column.
        ..removeWhere((k, v) => v == null && k == 'created_at'));
    }
    if (changed.isNotEmpty) {
      await client.from(table).upsert(changed);
      for (final row in rows) {
        _remember(table, id(row), json(row));
      }
    }
    await _deleteMissing(client, table, gid, {for (final r in rows) id(r)});
  }

  /// Removes rows upstream that this device no longer has. Scoped to the
  /// garage, and only ever for ids we know we wrote — a row another device
  /// has just added, and that we have not seen yet, is left alone.
  Future<void> _deleteMissing(
    SupabaseClient client,
    String table,
    String gid,
    Set<String> keep,
  ) async {
    final prefix = '$table/';
    final gone = <String>[];
    for (final key in _echo.keys) {
      if (!key.startsWith(prefix)) continue;
      final id = key.substring(prefix.length);
      if (!keep.contains(id)) gone.add(id);
    }
    if (gone.isEmpty) return;
    await client.from(table).delete().eq('garage_id', gid).inFilter('id', gone);
    for (final id in gone) {
      _echo.remove('$table/$id');
    }
  }

  // -------------------------------------------------------------------------
  // Realtime
  // -------------------------------------------------------------------------

  /// Subscribes to everything this garage owns. [onCard] is handed a job
  /// card another device changed, [onRows] a table-level change, and
  /// [onGone] the id of something that was deleted.
  ///
  /// Line items, payments and messages are deliberately not subscribed to:
  /// they carry no `garage_id` to filter on, and every write to them goes
  /// through `save_job_card()`, which touches the card's `updated_at` — so
  /// the card's own event already covers them.
  void connect({
    required String garageId,
    required void Function(JobCard card) onCard,
    required void Function(String table, Map<String, dynamic> row) onRow,
    required void Function(String table, String id) onGone,
  }) {
    final client = _client;
    if (client == null) return;
    if (_channel != null && _garageId == garageId) return;

    unawaited(reset());
    _garageId = garageId;

    final channel = client.channel('garage:$garageId');
    final filter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'garage_id',
      value: garageId,
    );

    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'job_cards',
      filter: filter,
      callback: (payload) => _onJobCard(payload, onCard, onGone),
    );

    for (final table in const [
      'garage_customers',
      'garage_vehicles',
      'masters',
      'staff',
      'garage_bookings',
      'reviews',
      'garages',
    ]) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        // `garages` is keyed by id, not garage_id.
        table: table,
        filter: table == 'garages'
            ? PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'id',
                value: garageId,
              )
            : filter,
        callback: (payload) {
          final row = payload.newRecord;
          final old = payload.oldRecord;
          if (payload.eventType == PostgresChangeEvent.delete) {
            final id = (old['id'] ?? '') as String;
            if (id.isEmpty) return;
            _forget(table, id);
            onGone(table, id);
            return;
          }
          if (row.isEmpty) return;
          final id = (row['id'] ?? '') as String;
          final clean = Map<String, dynamic>.from(row)
            ..remove('garage_id')
            ..remove('profile_id');
          if (_isEcho(table, id, clean)) return;
          onRow(table, clean);
        },
      );
    }

    channel.subscribe();
    _channel = channel;
  }

  Future<void> _onJobCard(
    PostgresChangePayload payload,
    void Function(JobCard card) onCard,
    void Function(String table, String id) onGone,
  ) async {
    if (payload.eventType == PostgresChangeEvent.delete) {
      final id = (payload.oldRecord['id'] ?? '') as String;
      if (id.isEmpty) return;
      _forget('job_cards', id);
      onGone('job_cards', id);
      return;
    }

    final id = (payload.newRecord['id'] ?? '') as String;
    if (id.isEmpty) return;

    // The header arrives without its lines, so fetch the whole card. A short
    // wait lets the rest of one `save_job_card` transaction land first.
    await Future<void>.delayed(_echoDelay);
    final client = _client;
    if (client == null) return;
    try {
      final raw = await client.rpc('job_card_detail', params: {'card': id});
      if (raw == null) return;
      final body = Map<String, dynamic>.from(raw as Map)..remove('garage_id');
      if (_isEcho('job_cards', id, body)) return;
      _remember('job_cards', id, body);
      onCard(JobCard.fromJson(body));
    } catch (e) {
      debugPrint('job card refetch failed: $e');
    }
  }

  // -------------------------------------------------------------------------
  // Echo tracking
  // -------------------------------------------------------------------------
  //
  // Every write comes back to us as a realtime event. Comparing what arrived
  // with what we last wrote is what stops the two devices from bouncing the
  // same row between them forever.

  String _key(String table, String id) => '$table/$id';

  /// True when [body] differs from what this device last wrote or read.
  bool _changed(String table, String id, Map<String, dynamic> body) =>
      _echo[_key(table, id)] != _stamp(body);

  void _remember(String table, String id, Map<String, dynamic> body) {
    _echo[_key(table, id)] = _stamp(body);
  }

  /// Drops our record of a row that has gone upstream.
  ///
  /// The removal is always applied locally afterwards: a delete this device
  /// made has already been applied here, so re-applying it is a no-op, and a
  /// delete from another device is one we must not ignore.
  void _forget(String table, String id) => _echo.remove(_key(table, id));

  bool _isEcho(String table, String id, Map<String, dynamic> body) {
    if (_echo[_key(table, id)] == _stamp(body)) return true;
    _remember(table, id, body);
    return false;
  }

  void _rememberAll(AdminData data) {
    _echo.clear();
    final g = data.garage;
    if (g != null) _remember('garages', g.id, g.toJson());
    for (final e in data.staff) {
      _remember('staff', e.id, e.toJson());
    }
    for (final e in data.customers) {
      _remember('garage_customers', e.id, e.toJson());
    }
    for (final e in data.vehicles) {
      _remember('garage_vehicles', e.id, e.toJson());
    }
    for (final e in data.masters) {
      _remember('masters', e.id, e.toJson());
    }
    for (final e in data.bookings) {
      _remember('garage_bookings', e.id, e.toJson());
    }
    for (final e in data.jobCards) {
      _remember('job_cards', e.id, e.toJson());
    }
  }

  /// A stable fingerprint of a row. Keys are sorted so two encodings of the
  /// same row compare equal, and timestamps are trimmed to the second
  /// because Postgres and Dart disagree below that.
  ///
  /// Everything rests on this: if a row written here and the same row coming
  /// back over the wire fingerprint differently, the two devices push the
  /// same edit at each other forever.
  @visibleForTesting
  static String fingerprint(Map<String, dynamic> body) => _stamp(body);

  static String _stamp(Map<String, dynamic> body) {
    final buf = StringBuffer();
    void write(Object? v) {
      if (v is Map) {
        final keys = v.keys.map((e) => e.toString()).toList()..sort();
        for (final k in keys) {
          if (k == 'garage_id' || k == 'profile_id') continue;
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
        // 2026-09-15T11:22:33.000Z and 2026-09-15T11:22:33+00:00 are the
        // same instant written two ways.
        final at = DateTime.tryParse(v);
        buf.write(at == null
            ? v
            : (at.toUtc().millisecondsSinceEpoch ~/ 1000).toString());
      } else if (v is num) {
        // 0, 0.0 and "0.00" all mean nothing was charged.
        buf.write(v == v.roundToDouble() ? v.toInt().toString() : v.toString());
      } else {
        buf.write(v);
      }
    }

    write(body);
    return buf.toString();
  }
}
