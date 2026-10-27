import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_surface.dart';
import '../../core/widgets/pressable.dart';
import '../../data/models/books.dart';
import '../../state/admin_state.dart';
import '../../state/auth_state.dart';
import '../../state/providers.dart';
import '../shared/sign_out.dart';

/// What the login screen should open on after a company switch: the email
/// form, filled in with the account being switched to, or the sign-up form
/// for a company that does not exist yet. Read once and cleared.
final loginHint = ValueNotifier<({String email, bool signUp})?>(null);

/// Switch company / Manage company / Add company.
///
/// Each workshop is its own account, and this phone holds one at a time —
/// the books of two companies are never on the counter together. Switching
/// is therefore a sign-out and a sign-in, with the email already typed: the
/// owner of three workshops on one phone (the usual case here) gets from
/// one to the next in a password.
Future<void> showCompanySheet(BuildContext context) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  builder: (_) => const _CompanySheet(),
);

class _CompanySheet extends ConsumerWidget {
  const _CompanySheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final garage = ref.watch(garageProvider);
    final access = ref.watch(accessProvider);
    final email = (ref.watch(authUserProvider)?.email ?? '').toLowerCase();
    final others = ref
        .watch(adminProvider.select((d) => d.knownCompanies))
        .where((c) => c.email != email)
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: p.canvas,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        Gap.page,
        Gap.md,
        Gap.page,
        Gap.xl + MediaQuery.paddingOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: p.line,
                  borderRadius: R.all(R.pill),
                ),
              ),
            ),
            const SizedBox(height: Gap.lg),
            Text('Your companies'.tr, style: AppType.h1.s(20).c(p.ink)),
            const SizedBox(height: Gap.xs),
            Text(
              'Each company keeps its own books. Switching signs this phone into the other one.'
                  .tr,
              style: AppType.bodyS.c(p.inkMuted),
            ),
            const SizedBox(height: Gap.lg),

            // --- the one open now ----------------------------------------
            _CompanyCard(
              name: garage?.name ?? 'Workshop'.tr,
              email: email,
              current: true,
            ),
            const SizedBox(height: Gap.md),

            // --- the others this phone knows ------------------------------
            if (others.isNotEmpty) ...[
              Text('SWITCH TO'.tr, style: AppType.over.c(p.inkFaint)),
              const SizedBox(height: Gap.sm),
              for (final c in others) ...[
                _CompanyCard(
                  name: c.name.isEmpty ? c.email : c.name,
                  email: c.email,
                  onTap: () => _switchTo(context, ref, c),
                  onForget: () =>
                      ref.read(adminProvider.notifier).forgetCompany(c.email),
                ),
                const SizedBox(height: Gap.sm),
              ],
              const SizedBox(height: Gap.sm),
            ],

            GTileGroup(
              children: [
                if (others.isEmpty)
                  GTile(
                    icon: Icons.swap_horiz_rounded,
                    iconColor: p.info,
                    title: 'Switch company'.tr,
                    subtitle: 'Sign in to another workshop account'.tr,
                    onTap: () => _switchTo(context, ref, null),
                  ),
                if (access.workshopSettings)
                  GTile(
                    icon: Icons.edit_note_rounded,
                    iconColor: p.accent,
                    title: 'Manage company'.tr,
                    subtitle: 'Name, address, GSTIN, logo and terms'.tr,
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push('/workshop');
                    },
                  ),
                GTile(
                  icon: Icons.add_business_rounded,
                  iconColor: p.success,
                  title: 'Add company'.tr,
                  subtitle: 'Open a new workshop with its own books'.tr,
                  onTap: () => _addCompany(context, ref),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Remembers this company, signs out, and lands on the login screen with
  /// [to]'s email typed in. Nothing happens if the owner backs out of the
  /// sign-out question, which is where unsent work is warned about.
  Future<void> _switchTo(
    BuildContext context,
    WidgetRef ref,
    KnownCompany? to,
  ) async {
    _rememberCurrent(ref);
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    loginHint.value = (email: to?.email ?? '', signUp: false);
    final left = await _signOut(router, ref);
    if (!left) loginHint.value = null;
  }

  Future<void> _addCompany(BuildContext context, WidgetRef ref) async {
    final ok = await GFeedback.confirm(
      context,
      title: 'Add a company?'.tr,
      message:
          'A new company is a new workshop account, with its own email. This phone signs out of {0} first; you can switch back any time from this menu.'
              .trf([ref.read(garageProvider)?.name ?? 'this workshop'.tr]),
      confirmLabel: 'Continue'.tr,
      icon: Icons.add_business_rounded,
    );
    if (!ok || !context.mounted) return;
    _rememberCurrent(ref);
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    loginHint.value = (email: '', signUp: true);
    final left = await _signOut(router, ref);
    if (!left) loginHint.value = null;
  }

  void _rememberCurrent(WidgetRef ref) {
    final email = ref.read(authUserProvider)?.email ?? '';
    final name = ref.read(garageProvider)?.name ?? '';
    ref.read(adminProvider.notifier).rememberCompany(email, name);
  }

  /// The ordinary sign-out, with its warning about unsent cards. Run on the
  /// router's own context: the sheet that asked is already gone.
  Future<bool> _signOut(GoRouter router, WidgetRef ref) async {
    final ctx = router.routerDelegate.navigatorKey.currentContext;
    if (ctx == null) return false;
    await confirmSignOut(ctx, ref);
    return !ref.read(adminProvider).signedIn;
  }
}

class _CompanyCard extends StatelessWidget {
  const _CompanyCard({
    required this.name,
    required this.email,
    this.current = false,
    this.onTap,
    this.onForget,
  });

  final String name;
  final String email;
  final bool current;
  final VoidCallback? onTap;
  final VoidCallback? onForget;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final initials = name
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: Container(
        padding: const EdgeInsets.all(Gap.md),
        decoration: BoxDecoration(
          color: current ? p.accentSoft : p.surface,
          borderRadius: R.all(R.lg),
          border: Border.all(color: current ? p.accent : p.line),
        ),
        child: Row(
          children: [
            Container(
              height: 44,
              width: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: current ? p.accent : p.surfaceAlt,
                borderRadius: R.all(R.md),
              ),
              child: Text(
                initials.isEmpty ? '?' : initials,
                style: AppType.labelL.c(current ? Colors.white : p.inkSoft),
              ),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.labelL.c(p.ink).w(FontWeight.w700),
                  ),
                  if (email.isNotEmpty)
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.bodyS.c(p.inkMuted),
                    ),
                ],
              ),
            ),
            if (current)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Gap.sm,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: p.accent,
                  borderRadius: R.all(R.pill),
                ),
                child: Text(
                  'OPEN'.tr,
                  style: AppType.over.s(9).c(Colors.white),
                ),
              )
            else ...[
              if (onForget != null)
                IconButton(
                  tooltip: 'Remove from this phone'.tr,
                  onPressed: onForget,
                  icon: Icon(Icons.close_rounded, size: 18, color: p.inkFaint),
                ),
              Icon(Icons.login_rounded, size: 20, color: p.accentInk),
            ],
          ],
        ),
      ),
    );
  }
}
