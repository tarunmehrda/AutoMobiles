import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../data/repo/intro_gateway.dart';
import 'providers.dart';

/// The workshop clip every install carries, so there is always something to
/// play: the platform can swap in its own video from the console
/// (Platform → Content), and when it has not — or its link will not load —
/// this is what plays.
const kWelcomeClip = 'assets/video/welcome.mp4';

/// Where the welcome video is on screen.
enum IntroMode {
  /// Not on screen — not started yet, finished, or closed.
  gone,

  /// The corner box: a small muted player over whatever screen the person
  /// is on. This is where it starts: a video that seizes the whole screen
  /// the moment the app opens is an obstacle, not a welcome.
  floating,

  /// Folded down to a small "Watch" chip in the same corner, paused, for
  /// the person who wants it out of the way without losing it.
  minimised,

  /// Full screen, as a page of its own, with sound — because they asked.
  full,
}

@immutable
class IntroState {
  const IntroState({
    this.mode = IntroMode.gone,
    this.controller,
  });

  final IntroMode mode;
  final VideoPlayerController? controller;

  bool get visible => mode != IntroMode.gone && controller != null;

  IntroState copyWith({IntroMode? mode}) =>
      IntroState(mode: mode ?? this.mode, controller: controller);
}

final introControllerProvider =
    NotifierProvider<IntroController, IntroState>(IntroController.new);

/// Owns the welcome video: when it appears, where it sits, and the one
/// [VideoPlayerController] behind every size of it.
///
/// It plays once each time the app is opened by a signed-in person — the
/// corner box first, muted, then whatever they choose: full screen with
/// sound, folded down to a chip, or closed. It used to play once per
/// account, ever, and only when the platform had pasted a link in; with no
/// link (the usual case) nobody ever saw it.
///
/// The same controller serves the corner box and the full-screen page, so
/// going full screen does not restart the video or load it again.
class IntroController extends Notifier<IntroState> {
  bool _disposed = false;

  /// Once per launch: the flag lives as long as this process does.
  bool _started = false;

  @override
  IntroState build() {
    ref.onDispose(() {
      _disposed = true;
      state.controller?.dispose();
    });
    ref.listen(isSignedInProvider, (was, now) {
      if (now && !(was ?? false)) unawaited(_start());
      // Signing out takes it away; the next person to sign in on this
      // phone gets their own.
      if (!now && (was ?? false)) {
        dismiss();
        _started = false;
      }
    }, fireImmediately: true);
    return const IntroState();
  }

  Future<void> _start() async {
    if (_started) return;
    _started = true;

    final url = await ref.read(introGatewayProvider).overrideUrl();
    VideoPlayerController? controller;
    if (url != null) {
      controller =
          await _open(VideoPlayerController.networkUrl(Uri.parse(url)));
    }
    // A dead link, an unplayable codec or no network all end here: the
    // built-in clip plays instead of nothing.
    controller ??= await _open(VideoPlayerController.asset(kWelcomeClip));
    if (controller == null) return;
    if (_disposed) {
      await controller.dispose();
      return;
    }

    controller.addListener(_watchForEnd);
    // Muted in the corner: sound that starts by itself, from a box the
    // person did not open, is the fastest way to get the app closed.
    await controller.setVolume(0);
    await controller.play();
    state = IntroState(mode: IntroMode.floating, controller: controller);
  }

  static Future<VideoPlayerController?> _open(VideoPlayerController c) async {
    try {
      await c.initialize();
      await c.setLooping(false);
      return c;
    } catch (e) {
      debugPrint('welcome video could not be opened: $e');
      await c.dispose();
      return null;
    }
  }

  bool get _ended {
    final c = state.controller;
    if (c == null || !c.value.isInitialized) return false;
    return c.value.position >= c.value.duration && !c.value.isPlaying;
  }

  /// Out of the way by itself once it has played through — unless it is
  /// full screen, where the person is watching and gets a replay button.
  void _watchForEnd() {
    if (_ended &&
        state.mode != IntroMode.full &&
        state.mode != IntroMode.gone) {
      // Not from inside the controller's own listener: disposing a notifier
      // while it is notifying is an error.
      scheduleMicrotask(dismiss);
    }
  }

  /// Full screen, with sound. The page itself is pushed by the overlay,
  /// which has the navigator; this only moves the state.
  void enterFull() {
    final c = state.controller;
    if (c == null || state.mode == IntroMode.full) return;
    state = state.copyWith(mode: IntroMode.full);
    unawaited(c.setVolume(1));
    if (!_ended) unawaited(c.play());
  }

  /// Back from full screen to the corner box, muted and still playing — or
  /// gone, if it had already finished.
  void leaveFull() {
    final c = state.controller;
    if (c == null || state.mode != IntroMode.full) return;
    if (_ended) {
      dismiss();
      return;
    }
    state = state.copyWith(mode: IntroMode.floating);
    unawaited(c.setVolume(0));
  }

  /// Corner box → chip. Paused, so it is not playing to nobody.
  void minimise() {
    final c = state.controller;
    if (c == null || state.mode != IntroMode.floating) return;
    unawaited(c.pause());
    state = state.copyWith(mode: IntroMode.minimised);
  }

  /// Chip → corner box, carrying on from where it stopped.
  void restore() {
    final c = state.controller;
    if (c == null || state.mode != IntroMode.minimised) return;
    state = state.copyWith(mode: IntroMode.floating);
    unawaited(c.play());
  }

  void togglePlay() {
    final c = state.controller;
    if (c == null) return;
    if (_ended) {
      unawaited(c.seekTo(Duration.zero).then((_) => c.play()));
    } else {
      unawaited(c.value.isPlaying ? c.pause() : c.play());
    }
  }

  /// Done with it for this launch.
  void dismiss() {
    final c = state.controller;
    if (c == null && state.mode == IntroMode.gone) return;
    state = const IntroState();
    if (c != null) {
      c.removeListener(_watchForEnd);
      unawaited(c.pause().whenComplete(c.dispose));
    }
  }
}
