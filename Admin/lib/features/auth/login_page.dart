import '../../core/i18n/strings.dart';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/anim/entrance.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/widgets/cinematic_hero.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_field.dart';
import '../../core/widgets/pressable.dart';
import '../../data/repo/auth_service.dart';
import '../../state/admin_state.dart';
import '../../state/auth_state.dart';
import '../business/company_sheet.dart';
import '../shared/google_mark.dart';

enum _Mode { signIn, signUp }

/// The way into the console.
///
/// The splash ends on carbon; this screen lifts the same carbon into a
/// held frame of a service bay, so the two read as one shot rather than two
/// screens. On top of the picture there is only what it takes to get in —
/// Google in one tap,
/// email behind a sheet. Everything that used
/// to sit on this page as a form now lives in [_EmailSheet], which slides up
/// over the picture instead of replacing it.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Arrived here from "Switch company" or "Add company": open the form the
    // owner was heading for, rather than make them find it.
    final hint = loginHint.value;
    if (hint != null) {
      loginHint.value = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _email(email: hint.email, signUp: hint.signUp);
      });
    }
  }

  Future<void> _google() async {
    if (_busy) return;
    setState(() => _busy = true);
    ref.read(awaitingOAuthProvider.notifier).state = true;

    final result = await ref.read(authServiceProvider).signInWithGoogle();

    if (!mounted) return;
    setState(() => _busy = false);
    if (!result.ok) {
      ref.read(awaitingOAuthProvider.notifier).state = false;
      GFeedback.error(context, result.message ?? 'Google sign-in failed.'.tr);
    }
  }

  /// The email form, over the picture. It reports success by popping `true`, so
  /// the sheet is off the navigator before the router redirect runs.
  Future<void> _email({String email = '', bool signUp = false}) async {
    if (_busy) return;
    final signedIn = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: BrandArt.carbon.withValues(alpha: 0.64),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      builder: (_) => _EmailSheet(email: email, signUp: signUp),
    );
    if (signedIn == true && mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final waiting = ref.watch(awaitingOAuthProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: BrandArt.carbon,
        // Nothing on this page takes typing — the email form is a sheet that
        // lifts itself — so the keyboard must not squeeze the picture and
        // its buttons underneath.
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const CinematicBackground(),
            const HeroScrim(),
            SafeArea(child: _content(context)),

            // The OAuth round trip leaves and re-enters the app. The frame
            // stays underneath, so coming back feels like returning
            // to the same room rather than booting a second screen.
            if (waiting && !_busy)
              _WaitingForGoogle(
                onCancel: () =>
                    ref.read(awaitingOAuthProvider.notifier).state = false,
              ),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final title = height < 700 ? 32.0 : (height < 820 ? 36.0 : 40.0);

    return Stack(
      children: [
        // Anchored to the bottom, and scrollable for the short phone with a
        // large font that cannot fit the pitch and both buttons.
        Align(
          alignment: Alignment.bottomLeft,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              Gap.page,
              Gap.xxl,
              Gap.page,
              Gap.xxl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Entrance(index: 1, child: _FeatureTicker()),
                const SizedBox(height: Gap.md),
                Entrance(
                  index: 2,
                  child: Text(
                    'Run the whole\nworkshop.'.tr,
                    style: AppType.d1.s(title).c(Colors.white),
                  ),
                ),
                const SizedBox(height: Gap.md),
                Entrance(
                  index: 3,
                  child: Text(
                    'Every job card, every bill and every part — on one screen, at the counter or in your pocket.'
                        .tr,
                    style: AppType.bodyL.c(
                      Colors.white.withValues(alpha: 0.74),
                    ),
                  ),
                ),
                const SizedBox(height: Gap.h1),
                Entrance(
                  index: 4,
                  child: _GoogleCta(
                    onTap: _busy ? null : _google,
                    loading: _busy,
                  ),
                ),
                const SizedBox(height: Gap.md),
                Entrance(
                  index: 5,
                  child: _GlassCta(
                    label: 'Continue with email'.tr,
                    icon: Icons.alternate_email_rounded,
                    onTap: _busy ? null : () => _email(),
                  ),
                ),
                if (!AppConfig.hasSupabase) ...[
                  const SizedBox(height: Gap.lg),
                  Entrance(
                    index: 6,
                    child: _OfflineNote(
                      onContinue: () {
                        // Straight into an empty console — the router sends a
                        // workshop with no profile to /setup, which is where a
                        // new workshop starts.
                        ref.read(adminProvider.notifier).markSignedIn();
                        context.go('/home');
                      },
                    ),
                  ),
                ],
                const SizedBox(height: Gap.lg),
                Center(
                  child: Text(
                    '{0} • v{1}'.trf([AppConfig.appName, AppConfig.version]),
                    style: AppType.labelS.c(
                      Colors.white.withValues(alpha: 0.34),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The one moving word on a screen that is already moving. Slow enough to
/// read, short enough that it never becomes the thing you look at.
class _FeatureTicker extends StatefulWidget {
  const _FeatureTicker();

  @override
  State<_FeatureTicker> createState() => _FeatureTickerState();
}

class _FeatureTickerState extends State<_FeatureTicker> {
  static const _items = ['Job cards', 'Billing', 'Inventory', 'Reminders'];

  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 2400), (_) {
      if (mounted) setState(() => _index = (_index + 1) % _items.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final word = _items[_index];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 6,
          width: 6,
          decoration: BoxDecoration(
            color: context.c.accent,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: Gap.sm),
        GSwap(
          alignment: Alignment.centerLeft,
          child: Text(
            word.toUpperCase(),
            key: ValueKey(word),
            style: AppType.over
                .c(Colors.white.withValues(alpha: 0.84))
                .copyWith(letterSpacing: 2.0),
          ),
        ),
      ],
    );
  }
}

/// The white pill. Deliberately the only opaque thing on the screen — on
/// a frame this dark, solid white is what the eye lands on first.
class _GoogleCta extends StatelessWidget {
  const _GoogleCta({required this.onTap, this.loading = false});

  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      enabled: onTap != null,
      scale: 0.98,
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: R.all(R.lg),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.38),
              blurRadius: 26,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: BrandArt.carbon,
                ),
              )
            else
              const GoogleMark(size: 21),
            const SizedBox(width: Gap.md),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Continue with Google'.tr,
                  style: AppType.labelL.s(15.5).c(BrandArt.carbon),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Secondary route in. Translucent rather than blurred: a [BackdropFilter]
/// here would re-filter the drifting background every frame for the sake of
/// one button.
class _GlassCta extends StatelessWidget {
  const _GlassCta({required this.label, required this.icon, this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      enabled: onTap != null,
      scale: 0.98,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.13),
          borderRadius: R.all(R.lg),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.26),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 19, color: Colors.white.withValues(alpha: 0.92)),
            const SizedBox(width: Gap.md),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: AppType.labelL.s(15.5).c(Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaitingForGoogle extends StatelessWidget {
  const _WaitingForGoogle({required this.onCancel});

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Positioned.fill(
      child: ColoredBox(
        color: BrandArt.carbon.withValues(alpha: 0.86),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.h1),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: p.accent),
                const SizedBox(height: Gap.xl),
                Text(
                  'Waiting for Google…'.tr,
                  style: AppType.h2.c(Colors.white),
                ),
                const SizedBox(height: Gap.sm),
                Text(
                  'Finish in the browser and you will land back here.'.tr,
                  textAlign: TextAlign.center,
                  style: AppType.bodyS.c(Colors.white.withValues(alpha: 0.66)),
                ),
                const SizedBox(height: Gap.xxl),
                Pressable(
                  onTap: onCancel,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Gap.lg,
                      vertical: Gap.md,
                    ),
                    child: Text(
                      'Cancel'.tr,
                      style: AppType.labelL.c(
                        Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OfflineNote extends StatelessWidget {
  const _OfflineNote({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: R.all(R.md),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_off_rounded, size: 17, color: p.warning),
              const SizedBox(width: Gap.sm),
              Text(
                'No backend configured'.tr,
                style: AppType.labelL.c(Colors.white),
              ),
            ],
          ),
          const SizedBox(height: Gap.xs),
          Text(
            'Supabase credentials are missing, so sign-in is unavailable. You can still run the console on this device.'
                .tr,
            style: AppType.bodyS.c(Colors.white.withValues(alpha: 0.70)),
          ),
          const SizedBox(height: Gap.md),
          Pressable(
            onTap: onContinue,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Gap.xs),
              child: Text(
                'Continue offline  →'.tr,
                style: AppType.labelL.c(p.accent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Email and password, on dark glass over the background frame.
///
/// It runs under [AppTheme.dark] whatever the device setting is: these fields
/// sit on a photograph, not on the app canvas, so the shared [GField] and
/// [GButton] need the dark palette to look right here.
class _EmailSheet extends ConsumerStatefulWidget {
  const _EmailSheet({this.email = '', this.signUp = false});

  /// Typed in already — the account a company switch is heading for.
  final String email;
  final bool signUp;

  @override
  ConsumerState<_EmailSheet> createState() => _EmailSheetState();
}

class _EmailSheetState extends ConsumerState<_EmailSheet> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();

  late _Mode _mode = widget.signUp ? _Mode.signUp : _Mode.signIn;
  bool _busy = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _email.text = widget.email;
  }

  @override
  void dispose() {
    for (final c in [_email, _password, _name, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _signUp => _mode == _Mode.signUp;

  bool get _valid {
    final email = _email.text.trim();
    final emailOk = email.contains('@') && email.contains('.');
    final passOk = _password.text.length >= 6;
    if (!_signUp) return emailOk && passOk;
    return emailOk && passOk && _name.text.trim().isNotEmpty;
  }

  Future<void> _submit() async {
    if (!_valid || _busy) return;
    setState(() => _busy = true);
    final auth = ref.read(authServiceProvider);

    final result = _signUp
        ? await auth.signUpWithEmail(
            email: _email.text,
            password: _password.text,
            name: _name.text,
            phone: _phone.text,
          )
        : await auth.signInWithEmail(
            email: _email.text,
            password: _password.text,
          );

    if (!mounted) return;
    setState(() => _busy = false);

    if (!result.ok) {
      GFeedback.error(context, result.message ?? 'That did not work.'.tr);
      return;
    }
    if (result.needsConfirmation) {
      GFeedback.info(context, result.message!);
      setState(() => _mode = _Mode.signIn);
      return;
    }
    Navigator.of(context).pop(true);
  }

  Future<void> _forgot() async {
    // Supabase rate-limits reset mail, so an impatient double tap would
    // spend the allowance and answer with a scolding instead of a link.
    if (_busy) return;
    final email = _email.text.trim();
    if (!email.contains('@')) {
      GFeedback.info(context, 'Type your email address first.'.tr);
      return;
    }
    setState(() => _busy = true);
    final result = await ref.read(authServiceProvider).sendPasswordReset(email);
    if (!mounted) return;
    setState(() => _busy = false);
    result.ok
        ? GFeedback.success(context, result.message!)
        : GFeedback.error(context, result.message ?? 'Could not send it.'.tr);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.dark(),
      child: Builder(builder: _sheet),
    );
  }

  Widget _sheet(BuildContext context) {
    final p = context.c;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(R.xxl)),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: p.surface.withValues(alpha: 0.93),
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  Gap.page,
                  Gap.md,
                  Gap.page,
                  Gap.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        height: 4,
                        width: 44,
                        decoration: BoxDecoration(
                          color: p.line,
                          borderRadius: R.all(R.pill),
                        ),
                      ),
                    ),
                    const SizedBox(height: Gap.xl),
                    Text(
                      _signUp
                          ? 'Create your workshop'.tr
                          : 'Workshop sign in'.tr,
                      style: AppType.d3.c(p.ink),
                    ),
                    const SizedBox(height: Gap.xs),
                    Text(
                      _signUp
                          ? 'One account runs the console. You can add mechanics afterwards.'
                                .tr
                          : 'Use the account this workshop was registered with.'
                                .tr,
                      style: AppType.bodyM.c(p.inkMuted),
                    ),
                    const SizedBox(height: Gap.xl),
                    if (_signUp) ...[
                      GField(
                        label: 'Your name'.tr,
                        hint: 'Who runs the workshop'.tr,
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: Gap.lg),
                      GField(
                        label: 'Mobile number'.tr,
                        hint:
                            'Optional — links customers who already know it'.tr,
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        textCapitalization: TextCapitalization.none,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                      ),
                      const SizedBox(height: Gap.lg),
                    ],
                    GField(
                      label: 'Email'.tr,
                      hint: 'xyz@gmail.com',
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textCapitalization: TextCapitalization.none,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: Gap.lg),
                    GField(
                      label: 'Password'.tr,
                      hint: _signUp ? 'At least 6 characters'.tr : null,
                      controller: _password,
                      obscure: _obscure,
                      textCapitalization: TextCapitalization.none,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _submit(),
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
                    if (!_signUp) ...[
                      const SizedBox(height: Gap.sm),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Pressable(
                          onTap: _forgot,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: Gap.xs,
                            ),
                            child: Text(
                              'Forgot password?'.tr,
                              style: AppType.labelM.c(p.accentInk),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: Gap.xxl),
                    GButton.accent(
                      label: _signUp ? 'Create account'.tr : 'Sign in'.tr,
                      loading: _busy,
                      onPressed: _valid ? _submit : null,
                      trailingIcon: Icons.arrow_forward_rounded,
                    ),
                    const SizedBox(height: Gap.lg),
                    Center(
                      child: Pressable(
                        onTap: () => setState(() {
                          _mode = _signUp ? _Mode.signIn : _Mode.signUp;
                          _password.clear();
                        }),
                        child: Padding(
                          padding: const EdgeInsets.all(Gap.sm),
                          child: RichText(
                            text: TextSpan(
                              style: AppType.bodyM.c(p.inkMuted),
                              children: [
                                TextSpan(
                                  text: _signUp
                                      ? 'Already have an account?  '
                                      : 'New workshop?  ',
                                ),
                                TextSpan(
                                  text: _signUp ? 'Sign in' : 'Create one',
                                  style: AppType.labelL.c(p.accentInk),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
