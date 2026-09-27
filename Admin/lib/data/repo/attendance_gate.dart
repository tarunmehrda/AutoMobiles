import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../models/attendance.dart';

/// What one attempt to place the phone came back with.
///
/// Both halves matter. [block] is why the punch cannot go ahead, and the
/// rest is what the screen shows regardless — somebody eleven metres out
/// wants to see "11 m" and walk, not "too far" and guess which way.
@immutable
class GateReading {
  const GateReading({
    required this.block,
    this.lat = 0,
    this.lng = 0,
    this.accuracyM = 0,
    this.distanceM = 0,
    this.mocked = false,
    this.fixAt,
    this.note = '',
  });

  const GateReading.blocked(this.block, {this.note = ''})
    : lat = 0,
      lng = 0,
      accuracyM = 0,
      distanceM = 0,
      mocked = false,
      fixAt = null;

  final PunchBlock block;
  final double lat;
  final double lng;
  final double accuracyM;

  /// Metres from the designated site, as this device measures it. The
  /// backend recomputes it and does not take this number on trust.
  final double distanceM;

  final bool mocked;

  /// The instant the fix itself claims to be from, which is not always the
  /// instant it arrived.
  final DateTime? fixAt;

  /// Anything worth recording that is not itself grounds for refusal.
  final String note;

  bool get ok => block == PunchBlock.none;

  /// Whether a position was obtained at all, whatever the verdict on it.
  bool get located => fixAt != null;
}

/// Everything the phone can be asked about where it is, and how much of that
/// answer deserves to be believed.
///
/// Three things are checked here, in the order they get cheaper to fake:
///
/// 1. **The platform's own mock flag.** Since Android 6 the only supported
///    way to feed a device a false position is to register as a mock
///    location provider in developer options, and every fix that comes out
///    of one carries `isFromMockProvider`. This catches the whole Play
///    Store shelf of "Fake GPS" apps, which is what the overwhelming
///    majority of attendance fraud actually is.
/// 2. **A second opinion from a different provider.** Android has two ways
///    to a position — Google's fused client and the platform
///    `LocationManager` — and a hook usually only sits on one of them. Two
///    providers that disagree by more than their own stated accuracy is not
///    a phone having a bad day; it is something in between.
/// 3. **Physics.** A phone that was at the workshop a minute ago cannot be
///    forty kilometres away now, whatever it says.
///
/// What this cannot see is worth stating plainly, because a control nobody
/// has measured is worse than none: a rooted device running an LSPosed-style
/// hook inside the app's own process can lie about all three, and on iOS
/// `isMocked` is always false — spoofing there needs a jailbreak or a Mac
/// on the end of a cable. This is why [AttendanceGateway] runs the same
/// checks again server-side on numbers the client cannot influence, and why
/// blocked attempts are kept rather than discarded.
class AttendanceGate {
  const AttendanceGate._();

  /// Fixes taken per attempt. Enough to see whether the position moves at
  /// all, few enough not to leave somebody holding a phone in the rain.
  static const int _samples = 3;

  static const Duration _between = Duration(milliseconds: 900);
  static const Duration _perFix = Duration(seconds: 12);

  /// Nothing on the road does this, so anything faster is a teleport.
  /// Generous on purpose — an employee legitimately arriving on a highway
  /// bus must not be accused of anything.
  static const double _maxSpeedMps = 60; // ~216 km/h

  /// How far two providers may disagree before the disagreement is the
  /// finding. Added to whatever accuracy the two fixes claim for
  /// themselves, so a vague pair is judged vaguely.
  static const double _providerSlackM = 50;

  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Metres between two coordinates, by the same formula the database uses.
  static double distanceM(double lat1, double lng1, double lat2, double lng2) =>
      Geolocator.distanceBetween(lat1, lng1, lat2, lng2);

  /// Places the phone and judges the result against [site].
  ///
  /// [previous] is the last accepted punch by the same person, used for the
  /// teleport check. Null on somebody's first ever punch, which nothing can
  /// be concluded from.
  static Future<GateReading> read({
    required AttendanceSite? site,
    AttendancePunch? previous,
  }) async {
    if (!supported) return const GateReading.blocked(PunchBlock.unsupported);
    if (site == null) return const GateReading.blocked(PunchBlock.noSite);

    final PunchBlock gate;
    final List<Position> fixes;
    try {
      gate = await _permission();
      if (gate != PunchBlock.none) return GateReading.blocked(gate);
      fixes = await _sample();
    } on TimeoutException {
      return const GateReading.blocked(PunchBlock.noFix);
    } on LocationServiceDisabledException {
      return const GateReading.blocked(PunchBlock.serviceOff);
    } catch (e) {
      // Deliberately everything. This runs on whatever handset the workshop
      // bought, through a plugin that can fail in ways neither end has a
      // typed exception for — a missing method channel, a null where an
      // enum was promised, a manufacturer's own location service. None of
      // those is a reason for the punch screen to go white; they are all
      // "no usable fix", which the screen already knows how to say.
      debugPrint('attendance fix failed: $e');
      return const GateReading.blocked(PunchBlock.noFix);
    }
    if (fixes.isEmpty) return const GateReading.blocked(PunchBlock.noFix);

    // A single mocked sample condemns the attempt. Averaging it away with
    // two honest ones would be a control that rewards feeding the app one
    // real fix in three.
    final mocked = fixes.any((f) => f.isMocked);

    // Otherwise the sharpest fix wins: they are all of the same spot, so
    // the tightest one is the best evidence about it.
    final best = fixes.reduce((a, b) => a.accuracy <= b.accuracy ? a : b);
    final distance = distanceM(
      best.latitude,
      best.longitude,
      site.lat,
      site.lng,
    );

    GateReading verdict(PunchBlock block, {String note = ''}) => GateReading(
      block: block,
      lat: best.latitude,
      lng: best.longitude,
      accuracyM: best.accuracy,
      distanceM: distance,
      mocked: mocked,
      fixAt: best.timestamp,
      note: note,
    );

    if (mocked) return verdict(PunchBlock.mocked);

    // Second opinion, before anything is decided on the first one.
    final second = await _crossCheck(best);
    if (second != null) {
      return verdict(PunchBlock.providerMismatch, note: second);
    }

    if (best.accuracy <= 0 || best.accuracy > site.maxAccuracyM) {
      return verdict(PunchBlock.inaccurate);
    }

    final jump = _teleport(previous, best);
    if (jump != null) return verdict(PunchBlock.jumped, note: jump);

    if (distance > site.radiusM) return verdict(PunchBlock.tooFar);

    return verdict(PunchBlock.none, note: _softNote(fixes));
  }

  // -------------------------------------------------------------------------
  // The pieces
  // -------------------------------------------------------------------------

  /// Permission and the two ways it can be useless even when granted: the
  /// phone's location switched off entirely, and iOS approximate mode.
  static Future<PunchBlock> _permission() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) return PunchBlock.blocked;
    if (perm == LocationPermission.denied) return PunchBlock.denied;

    if (!await Geolocator.isLocationServiceEnabled()) {
      return PunchBlock.serviceOff;
    }

    // "Precise: off" on iOS deliberately rounds the position to a few
    // kilometres. There is a way to ask for one-off full accuracy, and it
    // is worth asking before refusing somebody.
    try {
      if (await Geolocator.getLocationAccuracy() ==
          LocationAccuracyStatus.reduced) {
        final granted = await Geolocator.requestTemporaryFullAccuracy(
          purposeKey: 'attendance',
        );
        if (granted != LocationAccuracyStatus.precise) {
          return PunchBlock.reduced;
        }
      }
    } on PlatformException {
      // Android has no such notion, and an older iOS build may not answer.
      // Neither is a reason to refuse a punch.
    } on MissingPluginException {
      // Same.
    }
    return PunchBlock.none;
  }

  /// A short burst of fixes at the best accuracy the platform will give.
  static Future<List<Position>> _sample() async {
    final out = <Position>[];
    for (var i = 0; i < _samples; i++) {
      if (i > 0) await Future<void>.delayed(_between);
      try {
        out.add(
          await Geolocator.getCurrentPosition(
            locationSettings: _settings(force: false),
          ),
        );
      } on TimeoutException {
        // One slow fix does not sink the attempt; the caller only needs a
        // single usable sample, and an empty list is handled there.
        break;
      } on LocationServiceDisabledException {
        // Somebody switched GPS off between the check and the fix. Let it
        // out to `read`, which has a sentence for exactly this.
        rethrow;
      }
    }
    return out;
  }

  static LocationSettings _settings({required bool force}) => _android
      ? AndroidSettings(
          accuracy: LocationAccuracy.best,
          // The point of the second read: same question, different plumbing.
          forceLocationManager: force,
          timeLimit: _perFix,
        )
      : const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: _perFix,
        );

  /// Asks the platform `LocationManager` the same question the fused client
  /// was just asked, and returns a description of the disagreement if the
  /// two cannot be reconciled.
  ///
  /// Null means "nothing to report", which includes every case where a
  /// second opinion was not available — a phone with no Play Services, an
  /// indoor fix the raw provider never resolves. An absent witness is not
  /// evidence of guilt.
  static Future<String?> _crossCheck(Position first) async {
    if (!_android) return null;
    Position other;
    try {
      other = await Geolocator.getCurrentPosition(
        locationSettings: _settings(force: true),
      );
    } catch (_) {
      return null;
    }

    if (other.isMocked) {
      return 'the platform provider reported a mock position';
    }

    final apart = distanceM(
      first.latitude,
      first.longitude,
      other.latitude,
      other.longitude,
    );
    final allowed =
        math.max(first.accuracy, 0) +
        math.max(other.accuracy, 0) +
        _providerSlackM;
    if (apart <= allowed) return null;
    return 'the two location providers are ${apart.round()} m apart, which is more than their own accuracy explains';
  }

  /// Whether getting from [previous] to here in the time available would
  /// have taken a speed nothing travels at.
  static String? _teleport(AttendancePunch? previous, Position now) {
    if (previous == null || (previous.lat == 0 && previous.lng == 0)) {
      return null;
    }
    final seconds = now.timestamp.difference(previous.at).inSeconds;
    // A clock that says the last punch is in the future tells us nothing
    // about speed; the backend's own clock check is what catches that.
    if (seconds <= 0) return null;

    final moved = distanceM(
      previous.lat,
      previous.lng,
      now.latitude,
      now.longitude,
    );
    final mps = moved / seconds;
    if (mps <= _maxSpeedMps) return null;
    return '${(moved / 1000).toStringAsFixed(1)} km in ${(seconds / 60).toStringAsFixed(1)} min since the last punch';
  }

  /// Signals worth writing on the row but not worth refusing somebody over.
  ///
  /// A fix that never moves across three samples is what a replayed
  /// position looks like — and also what a phone sitting on a bench
  /// returning its cached fix looks like. It goes in the register's note
  /// column for the owner to read, and no further: an honest mechanic
  /// standing still must not be turned away by a heuristic this soft.
  static String _softNote(List<Position> fixes) {
    if (fixes.length < 2) return '';
    final first = fixes.first;
    final identical = fixes.every(
      (f) =>
          f.latitude == first.latitude &&
          f.longitude == first.longitude &&
          f.accuracy == first.accuracy,
    );
    if (!identical) return '';
    return 'position did not change across ${fixes.length} readings';
  }

  /// What to say, and what the person can do about it. Kept beside the
  /// checks so a new [PunchBlock] cannot be added without a sentence.
  static String explain(
    PunchBlock block, {
    AttendanceSite? site,
    GateReading? reading,
  }) => switch (block) {
    PunchBlock.none => 'You are at the workshop.',
    PunchBlock.unsupported =>
      'This device has no GPS, so attendance cannot be marked from it. Use the phone you carry on the floor.',
    PunchBlock.noSite =>
      'No attendance location has been set for this workshop yet. The owner sets it once, from the workshop itself.',
    PunchBlock.serviceOff =>
      'Location is switched off on the phone itself, so there is nothing for the app to read. Switch it on and try again.',
    PunchBlock.denied =>
      'Attendance needs to know where you are. Allow location and tap again.',
    PunchBlock.blocked =>
      'Location was refused for good, so the app can no longer ask. Open Settings, allow it, then come back.',
    PunchBlock.reduced =>
      'Your phone is only sharing an approximate location, which is vague to within a few kilometres. Turn on Precise Location for this app.',
    PunchBlock.noFix =>
      'No GPS fix arrived. Step outside or nearer a window and try again.',
    PunchBlock.inaccurate =>
      site == null
          ? 'The fix is too vague to place you.'
          : 'The fix is only good to ±${(reading?.accuracyM ?? 0).round()} m, which cannot prove you are inside a ${_metres(site.radiusM)} circle. Step outside, wait for the GPS to settle, and try again.',
    PunchBlock.mocked =>
      'This phone is reporting a simulated position. Attendance cannot be marked while a mock location app is active — turn it off in developer options.',
    PunchBlock.providerMismatch =>
      'The phone is giving two different answers about where it is, which is what location spoofing looks like. Attendance has been refused and the attempt recorded.',
    PunchBlock.tooFar =>
      site == null
          ? 'You are outside the attendance area.'
          : 'You are ${_metres(reading?.distanceM ?? 0)} from the workshop. Attendance can be marked within ${_metres(site.radiusM)}.',
    PunchBlock.jumped =>
      'This phone was somewhere else moments ago, too far away to have travelled here since. The attempt has been recorded.',
    PunchBlock.clockOff =>
      "The phone's clock does not agree with the server's. Set the date and time to automatic and try again.",
    PunchBlock.outOfOrder =>
      'That punch does not follow the last one. Refresh the register and look at where the shift actually stands.',
    PunchBlock.refused =>
      'The workshop server refused this punch. Try again in a moment.',
    PunchBlock.offline =>
      'The workshop server could not be reached, so this punch has not been verified yet.',
  };

  /// Metres readably: sub-metre precision below ten, whole metres above,
  /// kilometres once metres stop meaning anything.
  static String _metres(double m) {
    if (m >= 1000) return '${(m / 1000).toStringAsFixed(1)} km';
    if (m >= 10) return '${m.round()} m';
    return '${m.toStringAsFixed(1)} m';
  }

  /// Public spelling of the same, for the screens.
  static String metres(double m) => _metres(m);
}
