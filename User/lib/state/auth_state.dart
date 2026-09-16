import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:supabase_flutter/supabase_flutter.dart' as supa show User;

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

/// Keeps the local [AppData.user] in step with the Supabase session.
///
/// Google returns through a deep link, which can land long after the sign-in
/// screen has been disposed — so the bridge lives here, watched once for the
/// life of the app, rather than in any one page.
final sessionSyncProvider = Provider<void>((ref) {
  void sync() {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    final meta = user.userMetadata ?? const {};
    ref.read(appControllerProvider.notifier).adoptSession(
          id: user.id,
          email: user.email,
          name: (meta['full_name'] ?? meta['name'] ?? '') as String?,
          phone: user.phone ?? meta['phone'] as String?,
          avatarUrl: (meta['avatar_url'] ?? meta['picture']) as String?,
        );
    ref.read(awaitingOAuthProvider.notifier).state = false;
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
