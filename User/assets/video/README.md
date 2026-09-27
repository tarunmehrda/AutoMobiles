# Welcome screen film

Put one file here, named exactly:

```
garage_hero.mp4
```

That is it. No code change — [`lib/core/widgets/cinematic_hero.dart`](../../lib/core/widgets/cinematic_hero.dart)
already points at this name. Drop the file in, `flutter run`, and the sign-in
screen plays it behind everything instead of holding the still.

Remove the file and the screen goes back to the still. Nothing breaks either
way; the still is the poster the film fades up from, not a placeholder.

---

## What the clip needs to be

| | |
| --- | --- |
| **Length** | 6–12 seconds. It loops. Anything longer is bytes nobody sees. |
| **Sound** | None. It is muted regardless, so audio is dead weight in the APK. |
| **Size** | Under ~4 MB, 1080p, H.264 MP4. This ships *inside* the app and is decoded on the first screen of a cold start. |
| **Loop** | No hard cut at either end, or it blinks every few seconds. |
| **Framing** | Dark, with the action in the middle band. The scrim pours carbon over the top and bottom thirds so the type stays legible — anything important up there is hidden. |

A 40 MB 4K clip costs every user the download and costs cheap phones the
launch. Compress it.

---

## Where to get one

All of these license for commercial use, and none require attribution. Search
for *car workshop*, *mechanic*, *auto repair*, *garage*.

- [Pexels — car garage](https://www.pexels.com/search/videos/car%20garage/)
- [Pexels — mechanic](https://www.pexels.com/search/videos/mechanic/)
- [Coverr — garage](https://coverr.co/stock-video-footage/garage)
- [Coverr — mechanic](https://coverr.co/stock-video-footage/mechanic)
- [Pixabay — auto workshop](https://pixabay.com/videos/search/auto%20workshop/)
- [Mixkit](https://mixkit.co/free-stock-video/)

**Do not use a clip from a search-results page or YouTube.** It is somebody's
copyright and does not stop being theirs because the app is small. Every site
above states its licence on the download page — read it once and you are done.

---

## Compressing it

With ffmpeg, from wherever you saved the download:

```bash
ffmpeg -i original.mp4 \
  -t 10 \
  -vf "scale=1080:-2" \
  -c:v libx264 -crf 28 -preset slow \
  -an -movflags +faststart \
  garage_hero.mp4
```

- `-t 10` trims to ten seconds
- `-an` strips the audio
- `-crf 28` is the quality dial — lower is better and bigger; 30–32 is fine for
  something sitting behind a scrim
- `+faststart` puts the index at the front so playback starts sooner

Check the result is under ~4 MB. If it is not, raise `-crf` or drop to
`scale=720:-2`.

---

## Why bundled and not a URL

`HeroFilm.url` exists in the code and is deliberately empty. Streaming the
welcome screen means every cold start spends the user's data before they have
done anything, the screen is at the mercy of a host that can move or throttle
the file, and on a bad connection the first thing the app does is stall.

Ship the file.

---

## `welcome.mp4` — the corner welcome video

Plays in a corner box each time a signed-in person opens the app (muted;
full screen with sound on tap; can be minimised or closed). The console's
Platform → Content screen can swap in another video by link; this file is
what plays when it has not, or when that link will not load.

17.4 s, 720×1280 portrait (9:16, so it fills a phone held upright),
H.264 Main, no audio track, ~2.3 MB. Cropped from the 1080p versions of
two free-licence Coverr clips (commercial use allowed, no attribution
required), with a 0.6 s crossfade between them:

- "Checking the oil level of a car" — coverr.co, clip 6558, 0–7.5 s,
  cropped at x=230
- "Closing the bonnet of a car" — coverr.co, clip 3343, 0–10.5 s,
  cropped at x=620

To replace it, keep it short, silent and under ~3 MB: it ships inside the
APK.
