import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../data/repo/platform_gateway.dart';
import 'auth_state.dart';

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
/// It plays once each time the console is opened by a signed-in person —
/// the corner box first, muted, then whatever they choose: full screen with
/// sound, folded down to a chip, or closed. The customer app plays the same
/// video the same way, so the workshop sees exactly what its customers see.
///
/// The same controller serves the corner box and the full-screen page, so
/// going full screen does not restart the video or load it again.
class IntroController extends Notifier<IntroState> {
  bool _disposed = false;

  /// Once per launch: the flag lives as long as this process does.
  bool _started = false;

  /// Bumped on every start and every sign-out, so a load that finishes after
  /// the person it was for has signed out (or signed out and back in) is
  /// thrown away instead of appearing over the login screen, or leaking a
  /// second player behind the first.
  int _generation = 0;

  /// A player dismissed while the full-screen page was still drawing it,
  /// kept alive until that page is off screen. See [released].
  VideoPlayerController? _heldByPage;

  @override
  IntroState build() {
    ref.onDispose(() {
      _disposed = true;
      state.controller?.dispose();
      _heldByPage?.dispose();
    });
    ref.listen(signedInProvider, (was, now) {
      if (now && !(was ?? false)) unawaited(_start());
      // Signing out takes it away; the next person to sign in on this
      // phone gets their own.
      if (!now && (was ?? false)) {
        _generation++;
        dismiss();
        _started = false;
      }
    }, fireImmediately: true);
    return const IntroState();
  }

  Future<void> _start() async {
    if (_started) return;
    _started = true;
    final generation = ++_generation;

    final url = await _overrideUrl();
    VideoPlayerController? controller;
    if (url != null) {
      controller =
          await _open(VideoPlayerController.networkUrl(Uri.parse(url)));
    }
    // A dead link, an unplayable codec or no network all end here: the
    // built-in clip plays instead of nothing.
    controller ??= await _open(VideoPlayerController.asset(kWelcomeClip));
    if (controller == null) return;

    // Muted in the corner: sound that starts by itself, from a box the
    // person did not open, is the fastest way to get the app closed.
    await controller.setVolume(0);
    await controller.play();
    if (_disposed || generation != _generation) {
      await controller.dispose();
      return;
    }
    controller.addListener(_watchForEnd);
    state = IntroState(mode: IntroMode.floating, controller: controller);
  }

  /// The video set under Platform → Content, when it is switched on and is
  /// a direct video file; null means "play the built-in clip".
  static Future<String?> _overrideUrl() async {
    final s = await PlatformGateway.instance.settings();
    final url = s.introVideoUrl.trim();
    if (!s.introVideoOn || url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !uri.host.contains('.')) return null;
    final path = uri.path.toLowerCase();
    return path.endsWith('.mp4') || path.endsWith('.m3u8') ? url : null;
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
    // Paused full screen, it would otherwise sit in the corner as a frozen
    // frame with no play button, and never finish to take itself away.
    if (!c.value.isPlaying) unawaited(c.play());
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
    final onScreen = state.mode == IntroMode.full;
    state = const IntroState();
    if (c == null) return;
    c.removeListener(_watchForEnd);
    if (onScreen) {
      // The full-screen page is still drawing it (signed out mid-video,
      // say). The page closes itself on seeing `gone`; the player goes once
      // it is off screen, in [released].
      unawaited(c.pause());
      _heldByPage = c;
    } else {
      unawaited(c.pause().whenComplete(c.dispose));
    }
  }

  /// The full-screen page has finished closing.
  void released() {
    final c = _heldByPage;
    _heldByPage = null;
    if (c != null) unawaited(c.dispose());
  }
}
