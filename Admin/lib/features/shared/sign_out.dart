import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import '../../core/widgets/g_feedback.dart';
import '../../data/repo/auth_service.dart';
import '../../data/repo/garage_gateway.dart';
import '../../state/admin_state.dart';

/// Asks, then signs out and clears this phone for the next account.
///
/// Signing out removes the workshop's rows from the phone, including job
/// cards that have not reached the server yet — which then exist nowhere.
/// So when there are any, or when this session never reached the server and
/// cannot tell, the question says so before anything is lost.
Future<void> confirmSignOut(BuildContext context, WidgetRef ref) async {
  final data = ref.read(adminProvider);
  final unsent = ref.read(garageGatewayProvider).unsentCards(data);

  final String message;
  if (unsent == null && data.jobCards.isNotEmpty) {
    message = 'This phone has not reached the server since it opened. Any job card not sent yet is removed when you sign out.'.tr;
  } else if ((unsent ?? 0) > 0) {
    message = Tr.plural(
      unsent!,
      '{0} job card has not reached the server yet. Signing out removes it from this phone.',
      '{0} job cards have not reached the server yet. Signing out removes them from this phone.',
    );
  } else {
    message = 'Everything on this device is cleared. With no backend configured, there is no copy elsewhere.'.tr;
  }

  final ok = await GFeedback.confirm(
    context,
    title: 'Sign out?'.tr,
    message: message,
    confirmLabel: 'Sign out'.tr,
    destructive: true,
    icon: Icons.logout_rounded,
  );
  if (!ok || !context.mounted) return;
  await ref.read(authServiceProvider).signOut();
  await localStore.clear();
  ref.read(adminProvider.notifier).signOut();
}
