import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/anim/entrance.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/pressable.dart';
import '../../data/repo/garage_gateway.dart';

/// What somebody who has just signed in says they are.
///
/// Only the owner registers a workshop. A manager or staff member cannot
/// make themselves one: the owner gives their email a role (Staff → App
/// access), and they join from the screen this leads to. Super Admin is
/// not on offer at all — it is set on the server, never chosen.
enum JoinAs { owner, manager, staff }

extension JoinAsX on JoinAs {
  String get title => switch (this) {
    JoinAs.owner => 'Workshop owner'.tr,
    JoinAs.manager => 'Manager'.tr,
    JoinAs.staff => 'Staff'.tr,
  };

  String get blurb => switch (this) {
    JoinAs.owner => 'Register your workshop and run everything in it'.tr,
    JoinAs.manager => 'Run the floor for a workshop that added you'.tr,
    JoinAs.staff => 'Mechanic, counter or accountant at a workshop'.tr,
  };

  String get tag => switch (this) {
    JoinAs.owner => 'Admin'.tr,
    JoinAs.manager => 'Invited by the owner'.tr,
    JoinAs.staff => 'Invited by the owner'.tr,
  };

  IconData get icon => switch (this) {
    JoinAs.owner => Icons.storefront_rounded,
    JoinAs.manager => Icons.manage_accounts_rounded,
    JoinAs.staff => Icons.engineering_rounded,
  };
}

/// "Who are you?" — three cards, the first thing a new sign-in sees.
class RoleChoiceView extends StatefulWidget {
  const RoleChoiceView({super.key, required this.email, required this.onPick});

  final String email;
  final ValueChanged<JoinAs> onPick;

  @override
  State<RoleChoiceView> createState() => _RoleChoiceViewState();
}

class _RoleChoiceViewState extends State<RoleChoiceView> {
  JoinAs? _picked;

  Future<void> _pick(JoinAs r) async {
    if (_picked != null) return;
    HapticFeedback.selectionClick();
    setState(() => _picked = r);
    // Long enough to see the card take the tap, short enough not to wait.
    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (mounted) widget.onPick(r);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.h2),
      children: [
        const Center(child: _OrbitBadge()),
        const SizedBox(height: Gap.xl),
        Entrance(
          index: 1,
          child: Text(
            'Who are you?'.tr,
            textAlign: TextAlign.center,
            style: AppType.d2.c(p.ink).w(FontWeight.w800),
          ),
        ),
        const SizedBox(height: Gap.xs),
        Entrance(
          index: 2,
          child: Text(
            'Pick how you use this workshop app. You can only register a workshop as its owner.'
                .tr,
            textAlign: TextAlign.center,
            style: AppType.bodyM.c(p.inkMuted),
          ),
        ),
        if (widget.email.isNotEmpty) ...[
          const SizedBox(height: Gap.md),
          Entrance(
            index: 3,
            child: Center(child: _EmailChip(email: widget.email)),
          ),
        ],
        const SizedBox(height: Gap.xl),
        for (final (i, r) in JoinAs.values.indexed) ...[
          Entrance(
            index: 4 + i,
            offset: 26,
            child: _RoleCard(
              role: r,
              picked: _picked == r,
              dimmed: _picked != null && _picked != r,
              onTap: () => _pick(r),
            ),
          ),
          const SizedBox(height: Gap.md),
        ],
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.picked,
    required this.dimmed,
    required this.onTap,
  });

  final JoinAs role;
  final bool picked;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final owner = role == JoinAs.owner;
    return AnimatedOpacity(
      duration: Motion.fast,
      opacity: dimmed ? 0.45 : 1,
      child: AnimatedScale(
        duration: Motion.base,
        curve: Motion.spring,
        scale: picked ? 1.03 : 1,
        child: Pressable(
          onTap: onTap,
          scale: 0.97,
          child: AnimatedContainer(
            duration: Motion.base,
            curve: Motion.emphasized,
            padding: const EdgeInsets.all(Gap.lg),
            decoration: BoxDecoration(
              gradient: picked
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        p.accent,
                        Color.lerp(p.accent, Colors.black, 0.18)!,
                      ],
                    )
                  : null,
              color: picked ? null : p.surface,
              borderRadius: R.rLg,
              border: Border.all(
                color: picked
                    ? p.accent
                    : owner
                    ? p.accent.withValues(alpha: 0.45)
                    : p.line,
                width: picked || owner ? 1.5 : 1,
              ),
              boxShadow: picked
                  ? [
                      BoxShadow(
                        color: p.accent.withValues(alpha: 0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : Shadows.soft(p),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: Motion.base,
                  height: 52,
                  width: 52,
                  decoration: BoxDecoration(
                    color: picked
                        ? p.onAccent.withValues(alpha: 0.18)
                        : p.accentSoft,
                    borderRadius: R.all(R.md),
                  ),
                  child: Icon(
                    role.icon,
                    size: 26,
                    color: picked ? p.onAccent : p.accentInk,
                  ),
                ),
                const SizedBox(width: Gap.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: Gap.sm,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            role.title,
                            style: AppType.h2.c(picked ? p.onAccent : p.ink),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Gap.sm,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: picked
                                  ? p.onAccent.withValues(alpha: 0.2)
                                  : (owner ? p.accentSoft : p.surfaceSunken),
                              borderRadius: R.all(R.pill),
                            ),
                            child: Text(
                              role.tag,
                              style: AppType.labelS.c(
                                picked
                                    ? p.onAccent
                                    : (owner ? p.accentInk : p.inkMuted),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        role.blurb,
                        style: AppType.bodyS.c(
                          picked
                              ? p.onAccent.withValues(alpha: 0.88)
                              : p.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Gap.sm),
                AnimatedRotation(
                  duration: Motion.base,
                  turns: picked ? 0.25 : 0,
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: picked ? p.onAccent : p.inkFaint,
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

/// A badge with three small role glyphs circling it — the welcome's one
/// moving thing.
class _OrbitBadge extends StatefulWidget {
  const _OrbitBadge();

  @override
  State<_OrbitBadge> createState() => _OrbitBadgeState();
}

class _OrbitBadgeState extends State<_OrbitBadge>
    with SingleTickerProviderStateMixin {
  late final _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    const size = 132.0;
    return Entrance(
      scaleFrom: 0.85,
      child: SizedBox(
        height: size,
        width: size,
        child: AnimatedBuilder(
          animation: _spin,
          builder: (context, _) {
            final t = _spin.value * 2 * math.pi;
            return Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: size,
                  width: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: p.accent.withValues(alpha: 0.18),
                      width: 1.5,
                    ),
                  ),
                ),
                Container(
                  height: 78,
                  width: 78,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        p.accent,
                        Color.lerp(p.accent, Colors.black, 0.2)!,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: p.accent.withValues(alpha: 0.35),
                        blurRadius: 22,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(Icons.badge_rounded, size: 36, color: p.onAccent),
                ),
                for (final (i, r) in JoinAs.values.indexed)
                  Transform.translate(
                    offset: Offset(
                      math.cos(t + i * 2 * math.pi / 3) * (size / 2),
                      math.sin(t + i * 2 * math.pi / 3) * (size / 2),
                    ),
                    child: Container(
                      height: 30,
                      width: 30,
                      decoration: BoxDecoration(
                        color: p.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: p.line),
                        boxShadow: Shadows.soft(p),
                      ),
                      child: Icon(r.icon, size: 16, color: p.accentInk),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EmailChip extends StatelessWidget {
  const _EmailChip({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 6),
      decoration: BoxDecoration(
        color: p.surfaceSunken,
        borderRadius: R.all(R.pill),
        border: Border.all(color: p.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.alternate_email_rounded, size: 15, color: p.inkMuted),
          const SizedBox(width: Gap.xs),
          Flexible(
            child: Text(
              email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.labelM.c(p.ink),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Joining a workshop
// ---------------------------------------------------------------------------

/// For a manager or staff member: what to ask the owner for, and a quiet
/// check every few seconds so the workshop opens by itself the moment the
/// owner gives this email access.
class JoinWorkshopView extends ConsumerStatefulWidget {
  const JoinWorkshopView({
    super.key,
    required this.role,
    required this.email,
    required this.onJoined,
    required this.onSignOut,
  });

  final JoinAs role;
  final String email;

  /// Runs the full restore that takes them into the workshop.
  final Future<void> Function() onJoined;
  final VoidCallback onSignOut;

  @override
  ConsumerState<JoinWorkshopView> createState() => _JoinWorkshopViewState();
}

class _JoinWorkshopViewState extends ConsumerState<JoinWorkshopView>
    with SingleTickerProviderStateMixin {
  static const _every = Duration(seconds: 8);

  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  Timer? _timer;
  bool _checking = false;
  bool _joining = false;
  DateTime? _lastCheck;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_every, (_) => _check(quiet: true));
    WidgetsBinding.instance.addPostFrameCallback((_) => _check(quiet: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _check({bool quiet = false}) async {
    if (_checking || _joining) return;
    setState(() => _checking = true);
    final found = await ref.read(garageGatewayProvider).claimInvite();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _lastCheck = DateTime.now();
    });
    if (found) {
      _timer?.cancel();
      setState(() => _joining = true);
      HapticFeedback.mediumImpact();
      await widget.onJoined();
      if (mounted) setState(() => _joining = false);
      return;
    }
    if (!quiet) {
      GFeedback.info(
        context,
        'No invitation for this email yet. Ask the owner to add it.'.tr,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final steps = [
      'Ask the owner to open Staff in their app and tap your name.'.tr,
      'They tap Give app access, enter the email below and choose {0}.'.trf([
        widget.role == JoinAs.manager ? 'Manager'.tr : 'your role'.tr,
      ]),
      'This screen opens the workshop by itself. No need to sign in again.'.tr,
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.h2),
      children: [
        Center(
          child: SizedBox(
            height: 150,
            width: 150,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) => Stack(
                alignment: Alignment.center,
                children: [
                  for (var i = 0; i < 3; i++)
                    _Ring(
                      t: (_pulse.value + i / 3) % 1,
                      color: _joining ? p.success : p.accent,
                    ),
                  child!,
                ],
              ),
              child: AnimatedSwitcher(
                duration: Motion.base,
                transitionBuilder: (c, a) =>
                    ScaleTransition(scale: a, child: c),
                child: Container(
                  key: ValueKey(_joining),
                  height: 76,
                  width: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _joining ? p.success : p.accent,
                    boxShadow: [
                      BoxShadow(
                        color: (_joining ? p.success : p.accent).withValues(
                          alpha: 0.35,
                        ),
                        blurRadius: 22,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    _joining
                        ? Icons.check_rounded
                        : Icons.mark_email_unread_rounded,
                    size: 34,
                    color: p.onAccent,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: Gap.lg),
        Entrance(
          child: Text(
            _joining
                ? 'You are in. Opening the workshop…'.tr
                : 'Waiting for the owner'.tr,
            textAlign: TextAlign.center,
            style: AppType.d3.c(p.ink).w(FontWeight.w800),
          ),
        ),
        const SizedBox(height: Gap.xs),
        Entrance(
          index: 1,
          child: Text(
            'Joining as {0}. Only the workshop owner can give you access.'.trf([
              widget.role.title,
            ]),
            textAlign: TextAlign.center,
            style: AppType.bodyM.c(p.inkMuted),
          ),
        ),
        const SizedBox(height: Gap.lg),
        Entrance(
          index: 2,
          child: Center(child: _EmailChip(email: widget.email)),
        ),
        const SizedBox(height: Gap.xl),
        for (final (i, s) in steps.indexed)
          Entrance(
            index: 3 + i,
            offset: 22,
            child: _Step(n: i + 1, text: s),
          ),
        const SizedBox(height: Gap.lg),
        Entrance(
          index: 6,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 12,
                width: 12,
                child: _checking
                    ? CircularProgressIndicator(
                        strokeWidth: 1.8,
                        color: p.inkMuted,
                      )
                    : Icon(Icons.sync_rounded, size: 12, color: p.inkFaint),
              ),
              const SizedBox(width: Gap.xs),
              Flexible(
                child: Text(
                  _lastCheck == null
                      ? 'Checking for your invitation…'.tr
                      : 'Checked at {0}. Checking again every few seconds.'.trf(
                          [Fmt.time(_lastCheck!)],
                        ),
                  textAlign: TextAlign.center,
                  style: AppType.labelS.c(p.inkFaint),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Gap.xl),
        GButton.accent(
          label: 'Check now'.tr,
          icon: Icons.refresh_rounded,
          size: GButtonSize.lg,
          expand: true,
          loading: _checking || _joining,
          onPressed: _checking || _joining ? null : () => _check(),
        ),
        const SizedBox(height: Gap.md),
        GButton(
          label: 'Use a different email'.tr,
          kind: GButtonKind.ghost,
          size: GButtonSize.md,
          expand: true,
          onPressed: _joining ? null : widget.onSignOut,
        ),
      ],
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.t, required this.color});

  /// 0 → 1 across one pulse.
  final double t;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final d = 76 + 74 * Curves.easeOut.transform(t);
    return Container(
      height: d,
      width: d,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.10 * (1 - t)),
        border: Border.all(
          color: color.withValues(alpha: 0.45 * (1 - t)),
          width: 1.5,
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.text});

  final int n;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 26,
            width: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.accentSoft,
              shape: BoxShape.circle,
            ),
            child: Text('$n', style: AppType.labelM.c(p.accentInk)),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(text, style: AppType.bodyM.c(p.ink)),
            ),
          ),
        ],
      ),
    );
  }
}
