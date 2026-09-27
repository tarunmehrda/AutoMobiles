import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final pushServiceProvider = Provider<PushService>((ref) => PushService.instance);

/// Alerts that reach a console which is not running.
///
/// Everything else in this app's notification path depends on the realtime
/// socket, and a socket needs a process to live in. Close the console at
/// six and the booking raised at seven lands in `garage_notifications`,
/// where it waits — correctly, durably, and entirely unseen until somebody
/// opens the app again. That is the gap this closes, and it is the only
/// gap it closes: a console that *is* running already learned about the
/// row over its own channel and shows it as a banner.
///
/// ## It is optional, on purpose
///
/// Push is the one part of this product that cannot run on the Supabase
/// project alone — it needs a Firebase project, a service account, and a
/// `google-services.json` in `android/app/`. A workshop that has not set
/// that up should still get a console that builds, runs and notifies
/// exactly as it did before, so every entry point here is guarded and
/// [enabled] is false until `Firebase.initializeApp()` actually succeeds.
/// Nothing calls into the plugin before that check.
///
/// See `docs/06-notifications.md` for the setup this expects.
class PushService {
  PushService._();

  static final PushService instance = PushService._();

  bool _ready = false;
  String? _token;
  StreamSubscription<String>? _refresh;

  final StreamController<String> _opened = StreamController<String>.broadcast();

  /// The route of a notification that launched the app cold, held until
  /// somebody listens. It used to go straight into [_opened] from `main()`,
  /// before the app was built — and a broadcast stream drops what nobody
  /// hears, so a tap on a closed console opened the dashboard, not the
  /// booking.
  String? _launchRoute;

  /// Whether a Firebase project was found on this build.
  bool get enabled => _ready;

  /// This handset's registration token, once [start] has run.
  String? get token => _token;

  /// Routes from notifications the user tapped while the app was in the
  /// background or not running at all, starting with the one that launched
  /// it, if one did.
  Stream<String> get openedRoutes async* {
    final first = _launchRoute;
    _launchRoute = null;
    if (first != null) yield first;
    yield* _opened.stream;
  }

  /// Brings Firebase up, if this build has it.
  ///
  /// Called from `main()` before the first frame, and deliberately never
  /// throws: an app that will not start because the push project is missing
  /// is a worse failure than an app that does not push.
  Future<void> init() async {
    if (_ready) return;
    try {
      await Firebase.initializeApp();
      _ready = true;
    } catch (e) {
      // The overwhelmingly common cause is no google-services.json, which
      // is a configuration state and not a fault.
      debugPrint('push disabled — no Firebase configuration: $e');
      return;
    }

    // A tap that launched the app cold. Read once, because the message is
    // consumed by reading it.
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    final launch = initial?.data['route'];
    if (launch is String && launch.isNotEmpty) _launchRoute = launch;

    FirebaseMessaging.onMessageOpenedApp.listen(_route);

    // `onMessage` is deliberately not listened to. A foreground console is
    // connected to its realtime channel, which has already delivered the
    // row and raised the in-app banner; showing a tray notification for the
    // same event would announce every booking twice.
  }

  /// Asks for permission, then hands the token to [register].
  ///
  /// Split from [init] because the two happen at different moments: Firebase
  /// comes up before the first frame, but a token is worth nothing until the
  /// console knows which workshop to file it under — so this runs once the
  /// backend session has joined its garage.
  Future<void> start(
    Future<void> Function(String token, String platform) register,
  ) async {
    if (!_ready) return;
    try {
      final messaging = FirebaseMessaging.instance;

      // On Android 13+ this is the POST_NOTIFICATIONS prompt; below that it
      // returns authorized without showing anything. A refusal is a real
      // answer — the counter does not want to be rung — so it is respected
      // rather than retried.
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

      // A token can be reissued at any time — a restore to a new handset, a
      // clear of app data, a Firebase-side rotation. Missing one is how a
      // workshop quietly stops being rung.
      await _refresh?.cancel();
      _refresh = messaging.onTokenRefresh.listen((next) {
        _token = next;
        unawaited(register(next, defaultTargetPlatform.name));
      });
    } catch (e) {
      debugPrint('push registration failed: $e');
    }
  }

  /// Stops this handset ringing, on the way out of a session.
  ///
  /// The token is deleted at the Firebase end as well as the workshop's, so
  /// the next person to sign in on this phone gets a new one rather than
  /// inheriting a registration filed under somebody else's garage.
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
  /// Xiaomi, Vivo and Oppo stop an idle app so hard that a booking pushed to
  /// a shut console can sit undelivered until it is opened. The fix used to
  /// be a trip through Settings → Apps → Battery; this is one tap on a
  /// system dialog. Asked once: a "Deny" is an answer.
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

  void _route(RemoteMessage message) {
    final route = message.data['route'];
    if (route is String && route.isNotEmpty && !_opened.isClosed) {
      _opened.add(route);
    }
  }
}
