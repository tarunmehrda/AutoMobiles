import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../data/models/enums.dart';

/// Sounds an update the workshop has just sent.
///
/// The banner alone is not enough. A customer is not watching this screen
/// — they are at work, or driving, or waiting — and an update that
/// appears silently is an update they find later by accident.
///
/// Two sounds, not six: "your booking is confirmed" is the one worth
/// interrupting for, and everything else shares a quieter chime. They are
/// the same WAVs the workshop console uses for the same events, so the two
/// apps sound like one product.
///
/// Played on the notification stream, so a phone that has been silenced
/// stays silent.
class AlertChime {
  const AlertChime._();

  static const _channel = MethodChannel('garagepro/alerts');

  static Future<void> play(NotifyKind kind) async {
    final sound = switch (kind) {
      NotifyKind.booking || NotifyKind.approval => 'booking',
      _ => 'general',
    };
    try {
      await _channel.invokeMethod<void>('chime', {'kind': sound});
    } catch (e) {
      // Never worth taking the banner down for.
      debugPrint('alert chime skipped: $e');
    }
  }
}
