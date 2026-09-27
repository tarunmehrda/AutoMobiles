import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_data.dart';

/// On-device persistence.
///
/// Two things keep this off the critical path. Writes are debounced, so a
/// burst of state changes during an animation is one write rather than
/// thirty. And the snapshot is serialised on a background isolate: turning a
/// full account into a string is milliseconds of pure CPU, which is a
/// dropped frame if it happens mid-scroll.
class LocalStore {
  LocalStore(this._prefs);

  static const String _key = 'garagepro.appdata.v1';
  static const String _draftKey = 'garagepro.draft.v1';

  final SharedPreferences _prefs;
  Timer? _debounce;

  static Future<LocalStore> open() async =>
      LocalStore(await SharedPreferences.getInstance());

  AppData read() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const AppData();
    try {
      return AppData.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      // A corrupt or older payload must never brick the app.
      return const AppData();
    }
  }

  void write(AppData data) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), () {
      unawaited(_save(data));
    });
  }

  Future<void> _save(AppData data) async {
    // `toJson` only allocates plain maps and lists on this thread; the
    // string building, which is the expensive half, happens elsewhere.
    final raw = await compute(jsonEncode, data.toJson());
    await _prefs.setString(_key, raw);
  }

  Future<void> flush(AppData data) async {
    _debounce?.cancel();
    await _save(data);
  }

  Map<String, dynamic>? readDraft() {
    final raw = _prefs.getString(_draftKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  void writeDraft(Map<String, dynamic>? draft) {
    if (draft == null) {
      unawaited(_prefs.remove(_draftKey));
      return;
    }
    unawaited(_prefs.setString(_draftKey, jsonEncode(draft)));
  }

  /// What became of each booking request sent to a workshop from this
  /// phone: `pending` (could not be filed yet — try again) or `sent` (the
  /// workshop had it). Keyed by booking id.
  ///
  /// Device-local on purpose. It is not a fact about the booking, it is a
  /// fact about this phone's attempt to deliver it, and it is what lets the
  /// app tell "never arrived" (send it again) apart from "arrived and was
  /// declined" (tell the customer, and do not put it back on the desk).
  Map<String, String> readRequestStates() {
    final raw = _prefs.getString(_requestsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      return Map<String, String>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  void writeRequestStates(Map<String, String> states) {
    unawaited(_prefs.setString(_requestsKey, jsonEncode(states)));
  }

  static const String _requestsKey = 'garagepro.requests.v1';

  Future<void> clear() async {
    _debounce?.cancel();
    await _prefs.remove(_key);
    await _prefs.remove(_draftKey);
    await _prefs.remove(_requestsKey);
  }
}
