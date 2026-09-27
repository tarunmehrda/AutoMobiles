import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:supabase_flutter/supabase_flutter.dart' as supa show User;

import '../core/config/app_config.dart';
import '../data/repo/auth_service.dart';
import 'app_state.dart';

/// Every sign-in, sign-out, token refresh and OAuth return.
final authChangesProvider = StreamProvider<AuthState>(
    (ref) => ref.watch(authServiceProvider).changes);

final sessionProvider = Provider<Session?>((ref) {
  ref.watch(authChangesProvider);
  return ref.watch(authServiceProvider).session;
});

final authUserProvider = Provider<supa.User?>((ref) {
  ref.watch(authChangesProvider);
  return ref.watch(authServiceProvider).currentUser;
});

/// True while a Google redirect is in flight.
final awaitingOAuthProvider = StateProvider<bool>((ref) => false);

/// True from the moment a session appears until this account has been pulled
/// back down from the backend.
///
/// Signing out wipes the device, so for a beat after signing back in the app
/// knows nothing about you. Deciding then whether you still need a profile
/// and a vehicle is what used to skip — or flash — the sign-up steps. The
/// router waits on this instead.
final restoringProvider = StateProvider<bool>((ref) => false);

/// How long to wait for the account before carrying on with whatever is on
/// the device. A dead network must not lock somebody out of their own garage.
const _restoreTimeout = Duration(seconds: 12);

/// Keeps the local [AppData.user] in step with the Supabase session, and
/// pulls the rest of the account down behind it.
///
/// Google returns through a deep link, which can land long after the sign-in
/// screen has been disposed — so the bridge lives here, watched once for the
/// life of the app, rather than in any one page.
final sessionSyncProvider = Provider<void>((ref) {
  // Which account the app has already restored, so a token refresh an hour
  // from now does not re-run the whole handshake.
  String? restoredFor;

  void setRestoring(bool v) {
    if (!ref.exists(restoringProvider)) return;
    ref.read(restoringProvider.notifier).state = v;
  }

  void sync() {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) {
      restoredFor = null;
      setRestoring(false);
      return;
    }

    final meta = user.userMetadata ?? const {};
    final ctrl = ref.read(appControllerProvider.notifier);
    ctrl.adoptSession(
      id: user.id,
      email: user.email,
      name: (meta['full_name'] ?? meta['name'] ?? '') as String?,
      phone: user.phone ?? meta['phone'] as String?,
      avatarUrl: (meta['avatar_url'] ?? meta['picture']) as String?,
    );
    ref.read(awaitingOAuthProvider.notifier).state = false;

    if (restoredFor == user.id) return;
    restoredFor = user.id;

    if (!AppConfig.hasSupabase) return;
    setRestoring(true);
    unawaited(ctrl
        .restoreAccount()
        .timeout(_restoreTimeout, onTimeout: () {})
        .whenComplete(() => setRestoring(false)));
  }

  ref.listen(authChangesProvider, (_, _) => sync());

  // The first pass has to wait until this provider has finished building:
  // Riverpod forbids a provider from modifying another one while it is
  // still initialising, and adoptSession does exactly that.
  var alive = true;
  ref.onDispose(() => alive = false);
  Future.microtask(() {
    if (alive) sync();
  });
});
