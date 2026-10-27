import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/enums.dart';
import '../../features/shared/support_sheet.dart';
import '../../state/admin_state.dart';
import '../../state/providers.dart';
import '../i18n/strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_type.dart';
import '../widgets/g_button.dart';
import '../widgets/g_feedback.dart';
import '../widgets/pressable.dart';

/// The console's five slots. The middle one is not a page — it is the create
/// action, raised out of the bar, because opening a card is the thing the
/// counter does all day and it should never be more than one tap away.
class _Tab {
  const _Tab(this.label, this.icon, this.activeIcon);
  final String label;
  final IconData icon;
  final IconData activeIcon;
}

const _left = <_Tab>[
  _Tab('Home', Icons.home_outlined, Icons.home_rounded),
  _Tab('Search', Icons.search_rounded, Icons.search_rounded),
];

const _right = <_Tab>[
  _Tab('Support', Icons.headset_mic_outlined, Icons.headset_mic_rounded),
  _Tab('Settings', Icons.settings_outlined, Icons.settings_rounded),
];

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  void _go(BuildContext context, int branch) {
    HapticFeedback.selectionClick();
    shell.goBranch(branch, initialLocation: branch == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final open = ref.watch(bucketCountProvider(JobStatus.open));

    return Scaffold(
      backgroundColor: p.canvas,
      // The shell is always the second child of the same Column, banner or
      // no banner. Swapping between `shell` and `Column([banner, shell])`
      // would move the branch navigators to a new place in the tree and
      // throw away every tab's back stack the moment a push failed.
      body: ValueListenableBuilder<Map<String, String>>(
        valueListenable: ref.read(adminProvider.notifier).syncIssues,
        builder: (context, issues, child) => Column(
          children: [
            _SyncBanner(issues: issues),
            Expanded(
              // The banner takes the status bar's inset for itself, so the
              // page under it must not pad for the status bar a second time.
              child: MediaQuery.removePadding(
                context: context,
                removeTop: issues.isNotEmpty,
                child: child!,
              ),
            ),
          ],
        ),
        child: shell,
      ),
      bottomNavigationBar: _NavBar(
        branch: shell.currentIndex,
        onTap: (i) => _go(context, i),
        // Support is a sheet, not a page, exactly as the counter expects.
        onSupport: () => showSupportSheet(context),
        // Only for a role that may open a job card. The slot stays, empty,
        // so the other four do not shift under a thumb that knows them.
        onCreate: ref.watch(accessProvider).openJobs
            ? () => context.push('/job/new')
            : null,
        badges: {1: open},
      ),
    );
  }
}

/// A slim warning across the top while the server is refusing something.
///
/// The console saves locally first and pushes in the background, and a push
/// the server refused used to be visible only in the log: the counter went on
/// working, every other phone went on not seeing that work, and nobody found
/// out until a job card was missing at the other end. This says so, names
/// the first thing that did not go up, retries on the spot, and a tap lists
/// every step and what was wrong with it.
///
/// It occupies the status bar's inset itself (the shell strips that inset
/// from the page below while it shows) and is one line high, so it never
/// sits under the clock or pushes into the navigation bar on a small phone.
class _SyncBanner extends ConsumerStatefulWidget {
  const _SyncBanner({required this.issues});

  /// Step name to readable problem, as `syncIssues` reports them.
  final Map<String, String> issues;

  @override
  ConsumerState<_SyncBanner> createState() => _SyncBannerState();
}

class _SyncBannerState extends ConsumerState<_SyncBanner> {
  bool _retrying = false;

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      await ref.read(adminProvider.notifier).retrySync();
    } catch (_) {
      // A failed retry is reported the same way the first failure was —
      // through `syncIssues` — so the banner simply stays.
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  void _details() {
    GFeedback.sheet<void>(
      context,
      title: 'Not saved to the server'.tr,
      subtitle: 'Saved on this phone. These did not reach the server.'.tr,
      child: _SyncIssuesSheet(onRetry: _retry),
    );
  }

  @override
  Widget build(BuildContext context) {
    final issues = widget.issues;
    if (issues.isEmpty) return const SizedBox.shrink();
    final p = context.c;
    // The problems are written as sentences; the full stop goes so that
    // "… and 2 more" does not follow one.
    final first = issues.values.first.tr.replaceFirst(RegExp(r'\.$'), '');
    final more = issues.length - 1;
    final text = more > 0
        ? '{0} and {1} more'.trf([
            'Not saved to the server: {0}'.trf([first]),
            more,
          ])
        : 'Not saved to the server: {0}'.trf([first]);

    return Material(
      color: p.warningSoft,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: p.warning.withValues(alpha: 0.35)),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Pressable(
            onTap: _details,
            scale: 0.99,
            haptic: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Gap.lg,
                Gap.sm,
                Gap.sm,
                Gap.sm,
              ),
              child: Row(
                children: [
                  Icon(Icons.cloud_off_rounded, size: 17, color: p.warning),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.labelM.c(p.warning),
                    ),
                  ),
                  const SizedBox(width: Gap.sm),
                  Pressable(
                    onTap: _retry,
                    scale: 0.94,
                    child: Container(
                      height: 30,
                      padding: const EdgeInsets.symmetric(horizontal: Gap.md),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius: R.all(R.pill),
                        border: Border.all(
                          color: p.warning.withValues(alpha: 0.35),
                        ),
                      ),
                      child: _retrying
                          ? SizedBox(
                              height: 14,
                              width: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: p.warning,
                              ),
                            )
                          : Text(
                              'Retry'.tr,
                              style: AppType.labelM.c(p.warning),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Every step the server refused and why, with a Retry that shows it is
/// working. Listens to `syncIssues` itself, so a retry that fixes one step
/// takes it off the list while the sheet is still open.
class _SyncIssuesSheet extends ConsumerStatefulWidget {
  const _SyncIssuesSheet({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  ConsumerState<_SyncIssuesSheet> createState() => _SyncIssuesSheetState();
}

class _SyncIssuesSheetState extends ConsumerState<_SyncIssuesSheet> {
  bool _retrying = false;

  Future<void> _retry() async {
    setState(() => _retrying = true);
    await widget.onRetry();
    if (!mounted) return;
    setState(() => _retrying = false);
    if (ref.read(adminProvider.notifier).syncIssues.value.isEmpty) {
      Navigator.of(context).pop();
      GFeedback.success(context, 'Everything is saved to the server.'.tr);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return ValueListenableBuilder<Map<String, String>>(
      valueListenable: ref.read(adminProvider.notifier).syncIssues,
      builder: (context, issues, _) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          Gap.page,
          Gap.lg,
          Gap.page,
          Gap.h1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (issues.isEmpty)
              Text(
                'Everything is saved to the server.'.tr,
                style: AppType.bodyM.c(p.success),
              ),
            for (final e in issues.entries)
              Container(
                margin: const EdgeInsets.only(bottom: Gap.sm),
                padding: const EdgeInsets.all(Gap.md),
                decoration: BoxDecoration(
                  color: p.warningSoft,
                  borderRadius: R.all(R.md),
                  border: Border.all(
                    color: p.warning.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      size: 17,
                      color: p.warning,
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _capitalised(e.key.tr),
                            style: AppType.labelL.c(p.ink),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            e.value.tr,
                            style: AppType.bodyS.c(p.inkMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: Gap.lg),
            GButton.accent(
              label: 'Retry now'.tr,
              icon: Icons.refresh_rounded,
              loading: _retrying,
              onPressed: issues.isEmpty || _retrying ? null : _retry,
            ),
          ],
        ),
      ),
    );
  }

  static String _capitalised(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

/// The raised create button. Used by the bar, and by any screen that wants
/// the same action floating over its own content.
class CreateJobCardFab extends StatefulWidget {
  const CreateJobCardFab({super.key, this.onTap, this.diameter = 62});

  final VoidCallback? onTap;
  final double diameter;

  @override
  State<CreateJobCardFab> createState() => _CreateJobCardFabState();
}

class _CreateJobCardFabState extends State<CreateJobCardFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _halo = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    _halo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final d = widget.diameter;
    return Pressable(
      onTap: widget.onTap ?? () => context.push('/job/new'),
      scale: 0.9,
      child: SizedBox(
        width: d + 16,
        height: d + 16,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // A slow breathing ring, so the eye finds the action without
            // anything shouting.
            AnimatedBuilder(
              animation: _halo,
              builder: (context, _) {
                final t = Curves.easeOut.transform(_halo.value);
                return Opacity(
                  opacity: (1 - t) * 0.35,
                  child: Container(
                    width: d + (d * 0.26 * t),
                    height: d + (d * 0.26 * t),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: p.accent, width: 1.4),
                    ),
                  ),
                );
              },
            ),
            Container(
              width: d,
              height: d,
              decoration: BoxDecoration(
                gradient: p.accentGradient,
                shape: BoxShape.circle,
                border: Border.all(color: p.canvas, width: 4),
                boxShadow: Shadows.accent(p),
              ),
              child: Icon(Icons.add_rounded, size: 30, color: p.onAccent),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.branch,
    required this.onTap,
    required this.onSupport,
    this.onCreate,
    this.badges = const {},
  });

  /// Index into the router's branches: 0 Home, 1 Search, 2 Settings.
  final int branch;
  final ValueChanged<int> onTap;
  final VoidCallback onSupport;
  final VoidCallback? onCreate;
  final Map<int, int> badges;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.line)),
        boxShadow: p.isDark ? null : Shadows.lifted(p),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 70,
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth / 5;
              // The underline only tracks the three real pages.
              final slot = switch (branch) {
                0 => 0,
                1 => 1,
                _ => 4,
              };
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedPositioned(
                    duration: Motion.base,
                    curve: Motion.spring,
                    left: w * slot + w * 0.5 - 14,
                    top: 0,
                    child: Container(
                      height: 3,
                      width: 28,
                      decoration: BoxDecoration(
                        color: p.accent,
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(R.pill),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < _left.length; i++)
                        SizedBox(
                          width: w,
                          child: _NavItem(
                            tab: _left[i],
                            selected: branch == i,
                            badge: badges[i] ?? 0,
                            onTap: () => onTap(i),
                          ),
                        ),
                      SizedBox(
                        width: w,
                        child: onCreate == null
                            ? const SizedBox.shrink()
                            : _CreateSlot(onTap: onCreate!),
                      ),
                      SizedBox(
                        width: w,
                        child: _NavItem(
                          tab: _right[0],
                          selected: false,
                          badge: 0,
                          onTap: onSupport,
                        ),
                      ),
                      SizedBox(
                        width: w,
                        child: _NavItem(
                          tab: _right[1],
                          selected: branch == 2,
                          badge: 0,
                          onTap: () => onTap(2),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The create button plus its caption, lifted above the bar.
class _CreateSlot extends StatelessWidget {
  const _CreateSlot({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    // The button is deliberately taller than the bar it sits in, so it is
    // laid out unconstrained and allowed to sit proud of the top edge
    // rather than overflowing it.
    return OverflowBox(
      alignment: Alignment.topCenter,
      minHeight: 0,
      maxHeight: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.translate(
            offset: const Offset(0, -18),
            child: CreateJobCardFab(onTap: onTap, diameter: 58),
          ),
          Transform.translate(
            offset: const Offset(0, -18),
            // One word. Two lines of 7.4pt caption under a button that is
            // already the biggest thing on the bar was belt, braces and a
            // second pair of braces.
            child: Text(
              'CREATE',
              textAlign: TextAlign.center,
              maxLines: 1,
              style: AppType.over.s(8.5).c(p.inkMuted).copyWith(height: 1.2),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.selected,
    required this.onTap,
    required this.badge,
  });

  final _Tab tab;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final color = selected ? p.accent : p.inkFaint;
    return Pressable(
      onTap: onTap,
      scale: 0.9,
      haptic: false,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 6),
          Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedScale(
                scale: selected ? 1.08 : 1,
                duration: Motion.base,
                curve: Motion.spring,
                child: Icon(
                  selected ? tab.activeIcon : tab.icon,
                  size: 23,
                  color: color,
                ),
              ),
              if (badge > 0)
                Positioned(
                  right: -7,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    decoration: BoxDecoration(
                      color: p.accent,
                      borderRadius: R.all(R.pill),
                      border: Border.all(color: p.surface, width: 1.6),
                    ),
                    child: Center(
                      child: Text(
                        badge > 9 ? '9+' : '$badge',
                        style: AppType.labelS.s(9).c(p.onAccent),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          AnimatedDefaultTextStyle(
            duration: Motion.fast,
            style: AppType.labelS
                .s(10.5)
                .c(color)
                .w(selected ? FontWeight.w700 : FontWeight.w500),
            child: Text(tab.label, maxLines: 1),
          ),
        ],
      ),
    );
  }
}
