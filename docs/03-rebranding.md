# Rebranding for another garage

Both apps are built to be resold. A full rebrand is one Dart file per app plus
two platform values that a Dart constant cannot reach.

Budget: about 20 minutes, most of it waiting for a release build.

---

## 1. The one file

| App | File |
|---|---|
| Console | `Admin/lib/config/brand.dart` |
| Customer | `User/lib/config/brand.dart` |

Everything the customer sees comes from here:

- **Names** — `appName`, `launcherName`, `desktopName`, `storeName`, `tagline`, `vendor`
- **Colour** — `accent`, `accentInk`, `accentSoft`, `onAccent`, `accentGradient`
  (`AppPalette` reads these; there are no other accent literals in the codebase)
- **Art** — `logoMark`, `logoFull`, `splashVideo`
- **Contact** — `supportPhone`, `supportWhatsapp`, `supportEmail`
- **Feature switches** — `showPromoCard`, `showSubscription`, `showMessageCredits`,
  `showBranches`, `showOnlineGarage` (console); `showUpiPayment`, `showChat`,
  `showPickupDrop`, `showOffers` (customer)
- **First-run business profile** — `Brand.business` in the console

The two files must agree on colour. The customer holding the phone sees one product;
an accent that matches in one app and not the other reads as a fake.

---

## 2. The art

Drop replacements in, same filenames, and nothing else has to change:

```
<app>/assets/logo/mark_light.png  the mark inked for paper coloured surfaces
<app>/assets/logo/mark_dark.png   the same mark in amber, for carbon ones
<app>/assets/logo/icon.png        the mark pre-composited on its carbon tile
<app>/assets/video/intro.mp4      splash background (console only)
```

Both apps carry the same three files. The two cuts must be the same artwork at the
same size — they are swapped when the theme flips, so anything that does not
register pixel-for-pixel shows up as a jump. Square, at least 1024x1024. There is
no horizontal lockup any more: the wordmark under the mark on the splash and the
sign-in sheet is set in type by `BrandLogo`, not baked into a file.

The platform icons are cut from `mark_dark.png` and have to be regenerated with it
— `mipmap-*/ic_launcher*.png`, `drawable-*/splash_logo.png`, the iOS
`AppIcon.appiconset`, and `web/icons/`. The geometry the current set was cut at:
the mark at 65.8% of a carbon square for the launcher and iOS, 56.1% on
transparent for the adaptive foreground, 43.9% for the maskable web icon, and
edge to edge for the splash.

---

## 3. The two values Dart cannot set

**Android** — `<app>/android/app/build.gradle.kts`:

```kotlin
android {
    namespace = "com.newgarage.garage"      // must match the Kotlin package below
    defaultConfig {
        applicationId = "com.newgarage.garage"
    }
}
```

Three more places follow from it:

1. `android/app/src/main/kotlin/<path>/MainActivity.kt` — move the file to match the
   new package and change its `package` line. The console's MainActivity carries the
   MediaStore download channel, so do not delete it.
2. `android/app/src/main/AndroidManifest.xml` — `android:label` (the launcher name)
   and the OAuth callback `android:scheme`, which must equal the `applicationId`.
3. `Brand.androidPackage` — it feeds `AppConfig.authRedirect`, so the app and the
   manifest cannot drift apart.

**iOS** — the bundle id in `ios/Runner.xcodeproj`, and `Brand.iosBundleId` to match.

---

## 4. After an id change, update the backend

Changing `applicationId` breaks OAuth until three things are told about it:

- **Supabase → Authentication → URL Configuration** — add
  `com.newgarage.garage://login-callback` to the redirect allow-list.
- **Google Cloud Console → Credentials** — the Android OAuth client is keyed on
  package name + signing SHA-1. A new package needs a new client.
- `Brand`'s `googleWebClientId` in `AppConfig`, if the reseller uses their own
  Google project.

A changed `applicationId` is a different app to the Play Store and to every phone.
Existing installs do not upgrade — they sit alongside. Decide that before shipping,
not after.

---

## 5. Windows (console only)

- `windows/runner/main.cpp` — the `window.Create(L"…")` title
- `windows/runner/Runner.rc` — `FileDescription`, `InternalName`,
  `OriginalFilename`, `ProductName`
- `windows/CMakeLists.txt` — `BINARY_NAME`, which names the `.exe`

---

## 6. Check it

```bash
cd Admin && flutter analyze && flutter test && flutter build apk --release
cd ../User && flutter analyze && flutter test test/ && flutter build apk --release
```

Then open the app and look at: splash, sign-in, the dashboard header, a printed
invoice, and the support sheet. Those five surfaces carry every brandable value
between them.
