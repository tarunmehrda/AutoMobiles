import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Sounds an alert the console shows while it is open.
///
/// A pushed alert arrives with its channel's sound. One that lands while
/// the app is in the foreground does not, because Android posts no
/// notification when the app is already showing — so the banner was
/// silent. On a shop floor that is a banner nobody sees: the phone is on
/// the bench and the counter is under a car.
///
/// The native side plays the same four WAVs the push channels use, keyed
/// the same way, so a booking sounds like a booking whether the console
/// happened to be open or not. It plays on the notification stream, so a
/// handset that has been silenced stays silent.
class AlertChime {
  const AlertChime._();

  static const _channel = MethodChannel('garagepro/alerts');

  /// [kind] is [GarageNotification.kind] — `booking`, `payment`,
  /// `reminder`, or anything else, which gets the general chime.
  ///
  /// Never throws. A chime is the least important thing on the screen and
  /// must not take the banner down with it: on a platform with no
  /// implementation, or if the audio fails, the banner still shows.
  static Future<void> play(String kind) async {
    try {
      await _channel.invokeMethod<void>('chime', {'kind': kind});
    } catch (e) {
      debugPrint('alert chime skipped: $e');
    }
  }
}
