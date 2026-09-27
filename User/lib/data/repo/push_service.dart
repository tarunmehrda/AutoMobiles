import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final pushServiceProvider = Provider<PushService>((ref) => PushService.instance);

/// Tray notifications for a customer whose app is shut.
///
/// While the app is open it already hears about the workshop's changes and
/// announces them itself (`AlertHost`). What it could not do was tell a
/// customer anything while it was closed: "your car is ready" waited until
/// they happened to open the app. The server now raises a row in
/// `customer_alerts` for each such moment (22_customer_push.sql), and the
/// `notify-garage` edge function sends it here through Firebase.
///
/// Optional in the same way as the console's: [enabled] stays false until
/// `Firebase.initializeApp()` succeeds, and every entry point is a no-op
/// until then, so a build without a Firebase project runs exactly as before.
class PushService {
  PushService._();

  static final PushService instance = PushService._();

  bool _ready = false;
  String? _token;
  StreamSubscription<String>? _refresh;

  /// The route of a notification that launched the app cold, held until
  /// somebody listens. Added to [_opened] straight away it was lost: the
  /// app was not built yet, and a broadcast stream drops what nobody hears.
  String? _launchRoute;

  final StreamController<String> _opened = StreamController<String>.broadcast();

  bool get enabled => _ready;

  /// Routes from tapped notifications, starting with the one that launched
  /// the app, if one did.
  Stream<String> get openedRoutes async* {
    final first = _launchRoute;
    _launchRoute = null;
    if (first != null) yield first;
    yield* _opened.stream;
  }

  /// Brings Firebase up, if this build has it. Called from `main()` before
  /// the first frame, and never throws.
  Future<void> init() async {
    if (_ready) return;
    try {
      await Firebase.initializeApp();
      _ready = true;
    } catch (e) {
      debugPrint('push disabled — no Firebase configuration: $e');
      return;
    }

    try {
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      _launchRoute = _routeOf(initial);
      FirebaseMessaging.onMessageOpenedApp.listen((m) {
        final route = _routeOf(m);
        if (route != null && !_opened.isClosed) _opened.add(route);
      });
    } catch (e) {
      debugPrint('push listeners failed: $e');
    }

    // `onMessage` (the app in the foreground) is deliberately not shown in
    // the tray: an open app has already announced the same update itself.
  }

  /// Asks for permission, then hands the token to [register]. Runs once
  /// the customer's account is known, because a token is filed under them.
  Future<void> start(
    Future<void> Function(String token, String platform) register,
  ) async {
    if (!_ready) return;
    try {
      final messaging = FirebaseMessaging.instance;

      // Android 13+ shows the notification prompt here; below that it
      // answers authorized without asking. A refusal is respected.
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('push permission declined');
        return;
      }

      final token = await messaging.getToken();
      if (token == null || token.isEmpty) return;
      _token = token;
      await register(token, defaultTargetPlatform.name);
      await _askToRunUnrestricted();

      await _refresh?.cancel();
      _refresh = messaging.onTokenRefresh.listen((next) {
        _token = next;
        unawaited(register(next, defaultTargetPlatform.name));
      });
    } catch (e) {
      debugPrint('push registration failed: $e');
    }
  }

  /// Stops this phone ringing for this account, on the way out. Must run
  /// while the session is still alive: the server forgets a token only for
  /// the account that registered it.
  Future<void> stop(Future<void> Function(String token) forget) async {
    final token = _token;
    _token = null;
    await _refresh?.cancel();
    _refresh = null;
    if (!_ready || token == null) return;
    try {
      await forget(token);
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint('push sign-out failed: $e');
    }
  }

  static const MethodChannel _power = MethodChannel('garagepro/power');
  static const String _askedKey = 'push.asked_unrestricted';

  /// Android's one-tap "let the app always run in the background?" dialog
  /// (MainActivity), shown once per install right after notifications are
  /// allowed.
  ///
  /// Xiaomi, Vivo and Oppo stop an idle app so hard that a push for a shut
  /// app can sit undelivered until it is opened again. The fix used to be a
  /// trip through Settings → Apps → Battery that no customer makes; this is
  /// one tap on a system dialog instead. Asked once: a "Deny" is an answer.
  Future<void> _askToRunUnrestricted() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_askedKey) ?? false) return;
      if (await _power.invokeMethod<bool>('runsUnrestricted') ?? true) return;
      await prefs.setBool(_askedKey, true);
      await _power.invokeMethod<void>('askToRunUnrestricted');
    } catch (e) {
      debugPrint('background-running prompt failed: $e');
    }
  }

  static String? _routeOf(RemoteMessage? message) {
    final route = message?.data['route'];
    return route is String && route.isNotEmpty ? route : null;
  }
}
