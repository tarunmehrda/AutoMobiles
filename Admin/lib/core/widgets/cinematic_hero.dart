import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../theme/app_colors.dart';
import 'brand_logo.dart';

/// Where the welcome reel lives.
///
/// The poster is the reel's own first frame, so it is not a stand-in for the
/// footage — it *is* the footage, held still until the decoder catches up.
class HeroReel {
  const HeroReel._();

  static const String video = 'assets/video/hero_loop.mp4';
  static const String poster = 'assets/video/hero_poster.jpg';
}

/// Full-bleed looping footage, the way the dating apps open: the picture runs
/// behind everything and the screen is just type and buttons floating on it.
///
/// Three things keep it from being a naive `VideoPlayer`:
///
/// * the poster frame is painted underneath from the first frame, so the reel
///   dissolves into motion instead of punching in from black;
/// * the whole layer lifts out of [BrandArt.carbon], which is the colour the
///   splash ends on — the handoff reads as one continuous shot;
/// * if the platform has no decoder for us the poster simply stays, with a
///   slow drift on it, and nobody sees a hole where the video should be.
class CinematicBackground extends StatefulWidget {
  const CinematicBackground({super.key});

  @override
  State<CinematicBackground> createState() => _CinematicBackgroundState();
}

class _CinematicBackgroundState extends State<CinematicBackground>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  VideoPlayerController? _video;

  /// The lift out of carbon. Runs immediately, whether or not the reel loads.
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  /// Dissolve from the held poster frame into the moving one.
  late final AnimationController _videoIn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );

  /// Only ever runs in the no-decoder case, to keep the still from feeling
  /// like a broken video.
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 22),
  );

  bool _playing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reveal.forward();
    _load();
  }

  Future<void> _load() async {
    final controller = VideoPlayerController.asset(HeroReel.video);
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();
    } catch (_) {
      // No decoder, no asset, or a platform with no video support at all —
      // the poster carries the screen on its own.
      await _discard(controller);
      if (!mounted) return;
      _drift.repeat(reverse: true);
      return;
    }

    if (!mounted) {
      await _discard(controller);
      return;
    }
    setState(() {
      _video = controller;
      _playing = true;
    });
    _videoIn.forward();
  }

  /// Teardown for a controller we are abandoning. It has already failed us
  /// once, so its own `dispose` is not to be trusted to stay quiet either.
  Future<void> _discard(VideoPlayerController controller) async {
    try {
      await controller.dispose();
    } catch (_) {
      // Nothing useful is left to do with it.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final video = _video;
    if (video == null || !video.value.isInitialized) return;
    state == AppLifecycleState.resumed ? video.play() : video.pause();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _video?.dispose();
    _reveal.dispose();
    _videoIn.dispose();
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: BrandArt.carbon,
      child: FadeTransition(
        opacity: CurvedAnimation(parent: _reveal, curve: Curves.easeOut),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _poster(),
            if (_playing && _video != null)
              FadeTransition(
                opacity:
                    CurvedAnimation(parent: _videoIn, curve: Curves.easeOut),
                child: _cover(_video!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _poster() {
    final still = Image.asset(
      HeroReel.poster,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
    );

    // Once the reel is running the poster is covered — leave it still rather
    // than paying for a ticker nobody can see.
    if (_playing) return SizedBox.expand(child: still);

    return AnimatedBuilder(
      animation: _drift,
      builder: (context, child) => Transform.scale(
        scale: 1.03 + 0.09 * Curves.easeInOut.transform(_drift.value),
        child: child,
      ),
      child: SizedBox.expand(child: still),
    );
  }

  /// `BoxFit.cover` for a texture: scale the reel's own frame up until it
  /// fills, and crop the overhang.
  Widget _cover(VideoPlayerController controller) {
    final size = controller.value.size;
    if (size.width <= 0 || size.height <= 0) return const SizedBox.expand();
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }
}

/// What makes the footage a *background* rather than a picture competing with
/// the words.
///
/// A flat veil knocks the greens back towards the brand's carbon, one
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
                // the reel's sky peaks well above its own average (the frame
                // averages ~114/255 up there, and the bright gaps between the
                // trees go far higher), and the white lockup sits right in
                // it. Between 0.36 and 0.60 the scrim lets go entirely —
                // that is where the car is.
                colors: [
                  carbon.withValues(alpha: 0.86),
                  carbon.withValues(alpha: 0.34),
                  carbon.withValues(alpha: 0.06),
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
