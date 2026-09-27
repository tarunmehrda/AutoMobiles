import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Where the phone is, and why it is not, when it is not.
///
/// Every screen that wants a location wants the same four answers — a fix, a
/// refusal it can explain, a settings switch that is off, or a timeout — so
/// this returns one object carrying all of them rather than throwing and
/// making each caller write the same try/catch.
///
/// Nothing here asks for a permission the app has not already explained. The
/// search screen shows what location is for before it calls [fix], because a
/// system dialog that arrives unannounced is the one people refuse forever.
@immutable
class LocationFix {
  const LocationFix({this.lat, this.lng, this.problem = LocationProblem.none});

  const LocationFix.problem(LocationProblem p) : lat = null, lng = null,
        problem = p;

  final double? lat;
  final double? lng;
  final LocationProblem problem;

  bool get ok => lat != null && lng != null;

  /// What the screen says under the "use my location" button. Empty when
  /// there is nothing to apologise for.
  String get message => switch (problem) {
        LocationProblem.none => '',
        LocationProblem.serviceOff =>
          'Location is switched off on this phone. Turn it on, or search by '
              'PIN code instead.',
        LocationProblem.denied =>
          'Location permission was declined. You can still search by PIN code.',
        LocationProblem.deniedForever =>
          'Location is blocked for this app. Allow it in Settings, or search '
              'by PIN code instead.',
        LocationProblem.timeout =>
          'Could not get a fix — the sky may be blocked. Try again, or search '
              'by PIN code.',
        LocationProblem.failed =>
          'Could not read this phone\'s location. Search by PIN code instead.',
      };
}

enum LocationProblem { none, serviceOff, denied, deniedForever, timeout, failed }

class LocationService {
  LocationService._();

  static final LocationService instance = LocationService._();

  /// The last good fix this session. A search that reopens does not ask the
  /// GPS again from cold — the customer has not moved a kilometre between
  /// two screens, and a warm start is the difference between a list that is
  /// there and a spinner.
  LocationFix? _last;
  LocationFix? get last => _last;

  /// Ask the phone where it is.
  ///
  /// [precise] false accepts a fix the phone took in the last few minutes,
  /// which is all a "garages within 5 km" list needs. True always takes a
  /// fresh reading.
  ///
  /// Location switched off is not a dead end. Asking for a position with it
  /// off makes Android show its own "Turn on location" popup, and a yes
  /// carries straight on to the fix — so this does not check the switch and
  /// bail out first, which used to leave the customer with nothing but a
  /// snackbar.
  Future<LocationFix> fix({
    bool precise = false,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    try {
      final serviceOn = await Geolocator.isLocationServiceEnabled();

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        return _remember(
            const LocationFix.problem(LocationProblem.deniedForever));
      }
      if (perm == LocationPermission.denied) {
        return _remember(const LocationFix.problem(LocationProblem.denied));
      }

      // A fix the phone already has, if it is recent. Android hands this back
      // instantly and it is typically the same reading the GPS would spend
      // eight seconds re-deriving.
      if (!precise && serviceOn) {
        final cached = await Geolocator.getLastKnownPosition();
        if (cached != null &&
            DateTime.now().difference(cached.timestamp).inMinutes < 10) {
          return _remember(
              LocationFix(lat: cached.latitude, lng: cached.longitude));
        }
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          // High even for the search. Medium asks Android for its
          // battery-saving network fix, which on a phone with Google
          // Location Accuracy off may never answer; the partner screen
          // always asked for high and was the one that always worked.
          accuracy: LocationAccuracy.high,
          // The clock runs while the "Turn on location" popup waits on the
          // customer, so give them time to read it.
          timeLimit: serviceOn ? timeout : timeout + const Duration(seconds: 30),
        ),
      );
      return _remember(LocationFix(lat: pos.latitude, lng: pos.longitude));
    } on TimeoutException {
      return _remember(const LocationFix.problem(LocationProblem.timeout));
    } on LocationServiceDisabledException {
      return _remember(const LocationFix.problem(LocationProblem.serviceOff));
    } catch (e) {
      debugPrint('location fix failed: $e');
      return _remember(const LocationFix.problem(LocationProblem.failed));
    }
  }

  /// Opens the OS screen where a blocked permission can be un-blocked. There
  /// is no in-app route to that; the system owns it.
  Future<void> openSettings() async {
    try {
      await Geolocator.openAppSettings();
    } catch (e) {
      debugPrint('could not open app settings: $e');
    }
  }

  Future<void> openLocationSettings() async {
    try {
      await Geolocator.openLocationSettings();
    } catch (e) {
      debugPrint('could not open location settings: $e');
    }
  }

  /// Only a good fix is worth keeping — a refusal should be re-asked next
  /// time, because the customer may have just changed their mind in Settings.
  LocationFix _remember(LocationFix f) {
    if (f.ok) _last = f;
    return f;
  }

  void forget() => _last = null;
}
