import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/widgets/decor.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_field.dart';
import '../../core/widgets/pressable.dart';
import '../../data/repo/auth_service.dart';
import '../../state/auth_state.dart';

/// The other half of "Forgot password?".
///
/// The emailed link hands the app a session whose only purpose is setting a
/// new password. The router holds the console here until that is done —
/// otherwise the owner lands on the dashboard, the old password still in
/// force, with no way back to this form.
class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  /// Supabase's own floor is six characters; rejecting a short one here
  /// saves a round trip to be told the same thing.
  bool get _longEnough => _password.text.length >= 6;
  bool get _matches => _password.text == _confirm.text;
  bool get _valid => _longEnough && _matches;

  Future<void> _save() async {
    if (_busy || !_valid) return;
    setState(() => _busy = true);
    final result = await ref
        .read(authServiceProvider)
        .updatePassword(_password.text);
    if (!mounted) return;
    setState(() => _busy = false);

    if (!result.ok) {
      GFeedback.error(context, result.message ?? 'Could not save it.'.tr);
      return;
    }
    // Lowering the latch is what lets the router move on — the session from
    // the link is a normal one now.
    ref.read(passwordRecoveryProvider.notifier).state = false;
    GFeedback.success(context, result.message ?? 'Password updated.'.tr);
  }

  /// Leaving without setting one. The recovery session goes with it, so the
  /// old password stays in force and the link can be requested again.
  Future<void> _cancel() async {
    await ref.read(authServiceProvider).signOut();
    if (!mounted) return;
    ref.read(passwordRecoveryProvider.notifier).state = false;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Scaffold(
      backgroundColor: p.canvas,
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: BlueprintPainter(color: p.ink, opacity: 0.04),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                Gap.page,
                Gap.h2,
                Gap.page,
                Gap.xxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const BrandBadge(size: 56),
                  const SizedBox(height: Gap.xl),
                  Text('Set a new password'.tr, style: AppType.d2.c(p.ink)),
                  const SizedBox(height: Gap.sm),
                  Text(
                    'You came in from the reset link. Choose the password you will sign in with from now on.'
                        .tr,
                    style: AppType.bodyM.c(p.inkMuted),
                  ),
                  const SizedBox(height: Gap.h1),
                  GField(
                    label: 'New password'.tr,
                    hint: 'At least 6 characters'.tr,
                    controller: _password,
                    obscure: _obscure,
                    textCapitalization: TextCapitalization.none,
                    onChanged: (_) => setState(() {}),
                    suffix: Pressable(
                      onTap: () => setState(() => _obscure = !_obscure),
                      scale: 0.9,
                      child: Icon(
                        _obscure
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                        size: 19,
                        color: p.inkMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: Gap.lg),
                  GField(
                    label: 'Confirm password'.tr,
                    controller: _confirm,
                    obscure: _obscure,
                    textCapitalization: TextCapitalization.none,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _save(),
                    // Silence until there is something to disagree with.
                    helper: _confirm.text.isEmpty || _matches
                        ? null
                        : 'The two do not match yet.'.tr,
                  ),
                  const SizedBox(height: Gap.h1),
                  GButton.accent(
                    label: 'Save password'.tr,
                    loading: _busy,
                    onPressed: _valid ? _save : null,
                    trailingIcon: Icons.arrow_forward_rounded,
                  ),
                  const SizedBox(height: Gap.lg),
                  Center(
                    child: Pressable(
                      onTap: _busy ? null : _cancel,
                      child: Padding(
                        padding: const EdgeInsets.all(Gap.sm),
                        child: Text(
                          'Back to sign in'.tr,
                          style: AppType.labelL.c(p.inkMuted),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
