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

  final SharedPreferences _prefs;
  Timer? _debounce;

  static Future<LocalStore> open() async =>
      LocalStore(await SharedPreferences.getInstance());

  AdminData read() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const AdminData();
    try {
      return AdminData.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map));
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
