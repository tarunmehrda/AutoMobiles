import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../state/auth_state.dart';
import 'auth_service.dart';

final platformGatewayProvider =
    Provider<PlatformGateway>((ref) => PlatformGateway.instance);

/// Whether the signed-in account is a partner head that is switched on —
/// one of the addresses in `platform_heads` (27_partner_heads.sql).
///
/// Cached per account by Riverpod. Another head can switch this one off,
/// so the platform screen refreshes it each time it opens; the database
/// refuses a switched-off head either way. Keyed on the signed-in user, so the next
/// account on this phone is asked afresh instead of inheriting the last
/// one's answer. Anything that goes wrong resolves to false, which hides the
/// section rather than showing a broken one.
final isPlatformAdminProvider = FutureProvider<bool>((ref) {
  ref.watch(authUserProvider.select((u) => u?.id));
  return ref.read(platformGatewayProvider).amPlatformAdmin();
});

/// One partner head and whether their platform access is on.
@immutable
class PlatformHead {
  const PlatformHead({
    required this.email,
    required this.enabled,
    this.me = false,
  });

  final String email;
  final bool enabled;

  /// The signed-in account's own row.
  final bool me;

  factory PlatformHead.fromJson(Map<String, dynamic> j) => PlatformHead(
        email: (j['email'] ?? '') as String,
        enabled: (j['enabled'] ?? false) as bool,
        me: (j['me'] ?? false) as bool,
      );
}

/// One workshop as the register sees it.
@immutable
class RegisteredGarage {
  const RegisteredGarage({
    required this.id,
    required this.name,
    this.owner = '',
    this.phone = '',
    this.email = '',
    this.city = '',
    this.district = '',
    this.state = '',
    this.pin = '',
    this.lat,
    this.lng,
    this.listed = false,
    this.verified = false,
    this.blocked = false,
    this.commissionPct,
    this.members = 0,
    this.cards = 0,
    this.createdAt,
  });

  final String id;
  final String name;
  final String owner;
  final String phone;
  final String email;
  final String city;

  /// From the phone's location lookup (29_block_and_district.sql). Empty
  /// for a workshop that has not set its location since.
  final String district;
  final String state;
  final String pin;
  final double? lat;
  final double? lng;
  final bool listed;
  final bool verified;

  /// Blocked by a partner head: out of customer search, and cannot be
  /// listed again until it is unblocked.
  final bool blocked;
  final double? commissionPct;

  /// How many people can sign in to it, and how many job cards it has
  /// raised. The two numbers that say whether a registration is a real
  /// workshop or an empty sign-up.
  final int members;
  final int cards;
  final DateTime? createdAt;

  bool get located => lat != null && lng != null;

  /// The district to file it under. An Indian city is usually its own
  /// district's name, so a workshop with no district yet goes under its
  /// city rather than under nothing.
  String get districtOrCity =>
      district.trim().isNotEmpty ? district.trim() : city.trim();

  /// "Jaipur, Rajasthan 302001" — the PIN is what the customer app shows
  /// beside the name, so the register shows it too.
  String get where => [
    city,
    [state, pin].where((s) => s.trim().isNotEmpty).join(' '),
  ].where((s) => s.trim().isNotEmpty).join(', ');

  factory RegisteredGarage.fromJson(Map<String, dynamic> j) =>
      RegisteredGarage(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? '') as String,
        owner: (j['owner'] ?? '') as String? ?? '',
        phone: (j['phone'] ?? '') as String,
        email: (j['email'] ?? '') as String,
        city: (j['city'] ?? '') as String,
        district: (j['district'] ?? '') as String,
        state: (j['state'] ?? '') as String,
        pin: (j['pin'] ?? '') as String,
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        listed: (j['listed'] ?? false) as bool,
        verified: (j['verified'] ?? false) as bool,
        blocked: (j['blocked'] ?? false) as bool,
        commissionPct: (j['commission_pct'] as num?)?.toDouble(),
        members: (j['members'] as num?)?.toInt() ?? 0,
        cards: (j['cards'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.tryParse((j['created_at'] ?? '') as String),
      );
}

/// A customer's "I need this part", in the platform's queue.
@immutable
class PlatformRequest {
  const PlatformRequest({
    required this.id,
    required this.code,
    this.vehicleText = '',
    this.partName = '',
    this.detail = '',
    this.photos = const [],
    this.status = 'pending',
    this.quote,
    this.note = '',
    this.garageId,
    this.createdAt,
  });

  final String id;
  final String code;
  final String vehicleText;
  final String partName;
  final String detail;
  final List<String> photos;
  final String status;
  final double? quote;
  final String note;
  final String? garageId;
  final DateTime? createdAt;

  factory PlatformRequest.fromJson(Map<String, dynamic> j) => PlatformRequest(
        id: (j['id'] ?? '') as String,
        code: (j['code'] ?? '') as String,
        vehicleText: (j['vehicle_text'] ?? '') as String,
        partName: (j['part_name'] ?? '') as String,
        detail: (j['detail'] ?? '') as String,
        photos: ((j['photos'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(growable: false),
        status: (j['status'] ?? 'pending') as String,
        quote: (j['quote'] as num?)?.toDouble(),
        note: (j['note'] ?? '') as String,
        garageId: j['garage_id'] as String?,
        createdAt: DateTime.tryParse((j['created_at'] ?? '') as String),
      );
}

/// A part listing awaiting a decision.
@immutable
class PlatformListing {
  const PlatformListing({
    required this.id,
    this.title = '',
    this.detail = '',
    this.partNo = '',
    this.condition = 'used',
    this.price = 0,
    this.photos = const [],
    this.vehicleText = '',
    this.city = '',
    this.status = 'pending',
    this.rejectNote = '',
    this.createdAt,
  });

  final String id;
  final String title;
  final String detail;
  final String partNo;
  final String condition;
  final double price;
  final List<String> photos;
  final String vehicleText;
  final String city;
  final String status;
  final String rejectNote;
  final DateTime? createdAt;

  factory PlatformListing.fromJson(Map<String, dynamic> j) => PlatformListing(
        id: (j['id'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        detail: (j['detail'] ?? '') as String,
        partNo: (j['part_no'] ?? '') as String,
        condition: (j['condition'] ?? 'used') as String,
        price: (j['price'] as num?)?.toDouble() ?? 0,
        photos: ((j['photos'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(growable: false),
        vehicleText: (j['vehicle_text'] ?? '') as String,
        city: (j['city'] ?? '') as String,
        status: (j['status'] ?? 'pending') as String,
        rejectNote: (j['reject_note'] ?? '') as String,
        createdAt: DateTime.tryParse((j['created_at'] ?? '') as String),
      );
}

/// One line of the commission ledger.
@immutable
class CommissionLine {
  const CommissionLine({
    required this.id,
    required this.garageId,
    this.garageName = '',
    this.amount = 0,
    this.pct = kDefaultCommissionPct,
    this.fee = 0,
    this.status = 'accrued',
    this.note = '',
    this.at,
    this.jobCardId,
  });

  final String id;
  final String garageId;
  final String garageName;
  final double amount;
  final double pct;
  final double fee;
  final String status;
  final String note;
  final DateTime? at;

  /// Set on a line the database booked itself when the card closed; null on
  /// one recorded by hand.
  final String? jobCardId;

  factory CommissionLine.fromJson(Map<String, dynamic> j) => CommissionLine(
        id: (j['id'] ?? '') as String,
        garageId: (j['garage_id'] ?? '').toString(),
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        pct: (j['pct'] as num?)?.toDouble() ?? kDefaultCommissionPct,
        fee: (j['fee'] as num?)?.toDouble() ?? 0,
        status: (j['status'] ?? 'accrued') as String,
        note: (j['note'] ?? '') as String,
        at: DateTime.tryParse((j['at'] ?? '') as String),
        jobCardId: j['job_card_id'] as String?,
      );
}

/// The platform's rate when nothing else is set, and the band a rate must
/// sit in: never under 3%, and a 10% ceiling against a typo. The database
/// enforces both (21_private_commission.sql); these are here so the screen
/// can say so before it asks.
const double kDefaultCommissionPct = 3;
const double kMinCommissionPct = 3;
const double kMaxCommissionPct = 10;

/// One partner's commission, added up by the database
/// (`commission_summary()`), not from whatever lines happen to be loaded.
@immutable
class GarageCommission {
  const GarageCommission({
    required this.garageId,
    required this.name,
    this.phone = '',
    this.rate = kDefaultCommissionPct,
    this.customRate,
    this.lines = 0,
    this.billed = 0,
    this.accrued = 0,
    this.invoiced = 0,
    this.settled = 0,
    this.waived = 0,
    this.recent = const [],
  });

  final String garageId;
  final String name;
  final String phone;

  /// What the next closed card is charged at.
  final double rate;

  /// This garage's own rate, or null when it follows the default.
  final double? customRate;
  final int lines;

  /// Work billed before GST across its lines, waived ones excluded.
  final double billed;
  final double accrued;
  final double invoiced;
  final double settled;
  final double waived;

  /// The latest lines, newest first. Only `my_commission()` sends them.
  final List<CommissionLine> recent;

  /// What the partner still has to pay.
  double get owed => accrued + invoiced;

  factory GarageCommission.fromJson(Map<String, dynamic> j) {
    double n(String k) => (j[k] as num?)?.toDouble() ?? 0;
    return GarageCommission(
      garageId: (j['garage_id'] ?? '').toString(),
      name: (j['name'] ?? '') as String,
      phone: (j['phone'] ?? '') as String? ?? '',
      rate: (j['rate'] as num?)?.toDouble() ?? kDefaultCommissionPct,
      customRate: (j['custom_rate'] as num?)?.toDouble(),
      lines: (j['lines'] as num?)?.toInt() ?? 0,
      billed: n('billed'),
      accrued: n('accrued'),
      invoiced: n('invoiced'),
      settled: n('settled'),
      waived: n('waived'),
      recent: ((j['recent'] as List?) ?? const [])
          .map((r) => CommissionLine.fromJson(Map<String, dynamic>.from(r)))
          .toList(growable: false),
    );
  }
}

/// Platform-wide settings: the default commission and the welcome video.
@immutable
class PlatformSettings {
  const PlatformSettings({
    this.commissionPct = kDefaultCommissionPct,
    this.introVideoUrl = '',
    this.introVideoOn = false,
  });

  final double commissionPct;
  final String introVideoUrl;
  final bool introVideoOn;

  factory PlatformSettings.fromJson(Map<String, dynamic> j) => PlatformSettings(
        commissionPct: (j['commission_pct'] as num?)?.toDouble() ??
            kDefaultCommissionPct,
        introVideoUrl: (j['intro_video_url'] ?? '') as String,
        introVideoOn: (j['intro_video_on'] ?? false) as bool,
      );
}

/// Everything the platform admin can do that a garage owner cannot.
///
/// Every method here is gated at the database, not here: the functions this
/// calls check `is_platform_admin()` themselves and the tables carry policies
/// that say the same thing. A console that somehow reached these screens
/// without the role would get empty lists and refused writes, which is the
/// correct outcome and the reason the screens can be this plain.
class PlatformGateway {
  PlatformGateway._();

  static final PlatformGateway instance = PlatformGateway._();

  SupabaseClient? get _client =>
      AuthService.instance.enabled ? Supabase.instance.client : null;

  /// Whether the signed-in account runs the register. Drives whether the
  /// console shows the platform section at all.
  Future<bool> amPlatformAdmin() async => await checkPlatformAdmin() ?? false;

  /// [amPlatformAdmin], but null when the question could not be asked, so
  /// a dropped connection is not mistaken for "not a head".
  Future<bool?> checkPlatformAdmin() async {
    final client = _client;
    if (client == null) return false;
    try {
      final res = await client.rpc('is_platform_admin');
      return res == true;
    } catch (e) {
      debugPrint('is_platform_admin failed: $e');
      return null;
    }
  }

  // -------------------------------------------------------------------------
  // Partner heads
  // -------------------------------------------------------------------------

  /// Every partner head, on or off. Null when the list could not be read.
  Future<List<PlatformHead>?> heads() async {
    final client = _client;
    if (client == null) return null;
    try {
      final res = await client.rpc('list_platform_heads');
      return ((res as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PlatformHead.fromJson)
          .toList(growable: false);
    } catch (e) {
      debugPrint('list_platform_heads failed: $e');
      return null;
    }
  }

  /// Switches one head's platform access on or off. Returns an error
  /// sentence, or null. The database refuses to switch off the last head
  /// that is on, and says so in words fit to show.
  Future<String?> setHead(String email, bool enabled) async {
    final client = _client;
    if (client == null) return 'No connection to the backend.';
    try {
      await client.rpc('set_platform_head', params: {
        'head_email': email,
        'head_enabled': enabled,
      });
      return null;
    } on PostgrestException catch (e) {
      debugPrint('set_platform_head failed: $e');
      return e.code == '23514' || e.code == '42501'
          ? e.message
          : 'Could not save that. Try again in a moment.';
    } catch (e) {
      debugPrint('set_platform_head failed: $e');
      return 'Could not save that. Try again in a moment.';
    }
  }

  /// Adds [email] as a partner head, switched on (33_add_partner_head.sql).
  /// Returns an error sentence, or null. A bad address, one already on the
  /// list, and a caller who is not a head come back in words fit to show.
  Future<String?> addHead(String email) async {
    final client = _client;
    if (client == null) return 'No connection to the backend.';
    try {
      await client.rpc('add_platform_head', params: {'head_email': email});
      return null;
    } on PostgrestException catch (e) {
      debugPrint('add_platform_head failed: $e');
      return const {'22023', '23505', '42501'}.contains(e.code)
          ? e.message
          : 'Could not add that head. Try again in a moment.';
    } catch (e) {
      debugPrint('add_platform_head failed: $e');
      return 'Could not add that head. Try again in a moment.';
    }
  }

  // -------------------------------------------------------------------------
  // The register
  // -------------------------------------------------------------------------

  /// Null when the register could not be read — the screen says so rather
  /// than showing "No partners yet" for what is really a failed request.
  Future<List<RegisteredGarage>?> garages() async {
    final client = _client;
    if (client == null) return null;
    try {
      final res = await client.rpc('platform_garages');
      final rows = (res as List?) ?? const [];
      return rows
          .whereType<Map<String, dynamic>>()
          .map(RegisteredGarage.fromJson)
          .toList(growable: false);
    } catch (e) {
      debugPrint('platform_garages failed: $e');
      return null;
    }
  }

  /// Drops this workshop's pin, which is what puts it on the customer app's
  /// map. Returns an error sentence, or null.
  ///
  /// Without a coordinate a garage is invisible to `nearby_garages()` the
  /// moment the customer taps one of the 1 / 5 / 10 km chips: a radius
  /// filter cannot honestly include a workshop of unknown place, so it
  /// excludes it. Setup reads a real fix off the phone to fill the address
  /// in and used to throw the numbers away immediately afterwards, which is
  /// how a workshop ended up on the register with an address and no pin.
  ///
  /// A partner may move their own pin and nothing else. `listed`,
  /// `verified` and the commission rate are the platform's, and
  /// `set_garage_location` simply never reads them from the payload.
  Future<String?> setLocation(
    String garageId, {
    double? lat,
    double? lng,
    String? addressLine,
    String? city,
    String? district,
    String? state,
    String? pin,
  }) async {
    final client = _client;
    if (client == null) return 'No connection to the backend.';
    try {
      await client.rpc('set_garage_location', params: {
        'payload': {
          'garage_id': garageId,
          'lat': ?lat,
          'lng': ?lng,
          'address_line': ?addressLine,
          'city': ?city,
          'district': ?district,
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

  /// Listing and verifying. Returns an error sentence, or null. The rate has
  /// its own call, [setGarageRate].
  Future<String?> setListing(
    String garageId, {
    bool? listed,
    bool? verified,
    bool? blocked,
  }) async {
    final client = _client;
    if (client == null) return 'No connection to the backend.';
    try {
      await client.rpc('set_garage_listing', params: {
        'payload': {
          'garage_id': garageId,
          'listed': ?listed,
          'verified': ?verified,
          'blocked': ?blocked,
        }
      });
      return null;
    } on PostgrestException catch (e) {
      debugPrint('set_garage_listing failed: $e');
      // 29_block_and_district.sql words this one for the screen.
      if (e.code == '23514') return e.message;
      return 'Could not save that. Try again in a moment.';
    } catch (e) {
      debugPrint('set_garage_listing failed: $e');
      return 'Could not save that. Try again in a moment.';
    }
  }

  // -------------------------------------------------------------------------
  // Part requests
  // -------------------------------------------------------------------------

  /// [garageId] narrows it to the requests addressed to one workshop — what
  /// a garage owner sees from Buy & Sell. Null on failure.
  Future<List<PlatformRequest>?> requests({
    String? status,
    String? garageId,
  }) async {
    final client = _client;
    if (client == null) return null;
    try {
      var q = client.from('part_requests').select();
      if (status != null) q = q.eq('status', status);
      if (garageId != null) q = q.eq('garage_id', garageId);
      final rows = await q.order('created_at', ascending: false);
      return rows
          .map((r) => PlatformRequest.fromJson(Map<String, dynamic>.from(r)))
          .toList(growable: false);
    } catch (e) {
      debugPrint('requests failed: $e');
      return null;
    }
  }

  /// Moving a request along and pricing it. The guard trigger ignores every
  /// one of these fields unless the caller is the platform admin.
  Future<String?> updateRequest(
    String id, {
    String? status,
    double? quote,
    String? note,
    String? garageId,
  }) async {
    final client = _client;
    if (client == null) return 'No connection to the backend.';
    try {
      await client.from('part_requests').update({
        'status': ?status,
        'quote': ?quote,
        'note': ?note,
        'garage_id': ?garageId,
      }).eq('id', id);
      return null;
    } catch (e) {
      debugPrint('updateRequest failed: $e');
      return 'Could not update that request.';
    }
  }

  // -------------------------------------------------------------------------
  // Listings
  // -------------------------------------------------------------------------

  /// [garageId] narrows it to the listings addressed to one workshop. Without
  /// it a garage owner was shown every approved listing on the platform —
  /// the browse policy lets anyone read those — with Approve and Reject
  /// buttons on other workshops' rows that reported success and changed
  /// nothing. Null on failure.
  Future<List<PlatformListing>?> listings({
    String? status,
    String? garageId,
  }) async {
    final client = _client;
    if (client == null) return null;
    try {
      var q = client.from('part_listings').select();
      if (status != null) q = q.eq('status', status);
      if (garageId != null) q = q.eq('garage_id', garageId);
      final rows = await q.order('created_at', ascending: false);
      return rows
          .map((r) => PlatformListing.fromJson(Map<String, dynamic>.from(r)))
          .toList(growable: false);
    } catch (e) {
      debugPrint('listings failed: $e');
      return null;
    }
  }

  /// Approving or rejecting. A rejection without a reason is allowed by the
  /// database but discouraged by the screen — the seller sees this text and
  /// has nothing else to go on.
  Future<String?> decideListing(
    String id, {
    required bool approve,
    String rejectNote = '',
  }) async {
    final client = _client;
    if (client == null) return 'No connection to the backend.';
    try {
      await client.from('part_listings').update({
        'status': approve ? 'approved' : 'rejected',
        'reject_note': approve ? '' : rejectNote.trim(),
      }).eq('id', id);
      return null;
    } catch (e) {
      debugPrint('decideListing failed: $e');
      return 'Could not save that decision.';
    }
  }

  // -------------------------------------------------------------------------
  // Commission
  // -------------------------------------------------------------------------

  /// One partner's latest lines — the platform looks at partners one at a
  /// time, never at a ledger of everybody's mixed together.
  Future<List<CommissionLine>?> commissions(String garageId) async {
    final client = _client;
    if (client == null) return null;
    try {
      final rows = await client
          .from('commissions')
          .select()
          .eq('garage_id', garageId)
          .order('at', ascending: false)
          .limit(50);
      return rows
          .map((r) => CommissionLine.fromJson(Map<String, dynamic>.from(r)))
          .toList(growable: false);
    } catch (e) {
      debugPrint('commissions failed: $e');
      return null;
    }
  }

  Future<String?> bookCommission({
    required String garageId,
    required double amount,
    double? pct,
    String? jobCardId,
    String note = '',
  }) async {
    final client = _client;
    if (client == null) return 'No connection to the backend.';
    try {
      await client.rpc('book_commission', params: {
        'payload': {
          'garage_id': garageId,
          'amount': amount,
          'pct': ?pct,
          'job_card_id': ?jobCardId,
          'note': note,
        }
      });
      return null;
    } catch (e) {
      debugPrint('book_commission failed: $e');
      return 'Could not record that commission.';
    }
  }

  Future<String?> setCommissionStatus(String id, String status) async {
    final client = _client;
    if (client == null) return 'No connection to the backend.';
    try {
      await client.from('commissions').update({'status': status}).eq('id', id);
      return null;
    } catch (e) {
      debugPrint('setCommissionStatus failed: $e');
      return 'Could not update that line.';
    }
  }

  /// Every partner with what it owes, totalled by the database. Empty for
  /// anybody but the platform account, and on any failure.
  Future<List<GarageCommission>?> commissionSummary() async {
    final client = _client;
    if (client == null) return null;
    try {
      final res = await client.rpc('commission_summary');
      return ((res as List?) ?? const [])
          .map((r) => GarageCommission.fromJson(Map<String, dynamic>.from(r)))
          .toList(growable: false);
    } catch (e) {
      debugPrint('commission_summary failed: $e');
      return null;
    }
  }

  /// This workshop's own commission, for its owner (21_private_commission.sql).
  /// `ok` is false when it could not be read; `mine` is null when the
  /// signed-in account does not own [garageId] — a staff login, say.
  Future<({bool ok, GarageCommission? mine})> myCommission(
    String garageId,
  ) async {
    final client = _client;
    if (client == null) return (ok: false, mine: null);
    try {
      final res = await client.rpc(
        'my_commission',
        params: {'gid': garageId},
      );
      if (res is! Map) return (ok: true, mine: null);
      return (
        ok: true,
        mine: GarageCommission.fromJson(Map<String, dynamic>.from(res)),
      );
    } catch (e) {
      debugPrint('my_commission failed: $e');
      return (ok: false, mine: null);
    }
  }

  /// Marks everything a partner owes — accrued and invoiced — as settled, for
  /// the day they pay. Lines already settled or waived are left alone.
  Future<String?> settleGarage(String garageId) async {
    final client = _client;
    if (client == null) return 'No connection to the backend.';
    try {
      await client
          .from('commissions')
          .update({'status': 'settled'})
          .eq('garage_id', garageId)
          .inFilter('status', const ['accrued', 'invoiced']);
      return null;
    } catch (e) {
      debugPrint('settleGarage failed: $e');
      return 'Could not mark that partner settled.';
    }
  }

  /// A partner's own rate, or null to put them back on the default. Only
  /// cards that close from now on are charged at it — a line books its rate
  /// the moment its card closes.
  Future<String?> setGarageRate(String garageId, double? pct) async {
    final client = _client;
    if (client == null) return 'No connection to the backend.';
    try {
      await client.rpc('set_garage_listing', params: {
        'payload': {'garage_id': garageId, 'commission_pct': pct},
      });
      return null;
    } catch (e) {
      debugPrint('setGarageRate failed: $e');
      return 'Could not save that rate.';
    }
  }

  // -------------------------------------------------------------------------
  // Settings and content
  // -------------------------------------------------------------------------

  Future<PlatformSettings> settings() async {
    final client = _client;
    if (client == null) return const PlatformSettings();
    try {
      final row =
          await client.from('platform_settings').select().eq('id', 1).single();
      return PlatformSettings.fromJson(Map<String, dynamic>.from(row));
    } catch (e) {
      debugPrint('platform settings failed: $e');
      return const PlatformSettings();
    }
  }

  Future<String?> saveSettings({
    double? commissionPct,
    String? introVideoUrl,
    bool? introVideoOn,
  }) async {
    final client = _client;
    if (client == null) return 'No connection to the backend.';
    try {
      await client.from('platform_settings').update({
        'commission_pct': ?commissionPct,
        'intro_video_url': ?introVideoUrl,
        'intro_video_on': ?introVideoOn,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', 1);
      return null;
    } catch (e) {
      debugPrint('saveSettings failed: $e');
      return 'Could not save the settings.';
    }
  }
}
