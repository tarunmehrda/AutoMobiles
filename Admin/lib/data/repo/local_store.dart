import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'admin_data.dart';

/// On-device persistence.
///
/// Two things keep this off the critical path. Writes are debounced, so
/// holding down a quantity stepper is one write rather than thirty. And the
/// snapshot is serialised on a background isolate: turning a full workshop
/// into a string is milliseconds of pure CPU, which is a dropped frame if it
/// happens while something is scrolling.
class LocalStore {
  LocalStore(this._prefs);

  static const String _key = 'garagepro.admin.v1';

  /// Deliberately outside the snapshot, because the snapshot is thrown away
  /// on sign-out and this must not be.
  static const String _registeredKey = 'garagepro.admin.registered';

  /// Who punched last on this handset.
  ///
  /// Device-scoped on purpose, so it is not in the snapshot: a workshop
  /// where three people share the counter phone wants each of them to find
  /// their own name still selected, and a workshop where everybody carries
  /// their own wants no selection step at all after the first time.
  static const String _puncherKey = 'garagepro.admin.puncher';

  final SharedPreferences _prefs;
  Timer? _debounce;

  /// Whether a workshop has ever been registered on this device.
  ///
  /// One bit, and it is the difference between "the lookup failed and this
  /// owner has a shop waiting upstream" and "the lookup failed and this is
  /// somebody's first run". The first deserves a retry; the second deserves
  /// the registration form, and holding them at a retry screen for a shop
  /// they have never opened is a dead end.
  bool get everRegistered => _prefs.getBool(_registeredKey) ?? false;

  Future<void> markRegistered() => _prefs.setBool(_registeredKey, true);

  String get lastPuncher => _prefs.getString(_puncherKey) ?? '';

  Future<void> setLastPuncher(String staffId) =>
      _prefs.setString(_puncherKey, staffId);

  static Future<LocalStore> open() async =>
      LocalStore(await SharedPreferences.getInstance());

  AdminData read() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const AdminData();
    try {
      return AdminData.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      // A corrupt or older payload must never brick the console.
      return const AdminData();
    }
  }

  void write(AdminData data) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), () {
      unawaited(_save(data));
    });
  }

  Future<void> _save(AdminData data) async {
    // `toJson` only allocates plain maps and lists on this thread; the
    // string building, which is the expensive half, happens elsewhere.
    final raw = await compute(jsonEncode, data.toJson());
    await _prefs.setString(_key, raw);
  }

  /// Writes now and waits for it — used on sign-out, where the next thing
  /// that happens may be the snapshot being thrown away.
  Future<void> flush(AdminData data) async {
    _debounce?.cancel();
    await _save(data);
  }

  Future<void> clear() async {
    _debounce?.cancel();
    await _prefs.remove(_key);
  }
}
