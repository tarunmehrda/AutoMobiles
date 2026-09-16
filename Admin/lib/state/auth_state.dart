import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_config.dart';
import '../data/repo/auth_service.dart';
import 'admin_state.dart';

/// Every sign-in, sign-out, token refresh and OAuth return.
final authChangesProvider = StreamProvider<AuthState>(
    (ref) => ref.watch(authServiceProvider).changes);

final sessionProvider = Provider<Session?>((ref) {
  // Depend on the stream so this recomputes the moment anything changes,
  // then read the live value rather than the event's snapshot.
  ref.watch(authChangesProvider);
  return ref.watch(authServiceProvider).session;
});

final authUserProvider = Provider<User?>((ref) {
  ref.watch(authChangesProvider);
  return ref.watch(authServiceProvider).currentUser;
});

/// The gate the router actually uses.
///
/// With Supabase configured, a real session is the only thing that counts.
/// Without it the console still runs, gated by the on-device flag, so the
/// app is demoable with no backend at all.
final signedInProvider = Provider<bool>((ref) {
  if (!AppConfig.hasSupabase) {
    return ref.watch(adminProvider.select((s) => s.signedIn));
  }
  return ref.watch(sessionProvider) != null;
});

/// True while a Google redirect is in flight and we are waiting to be
/// brought back — the login screen shows a spinner instead of the form.
final awaitingOAuthProvider = StateProvider<bool>((ref) => false);

/// Opens the backend connection when somebody signs in and closes it when
/// they leave.
///
/// Watched once, high in the widget tree, so the console is joined to its
/// workshop for the whole session — including when Google hands the app back
/// through a deep link long after the login screen is gone. It depends on a
/// bool rather than the session itself, so an hourly token refresh does not
/// re-run the handshake.
final backendSyncProvider = Provider<void>((ref) {
  final signedIn = ref.watch(signedInProvider);
  final ctrl = ref.read(adminProvider.notifier);
  if (signedIn) {
    unawaited(ctrl.connectBackend());
  } else {
    unawaited(ctrl.disconnectBackend());
  }
});
