import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/entities.dart';
import '../../data/models/enums.dart';
import '../../state/providers.dart';
import '../router/app_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_type.dart';
import '../utils/alert_chime.dart';

/// Announces an update from the workshop over whatever is on screen.
///
/// Until this existed the app changed underneath the customer in silence.
/// The counter would accept the booking, start the work, finish it — and
/// the only way to find out was to open the bookings screen on the off
/// chance. That is the wrong way round: the whole point of the customer
/// app is that they do not have to ring up and ask.
///
/// Sits above the navigator so it shows over any route, including a
/// full-screen sheet.
class AlertHost extends ConsumerStatefulWidget {
  const AlertHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AlertHost> createState() => _AlertHostState();
}

class _AlertHostState extends ConsumerState<AlertHost> {
  /// Long enough to read two lines while holding something else, short
  /// enough not to sit over the screen the customer actually opened.
  static const Duration _dwell = Duration(seconds: 6);

  AppNotification? _showing;
  Timer? _hide;

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  void _announce(AppNotification n) {
    // The newest replaces the one on screen rather than queueing behind
    // it. Two updates arriving together is one thing to go and look at,
    // and a queue would hold the second banner up for twelve seconds.
    _hide?.cancel();
    HapticFeedback.heavyImpact();
    unawaited(AlertChime.play(n.kind));
    setState(() => _showing = n);
    _hide = Timer(_dwell, _dismiss);
  }

  void _dismiss() {
    _hide?.cancel();
    if (mounted) setState(() => _showing = null);
  }

  /// Goes through the router itself rather than `context.push`.
  ///
  /// This widget is mounted in `MaterialApp.router`'s `builder`, which puts
  /// it above the Router — so there is no GoRouter in its context, and the
  /// context lookup threw "No GoRouter found in context" on every tap. The
  /// provider hands back the same instance the app was built with.
  void _open(AppNotification n) {
    _dismiss();
    ref.read(routerProvider).push(n.route ?? '/notifications');
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appAlertProvider, (_, next) {
      final n = next.valueOrNull;
      if (n != null) _announce(n);
    });

    // A tray notification tapped: the OS already told them, so no banner,
    // just the screen it points at.
    ref.listen(pushOpenedProvider, (_, next) {
      final route = next.valueOrNull;
      if (route != null && route.isNotEmpty) {
        ref.read(routerProvider).push(route);
      }
    });

    final showing = _showing;
    return Stack(
      children: [
        widget.child,
        if (showing != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _AlertBanner(
              key: ValueKey(showing.id),
              alert: showing,
              onOpen: () => _open(showing),
              onDismiss: _dismiss,
            ),
          ),
      ],
    );
  }
}

class _AlertBanner extends StatefulWidget {
  const _AlertBanner({
    super.key,
    required this.alert,
    required this.onOpen,
    required this.onDismiss,
  });

  final AppNotification alert;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  @override
  State<_AlertBanner> createState() => _AlertBannerState();
}

class _AlertBannerState extends State<_AlertBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: Motion.base,
  )..forward();

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final n = widget.alert;

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, -1),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: _slide, curve: Motion.spring)),
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, 0),
            // Up is the only direction that dismisses: the banner came
            // from the top edge and going back the way it came is the
            // gesture people already make. A sideways swipe would fight
            // the back-gesture on both edges of the screen.
            child: Dismissible(
              key: ValueKey('alert-${n.id}'),
              direction: DismissDirection.up,
              onDismissed: (_) => widget.onDismiss(),
              child: GestureDetector(
                onTap: widget.onOpen,
                child: Container(
                  padding: const EdgeInsets.all(Gap.md),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: R.all(R.lg),
                    border: Border.all(color: p.accent.withValues(alpha: 0.35)),
                    boxShadow: Shadows.lifted(p),
                  ),
                  child: Row(
                    children: [
                      Container(
                        height: 42,
                        width: 42,
                        decoration: BoxDecoration(
                          color: p.accent.withValues(alpha: 0.12),
                          borderRadius: R.all(R.md),
                        ),
                        child: Icon(n.kind.icon, color: p.accent, size: 22),
                      ),
                      const SizedBox(width: Gap.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              n.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.labelL.c(p.ink),
                            ),
                            if (n.body.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                n.body,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppType.bodyS.c(p.inkMuted),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: Gap.sm),
                      Text('Open', style: AppType.labelM.c(p.accent)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
