import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../core/i18n/strings.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/widgets/pressable.dart';
import '../../state/intro_state.dart';

/// The welcome video, in a corner of whatever screen the counter is on.
///
/// It lives in `MaterialApp.builder`, above the router, so it survives
/// navigation: a player owned by a screen dies with that screen, and a
/// welcome video that stops because somebody tapped through to their car is
/// not much of a welcome.
///
/// Three sizes, one player:
/// * the corner box — muted, with full screen, minimise and close;
/// * the chip — minimised and paused; tap to bring the box back;
/// * full screen — a page of its own, with sound, so the phone's Back
///   button returns to the corner box instead of leaving the screen under
///   it.
class IntroOverlay extends ConsumerWidget {
  const IntroOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(introControllerProvider);
    if (!state.visible) return const SizedBox.shrink();
    return switch (state.mode) {
      IntroMode.floating => _CornerBox(controller: state.controller!),
      IntroMode.minimised => const _Chip(),
      _ => const SizedBox.shrink(),
    };
  }
}

/// Clear of the bottom tab bar and the gesture area on every phone.
double _bottomInset(BuildContext context) =>
    MediaQuery.of(context).padding.bottom + Gap.h3 + Gap.xl;

/// Opens the full-screen page over whatever route is on top.
///
/// A real route rather than an overlay, for the Back button: the router
/// answers Back before anything else in the app gets the chance, so a
/// full-screen overlay could not stop Back from popping the page beneath it.
void _openFull(WidgetRef ref) {
  final controller = ref.read(introControllerProvider).controller;
  final navigator =
      ref.read(routerProvider).routerDelegate.navigatorKey.currentState;
  if (controller == null || navigator == null) return;

  final notifier = ref.read(introControllerProvider.notifier)..enterFull();
  final route = PageRouteBuilder<bool>(
    opaque: true,
    transitionDuration: Motion.base,
    reverseTransitionDuration: Motion.fast,
    pageBuilder: (_, _, _) => IntroFullPage(controller: controller),
    transitionsBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
  navigator.push(route);
  // Only once the page has finished animating away: disposing the player
  // while it is still on screen would draw a dead controller.
  route.completed.then((closed) {
    if (closed == true) {
      notifier.dismiss();
    } else {
      notifier.leaveFull();
    }
    notifier.released();
  });
}

class _CornerBox extends ConsumerWidget {
  const _CornerBox({required this.controller});

  final VideoPlayerController controller;

  /// Portrait, like the video: a phone is held upright, and a tall box
  /// shows the whole frame without cropping it to a letterbox.
  static const double _width = 116;
  static const double _height = _width * 16 / 9;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final notifier = ref.read(introControllerProvider.notifier);

    return Positioned(
      left: Gap.lg,
      bottom: _bottomInset(context),
      child: Material(
        color: Colors.transparent,
        child: Pressable(
          onTap: () => _openFull(ref),
          scale: 0.97,
          borderRadius: R.rMd,
          child: Container(
            width: _width,
            height: _height,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: R.rMd,
              border: Border.all(color: p.line),
              boxShadow: Shadows.lifted(p),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller.value.size.width,
                    height: controller.value.size.height,
                    child: VideoPlayer(controller),
                  ),
                ),
                // A thin progress line, so a small silent rectangle in the
                // corner reads as a video that is playing, not a stuck image.
                Align(
                  alignment: Alignment.bottomCenter,
                  child: VideoProgressIndicator(
                    controller,
                    allowScrubbing: false,
                    padding: EdgeInsets.zero,
                    colors: VideoProgressColors(
                      playedColor: p.accent,
                      bufferedColor: Colors.white24,
                      backgroundColor: Colors.white10,
                    ),
                  ),
                ),
                Positioned(
                  top: 3,
                  left: 3,
                  child: _GlassButton(
                    icon: Icons.open_in_full_rounded,
                    size: 26,
                    tooltip: 'Full screen'.tr,
                    onTap: () => _openFull(ref),
                  ),
                ),
                Positioned(
                  top: 3,
                  right: 3,
                  child: Row(
                    children: [
                      _GlassButton(
                        icon: Icons.remove_rounded,
                        size: 26,
                        tooltip: 'Minimise'.tr,
                        onTap: notifier.minimise,
                      ),
                      const SizedBox(width: 4),
                      _GlassButton(
                        icon: Icons.close_rounded,
                        size: 26,
                        tooltip: 'Close'.tr,
                        onTap: notifier.dismiss,
                      ),
                    ],
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

/// The minimised video: a chip in the same corner. Tap to bring the box
/// back where it left off; × to be done with it.
class _Chip extends ConsumerWidget {
  const _Chip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final notifier = ref.read(introControllerProvider.notifier);
    return Positioned(
      left: Gap.lg,
      bottom: _bottomInset(context),
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
          decoration: BoxDecoration(
            color: p.inverse,
            borderRadius: R.all(R.pill),
            boxShadow: Shadows.lifted(p),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Pressable(
                onTap: notifier.restore,
                scale: 0.95,
                child: Padding(
                  padding:
                      const EdgeInsets.fromLTRB(Gap.sm, Gap.xs, Gap.md, Gap.xs),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_circle_fill_rounded,
                          size: 22, color: p.accent),
                      const SizedBox(width: Gap.xs),
                      Text('Watch'.tr, style: AppType.labelM.c(p.onInverse)),
                    ],
                  ),
                ),
              ),
              _GlassButton(
                icon: Icons.close_rounded,
                size: 26,
                tooltip: 'Close'.tr,
                onTap: notifier.dismiss,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The video, full screen and with sound.
///
/// The clip is portrait, so it fills the phone edge to edge the way it is
/// already held — no black bands, and no rotating the phone. Pops `true`
/// when the person closes the video altogether, and nothing (Back, or the
/// shrink button) to return to the corner box.
class IntroFullPage extends ConsumerStatefulWidget {
  const IntroFullPage({super.key, required this.controller});

  final VideoPlayerController controller;

  @override
  ConsumerState<IntroFullPage> createState() => _IntroFullPageState();
}

class _IntroFullPageState extends ConsumerState<IntroFullPage> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    // Back to the platform default, not edge-to-edge: nothing else in the
    // app opts into drawing under the system bars.
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  static String _clock(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final c = widget.controller;
    final notifier = ref.read(introControllerProvider.notifier);
    // Dismissed from elsewhere while on screen — signing out — so close.
    ref.listen(introControllerProvider.select((s) => s.mode), (_, mode) {
      if (mode == IntroMode.gone &&
          (ModalRoute.of(context)?.isCurrent ?? false)) {
        Navigator.of(context).pop();
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Edge to edge, under the status bar too. `cover` fills a tall
          // phone completely, trimming a sliver off the sides rather than
          // leaving black bands above and below.
          Positioned.fill(
            child: GestureDetector(
              onTap: notifier.togglePlay,
              child: FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: c.value.size.width,
                  height: c.value.size.height,
                  child: VideoPlayer(c),
                ),
              ),
            ),
          ),
          // Shade behind the controls at the top and the bottom, so white
          // buttons stay readable over a bright frame.
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x99000000),
                      Color(0x00000000),
                      Color(0x00000000),
                      Color(0xB3000000),
                    ],
                    stops: [0, 0.18, 0.78, 1],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Stack(
              children: [
                // Paused, or finished: a big button that says what a tap does.
                Center(
                  child: ValueListenableBuilder<VideoPlayerValue>(
                    valueListenable: c,
                    builder: (context, v, _) {
                      final ended = v.isInitialized &&
                          v.position >= v.duration &&
                          !v.isPlaying;
                      return AnimatedOpacity(
                        duration: Motion.fast,
                        opacity: v.isPlaying ? 0 : 1,
                        child: IgnorePointer(
                          ignoring: v.isPlaying,
                          child: Pressable(
                            onTap: notifier.togglePlay,
                            scale: 0.92,
                            child: Container(
                              padding: const EdgeInsets.all(Gap.lg),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black54,
                              ),
                              child: Icon(
                                ended
                                    ? Icons.replay_rounded
                                    : Icons.play_arrow_rounded,
                                size: 42,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                Positioned(
                  left: Gap.lg,
                  right: Gap.lg,
                  bottom: Gap.md,
                  child: Row(
                    children: [
                      ValueListenableBuilder<VideoPlayerValue>(
                        valueListenable: c,
                        builder: (context, v, _) => Text(
                          '${_clock(v.position)} / ${_clock(v.duration)}',
                          style: AppType.labelS.c(Colors.white70),
                        ),
                      ),
                      const SizedBox(width: Gap.md),
                      Expanded(
                        child: VideoProgressIndicator(
                          c,
                          allowScrubbing: true,
                          padding: const EdgeInsets.symmetric(vertical: Gap.md),
                          colors: VideoProgressColors(
                            playedColor: p.accent,
                            bufferedColor: Colors.white24,
                            backgroundColor: Colors.white12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Positioned(
                  top: Gap.md,
                  left: Gap.md,
                  child: _GlassButton(
                    icon: Icons.close_fullscreen_rounded,
                    tooltip: 'Back to the corner'.tr,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
                Positioned(
                  top: Gap.md,
                  right: Gap.md,
                  child: _GlassButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Close'.tr,
                    onTap: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A round translucent control that stays legible over any frame of video.
class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.size = 38,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Pressable(
        onTap: onTap,
        scale: 0.9,
        child: Container(
          height: size,
          width: size,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black54,
          ),
          child: Icon(icon, size: size * 0.55, color: Colors.white),
        ),
      ),
    );
  }
}
