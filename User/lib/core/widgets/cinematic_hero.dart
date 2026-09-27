import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../theme/app_colors.dart';
import 'brand_logo.dart';

/// Where the welcome picture lives.
///
/// One frame, shot inside a bay: a car up on the lift, the amber of its body
/// already the brand's accent, and enough unlit clutter top and bottom for the
/// type to sit in.
///
/// The still is not a placeholder to be deleted once the film lands — it is
/// the poster the film fades up from, and the screen the app falls back to on
/// any device or build where the film cannot play.
class HeroStill {
  const HeroStill._();

  static const String image = 'assets/photos/garage_hero.jpg';
}

/// The opening film.
///
/// Drop a short, silent, loopable clip of a workshop at `asset` and the
/// welcome screen plays it behind everything. Leave it empty and the screen
/// keeps the still — nothing else in the app needs to know which it got.
///
/// ## Choosing the clip
///
/// * **6–12 seconds.** It loops; anything longer is bytes nobody sees.
/// * **Silent.** It is muted regardless, so audio is dead weight.
/// * **Under ~4 MB, 1080p.** This ships inside the APK and is decoded on the
///   first screen of a cold start. A 40 MB 4K clip costs every user the
///   download and costs cheap phones the launch.
/// * **Dark, with the action off-centre.** [HeroScrim] pours carbon over the
///   top and bottom thirds for the type; whatever matters wants to be in the
///   middle band.
/// * **No hard cut at either end.** The loop is seamless or it blinks.
///
/// ## Licensing
///
/// Use a clip you are allowed to ship. Pexels, Coverr, Pixabay and Mixkit all
/// license for commercial use without attribution; a video lifted from search
/// results or YouTube is somebody's copyright and does not stop being theirs
/// because an app is small.
class HeroFilm {
  const HeroFilm._();

  /// Bundled clip. Declared under `assets/video/` in pubspec.yaml.
  static const String asset = 'assets/video/garage_hero.mp4';

  /// A remote clip, used only when [asset] is not in the bundle.
  ///
  /// Deliberately empty. Streaming the welcome screen means every cold start
  /// spends the user's data before they have done anything, the screen is at
  /// the mercy of a host that can move or throttle it, and on a bad connection
  /// the first thing the app does is stall. Ship the file.
  static const String url = '';

  static bool get any => asset.isNotEmpty || url.isNotEmpty;
}

/// Full-bleed opening frame, the way the dating apps open: the picture runs
/// behind everything and the screen is just type and buttons floating on it.
///
/// Three things keep it from being a naive `Image.asset`:
///
/// * the still lifts out of [BrandArt.carbon] — the colour the splash ends on
///   — only once the decoder has handed us a frame, so the handoff reads as
///   one continuous shot instead of a flash of bare colour;
/// * a slow push-in runs on the still, so even with no film it reads as held
///   footage rather than as wallpaper;
/// * if a film is bundled, it fades up over the still once it has buffered
///   enough to play cleanly — never a black rectangle waiting to start.
class CinematicBackground extends StatefulWidget {
  const CinematicBackground({super.key});

  @override
  State<CinematicBackground> createState() => _CinematicBackgroundState();
}

class _CinematicBackgroundState extends State<CinematicBackground>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  /// The push-in on the still. Reversing rather than looping means it never
  /// cuts back to the top of the move; it just breathes.
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 22),
  )..repeat(reverse: true);

  VideoPlayerController? _film;
  bool _rolling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (HeroFilm.any) _loadFilm();
  }

  Future<void> _loadFilm() async {
    final controller = HeroFilm.asset.isNotEmpty
        ? VideoPlayerController.asset(HeroFilm.asset)
        : VideoPlayerController.networkUrl(Uri.parse(HeroFilm.url));

    try {
      await controller.initialize();
      await controller.setVolume(0);
      await controller.setLooping(true);
      await controller.play();
    } catch (_) {
      // A missing file, a codec this device does not have, a dead link. The
      // still is already on screen and is a perfectly good welcome — there is
      // nothing to report and nobody to report it to.
      await controller.dispose();
      return;
    }

    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() {
      _film = controller;
      _rolling = true;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A loop running behind a backgrounded app is battery spent on a screen
    // nobody is looking at.
    final film = _film;
    if (film == null || !film.value.isInitialized) return;
    if (state == AppLifecycleState.resumed) {
      film.play();
    } else {
      film.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _drift.dispose();
    _film?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: BrandArt.carbon,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _still(),

          // The film sits over the still and fades in, so the cut from one to
          // the other is a dissolve on an image that is already there rather
          // than a black frame arriving.
          if (_film case final film?)
            AnimatedOpacity(
              opacity: _rolling ? 1 : 0,
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOut,
              child: FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: film.value.size.width,
                  height: film.value.size.height,
                  child: VideoPlayer(film),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _still() {
    return AnimatedBuilder(
      animation: _drift,
      builder: (context, child) {
        // Once the film is carrying the motion, the still underneath holds
        // position — two different drifts fighting each other is a wobble.
        if (_rolling) return child!;
        final t = Curves.easeInOut.transform(_drift.value);
        return Transform.scale(
          scale: 1.04 + 0.08 * t,
          // A touch of rise with the push, so the move has a direction
          // instead of only swelling.
          child: Transform.translate(
            offset: Offset(0, -10 * t),
            child: child,
          ),
        );
      },
      child: SizedBox.expand(
        child: Image.asset(
          HeroStill.image,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          // Decode is a frame or two on a cold start. Hold carbon until the
          // picture exists, then dissolve, rather than punching it in.
          frameBuilder: (context, child, frame, wasSyncLoaded) {
            if (wasSyncLoaded) return child;
            return AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: const Duration(milliseconds: 620),
              curve: Curves.easeOut,
              child: child,
            );
          },
          // Nothing useful to draw in place of it — carbon alone is a
          // deliberate-looking screen, a broken-image glyph is not.
          errorBuilder: (context, error, stack) => const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// What makes the picture a *background* rather than an image competing with
/// the words.
///
/// A flat veil knocks the frame back towards the brand's carbon, one
/// top-to-bottom ramp buys a legible status bar and a near-solid floor for the
/// buttons, and a low amber bloom ties the whole thing to the accent.
class HeroScrim extends StatelessWidget {
  const HeroScrim({super.key});

  @override
  Widget build(BuildContext context) {
    const carbon = BrandArt.carbon;
    final glow = context.c.accent;

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0x24101215)),
          Align(
            alignment: const Alignment(-0.9, 0.55),
            child: SizedBox(
              height: 380,
              width: 380,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    glow.withValues(alpha: 0.22),
                    glow.withValues(alpha: 0),
                  ]),
                ),
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                // The top band is darker than it looks like it needs to be:
                // the bay's ceiling tubes are the brightest thing in the
                // frame, and the white lockup sits right in them. At these
                // stops it clears ~9:1 against white on average and never
                // drops below ~4:1 on the worst pixel under it. Between 0.36
                // and 0.60 the scrim lets go entirely — that is where the car
                // on the lift is.
                colors: [
                  carbon.withValues(alpha: 0.90),
                  carbon.withValues(alpha: 0.46),
                  carbon.withValues(alpha: 0.14),
                  carbon.withValues(alpha: 0.00),
                  carbon.withValues(alpha: 0.55),
                  carbon.withValues(alpha: 0.94),
                  carbon,
                ],
                stops: const [0.0, 0.14, 0.26, 0.36, 0.60, 0.85, 1.0],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
