import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../models/access.dart';
import '../models/books.dart';
import '../models/entities.dart';
import '../models/team.dart';
import 'admin_data.dart';
import 'auth_service.dart';

final garageGatewayProvider = Provider<GarageGateway>(
  (ref) => GarageGateway.instance,
);

/// The answer to "does this account already have a workshop?".
///
/// The third case is the one that matters. A backend that could not be
/// reached has told us nothing, and reading its silence as "no workshop"
/// is what marches a returning owner back through the registration form
/// and opens a second shop on top of their real one.
@immutable
class GarageLookup {
  const GarageLookup.found(Garage this.garage)
    : reachable = true,
      reason = null;

  /// The account answered: it has no workshop yet. Registration is correct.
  const GarageLookup.none() : garage = null, reachable = true, reason = null;

  /// We never got an answer. Nothing can be concluded from this.
  const GarageLookup.unreachable([this.reason])
    : garage = null,
      reachable = false;

  final Garage? garage;
  final bool reachable;

  /// What went wrong, when something did.
  final String? reason;
}

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

  /// Where a job card the database corrected on its way in is handed back.
  /// Set by [connect]; null until the console has joined its channel.
  void Function(JobCard card)? _onCard;

  /// Where a row this phone must stop holding is dropped. Set by [connect].
  void Function(String table, String id)? _onGone;

  bool get enabled => AuthService.instance.enabled;

  SupabaseClient? get _client => enabled ? Supabase.instance.client : null;

  String? get garageId => _garageId;

  /// What the signed-in person may do here. The owner until the database
  /// says otherwise; see [Access].
  final ValueNotifier<Access> access = ValueNotifier(Access.owner);

  /// What the server refused on the last push, by step, as a sentence the
  /// counter can read. Empty when everything went up.
  ///
  /// Every push failure used to end in a `debugPrint` and nothing else. The
  /// console showed "saved" either way, which is how job cards sat on one
  /// phone for days while the database refused them — the pgcrypto outage
  /// was found in `adb logcat`, not on screen. The app shell watches this
  /// and says so.
  final ValueNotifier<Map<String, String>> syncIssues =
      ValueNotifier(const {});

  void _issue(String step, String? problem) {
    final next = {...syncIssues.value};
    if (problem == null) {
      if (next.remove(step) == null) return;
    } else {
      if (next[step] == problem) return;
      next[step] = problem;
    }
    syncIssues.value = Map.unmodifiable(next);
  }

  /// A push failure in words. The raw exception still goes to the log.
  static String _describe(Object e) {
    if (e is PostgrestException) {
      if (e.code == 'PGRST204' ||
          e.code == 'PGRST205' ||
          e.code == '42P01' ||
          e.code == '42703' ||
          e.code == '42883') {
        return 'The database needs the latest update (supabase/*.sql).';
      }
      if (e.code == '42501') return 'The database refused permission.';
      if (e.code == '23505') return 'A duplicate record was refused.';
      if (e.code == '23503') return 'It refers to a record the server lacks.';
      return e.message;
    }
    final text = '$e';
    if (text.contains('SocketException') ||
        text.contains('ClientException') ||
        text.contains('Failed host lookup') ||
        text.contains('TimeoutException')) {
      return 'No connection to the server.';
    }
    return 'The server did not accept it.';
  }

  /// How many of [data]'s job cards the server does not hold as they are on
  /// this phone. Null when this session never reached the server, so there
  /// is no telling; zero with no backend at all.
  int? unsentCards(AdminData data) {
    if (!enabled) return 0;
    if (_garageId == null) return null;
    return data.jobCards
        .where((c) => _changed('job_cards', c.id, c.toJson()))
        .length;
  }

  /// Pushes [data] now rather than after the usual pause — the Retry on the
  /// sync banner.
  Future<void> pushNow(AdminData data) async {
    _debounce?.cancel();
    _pending = null;
    await _pushNow(data);
  }

  // -------------------------------------------------------------------------
  // Photos
  // -------------------------------------------------------------------------

  /// Puts one photo taken at the counter in storage and returns the URL it
  /// can be read from, or null when it could not go up (offline, or the
  /// bucket from 20_*.sql not created yet) — the caller keeps the local
  /// path and tries again later.
  ///
  /// Photos used to stay as file paths on the phone that took them. Every
  /// other phone, the same phone after a reinstall, the PDF and the
  /// customer all got a broken picture.
  Future<String?> uploadPhoto(String cardId, String localPath) async {
    final client = _client;
    final gid = _garageId;
    if (client == null || gid == null) return null;
    try {
      final bytes = await XFile(localPath).readAsBytes();
      final name = localPath.split(RegExp(r'[\\/]')).last;
      final path =
          '$gid/$cardId/${DateTime.now().microsecondsSinceEpoch}_$name';
      final bucket = client.storage.from('job-photos');
      await bucket.uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          contentType: name.toLowerCase().endsWith('.png')
              ? 'image/png'
              : 'image/jpeg',
          upsert: true,
        ),
      );
      return bucket.getPublicUrl(path);
    } catch (e) {
      debugPrint('photo upload failed, keeping it local for now: $e');
      return null;
    }
  }

  // -------------------------------------------------------------------------
  // The online shopfront
  // -------------------------------------------------------------------------

  /// Whether customers are offered this workshop's service menu.
  ///
  /// The switch on the Online Garage screen used to live on the phone
  /// alone: turning it off hid the menu from the counter and nobody else,
  /// and customers went on booking from it. `garage_card()` now reads it.
  Future<void> setOnline(bool on) async {
    final client = _client;
    final gid = _garageId;
    if (client == null || gid == null) return;
    try {
      await client.from('garages').update({'online_on': on}).eq('id', gid);
      _issue('online shopfront', null);
    } catch (e) {
      debugPrint('online_on not saved: $e');
      _issue('online shopfront', _describe(e));
    }
  }

  // -------------------------------------------------------------------------
  // Session
  // -------------------------------------------------------------------------

  /// The garage this account works at, creating it from [local] the first
  /// time.
  ///
  /// `create_garage()` is idempotent per owner, so a retry after a dropped
  /// connection updates the workshop rather than opening a second one.
  Future<GarageLookup> ensureGarage(Garage? local) async {
    final client = _client;
    if (client == null) {
      return const GarageLookup.unreachable('The backend is not configured.');
    }
    try {
      // An employee the owner invited joins that workshop here, before the
      // lookup, so they arrive at it instead of at the registration form.
      // A database without 31_staff_logins.sql simply has nothing to claim.
      try {
        await client.rpc('claim_staff_invite');
      } catch (e) {
        debugPrint('claim_staff_invite skipped: $e');
      }
      final mine = await client.rpc('my_garage');
      if (mine != null) {
        final g = Garage.fromJson(Map<String, dynamic>.from(mine as Map));
        _garageId = g.id;
        lastError = null;
        return GarageLookup.found(g);
      }
      // The account answered, and the answer is that it has no workshop yet.
      //
      // Staff never register one from what is on the phone. A staff login
      // the owner has just removed still holds that owner's workshop here,
      // and "creating" it would open a copy of somebody else's shop under
      // the ex-employee's name.
      //
      // Nor is a workshop the server has already issued an id to. If the
      // server no longer lists it for this account, it was deleted, or it
      // is another account's shop left on a shared phone. Uploading it again
      // brought a deleted account's workshop straight back, and cloned one
      // account's workshop into the next. Only a workshop registered with
      // no connection, which exists on this phone alone, is sent up here.
      if (local == null || !access.value.isOwner || serverIssued(local.id)) {
        lastError = null;
        return const GarageLookup.none();
      }

      final made = await client.rpc(
        'create_garage',
        params: {'payload': local.toJson()..remove('id')},
      );
      if (made == null) {
        return _fail('create_garage returned nothing.');
      }
      final g = Garage.fromJson(Map<String, dynamic>.from(made as Map));
      _garageId = g.id;
      lastError = null;
      return GarageLookup.found(g);
    } catch (e) {
      return _fail(_reason(e));
    }
  }

  /// Why the last lookup failed, kept so the screen that holds the owner can
  /// say what went wrong instead of shrugging. Cleared by any success.
  String? lastError;

  GarageLookup _fail(String reason) {
    debugPrint('ensureGarage failed, staying local: $reason');
    lastError = reason;
    return GarageLookup.unreachable(reason);
  }

  /// A missing database function is a setup problem, not a network one, and
  /// saying "check your connection" about it sends somebody hunting for the
  /// wrong fault.
  static String _reason(Object e) {
    final s = e.toString();
    final low = s.toLowerCase();
    if (low.contains('could not find the function') ||
        low.contains('does not exist') ||
        low.contains('pgrst202')) {
      return 'This Supabase project is missing the my_garage / create_garage '
          'functions the console calls.';
    }
    if (low.contains('jwt') ||
        low.contains('permission denied') ||
        low.contains('row-level security')) {
      return 'The account is signed in but not allowed to read its workshop.';
    }
    return s;
  }

  /// Upstream's job cards, plus any this device is still holding alone.
  ///
  /// The snapshot used to be copied straight over the local list. That is
  /// safe for every other collection and catastrophic for this one: a card
  /// whose `save_job_card()` call failed never reaches the server, so the
  /// next snapshot does not mention it, and the copy-over deleted the only
  /// copy in existence. A workshop lost a closed, settled card that way --
  /// the money taken, the invoice handed over, and no record of either.
  ///
  /// A push failure is invisible by design here (see [_step]), so the rule
  /// cannot be "trust the server". It is: the server decides what a card
  /// *contains*, and a card the server has never heard of stays.
  ///
  /// The cost is that a card deleted on another handset, while this one was
  /// away, comes back on the next hydrate rather than staying deleted. That
  /// is the right way round to be wrong. A card that reappears is a row to
  /// delete again; a card that vanishes is a job nobody can prove happened.
  @visibleForTesting
  static List<JobCard> debugMergeCards(
    List<JobCard> local,
    List<JobCard> upstream, {
    bool keepOrphans = true,
  }) => _mergeCards(local, upstream, keepOrphans: keepOrphans);

  static List<JobCard> _mergeCards(
    List<JobCard> local,
    List<JobCard> upstream, {
    bool keepOrphans = true,
  }) {
    // Somebody who cannot open job cards never made one on this phone, so
    // a card the server left out is one they have been taken off. Kept, it
    // would be pushed back and refused on every sync.
    if (!keepOrphans) return upstream;
    final ids = {for (final c in upstream) c.id};
    final orphans = [
      for (final c in local)
        if (!ids.contains(c.id)) c,
    ];
    if (orphans.isEmpty) return upstream;
    debugPrint(
      'hydrate kept ${orphans.length} job card(s) the server has never '
      'seen: ${orphans.map((c) => c.number).join(", ")}',
    );
    return [...upstream, ...orphans];
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

      /// Like [list], but tells an empty collection apart from one the
      /// database has never heard of.
      ///
      /// `garage_snapshot` gained the books after the console shipped. A
      /// project still running the older function simply leaves those keys
      /// out, and reading that silence as "no expenses" would wipe the day
      /// book off the counter on the next hydrate. Null means "say nothing",
      /// which `copyWith` takes as keep what is there.
      List<T>? known<T>(String key, T Function(Map<String, dynamic>) parse) =>
          j[key] is List ? list(key, parse) : null;

      final garage = j['garage'] == null
          ? local.garage
          : Garage.fromJson(Map<String, dynamic>.from(j['garage'] as Map));

      // The ledger tables arrived after garage_snapshot() last changed, and
      // are read on their own so that function need not move. Null — no
      // such table yet (35_*.sql not run) — keeps what the phone has.
      final banks = await _readTable(client, 'bank_accounts', gid);
      final trades = await _readTable(client, 'trade_docs', gid);
      final socialRaw = (j['garage'] as Map?)?['social'];

      final next = local.copyWith(
        garage: garage,
        // The shopfront switch lives on the garage row now, so every phone
        // at the counter agrees on it. Null (a database without the
        // column) keeps whatever this phone had.
        onlineGarageOn: (j['garage'] as Map?)?['online_on'] as bool?,
        staff: list('staff', Staff.fromJson),
        customers: list('customers', Customer.fromJson),
        vehicles: list('vehicles', Vehicle.fromJson),
        masters: list('masters', MasterItem.fromJson),
        bookings: list('bookings', Booking.fromJson),
        reviews: list('reviews', Review.fromJson),
        // Merged, not replaced. See [_mergeCards]: a card this device
        // has not managed to push must survive a snapshot that does
        // not contain it.
        jobCards: _mergeCards(
          local.jobCards,
          list('job_cards', JobCard.fromJson),
          keepOrphans: access.value.openJobs,
        ),
        expenses: known('expenses', Expense.fromJson),
        cashBook: known('cash_book', CashEntry.fromJson),
        suppliers: known('suppliers', Supplier.fromJson),
        counterSales: known('counter_sales', CounterSale.fromJson),
        purchaseOrders: known('purchase_orders', PurchaseOrder.fromJson),
        onlineServices: known('online_services', OnlineService.fromJson),
        bankAccounts: banks?.map(BankAccount.fromJson).toList(),
        tradeDocs: trades?.map(TradeDoc.fromJson).toList(),
        social: socialRaw is Map
            ? SocialLinks.fromJson(Map<String, dynamic>.from(socialRaw))
            : null,
      );

      // Everything upstream is now known-good; nothing needs pushing back —
      // except a collection this database did not answer on, whose rows are
      // still only on this device and must stay queued for the next push.
      final upstreamCardIds = {
        for (final c in list('job_cards', JobCard.fromJson)) c.id,
      };
      _rememberAll(
        next,
        unanswered: {
          for (final key in const [
            'expenses',
            'cash_book',
            'suppliers',
            'counter_sales',
            'purchase_orders',
            'online_services',
          ])
            if (j[key] is! List) key,
          if (banks == null) 'bank_accounts',
          if (trades == null) 'trade_docs',
          if (socialRaw is! Map) 'social',
        },
        stillLocal: {
          for (final c in next.jobCards)
            if (!upstreamCardIds.contains(c.id)) _key('job_cards', c.id),
        },
      );
      return next;
    } catch (e) {
      debugPrint('hydrate failed, staying local: $e');
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
    _onCard = null;
    _onGone = null;
    syncIssues.value = const {};
    access.value = Access.owner;
    await _closeChannel();
  }

  /// Drops the socket and nothing else.
  ///
  /// Separate from [reset] because [connect] runs immediately after
  /// `hydrate()` and after the seeding `push()`: a full reset there would
  /// throw away the fingerprints hydrate had just recorded and cancel the
  /// push still sitting in its debounce, so a brand new workshop never
  /// reached the database and every reconnect re-uploaded the whole
  /// counter on the next keystroke.
  Future<void> _closeChannel() async {
    final channel = _channel;
    _channel = null;
    if (channel == null) return;
    try {
      await _client?.removeChannel(channel);
    } catch (_) {
      // A torn-down socket is already what we wanted.
    }
  }

  // -------------------------------------------------------------------------
  // Sharing a job card
  // -------------------------------------------------------------------------

  /// The public link for a job card, fetched at the moment the counter
  /// presses Share.
  ///
  /// Asked for here rather than carried on every card: `job_card_json` does
  /// not include the token on purpose, so it never sits in the console's
  /// memory, its logs or a crash report except while it is being used.
  ///
  /// Null when there is no backend, or the card has no token — which is
  /// every card on a project that has not had `supabase/07_share.sql` run
  /// on it. Callers send their message without a link rather than not at
  /// all: a reminder with no link still works, one that never went because
  /// of a missing migration does not.
  Future<String?> shareLink(String cardId) async {
    final client = _client;
    if (client == null) return null;
    try {
      final token =
          await client.rpc('card_share_token', params: {'card': cardId});
      if (token is! String || token.isEmpty) return null;
      return AppConfig.shareLink(token);
    } catch (e) {
      debugPrint('card_share_token failed: $e');
      return null;
    }
  }

  /// Burns the current link and issues a new one — for the link that went
  /// to the wrong number, or into a group chat.
  Future<String?> rotateShareLink(String cardId) async {
    final client = _client;
    if (client == null) return null;
    try {
      final token =
          await client.rpc('rotate_share_token', params: {'card': cardId});
      if (token is! String || token.isEmpty) return null;
      return AppConfig.shareLink(token);
    } catch (e) {
      debugPrint('rotate_share_token failed: $e');
      return null;
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
      await _step(
        'staff',
        () => _syncTable(
          client,
          'staff',
          gid,
          data.staff,
          id: (e) => e.id,
          json: (e) => e.toJson(),
        ),
      );
      await _step(
        'customers',
        () => _syncTable(
          client,
          'garage_customers',
          gid,
          data.customers,
          id: (e) => e.id,
          json: (e) => e.toJson(),
        ),
      );
      await _step(
        'vehicles',
        () => _syncTable(
          client,
          'garage_vehicles',
          gid,
          data.vehicles,
          id: (e) => e.id,
          json: (e) => e.toJson(),
        ),
      );
      await _step(
        'masters',
        () => _syncTable(
          client,
          'masters',
          gid,
          data.masters,
          id: (e) => e.id,
          json: (e) => e.toJson(),
        ),
      );
      // The books.
      await _step(
        'expenses',
        () => _syncTable(
          client,
          'expenses',
          gid,
          data.expenses,
          id: (e) => e.id,
          json: (e) => e.toJson(),
        ),
      );
      await _step(
        'cash book',
        () => _syncTable(
          client,
          'cash_book',
          gid,
          data.cashBook,
          id: (e) => e.id,
          json: (e) => e.toJson(),
        ),
      );
      await _step(
        'suppliers',
        () => _syncTable(
          client,
          'suppliers',
          gid,
          data.suppliers,
          id: (e) => e.id,
          json: (e) => e.toJson(),
        ),
      );
      await _step(
        'counter sales',
        () => _syncTable(
          client,
          'counter_sales',
          gid,
          data.counterSales,
          id: (e) => e.id,
          json: (e) => e.toJson(),
        ),
      );
      await _step(
        'purchase orders',
        () => _syncTable(
          client,
          'purchase_orders',
          gid,
          data.purchaseOrders,
          id: (e) => e.id,
          json: (e) => e.toJson(),
        ),
      );
      await _step(
        'online services',
        () => _syncTable(
          client,
          'online_services',
          gid,
          data.onlineServices,
          id: (e) => e.id,
          json: (e) => e.toJson(),
        ),
      );

      await _step(
        'bank accounts',
        () => _syncTable(
          client,
          'bank_accounts',
          gid,
          data.bankAccounts,
          id: (e) => e.id,
          json: (e) => e.toJson(),
        ),
      );
      await _step(
        'sales & purchases',
        () => _syncTable(
          client,
          'trade_docs',
          gid,
          data.tradeDocs,
          id: (e) => e.id,
          json: (e) => e.toJson(),
        ),
      );
      // Kept apart from the letterhead below: a database without the
      // column must not stop the garage's name and address syncing.
      final social = data.social.toJson();
      if (_changed('social', gid, social)) {
        await _step('social links', () async {
          await client.from('garages').update({'social': social}).eq('id', gid);
          _remember('social', gid, social);
        });
      }

      // The workshop's own letterhead.
      final garage = data.garage;
      if (garage != null && _changed('garages', garage.id, garage.toJson())) {
        await _step('garage', () async {
          await client
              .from('garages')
              // `blocked` is the platform's; a database without 29 has
              // no such column, and PostgREST refuses the whole update.
              .update(
                garage.toJson()
                  ..remove('id')
                  ..remove('blocked'),
              )
              .eq('id', gid);
          _remember('garages', garage.id, garage.toJson());
        });
      }

      // Job cards: one transaction each, and only the ones that moved.
      for (final card in data.jobCards) {
        final body = card.toJson();
        if (!_changed('job_cards', card.id, body)) continue;
        await _step(
          'job card ${card.number}',
          () => _saveCard(client, gid, body),
        );
      }

      // A card that failed and has since been deleted never pushes again,
      // so its complaint would sit on the banner until a restart.
      final live = {for (final c in data.jobCards) 'job card ${c.number}'};
      for (final step in syncIssues.value.keys.toList()) {
        if (step.startsWith('job card ') &&
            step != 'job card removals' &&
            !live.contains(step)) {
          _issue(step, null);
        }
      }

      // After the job cards, never before. Accepting a booking sets its
      // `job_card_id`, a foreign key to `job_cards`, and the card it names
      // is created in this same push. Pushed first, the booking was refused
      // (23503) for pointing at a card that did not exist yet; the next
      // resume re-read the server's copy — still unaccepted — over the
      // local one, so the booking popped back onto the front desk, the
      // customer was never linked to their card, and their app said
      // "Confirmed" forever. Before the removals, so a booking still points
      // at a card that exists when it is written.
      //
      // `toRow`, not `toJson`: the car details are the customer's columns
      // and the console never writes them back.
      await _step(
        'bookings',
        () => _syncTable(
          client,
          'garage_bookings',
          gid,
          data.bookings,
          id: (e) => e.id,
          json: (e) => e.toRow(),
        ),
      );
      await _step(
        'job card removals',
        () => _deleteMissing(client, 'job_cards', gid, {
          for (final c in data.jobCards) c.id,
        }),
      );
    } finally {
      _pushing = false;
      final queued = _pending;
      if (queued != null) {
        _pending = null;
        unawaited(_pushNow(queued));
      }
    }
  }

  /// Runs one step of a push, keeping a failure local to that step.
  ///
  /// A single row the database refuses — a job card number another counter
  /// already used, a value that trips a check constraint — used to abort the
  /// whole push from wherever it happened. Everything after it stopped
  /// syncing, and stayed stopped, because that row is still there on the
  /// next attempt. Local state remains authoritative either way, and the
  /// rows in a failed step stay marked dirty so the next edit carries them.
  Future<void> _step(String what, Future<void> Function() body) async {
    try {
      await body();
      _issue(what, null);
    } catch (e) {
      _issue(what, _describe(e));
      debugPrint(
        'push step "$what" failed '
        '(local state is still authoritative): $e',
      );
    }
  }

  /// Writes one job card and takes back whatever the database made of it.
  ///
  /// The console mints a card's number offline, so two counters open on the
  /// same morning can propose the same one. `save_job_card()` settles that
  /// by handing back the number it actually stored — which is why the reply
  /// is read rather than discarded.
  Future<void> _saveCard(
    SupabaseClient client,
    String gid,
    Map<String, dynamic> body,
  ) async {
    final id = body['id'] as String;
    final Object? saved;
    try {
      saved = await client.rpc(
        'save_job_card',
        params: {
          'payload': {...body, 'garage_id': gid},
        },
      );
    } on PostgrestException catch (e) {
      final drop = _onGone;
      if (drop == null || !e.message.contains('belongs to another garage')) {
        rethrow;
      }
      // The card is already on the server, in the workshop it was opened
      // in. It reached this phone from another account signed in here
      // before, and retrying could never succeed — so it goes.
      debugPrint('job card ${body['number']} belongs to another workshop; '
          'dropped from this phone');
      drop('job_cards', id);
      return;
    }
    _remember('job_cards', id, body);
    if (saved == null) return;

    final number = (Map<String, dynamic>.from(saved as Map)['number'] ?? '')
        .toString();
    if (number.isEmpty || number == body['number']) return;

    // The floor renumbered this card. Record it against the number that is
    // now upstream, or every later push sees a card that never matches.
    final fixed = {...body, 'number': number};
    _remember('job_cards', id, fixed);
    _onCard?.call(JobCard.fromJson(fixed));
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
      changed.add(
        {...body, 'garage_id': gid}
          // A record with no date on it wants the column's default, not an
          // explicit null into a NOT NULL column.
          ..removeWhere((k, v) => v == null && k == 'created_at'),
      );
    }
    if (changed.isNotEmpty) {
      await _upsertShedding(client, table, changed);
      for (final row in rows) {
        _remember(table, id(row), json(row));
      }
    }
    await _deleteMissing(client, table, gid, {for (final r in rows) id(r)});
  }

  /// Upserts [rows], dropping any column the database says it does not have.
  ///
  /// PGRST204 is PostgREST refusing a whole batch over one unknown key. On
  /// this project that always means a migration not yet run: the console
  /// starts sending a column (the vehicles' `transmission`, from
  /// 18_booking_vehicle_details.sql) before the SQL editor has added it. The
  /// entire table then stopped syncing — and since a job card needs its
  /// vehicle upstream, so did every new job card. Now only that one column
  /// waits for the migration; the log names it.
  Future<void> _upsertShedding(
    SupabaseClient client,
    String table,
    List<Map<String, dynamic>> rows,
  ) async {
    var batch = rows;
    for (var shed = 0; shed < 8; shed++) {
      try {
        await client.from(table).upsert(batch);
        return;
      } on PostgrestException catch (e) {
        final column = e.code == 'PGRST204'
            ? RegExp(r"'([^']+)' column").firstMatch(e.message)?.group(1)
            : null;
        if (column == null || !batch.first.containsKey(column)) rethrow;
        debugPrint(
          '$table has no "$column" column yet; pushing without it. '
          'Run the latest supabase/*.sql to keep it.',
        );
        batch = [for (final r in batch) Map.of(r)..remove(column)];
      }
    }
    await client.from(table).upsert(batch);
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
  // Who may do what
  // -------------------------------------------------------------------------

  /// The signed-in person's role here, or null when it could not be asked.
  Future<Access?> fetchAccess() async {
    final client = _client;
    final gid = _garageId;
    if (client == null || gid == null) return null;
    try {
      final raw = await client.rpc('my_access', params: {'gid': gid});
      if (raw is! Map) return null;
      return Access.fromJson(Map<String, dynamic>.from(raw));
    } catch (e) {
      debugPrint('my_access failed: $e');
      return null;
    }
  }

  /// Whether [id] was handed out by the server (a uuid), as opposed to minted
  /// on this phone for a workshop registered with no connection.
  static bool serverIssued(String id) => _uuid.hasMatch(id);

  static final _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  /// Whether an invitation for the signed-in email is waiting, claiming it
  /// if so. The join screen polls this quietly; a hit is followed by the
  /// full restore that opens the workshop.
  Future<bool> claimInvite() async {
    final client = _client;
    if (client == null) return false;
    try {
      return await client.rpc('claim_staff_invite') != null;
    } catch (e) {
      debugPrint('claim_staff_invite failed: $e');
      return false;
    }
  }

  /// Everybody who can sign in here, and every invitation still waiting.
  /// Null when it could not be read, or this person may not see the team.
  Future<Team?> team() async {
    final client = _client;
    final gid = _garageId;
    if (client == null || gid == null) return null;
    try {
      final raw = await client.rpc('garage_team', params: {'gid': gid});
      if (raw is! Map) return null;
      return Team.fromJson(Map<String, dynamic>.from(raw));
    } catch (e) {
      debugPrint('garage_team failed: $e');
      return null;
    }
  }

  /// Gives [email] the app, as [role], for the staff record [staffId].
  /// Returns an error sentence, or null.
  Future<String?> invite({
    required String staffId,
    required String email,
    required StaffRole role,
  }) async {
    // The staff record has to be upstream before an invitation can name
    // it, and a person added a moment ago may still be in the debounce.
    await _flush();
    return _teamCall('invite_staff', {
      'payload': {
        'garage_id': _garageId,
        'email': email.trim(),
        'role': role.name,
        'staff_id': staffId,
      },
    });
  }

  Future<String?> setRole(String profileId, StaffRole role) => _teamCall(
    'set_staff_role',
    {'gid': _garageId, 'member': profileId, 'new_role': role.name},
  );

  Future<String?> removeAccess(String profileId) =>
      _teamCall('remove_staff_access', {'gid': _garageId, 'member': profileId});

  Future<String?> cancelInvite(String email) => _teamCall(
    'cancel_staff_invite',
    {'gid': _garageId, 'invite_email': email},
  );

  Future<String?> _teamCall(String fn, Map<String, dynamic> params) async {
    final client = _client;
    if (client == null || _garageId == null) {
      return 'Connect to the internet to manage app access.';
    }
    try {
      await client.rpc(fn, params: params);
      return null;
    } on PostgrestException catch (e) {
      debugPrint('$fn failed: $e');
      // 31_staff_logins.sql words its refusals for the screen.
      const worded = {'42501', '23514', '23505', 'P0002'};
      if (worded.contains(e.code)) return e.message;
      if (e.code == 'PGRST202' || e.code == '42883') {
        return 'The database needs the latest update (supabase/*.sql).';
      }
      return 'Could not save that. Try again in a moment.';
    } catch (e) {
      debugPrint('$fn failed: $e');
      return 'No connection to the server.';
    }
  }

  /// Sends whatever is waiting in the debounce now.
  Future<void> _flush() async {
    final data = _pending;
    if (data == null) return;
    _debounce?.cancel();
    _pending = null;
    await _pushNow(data);
  }

  // -------------------------------------------------------------------------
  // The bell
  // -------------------------------------------------------------------------

  /// The workshop's alert feed, newest first.
  ///
  /// Deliberately outside the diff-and-push machinery above. Notifications
  /// are raised by database triggers at the moment the thing they describe
  /// happened, so there is nothing for this device to have an opinion
  /// about: it reads, and it marks read. Null on failure, so the caller can
  /// tell "the feed is empty" from "we could not ask".
  Future<List<GarageNotification>?> notifications({int limit = 120}) async {
    final client = _client;
    final gid = _garageId;
    if (client == null || gid == null) return null;
    try {
      final rows = await client
          .from('garage_notifications')
          .select()
          .eq('garage_id', gid)
          .order('at', ascending: false)
          .limit(limit);
      return [
        for (final r in (rows as List))
          GarageNotification.fromJson(Map<String, dynamic>.from(r as Map)),
      ];
    } catch (e) {
      debugPrint('notifications unavailable: $e');
      return null;
    }
  }

  /// Marks [ids] read, or the whole feed when null.
  ///
  /// `read` is the only column the function will touch — the text of a
  /// notification is the record of what the workshop was told, and is not
  /// the workshop's to edit. Returns false when the round trip failed, so
  /// the console can leave the badge alone rather than showing a zero it
  /// has not earned.
  Future<bool> markNotificationsRead([List<String>? ids]) async {
    final client = _client;
    if (client == null || _garageId == null) return false;
    try {
      await client.rpc('read_garage_notifications', params: {'ids': ids});
      return true;
    } catch (e) {
      debugPrint('mark read failed: $e');
      return false;
    }
  }

  // -------------------------------------------------------------------------
  // Devices to push to
  // -------------------------------------------------------------------------

  /// Registers this handset's push token against the current workshop.
  ///
  /// Called on every launch and on every token rotation, and an upsert on
  /// the server, so it is safe to call as often as it is convenient to.
  Future<void> registerDevice(String token, String platform) async {
    final client = _client;
    final gid = _garageId;
    if (client == null || gid == null || token.trim().isEmpty) return;
    try {
      await client.rpc('register_garage_device', params: {
        'tok': token,
        'gid': gid,
        'plat': platform,
      });
    } catch (e) {
      debugPrint('device registration failed: $e');
    }
  }

  // Un-registering is not here but in `AuthService.signOut`, because it has
  // to happen while the session is still alive — see the note there.

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
  Future<void> connect({
    required String garageId,
    required void Function(JobCard card) onCard,
    required void Function(String table, Map<String, dynamic> row) onRow,
    required void Function(String table, String id) onGone,
  }) async {
    final client = _client;
    if (client == null) return;
    // Before any early return: a push can need these before the channel is
    // up, and `reset()` clears them without closing a live channel's id.
    _onCard = onCard;
    _onGone = onGone;
    if (_channel != null && _garageId == garageId) return;

    unawaited(_closeChannel());
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
      // Read-only from here, like `attendance` below: rows are raised by
      // the triggers in 06_notifications.sql and never written by the
      // console, so this subscription exists purely so a booking raised on
      // a customer's phone reaches the counter while they are looking at
      // another screen.
      'garage_notifications',
      'expenses',
      'cash_book',
      'suppliers',
      'counter_sales',
      'purchase_orders',
      'online_services',
      // Read-only from here. Punches are written by `punch_attendance()`
      // alone and never pushed, so this subscription exists purely so a
      // punch made on the floor reaches the owner's console without a
      // refresh.
      'attendance',
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
          debugPrint('realtime: $table ${payload.eventType.name}');
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

    // Hand the socket a current JWT before joining.
    //
    // The SDK already does this on `initialSession`, `signedIn` and
    // `tokenRefreshed` -- and swallows the `InvalidJWTToken` it throws
    // when the token has expired, which is exactly what happens on a cold
    // launch after the app has been shut for a while. The socket is then
    // left carrying the anon key. The channel still joins, because joining
    // is allowed; every table is then RLS-filtered to nothing, because
    // Realtime has no user to evaluate the policies as.
    //
    // That failure is invisible from the client: `subscribed` comes back,
    // and the console sits there looking calm and receiving nothing --
    // which is precisely what was happening here on 22 Sep 2026. Setting
    // it explicitly, at the one moment we know we are about to subscribe,
    // costs nothing and removes the whole class of problem.
    final token = client.auth.currentSession?.accessToken;
    if (token != null) {
      try {
        await client.realtime.setAuth(token);
      } catch (e) {
        // Worth saying, never worth failing the connection over: a stale
        // token still gives a channel, just a quiet one.
        debugPrint('realtime: could not set auth on the socket -- $e');
      }
    }

    // Say out loud whether the channel actually came up.
    //
    // `subscribe()` took no callback here, so a channel that never joined
    // looked exactly like a channel with nothing to report: silence. When
    // bookings stopped reaching the front desk on 21 Sep 2026 there was no
    // way to tell a dead socket from an empty one, and working out which
    // took an hour and a database query. One line of log would have
    // answered it.
    //
    // This only reports. Reconnection is the client's own job and it does
    // it well; what was missing was the ability to see.
    channel.subscribe((status, error) {
      switch (status) {
        case RealtimeSubscribeStatus.subscribed:
          debugPrint('realtime: listening to garage:$garageId');
        case RealtimeSubscribeStatus.closed:
          debugPrint('realtime: channel closed');
        case RealtimeSubscribeStatus.timedOut:
          debugPrint('realtime: subscribe timed out, client will retry');
        case RealtimeSubscribeStatus.channelError:
          // The one worth reading carefully. A table that is not on the
          // `supabase_realtime` publication fails here, and the console
          // then shows stale data with no other sign anything is wrong.
          debugPrint('realtime: channel error -- $error');
      }
    });
    _channel = channel;
  }

  Future<void> _onJobCard(
    PostgresChangePayload payload,
    void Function(JobCard card) onCard,
    void Function(String table, String id) onGone,
  ) async {
    debugPrint('realtime: job_cards ${payload.eventType.name}');
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

  /// Records the whole snapshot as known-good.
  ///
  /// [unanswered] names tables the snapshot said nothing about, whose rows
  /// are therefore not known to be upstream at all. Leaving those out is
  /// what keeps them dirty, so the next push carries them.
  ///
  /// [stillLocal] names individual rows, as `table/id`, that are on this
  /// device and nowhere else -- the job cards [_mergeCards] rescued. They
  /// are left dirty for the same reason: the next push must try them again.
  void _rememberAll(
    AdminData data, {
    Set<String> unanswered = const {},
    Set<String> stillLocal = const {},
  }) {
    _echo.clear();
    void remember(String table, String id, Map<String, dynamic> body) {
      if (unanswered.contains(table)) return;
      _remember(table, id, body);
    }

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
      _remember('garage_bookings', e.id, e.toRow());
    }
    for (final e in data.jobCards) {
      if (stillLocal.contains(_key('job_cards', e.id))) continue;
      _remember('job_cards', e.id, e.toJson());
    }
    for (final e in data.expenses) {
      remember('expenses', e.id, e.toJson());
    }
    for (final e in data.cashBook) {
      remember('cash_book', e.id, e.toJson());
    }
    for (final e in data.suppliers) {
      remember('suppliers', e.id, e.toJson());
    }
    for (final e in data.counterSales) {
      remember('counter_sales', e.id, e.toJson());
    }
    for (final e in data.purchaseOrders) {
      remember('purchase_orders', e.id, e.toJson());
    }
    for (final e in data.onlineServices) {
      remember('online_services', e.id, e.toJson());
    }
    for (final e in data.bankAccounts) {
      remember('bank_accounts', e.id, e.toJson());
    }
    for (final e in data.tradeDocs) {
      remember('trade_docs', e.id, e.toJson());
    }
    final gid = _garageId;
    if (gid != null) remember('social', gid, data.social.toJson());
  }

  /// Every row of a garage's table, or null when the table is not there.
  Future<List<Map<String, dynamic>>?> _readTable(
    SupabaseClient client,
    String table,
    String gid,
  ) async {
    try {
      final rows = await client.from(table).select().eq('garage_id', gid);
      return [
        for (final r in rows as List)
          Map<String, dynamic>.from(r as Map)
            ..remove('garage_id')
            ..remove('created_at'),
      ];
    } catch (e) {
      debugPrint('$table not readable yet: $e');
      return null;
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
          buf
            ..write(k)
            ..write(':');
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
        buf.write(
          at == null
              ? v
              : (at.toUtc().millisecondsSinceEpoch ~/ 1000).toString(),
        );
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
