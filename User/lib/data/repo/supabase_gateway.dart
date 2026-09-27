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

    final profile = {...data.user!.toJson(), 'id': uid};
    if (_changed('profiles', uid, profile)) {
      await _step('profile', () async {
        await client.from('profiles').upsert(profile);
        _remember('profiles', uid, profile);
      });
    }

    // Vehicles and addresses are the two the customer can actually remove,
    // so they are the two swept: without it a deleted car stays upstream
    // and walks back in on the next hydrate.
    await _step(
        'vehicles',
        () => _sync(client, 'vehicles', uid, data.vehicles,
            id: (e) => e.id, json: (e) => e.toJson(), sweep: true));
    await _step(
        'addresses',
        () => _sync(client, 'addresses', uid, data.addresses,
            id: (e) => e.id, json: (e) => e.toJson(), sweep: true));
    await _step(
        'bookings',
        () => _sync(client, 'bookings', uid, data.bookings,
            id: (e) => e.id, json: (e) => e.toJson()));
    await _step(
        'inspections',
        () => _sync(client, 'inspections', uid, data.inspections.values.toList(),
            id: (e) => e.id, json: (e) => e.toJson()));
    // Not the quotes mirrored from a workshop's job card (`est-<card id>`).
    // Those are the garage's figures, rebuilt from the card on every refresh,
    // and they are stored as approved — which the database makes immutable.
    // Pushing one again after the card changed was refused every time, and
    // the estimates step failed on every push from then on.
    await _step(
        'estimates',
        () => _sync(client, 'estimates', uid,
            data.estimates.values
                .expand((e) => e)
                .where((e) => !e.id.startsWith('est-'))
                .toList(),
            id: (e) => e.id, json: (e) => e.toJson()));
    await _step(
        'invoices',
        () => _sync(client, 'invoices', uid, data.invoices.values.toList(),
            id: (e) => e.id, json: (e) => e.toJson()));
    // Deliberately not swept: only the newest fifty go up, so everything
    // older than that would read as deleted.
    await _step(
        'notifications',
        () => _sync(client, 'notifications', uid,
            data.notifications.take(50).toList(),
            id: (e) => e.id, json: (e) => e.toJson()));
  }

  /// Runs one step of a push, keeping a failure local to that step.
  ///
  /// One row the database refuses — an approved estimate, which is
  /// immutable by trigger, is the likely one — used to abort the push from
  /// wherever it happened, so every table after it stopped syncing and
  /// stayed stopped. Local state is authoritative either way, and a failed
  /// step's rows stay marked dirty for the next attempt.
  Future<void> _step(String what, Future<void> Function() body) async {
    try {
      await body();
    } catch (e) {
      debugPrint('push step "$what" failed '
          '(local state is still authoritative): $e');
    }
  }

  /// Upserts only the rows whose contents actually differ from what was last
  /// written or read.
  ///
  /// The whole snapshot used to go up on every change — every vehicle, every
  /// booking, every notification, each time a checkbox moved. On a phone
  /// connection that is the difference between a sync you never notice and
  /// one you watch happen.
  /// [sweep] also removes the rows upstream that this device no longer has.
  /// Only ever for ids we know we wrote or read, and only for a list that is
  /// the complete set — a truncated one would read as a pile of deletions.
  Future<void> _sync<T>(
    SupabaseClient client,
    String table,
    String uid,
    List<T> rows, {
    required String Function(T) id,
    required Map<String, dynamic> Function(T) json,
    bool sweep = false,
  }) async {
    final changed = <Map<String, dynamic>>[];
    for (final row in rows) {
      final body = json(row);
      if (!_changed(table, id(row), body)) continue;
      changed.add({...body, 'user_id': uid});
    }
    if (changed.isNotEmpty) {
      await client.from(table).upsert(changed);
      for (final row in rows) {
        _remember(table, id(row), json(row));
      }
    }
    if (sweep) {
      await _deleteMissing(client, table, uid, {for (final r in rows) id(r)});
    }
  }

  /// Removes rows upstream that this device has dropped. Scoped to the
  /// signed-in user, and only for ids this device has actually seen — a row
  /// added on another phone that has not reached us yet is left alone.
  Future<void> _deleteMissing(
    SupabaseClient client,
    String table,
    String uid,
    Set<String> keep,
  ) async {
    final prefix = '$table/';
    final gone = <String>[];
    for (final key in _written.keys) {
      if (!key.startsWith(prefix)) continue;
      final id = key.substring(prefix.length);
      if (!keep.contains(id)) gone.add(id);
    }
    if (gone.isEmpty) return;
    await client.from(table).delete().eq('user_id', uid).inFilter('id', gone);
    for (final id in gone) {
      _written.remove('$table/$id');
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
  ///
  /// Null when the question could not be asked — offline, or signed out —
  /// so a pull-to-refresh can say "could not reach the workshop" instead of
  /// quietly showing the same screen as if nothing had changed.
  Future<List<WorkshopCard>?> workshopCards() async {
    final client = _client;
    if (client == null || userId == null) return null;
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
      return null;
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
  /// dealt with — the policy is `deals_with_garage(id)`, not a directory.
  ///
  /// [preferId] is the workshop this customer last booked with or had a card
  /// at, and wins when it is readable. It used to be `limit(1)` with no order
  /// at all, so a customer of two workshops got whichever one Postgres
  /// returned first — on Home, on every booking card and on the help page.
  Future<Workshop?> linkedWorkshop({String? preferId}) async {
    final client = _client;
    if (client == null || userId == null) return null;
    try {
      List rows = const [];
      if (preferId != null && preferId.isNotEmpty) {
        rows = await client.from('garages').select().eq('id', preferId);
      }
      if (rows.isEmpty) {
        rows = await client
            .from('garages')
            .select()
            .order('created_at', ascending: false)
            .limit(1);
      }
      if (rows.isEmpty) return null;
      final shop = Map<String, dynamic>.from(rows.first as Map);

      // The menu this workshop publishes. Row level security already limits
      // it to a shop the account deals with, so there is no client-side
      // filter to get wrong. An empty list is a real answer — a workshop
      // that has not put anything on its page yet — and the booking screen
      // says so rather than inventing a menu. A workshop that has switched
      // its online shopfront off (`online_on`, 20_*.sql) offers none.
      if (shop['online_on'] == false) {
        shop['services'] = const [];
      } else {
        try {
          shop['services'] = await client
              .from('online_services')
              .select('id, name, price, blurb, duration_mins')
              .eq('garage_id', shop['id'] as Object)
              .order('name');
        } catch (e) {
          // A workshop with no menu is still a workshop worth showing.
          debugPrint('workshop menu unavailable: $e');
        }
      }
      return Workshop.fromJson(shop);
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
  ///
  /// Null when the question could not be asked (offline, signed out), which
  /// is not the same answer as "no requests": a request missing from a real
  /// answer is one the workshop removed, and reading a failed call that way
  /// would mark every booking declined the first time the network dropped.
  ///
  /// Filtered to this account even though row level security already is:
  /// a customer who also runs a workshop can read that workshop's whole
  /// front desk, and those are not their bookings.
  Future<Map<String, Map<String, dynamic>>?> myBookingRequests() async {
    final client = _client;
    final uid = userId;
    if (client == null || uid == null) return null;
    try {
      final rows = await client
          .from('garage_bookings')
          .select('id, garage_id, accepted, job_card_id, at')
          .eq('profile_id', uid);
      return {
        for (final r in (rows as List))
          ((r as Map)['id'] ?? '').toString(): Map<String, dynamic>.from(r),
      };
    } catch (e) {
      debugPrint('booking requests unavailable: $e');
      return null;
    }
  }

  /// Takes a request back off the workshop's front desk. The policy allows it
  /// only while the counter has not accepted it; after that it is a job card,
  /// and calling off work already under way is a phone call. True when the
  /// request is gone (or was never there).
  Future<bool> withdrawWorkshopBooking(String requestId) async {
    final client = _client;
    final uid = userId;
    if (client == null || uid == null) return false;
    try {
      final gone = await client
          .from('garage_bookings')
          .delete()
          .eq('id', requestId)
          .eq('profile_id', uid)
          .select('id');
      if ((gone as List).isNotEmpty) return true;
      // Nothing deleted: either it never arrived (fine) or the counter has
      // accepted it and the policy kept it (not fine). Ask which.
      final still = await client
          .from('garage_bookings')
          .select('id')
          .eq('id', requestId)
          .maybeSingle();
      return still == null;
    } catch (e) {
      debugPrint('withdraw booking request failed: $e');
      return false;
    }
  }

  /// Moves a request the counter has not accepted yet to a new slot. The
  /// policy (20_*.sql) lets the customer change the time and nothing else,
  /// and only before acceptance. True when it moved — or was never on the
  /// desk, so there is nothing there to be wrong.
  Future<bool> rescheduleWorkshopBooking(String requestId, DateTime at) async {
    final client = _client;
    final uid = userId;
    if (client == null || uid == null) return false;
    try {
      final moved = await client
          .from('garage_bookings')
          .update({'at': at.toUtc().toIso8601String()})
          .eq('id', requestId)
          .eq('profile_id', uid)
          .select('id');
      if ((moved as List).isNotEmpty) return true;
      final still = await client
          .from('garage_bookings')
          .select('id')
          .eq('id', requestId)
          .maybeSingle();
      return still == null;
    } catch (e) {
      debugPrint('reschedule booking request failed: $e');
      return false;
    }
  }

  /// Leaves (or changes) this customer's rating of a job card. One review
  /// per card: `reviews_unique_card` makes a second one an edit of the
  /// first. Returns an error sentence, or null.
  Future<String?> saveReview({
    required String garageId,
    required String jobCardId,
    required int stars,
    String comment = '',
  }) async {
    final client = _client;
    final uid = userId;
    if (client == null || uid == null) {
      return 'Connect to the internet to rate the workshop.';
    }
    try {
      await client.from('reviews').upsert({
        'id': 'rv-$jobCardId',
        'garage_id': garageId,
        'job_card_id': jobCardId,
        'profile_id': uid,
        'stars': stars.clamp(1, 5),
        'comment': comment.trim(),
      }, onConflict: 'job_card_id');
      return null;
    } catch (e) {
      debugPrint('save review failed: $e');
      return 'Could not send your rating. Try again in a moment.';
    }
  }

  /// Deletes the account on the server — the sign-in and everything the
  /// customer owns (`delete_my_account()`, 20_*.sql). Returns an error
  /// sentence, or null.
  Future<String?> deleteAccount() async {
    final client = _client;
    if (client == null || userId == null) {
      return 'Connect to the internet to delete your account.';
    }
    try {
      await client.rpc('delete_my_account');
      return null;
    } on PostgrestException catch (e) {
      debugPrint('delete_my_account failed (${e.code}): ${e.message}');
      if (e.message.contains('runs a workshop')) {
        return 'This account runs a workshop. Contact support to close it, '
            'so the workshop\'s records are not lost with it.';
      }
      if (e.code == 'PGRST202') {
        return 'Account deletion is not switched on for this project yet. '
            'Contact support and we will delete it for you.';
      }
      return 'Could not delete the account. Try again in a moment.';
    } catch (e) {
      debugPrint('delete_my_account failed: $e');
      return 'Could not delete the account. Try again in a moment.';
    }
  }

  /// Files this phone's push token under the signed-in customer
  /// (22_customer_push.sql). Called on every sign-in and token rotation; an
  /// upsert on the server, so calling it often costs nothing.
  Future<void> registerDevice(String token, String platform) async {
    final client = _client;
    if (client == null || userId == null || token.trim().isEmpty) return;
    try {
      await client.rpc('register_customer_device', params: {
        'tok': token,
        'plat': platform,
      });
    } catch (e) {
      debugPrint('device registration failed: $e');
    }
  }

  /// Sends whatever is still waiting to go up, now, and waits for it —
  /// bounded, so signing out with no signal does not hang.
  ///
  /// Sign-out wipes the phone. It used to cancel the debounced upload first,
  /// so anything changed in the last second, or anything a failed push had
  /// left dirty, was simply gone, while the dialog promised it would stay
  /// with the account.
  Future<void> flush(AppData data) async {
    _debounce?.cancel();
    if (!enabled) return;
    try {
      await _pushNow(data).timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('final push before sign-out did not finish: $e');
    }
  }

  /// Puts a booking on the workshop's front desk, where it appears as an
  /// unaccepted request the counter can turn into a job card.
  ///
  /// It can only ever be a request: the insert policy refuses a row that
  /// arrives already accepted or already pointing at a job card, so the
  /// customer app cannot book itself into the workshop's floor.
  ///
  /// The car goes up as the customer described it, one column per fact —
  /// brand, model, variant, fuel, gearbox, year and the odometer. It used to
  /// go up as the one string "Brand Model", and the counter opened a job
  /// card with the brand split on the first space, no gearbox and a blank
  /// KM reading. `vehicle` and `note` are still filled in as before, for a
  /// console that has not been updated.
  ///
  /// True once the workshop has the request — including when it already
  /// had it, which is what a retry after a lost reply looks like.
  Future<bool> requestWorkshopBooking({
    required String garageId,
    required String id,
    required String name,
    required String phone,
    required DateTime at,
    String regNo = '',
    String vehicle = '',
    String note = '',
    String brand = '',
    String model = '',
    String variant = '',
    String fuel = '',
    String transmission = '',
    int? year,
    int? odometerKm,
    String mode = '',
    String customerNote = '',
  }) async {
    final client = _client;
    final uid = userId;
    if (client == null || uid == null) return false;

    final base = {
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
    };

    try {
      await client.from('garage_bookings').insert({
        ...base,
        'brand': brand,
        'model': model,
        'variant': variant,
        'fuel': fuel,
        'transmission': transmission,
        'year': year,
        'odometer_km': odometerKm,
        'mode': mode,
        'customer_note': customerNote,
      });
      return true;
    } on PostgrestException catch (e) {
      if (e.code == '23505') return true;
      // PGRST204 is PostgREST saying a column does not exist: the project
      // has not run 18_booking_vehicle_details.sql yet. Refusing the
      // booking over that would be the worst outcome, so it goes up in the
      // old shape with the details written into the note, where the
      // counter can at least read them.
      if (e.code == 'PGRST204') {
        debugPrint('garage_bookings has no detail columns yet; '
            'sending the details in the note instead');
        return _insertBooking(client, {
          ...base,
          'note': [
            note,
            [
              if (variant.isNotEmpty) '$model $variant' else model,
              fuel,
              transmission,
              if (year != null) '$year',
              if (odometerKm != null && odometerKm > 0) '$odometerKm km',
              if (mode == 'pickup') 'Pick & drop',
              if (customerNote.isNotEmpty) 'Note: $customerNote',
            ].where((s) => s.trim().isNotEmpty).join(' • '),
          ].where((s) => s.trim().isNotEmpty).join(' — '),
        });
      }
      debugPrint('workshop booking request failed (${e.code}): ${e.message}');
      return false;
    } catch (e) {
      debugPrint('workshop booking request failed: $e');
      return false;
    }
  }

  Future<bool> _insertBooking(
    SupabaseClient client,
    Map<String, dynamic> row,
  ) async {
    try {
      await client.from('garage_bookings').insert(row);
      return true;
    } on PostgrestException catch (e) {
      if (e.code == '23505') return true;
      debugPrint('workshop booking request failed (${e.code}): ${e.message}');
      return false;
    } catch (e) {
      debugPrint('workshop booking request failed: $e');
      return false;
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
