import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_config.dart';
import '../data/repo/auth_service.dart';
import 'admin_state.dart';

/// Every sign-in, sign-out, token refresh and OAuth return.
final authChangesProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(authServiceProvider).changes,
);

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
/// Without it the console still runs, gated by the on-device flag, on
/// whatever the workshop has typed into this device.
final signedInProvider = Provider<bool>((ref) {
  if (!AppConfig.hasSupabase) {
    return ref.watch(adminProvider.select((s) => s.signedIn));
  }
  return ref.watch(sessionProvider) != null;
});

/// True while a Google redirect is in flight and we are waiting to be
/// brought back — the login screen shows a spinner instead of the form.
final awaitingOAuthProvider = StateProvider<bool>((ref) => false);

/// True from the moment a session appears until the workshop behind it has
/// been fetched.
///
/// Without it the router decides whether this console needs registering
/// while the answer is still in flight: signing back in on an existing
/// account momentarily looks like a brand new one, so the gate throws the
/// owner at the registration form and then yanks them to the dashboard a
/// beat later. The router waits on this instead.
final restoringProvider = StateProvider<bool>((ref) => false);

/// True when the workshop behind this session could not be fetched — as
/// opposed to fetched and found not to exist.
///
/// The router reads this to decide what a missing workshop means. Without
/// it, a slow network on the way back in looks identical to a brand new
/// account and the owner is sent to register a shop they already have.
final restoreFailedProvider = StateProvider<bool>((ref) => false);

/// Raised when a reset link brings the app back, and lowered once the new
/// password has been saved.
///
/// A recovery link signs the owner in, so without this latch the console
/// would simply drop them on the dashboard — the old password still in
/// force and no form in sight.
final passwordRecoveryProvider = StateProvider<bool>((ref) => false);

/// How long the console will wait for the workshop before giving up and
/// carrying on with whatever is on the device. A dead network must not lock
/// somebody out of their own counter.
const _restoreTimeout = Duration(seconds: 12);

/// One attempt at fetching the workshop, with the two flags the router reads
/// raised and lowered around it. Shared by the automatic attempt on sign-in
/// and by the Retry button on the restoring screen.
Future<void> attemptRestore(
  AdminController ctrl, {
  required void Function(bool) setRestoring,
  required void Function(bool) setFailed,
}) async {
  setFailed(false);
  setRestoring(true);
  try {
    final outcome = await ctrl.connectBackend().timeout(
      _restoreTimeout,
      onTimeout: () => RestoreOutcome.unreachable,
    );
    setFailed(outcome == RestoreOutcome.unreachable);
  } finally {
    setRestoring(false);
  }
}

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

  void set(StateProvider<bool> p, bool v) {
    if (!ref.exists(p)) return;
    ref.read(p.notifier).state = v;
  }

  // Riverpod forbids writing to another provider while this one is still
  // building, so the flag is raised on the next microtask — still before
  // any frame the router could redirect on.
  Future.microtask(() {
    if (!signedIn) {
      set(restoringProvider, false);
      set(restoreFailedProvider, false);
      unawaited(ctrl.disconnectBackend());
      return;
    }
    // With no backend configured there is nothing to fetch, so holding the
    // router would only flash a loader at somebody working offline.
    if (!AppConfig.hasSupabase) {
      set(restoringProvider, false);
      set(restoreFailedProvider, false);
      return;
    }
    unawaited(
      attemptRestore(
        ctrl,
        setRestoring: (v) => set(restoringProvider, v),
        setFailed: (v) => set(restoreFailedProvider, v),
      ),
    );
  });
});

/// Listens for the recovery deep link and latches [passwordRecoveryProvider].
///
/// Watched next to [backendSyncProvider], high in the tree, because the link
/// can land long after the login screen has gone.
final passwordRecoveryWatchProvider = Provider<void>((ref) {
  ref.listen(authChangesProvider, (_, next) {
    if (next.valueOrNull?.event == AuthChangeEvent.passwordRecovery) {
      ref.read(passwordRecoveryProvider.notifier).state = true;
    }
  });
});
