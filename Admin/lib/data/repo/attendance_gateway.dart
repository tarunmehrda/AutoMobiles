import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/attendance.dart';
import 'garage_gateway.dart';

final attendanceGatewayProvider = Provider<AttendanceGateway>(
  (ref) => AttendanceGateway.instance,
);

/// What came back from an attempt to punch.
@immutable
class PunchResult {
  const PunchResult({
    required this.block,
    required this.punch,
    this.message = '',
  });

  final PunchBlock block;

  /// The row that was written, accepted or not. Null only when nothing was
  /// recorded anywhere.
  final AttendancePunch? punch;

  /// The backend's own words, when it had any. Preferred over the client's
  /// stock sentence, because the server knows the real distance.
  final String message;

  bool get ok => block == PunchBlock.none;
}

/// The attendance half of the wire.
///
/// Deliberately not part of [GarageGateway]'s diff-and-push machinery, and
/// the difference is the whole point of the feature. Every other table in
/// this console is offline-first: the phone decides, the row is mirrored
/// upstream, and the backend stores what it is given. That is exactly the
/// arrangement attendance must not have, because the phone is the thing
/// being checked.
///
/// So attendance runs the other way round. There is no insert policy on the
/// table at all — not for the owner, not for anybody — and the only way a
/// row appears is `punch_attendance()`, which re-derives the distance from
/// the coordinates, re-reads the radius from the garage row, stamps the time
/// from the server's own clock, and refuses what does not add up. A tampered
/// client can lie about where it is; it cannot lie about what that means.
class AttendanceGateway {
  AttendanceGateway._();

  static final AttendanceGateway instance = AttendanceGateway._();

  /// How much of the register a device keeps. Long enough for a month's
  /// payroll argument, short enough not to grow without bound.
  static const Duration window = Duration(days: 92);

  GarageGateway get _garage => GarageGateway.instance;

  bool get enabled => _garage.enabled && _garage.garageId != null;

  SupabaseClient? get _client =>
      _garage.enabled ? Supabase.instance.client : null;

  /// Submits a punch for checking and returns what the backend made of it.
  ///
  /// [distanceM] and [mocked] are sent as the device saw them, and are
  /// recorded rather than trusted: the row keeps both the phone's claim and
  /// the server's own finding, which is what makes a disagreement between
  /// them visible later.
  Future<PunchResult> punch({
    required String staffId,
    required String staffName,
    required PunchKind kind,
    required double lat,
    required double lng,
    required double accuracyM,
    required double distanceM,
    required bool mocked,
    DateTime? fixAt,
    String note = '',
  }) async {
    final client = _client;
    final gid = _garage.garageId;
    if (client == null || gid == null) {
      return PunchResult(
        block: PunchBlock.offline,
        punch: null,
        message:
            'No workshop server is configured, so this punch could not '
            'be verified.',
      );
    }

    try {
      final raw = await client.rpc(
        'punch_attendance',
        params: {
          'payload': {
            'garage_id': gid,
            'staff_id': staffId,
            'staff_name': staffName,
            'kind': kind.wire,
            'lat': lat,
            'lng': lng,
            'accuracy_m': accuracyM,
            'distance_m': distanceM,
            'mocked': mocked,
            'fix_at': fixAt?.toUtc().toIso8601String(),
            'note': note,
          },
        },
      );
      if (raw == null) {
        return const PunchResult(
          block: PunchBlock.refused,
          punch: null,
          message: 'The workshop server returned nothing.',
        );
      }

      final j = Map<String, dynamic>.from(raw as Map);
      final row = j['row'];
      return PunchResult(
        block: PunchBlockX.parse(j['code'] ?? 'refused'),
        punch: row == null
            ? null
            : AttendancePunch.fromServer(Map<String, dynamic>.from(row as Map)),
        message: (j['message'] ?? '') as String,
      );
    } catch (e) {
      debugPrint('punch_attendance failed: $e');
      return PunchResult(
        block: PunchBlock.offline,
        punch: null,
        message: _reason(e),
      );
    }
  }

  /// The register as the server holds it. Null — not an empty list — when it
  /// could not be reached, so a dropped connection never reads as "nobody
  /// came in today".
  Future<List<AttendancePunch>?> log() async {
    final client = _client;
    final gid = _garage.garageId;
    if (client == null || gid == null) return null;
    try {
      final raw = await client.rpc(
        'attendance_log',
        params: {
          'gid': gid,
          'since': DateTime.now().toUtc().subtract(window).toIso8601String(),
        },
      );
      if (raw is! List) return null;
      return raw
          .map(
            (e) =>
                AttendancePunch.fromServer(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } catch (e) {
      debugPrint('attendance_log failed: $e');
      return null;
    }
  }

  /// A missing function is a setup problem, not a network one — the same
  /// distinction [GarageGateway] draws, for the same reason.
  static String _reason(Object e) {
    final low = e.toString().toLowerCase();
    if (low.contains('could not find the function') ||
        low.contains('pgrst202')) {
      return 'This Supabase project has not had 05_attendance.sql run on it '
          'yet, so punches cannot be verified.';
    }
    if (low.contains('permission denied') ||
        low.contains('row-level security')) {
      return 'This account is not allowed to mark attendance at this '
          'workshop.';
    }
    return 'The workshop server could not be reached.';
  }
}
