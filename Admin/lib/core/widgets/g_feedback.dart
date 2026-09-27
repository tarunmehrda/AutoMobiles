import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_type.dart';
import 'g_badge.dart';
import 'g_button.dart';
import 'g_field.dart';
import 'pressable.dart';

/// App-wide feedback helpers. Every toast/sheet/dialog in the product goes
/// through here so timing, shape and haptics never drift.
class GFeedback {
  const GFeedback._();

  /// The toast currently shown over a sheet or dialog, if any — see
  /// [_OverlayToast]. Bumped every time a toast is shown, so the one on
  /// screen knows it has been replaced and gets out of the way, the same way
  /// `clearSnackBars` retires the last SnackBar.
  static final ValueNotifier<int> _overlayToast = ValueNotifier<int>(0);

  /// Shows a one-line message at the bottom of the screen.
  ///
  /// A SnackBar is drawn by the page's Scaffold, which sits *under* every
  /// modal route. So a toast raised from inside a bottom sheet or a dialog —
  /// "Enter an amount first." on the payment sheet is the one everybody
  /// hit — used to land on the page beneath: dimmed by the scrim and hidden
  /// behind the very sheet it was about. The counter tapped the button,
  /// nothing seemed to happen, and they tapped it again.
  ///
  /// When [context] belongs to the modal route on top (a sheet or dialog that
  /// is still open), the toast goes into the root [Overlay] instead, which
  /// is above every route. Everywhere else it stays a SnackBar, so it still
  /// sits above the bottom navigation and moves with the Scaffold. A sheet
  /// that is already on its way out (the usual "save, pop, say saved")
  /// counts as gone: the page it is revealing is where the toast belongs.
  static void toast(
    BuildContext context,
    String message, {
    GTone tone = GTone.ink,
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    final p = context.c;
    final t = toneOf(context, tone);
    final bg = tone == GTone.ink ? p.inverse : t.bg;
    final fg = tone == GTone.ink ? p.onInverse : t.fg;
    final route = ModalRoute.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);

    // Whatever is on screen now is superseded, wherever it was drawn.
    final generation = ++_overlayToast.value;

    if (route is PopupRoute && route.isCurrent) {
      final overlay = Overlay.maybeOf(context, rootOverlay: true);
      if (overlay != null) {
        messenger?.clearSnackBars();
        late final OverlayEntry entry;
        entry = OverlayEntry(
          builder: (_) => _OverlayToast(
            generation: generation,
            live: _overlayToast,
            duration: duration,
            background: Color.alphaBlend(bg, p.surface),
            border: tone == GTone.ink
                ? Colors.transparent
                : t.fg.withValues(alpha: 0.2),
            onGone: () {
              entry.remove();
              entry.dispose();
            },
            child: _ToastContent(
              message: message,
              icon: icon,
              fg: fg,
              actionLabel: actionLabel,
              actionColor: tone == GTone.ink ? p.volt : t.fg,
              onAction: () {
                _overlayToast.value++;
                onAction?.call();
              },
            ),
          ),
        );
        overlay.insert(entry);
        return;
      }
    }

    if (messenger == null) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          duration: duration,
          backgroundColor: bg,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.lg,
            vertical: Gap.md,
          ),
          margin: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
          shape: RoundedRectangleBorder(
            borderRadius: R.rMd,
            side: BorderSide(
              color: tone == GTone.ink
                  ? Colors.transparent
                  : t.fg.withValues(alpha: 0.2),
            ),
          ),
          content: _ToastContent(
            message: message,
            icon: icon,
            fg: fg,
            actionLabel: actionLabel,
            actionColor: tone == GTone.ink ? p.volt : t.fg,
            onAction: () {
              messenger.hideCurrentSnackBar();
              onAction?.call();
            },
          ),
        ),
      );
  }

  static void success(BuildContext context, String message) => toast(
    context,
    message,
    tone: GTone.success,
    icon: Icons.check_circle_rounded,
  );

  static void error(BuildContext context, String message) {
    HapticFeedback.heavyImpact();
    toast(context, message, tone: GTone.danger, icon: Icons.error_rounded);
  }

  static void info(BuildContext context, String message) =>
      toast(context, message, icon: Icons.info_rounded);

  /// Rounded modal sheet with a grab handle and safe-area padding.
  static Future<T?> sheet<T>(
    BuildContext context, {
    required Widget child,
    bool isScrollControlled = true,
    bool dismissible = true,
    String? title,
    String? subtitle,
    List<ChangeNotifier> disposing = const [],
  }) {
    final p = context.c;
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      isDismissible: dismissible,
      enableDrag: dismissible,
      backgroundColor: Colors.transparent,
      barrierColor: p.scrim,
      builder: (context) {
        final p = context.c;
        // The sheet is laid out against the full screen, so an open keyboard
        // would sit on top of it. Lifting it here — in the sheet's own
        // builder, which rebuilds as the keyboard slides — is what keeps the
        // fields in view. The insets are then stripped from the subtree so a
        // caller that pads for the keyboard as well does not double up.
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: MediaQuery.removeViewInsets(
            context: context,
            removeBottom: true,
            child: Container(
              margin: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + Gap.h2,
              ),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(R.xxl),
                ),
                border: Border(top: BorderSide(color: p.line)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: Gap.md),
                  Container(
                    height: 4,
                    width: 42,
                    decoration: BoxDecoration(
                      color: p.line,
                      borderRadius: R.all(R.pill),
                    ),
                  ),
                  if (title != null) ...[
                    const SizedBox(height: Gap.lg),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Gap.page),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title, style: AppType.d3.c(p.ink)),
                                if (subtitle != null) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    subtitle,
                                    style: AppType.bodyS.c(p.inkMuted),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          GIconButton(
                            icon: Icons.close_rounded,
                            size: 36,
                            onTap: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Anything the caller built for this sheet alone dies with the
                  // sheet, not with the `await` that opened it — the route keeps
                  // rebuilding all the way through its exit transition. See
                  // [DisposeWithSubtree].
                  Flexible(
                    child: disposing.isEmpty
                        ? child
                        : DisposeWithSubtree(
                            disposables: disposing,
                            child: child,
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Confirmation dialog. Returns true when the primary action is chosen.
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool destructive = false,
    IconData? icon,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: context.c.scrim,
      builder: (context) {
        final p = context.c;
        final tone = destructive ? GTone.danger : GTone.accent;
        final t = toneOf(context, tone);
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: Gap.xxl),
          child: Padding(
            padding: const EdgeInsets.all(Gap.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[
                  Container(
                    height: 46,
                    width: 46,
                    decoration: BoxDecoration(
                      color: t.bg,
                      borderRadius: R.all(R.md),
                    ),
                    child: Icon(icon, color: t.fg, size: 23),
                  ),
                  const SizedBox(height: Gap.lg),
                ],
                Text(title, style: AppType.d3.c(p.ink)),
                const SizedBox(height: Gap.sm),
                Text(message, style: AppType.bodyM.c(p.inkMuted)),
                const SizedBox(height: Gap.xxl),
                Row(
                  children: [
                    Expanded(
                      child: GButton(
                        label: cancelLabel,
                        kind: GButtonKind.ghost,
                        size: GButtonSize.md,
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: GButton(
                        label: confirmLabel,
                        kind: destructive
                            ? GButtonKind.danger
                            : GButtonKind.primary,
                        size: GButtonSize.md,
                        onPressed: () => Navigator.of(context).pop(true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    return result ?? false;
  }
}

/// The inside of a toast — icon, message, optional action — shared by the
/// SnackBar and the overlay version so the two can never drift apart.
class _ToastContent extends StatelessWidget {
  const _ToastContent({
    required this.message,
    required this.icon,
    required this.fg,
    required this.actionLabel,
    required this.actionColor,
    required this.onAction,
  });

  final String message;
  final IconData? icon;
  final Color fg;
  final String? actionLabel;
  final Color actionColor;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: Gap.md),
        ],
        Expanded(child: Text(message, style: AppType.labelM.c(fg))),
        if (actionLabel != null)
          Pressable(
            onTap: onAction,
            child: Padding(
              padding: const EdgeInsets.only(left: Gap.md),
              child: Text(actionLabel!, style: AppType.labelM.c(actionColor)),
            ),
          ),
      ],
    );
  }
}

/// A toast drawn in the root [Overlay], above an open sheet or dialog.
///
/// It looks like the floating SnackBar it stands in for and keeps the same
/// clock, but it owns that clock itself: the timer lives in this State, so a
/// torn-down tree (a test ending, the app going away) cancels it with
/// everything else rather than leaving it to fire into nothing. It leaves
/// early when a newer toast bumps [live] past its [generation].
///
/// It sits above whichever is taller, the keyboard or the system gesture
/// bar, so the message a field's validation raises is not hidden by the
/// keyboard that field just opened.
class _OverlayToast extends StatefulWidget {
  const _OverlayToast({
    required this.generation,
    required this.live,
    required this.duration,
    required this.background,
    required this.border,
    required this.onGone,
    required this.child,
  });

  final int generation;
  final ValueListenable<int> live;
  final Duration duration;
  final Color background;
  final Color border;
  final VoidCallback onGone;
  final Widget child;

  @override
  State<_OverlayToast> createState() => _OverlayToastState();
}

class _OverlayToastState extends State<_OverlayToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: Motion.fast,
  )..forward();
  Timer? _clock;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _clock = Timer(widget.duration, _leave);
    widget.live.addListener(_onLive);
  }

  void _onLive() {
    if (widget.live.value != widget.generation) _leave();
  }

  Future<void> _leave() async {
    if (_leaving || !mounted) return;
    _leaving = true;
    _clock?.cancel();
    await _in.reverse();
    if (mounted) widget.onGone();
  }

  @override
  void dispose() {
    _clock?.cancel();
    widget.live.removeListener(_onLive);
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final lift = math.max(mq.viewInsets.bottom, mq.viewPadding.bottom);
    final curve = CurvedAnimation(parent: _in, curve: Motion.enter);
    return Positioned(
      left: Gap.lg,
      right: Gap.lg,
      bottom: lift + Gap.lg,
      child: FadeTransition(
        opacity: curve,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.4),
            end: Offset.zero,
          ).animate(curve),
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.lg,
                vertical: Gap.md,
              ),
              decoration: BoxDecoration(
                color: widget.background,
                borderRadius: R.rMd,
                border: Border.all(color: widget.border),
                boxShadow: Shadows.lifted(context.c),
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Sticky bottom action bar with a blurred, bordered surface.
class GBottomBar extends StatelessWidget {
  const GBottomBar({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(
      Gap.page,
      Gap.md,
      Gap.page,
      Gap.md,
    ),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.line)),
        boxShadow: Shadows.lifted(p),
      ),
      child: SafeArea(
        top: false,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Single-select row for sheets — replaces RadioListTile so the selection
/// affordance matches the rest of the design system.
class GOptionRow extends StatelessWidget {
  const GOptionRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.icon,
    this.trailing,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Pressable(
      onTap: onTap,
      scale: 0.99,
      child: AnimatedContainer(
        duration: Motion.fast,
        margin: const EdgeInsets.only(bottom: Gap.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.lg,
          vertical: Gap.md,
        ),
        decoration: BoxDecoration(
          color: selected ? p.surfaceSunken : p.surface,
          borderRadius: R.all(R.md),
          border: Border.all(color: selected ? p.ink : p.line),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: selected ? p.ink : p.inkMuted),
              const SizedBox(width: Gap.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppType.labelL.c(p.ink)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: AppType.bodyS.c(p.inkMuted)),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[trailing!, const SizedBox(width: Gap.sm)],
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 21,
              color: selected ? p.accent : p.line,
            ),
          ],
        ),
      ),
    );
  }
}
