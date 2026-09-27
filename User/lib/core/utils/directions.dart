import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Turn-by-turn directions to a workshop — Google Maps when the phone has
/// it, the browser when it does not.
///
/// The pin when there is one, because an address string can land on the
/// wrong street and a coordinate cannot; the address otherwise.
///
/// Launched without asking `canLaunchUrl` first. On Android 11+ that answers
/// false for any scheme the manifest has not declared, which is how the old
/// `geo:` link came to do nothing at all when tapped. Returns false when
/// nothing opened, so the button can say so instead of going quiet.
Future<bool> openDirections({
  double? lat,
  double? lng,
  String address = '',
}) async {
  final to = lat != null && lng != null ? '$lat,$lng' : address.trim();
  if (to.isEmpty) return false;
  final uri = Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': to,
  });
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e) {
    debugPrint('could not open directions: $e');
    return false;
  }
}
