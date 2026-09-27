import 'package:flutter/foundation.dart';

import '../../core/i18n/strings.dart';

DateTime? _date(Object? v) =>
    v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

String? _iso(DateTime? d) => d?.toUtc().toIso8601String();

double _num(Object? v) =>
    v == null ? 0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);

double? _maybe(Object? v) =>
    v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));

// ---------------------------------------------------------------------------
// The designated location
// ---------------------------------------------------------------------------

/// Where attendance may be marked, and how close somebody has to be.
///
/// One per workshop, kept on the garage row so it syncs with the letterhead
/// and cannot be edited into something different on each phone.
@immutable
class AttendanceSite {
  const AttendanceSite({
    required this.lat,
    required this.lng,
    this.radiusM = defaultRadiusM,
    this.maxAccuracyM = defaultMaxAccuracyM,
    this.label = '',
  });

  /// The radius the brief asks for.
  ///
  /// It is deliberately tight and deliberately adjustable. A consumer GPS
  /// fix is good to somewhere between three and fifteen metres in the open
  /// and worse under a metal roof, so a five metre circle is smaller than
  /// the instrument measuring it. That is a fact about the hardware, not
  /// something the app can code around: the honest options are to keep the
  /// circle and accept that staff will sometimes be told to step outside,
  /// or to widen it. [AttendanceSitePage] says so and lets the owner choose.
  static const double defaultRadiusM = 5;

  /// A fix vaguer than this is not evidence of anything at a five metre
  /// radius, so it is refused rather than rounded in the employee's favour.
  static const double defaultMaxAccuracyM = 25;

  final double lat;
  final double lng;
  final double radiusM;
  final double maxAccuracyM;

  /// What to call it on screen — "Main workshop", "Yard gate".
  final String label;

  AttendanceSite copyWith({
    double? lat,
    double? lng,
    double? radiusM,
    double? maxAccuracyM,
    String? label,
  }) => AttendanceSite(
    lat: lat ?? this.lat,
    lng: lng ?? this.lng,
    radiusM: radiusM ?? this.radiusM,
    maxAccuracyM: maxAccuracyM ?? this.maxAccuracyM,
    label: label ?? this.label,
  );

  @override
  bool operator ==(Object other) =>
      other is AttendanceSite &&
      other.lat == lat &&
      other.lng == lng &&
      other.radiusM == radiusM &&
      other.maxAccuracyM == maxAccuracyM &&
      other.label == label;

  @override
  int get hashCode => Object.hash(lat, lng, radiusM, maxAccuracyM, label);
}

// ---------------------------------------------------------------------------
// A punch
// ---------------------------------------------------------------------------

enum PunchKind { punchIn, punchOut }

extension PunchKindX on PunchKind {
  /// What goes on the wire and into the `kind` column.
  String get wire => this == PunchKind.punchIn ? 'in' : 'out';

  String get label =>
      this == PunchKind.punchIn ? 'Punch In'.tr : 'Punch Out'.tr;

  String get past => this == PunchKind.punchIn ? 'Punched in' : 'Punched out';

  static PunchKind parse(Object? v) =>
      '$v' == 'out' ? PunchKind.punchOut : PunchKind.punchIn;
}

/// Why a punch was refused.
///
/// Every one of these is a different sentence to the person holding the
/// phone, and a different thing for them to do about it. Collapsing them
/// into "could not punch in" is what leaves somebody tapping the same dead
/// button in the same spot for five minutes.
enum PunchBlock {
  /// Nothing wrong.
  none,

  /// No GPS on this platform at all — web and desktop.
  unsupported,

  /// No attendance location has been set for the workshop yet.
  noSite,

  /// Location is switched off for the whole phone.
  serviceOff,

  /// Refused this time; asking again is allowed.
  denied,

  /// Refused for good. Only Settings can undo it.
  blocked,

  /// iOS approximate location. It is deliberately vague to within a few
  /// kilometres, which is no use to a five metre circle.
  reduced,

  /// The fix never arrived.
  noFix,

  /// A fix arrived, but too vague to place anybody inside the radius.
  inaccurate,

  /// The phone itself says this position came from a mock provider.
  mocked,

  /// The two location providers disagree — something is intercepting one.
  providerMismatch,

  /// Outside the radius.
  tooFar,

  /// Further from the last punch than anybody could have travelled.
  jumped,

  /// The phone's clock does not agree with the server's.
  clockOff,

  /// Punching in twice, or out without being in.
  outOfOrder,

  /// The backend refused it for a reason this build does not know about.
  refused,

  /// Could not reach the backend to have it checked.
  offline,
}

extension PunchBlockX on PunchBlock {
  static PunchBlock parse(Object? v) => PunchBlock.values.firstWhere(
    (e) => e.wire == '$v',
    orElse: () => PunchBlock.refused,
  );

  /// The code the database speaks.
  String get wire => switch (this) {
    PunchBlock.none => 'ok',
    PunchBlock.unsupported => 'unsupported',
    PunchBlock.noSite => 'no_site',
    PunchBlock.serviceOff => 'service_off',
    PunchBlock.denied => 'denied',
    PunchBlock.blocked => 'blocked',
    PunchBlock.reduced => 'reduced',
    PunchBlock.noFix => 'no_fix',
    PunchBlock.inaccurate => 'inaccurate',
    PunchBlock.mocked => 'mocked',
    PunchBlock.providerMismatch => 'provider_mismatch',
    PunchBlock.tooFar => 'too_far',
    PunchBlock.jumped => 'jumped',
    PunchBlock.clockOff => 'clock_off',
    PunchBlock.outOfOrder => 'out_of_order',
    PunchBlock.refused => 'refused',
    PunchBlock.offline => 'offline',
  };

  /// Short enough for a pill on the register.
  String get short => switch (this) {
    PunchBlock.none => 'Verified'.tr,
    PunchBlock.unsupported => 'No GPS'.tr,
    PunchBlock.noSite => 'No location set'.tr,
    PunchBlock.serviceOff => 'GPS off'.tr,
    PunchBlock.denied => 'Not allowed'.tr,
    PunchBlock.blocked => 'Blocked'.tr,
    PunchBlock.reduced => 'Approximate only'.tr,
    PunchBlock.noFix => 'No fix'.tr,
    PunchBlock.inaccurate => 'Fix too vague'.tr,
    PunchBlock.mocked => 'Fake GPS'.tr,
    PunchBlock.providerMismatch => 'Spoofed'.tr,
    PunchBlock.tooFar => 'Too far'.tr,
    PunchBlock.jumped => 'Impossible jump'.tr,
    PunchBlock.clockOff => 'Clock wrong'.tr,
    PunchBlock.outOfOrder => 'Out of order'.tr,
    PunchBlock.refused => 'Refused'.tr,
    PunchBlock.offline => 'Not checked'.tr,
  };

  /// Whether this is somebody trying it on rather than a phone having a bad
  /// day. Drives the red treatment on the register.
  bool get isAbuse =>
      this == PunchBlock.mocked ||
      this == PunchBlock.providerMismatch ||
      this == PunchBlock.jumped ||
      this == PunchBlock.clockOff;
}

/// One row of the register.
///
/// Rejected attempts are kept alongside accepted ones. A blocked punch is
/// the only trace that somebody tried to mark themselves present from home,
/// and throwing it away would leave the owner with a register that looks
/// clean precisely because the interesting part was discarded.
@immutable
class AttendancePunch {
  const AttendancePunch({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.kind,
    required this.at,
    this.lat = 0,
    this.lng = 0,
    this.accuracyM = 0,
    this.distanceM = 0,
    this.mocked = false,
    this.accepted = true,
    this.block = PunchBlock.none,
    this.verified = false,
    this.note = '',
  });

  final String id;
  final String staffId;

  /// Held on the row rather than looked up. A mechanic who leaves is
  /// removed from the team, and last quarter's register should still say
  /// who was on the floor.
  final String staffName;

  final PunchKind kind;

  /// The server's clock on a verified punch, the phone's on an offline one.
  final DateTime at;

  final double lat;
  final double lng;

  /// The radius the phone claims this fix is good to.
  final double accuracyM;

  /// Metres from the designated location. Recomputed by the backend on a
  /// verified punch — never the number the phone sent.
  final double distanceM;

  /// What the device reported about its own position being simulated.
  final bool mocked;

  final bool accepted;

  /// Why it was refused, when it was.
  final PunchBlock block;

  /// Whether the backend re-ran the checks. False means the phone's word is
  /// all there is, which the register says out loud.
  final bool verified;

  final String note;

  AttendancePunch copyWith({bool? verified, String? note}) => AttendancePunch(
    id: id,
    staffId: staffId,
    staffName: staffName,
    kind: kind,
    at: at,
    lat: lat,
    lng: lng,
    accuracyM: accuracyM,
    distanceM: distanceM,
    mocked: mocked,
    accepted: accepted,
    block: block,
    verified: verified ?? this.verified,
    note: note ?? this.note,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'staff_id': staffId,
    'staff_name': staffName,
    'kind': kind.wire,
    'at': _iso(at),
    'lat': lat,
    'lng': lng,
    'accuracy_m': accuracyM,
    'distance_m': distanceM,
    'mocked': mocked,
    'accepted': accepted,
    'block': block.wire,
    'verified': verified,
    'note': note,
  };

  factory AttendancePunch.fromJson(Map<String, dynamic> j) => AttendancePunch(
    id: j['id'] as String,
    staffId: (j['staff_id'] ?? '') as String,
    staffName: (j['staff_name'] ?? '') as String,
    kind: PunchKindX.parse(j['kind']),
    at: _date(j['at']) ?? DateTime.now(),
    lat: _num(j['lat']),
    lng: _num(j['lng']),
    accuracyM: _num(j['accuracy_m']),
    distanceM: _num(j['distance_m']),
    mocked: (j['mocked'] ?? false) as bool,
    accepted: (j['accepted'] ?? true) as bool,
    block: PunchBlockX.parse(j['block'] ?? 'ok'),
    // A row that came back from the database has been through
    // `punch_attendance`, so it is verified by construction. A row read
    // from the on-device snapshot carries whatever it was written with.
    verified: (j['verified'] ?? false) as bool,
    note: (j['note'] ?? '') as String,
  );

  /// A row as the backend returns it, which is always a checked one.
  factory AttendancePunch.fromServer(Map<String, dynamic> j) =>
      AttendancePunch.fromJson({...j, 'verified': true});
}

/// Helpers the register and the punch screen both want, kept out of the
/// widgets so the shift arithmetic is testable on its own.
class Shift {
  const Shift._();

  /// Whether [staffId] is currently on the floor, by the last accepted
  /// punch they made.
  static bool onDuty(List<AttendancePunch> log, String staffId) =>
      lastAccepted(log, staffId)?.kind == PunchKind.punchIn;

  /// The most recent accepted punch for somebody.
  ///
  /// Scans by timestamp rather than trusting the list order. The register
  /// arrives newest-first from the server and grows newest-first on the
  /// device, but "which punch was last" decides whether the button says In
  /// or Out — too load-bearing to rest on an ordering convention holding.
  static AttendancePunch? lastAccepted(
    List<AttendancePunch> log,
    String staffId,
  ) {
    AttendancePunch? best;
    for (final p in log) {
      if (p.staffId != staffId || !p.accepted) continue;
      if (best == null || p.at.isAfter(best.at)) best = p;
    }
    return best;
  }

  /// What the button should offer next.
  static PunchKind next(List<AttendancePunch> log, String staffId) =>
      onDuty(log, staffId) ? PunchKind.punchOut : PunchKind.punchIn;

  /// Hours worked on one day, pairing each in with the out that follows it.
  ///
  /// An unmatched in — somebody still on the floor, or who forgot — pairs
  /// with nothing and contributes nothing, rather than silently counting to
  /// midnight.
  static Duration worked(List<AttendancePunch> dayLog, String staffId) {
    final rows =
        dayLog.where((p) => p.staffId == staffId && p.accepted).toList()
          ..sort((a, b) => a.at.compareTo(b.at));
    var total = Duration.zero;
    DateTime? since;
    for (final p in rows) {
      if (p.kind == PunchKind.punchIn) {
        since ??= p.at;
      } else if (since != null) {
        total += p.at.difference(since);
        since = null;
      }
    }
    return total;
  }
}

/// Parses the three site columns off a garage row. Null unless a location
/// has actually been pinned — a garage with no site set must not read as one
/// sitting at the equator.
AttendanceSite? siteFromJson(Map<String, dynamic> j) {
  final lat = _maybe(j['attendance_lat']);
  final lng = _maybe(j['attendance_lng']);
  if (lat == null || lng == null) return null;
  return AttendanceSite(
    lat: lat,
    lng: lng,
    radiusM: _maybe(j['attendance_radius_m']) ?? AttendanceSite.defaultRadiusM,
    maxAccuracyM:
        _maybe(j['attendance_max_accuracy_m']) ??
        AttendanceSite.defaultMaxAccuracyM,
    label: (j['attendance_label'] ?? '') as String,
  );
}

/// The same three columns on their way back out. Always written, so
/// clearing the site actually clears it upstream instead of leaving the old
/// pin in place.
Map<String, dynamic> siteToJson(AttendanceSite? s) => {
  'attendance_lat': s?.lat,
  'attendance_lng': s?.lng,
  'attendance_radius_m': s?.radiusM ?? AttendanceSite.defaultRadiusM,
  'attendance_max_accuracy_m':
      s?.maxAccuracyM ?? AttendanceSite.defaultMaxAccuracyM,
  'attendance_label': s?.label ?? '',
};
