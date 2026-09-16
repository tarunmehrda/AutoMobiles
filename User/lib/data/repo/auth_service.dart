import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';

final authServiceProvider =
    Provider<AuthService>((ref) => AuthService.instance);

/// What every sign-in path hands back: whether it worked, and something the
/// UI can actually show a person if it did not.
@immutable
class AuthResult {
  const AuthResult._(this.ok, {this.message, this.needsConfirmation = false});

  const AuthResult.ok([String? message]) : this._(true, message: message);

  const AuthResult.failed(String message) : this._(false, message: message);

  /// The account exists but the email has not been confirmed yet.
  const AuthResult.pendingConfirmation(String message)
      : this._(true, message: message, needsConfirmation: true);

  final bool ok;
  final String? message;
  final bool needsConfirmation;
}

/// Everything to do with who is signed in.
///
/// Wraps Supabase so the rest of the app never imports it, and so every
/// failure arrives as a sentence a customer can read rather than a
/// stack trace.
class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  bool _ready = false;

  bool get enabled => AppConfig.hasSupabase && _ready;

  SupabaseClient? get _client => _ready ? Supabase.instance.client : null;

  User? get currentUser => _client?.auth.currentUser;
  Session? get session => _client?.auth.currentSession;
  String? get userId => currentUser?.id;
  bool get isSignedIn => session != null;

  /// Emits on sign-in, sign-out, token refresh and OAuth return.
  Stream<AuthState> get changes =>
      _client?.auth.onAuthStateChange ?? const Stream.empty();

  /// Called from main(). A missing or unreachable backend leaves the app
  /// running on its on-device store rather than failing to start.
  Future<void> init() async {
    if (!AppConfig.hasSupabase) return;
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        publishableKey: AppConfig.supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Supabase init skipped: $e');
      _ready = false;
    }
  }

  // -------------------------------------------------------------------------
  // Email and password
  // -------------------------------------------------------------------------

  /// Signs a customer up. `role: customer` rides along in the user metadata
  /// so the database trigger stamps the right role on their profile, and the
  /// phone links them to any garage that already has them on its books.
  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
    String name = '',
    String phone = '',
  }) async {
    if (!enabled) return const AuthResult.failed(_offline);
    try {
      final res = await _client!.auth.signUp(
        email: email.trim(),
        password: password,
        emailRedirectTo: kIsWeb ? null : AppConfig.authRedirect,
        data: {
          'full_name': name.trim(),
          'phone': phone.trim(),
          'role': 'customer',
        },
      );
      if (res.session != null) return const AuthResult.ok();
      return const AuthResult.pendingConfirmation(
          'Check your email and tap the confirmation link, then sign in.');
    } on AuthException catch (e) {
      return AuthResult.failed(_humanise(e));
    } catch (e) {
      debugPrint('signUp failed: $e');
      return AuthResult.failed(_describe(e));
    }
  }

  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (!enabled) return const AuthResult.failed(_offline);
    try {
      final res = await _client!.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return res.session == null
          ? const AuthResult.failed('That did not sign you in. Try again.')
          : const AuthResult.ok();
    } on AuthException catch (e) {
      return AuthResult.failed(_humanise(e));
    } catch (e) {
      debugPrint('signIn failed: $e');
      return AuthResult.failed(_describe(e));
    }
  }

  Future<AuthResult> sendPasswordReset(String email) async {
    if (!enabled) return const AuthResult.failed(_offline);
    try {
      await _client!.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: kIsWeb ? null : AppConfig.authRedirect,
      );
      return const AuthResult.ok(
          'Reset link sent. Check your inbox and spam folder.');
    } on AuthException catch (e) {
      return AuthResult.failed(_humanise(e));
    } catch (e) {
      debugPrint('reset failed: $e');
      return const AuthResult.failed(_generic);
    }
  }

  /// Used after the reset link brings the app back with a recovery session.
  Future<AuthResult> updatePassword(String password) async {
    if (!enabled) return const AuthResult.failed(_offline);
    try {
      await _client!.auth.updateUser(UserAttributes(password: password));
      return const AuthResult.ok('Password updated.');
    } on AuthException catch (e) {
      return AuthResult.failed(_humanise(e));
    } catch (e) {
      debugPrint('updatePassword failed: $e');
      return const AuthResult.failed(_generic);
    }
  }

  // -------------------------------------------------------------------------
  // Google
  // -------------------------------------------------------------------------

  /// Native first: Android's own account sheet, no browser involved. Google
  /// hands back an ID token and Supabase turns it into a session right here,
  /// so the caller gets a real result, not a promise of one.
  ///
  /// A browser round trip is kept only as a fallback. It is fragile on
  /// phones with a second user space (Xiaomi XSpace, Samsung Secure Folder,
  /// work profiles): the system can open the copy of Chrome living in that
  /// other space, where nothing handles our callback scheme, and the app
  /// waits on a spinner forever.
  Future<AuthResult> signInWithGoogle() async {
    if (!enabled) return const AuthResult.failed(_offline);
    if (kIsWeb) return _googleViaBrowser();

    try {
      await _googleReady;
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        return const AuthResult.failed('Google did not return a sign-in token.');
      }
      await _client!.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
      return const AuthResult.ok();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return const AuthResult.failed('Sign-in cancelled.');
      }
      // Anything else here is a device or project-configuration problem
      // (Play Services missing, the app's SHA-1 not registered in Google
      // Cloud, ...). Say so in the log, then let the browser have a go.
      debugPrint('native google sign-in unavailable (${e.code}): '
          '${e.description}');
      return _googleViaBrowser();
    } on AuthException catch (e) {
      return AuthResult.failed(_humanise(e));
    } catch (e) {
      debugPrint('google sign-in failed: $e');
      return AuthResult.failed(_isNetwork(e)
          ? _offline
          : 'Google sign-in is not available on this device.');
    }
  }

  /// One-time set-up of the native sign-in client, shared by every attempt.
  late final Future<void> _googleReady = GoogleSignIn.instance.initialize(
    serverClientId: AppConfig.googleWebClientId,
  );

  /// The browser flow. Returns as soon as the tab has been opened; the
  /// session arrives afterwards on [changes], which the router listens to.
  Future<AuthResult> _googleViaBrowser() async {
    try {
      final started = await _client!.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : AppConfig.authRedirect,
        // A Custom Tab rather than the system browser: it stays inside this
        // app's own task, so the deep link comes back to the instance that
        // opened it whenever the platform honours that.
        authScreenLaunchMode:
            kIsWeb ? LaunchMode.platformDefault : LaunchMode.inAppBrowserView,
        queryParams: const {'prompt': 'select_account'},
      );
      return started
          ? const AuthResult.ok()
          : const AuthResult.failed('Could not open Google sign-in.');
    } on AuthException catch (e) {
      return AuthResult.failed(_humanise(e));
    } catch (e) {
      debugPrint('google sign-in failed: $e');
      return AuthResult.failed(_isNetwork(e)
          ? _offline
          : 'Google sign-in is not available on this device.');
    }
  }

  Future<void> signOut() async {
    if (!enabled) return;
    try {
      await _client!.auth.signOut();
    } catch (e) {
      debugPrint('signOut failed: $e');
    }    // Forget the Google account too, so the next tap shows the chooser
    // instead of silently picking whoever signed in last time.
    if (!kIsWeb) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }
  }


  static const String _offline =
      'No connection to the backend. Check the network and try again.';
  static const String _generic = 'Something went wrong. Try again.';

  /// A dropped connection looks like a SocketException / ClientException
  /// rather than an AuthException, so it would otherwise surface as the
  /// generic message and hide the one thing the person can actually fix.
  static bool _isNetwork(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('socketexception') ||
        s.contains('clientexception') ||
        s.contains('failed host lookup') ||
        s.contains('connection refused') ||
        s.contains('network is unreachable') ||
        s.contains('connection reset');
  }

  static String _describe(Object e) => _isNetwork(e) ? _offline : _generic;

  /// Supabase messages are accurate but written for developers.
  static String _humanise(AuthException e) {
    final raw = e.message.toLowerCase();
    if (raw.contains('invalid login credentials')) {
      return 'That email and password do not match an account.';
    }
    if (raw.contains('email not confirmed')) {
      return 'Confirm your email first — check your inbox for the link.';
    }
    if (raw.contains('already registered') ||
        raw.contains('already been registered')) {
      return 'That email already has an account. Sign in instead.';
    }
    if (raw.contains('password should be at least')) {
      return 'Use a password of at least 6 characters.';
    }
    if (raw.contains('rate limit') || raw.contains('too many')) {
      return 'Too many attempts. Wait a minute and try again.';
    }
    if (raw.contains('unable to validate email')) {
      return 'That does not look like a valid email address.';
    }
    if (raw.contains('sms') || raw.contains('phone provider')) {
      return 'SMS sign-in is not switched on for this project yet.';
    }
    if (raw.contains('provider is not enabled') ||
        raw.contains('unsupported provider')) {
      return 'Google sign-in is not switched on for this project yet. '
          'Use email and password for now.';
    }
    return e.message;
  }
}
