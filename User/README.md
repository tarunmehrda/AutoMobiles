# Balaji Automobiles — customer app

A complete Flutter customer app for a car workshop: browse and book services,
hand the car over, watch the job happen live, approve the estimate before any
extra work starts, pay the invoice and keep the whole service history.

The app runs **end to end with no backend**. Everything persists on-device, so
you can demo every screen immediately. When Supabase credentials are added it
mirrors the same data to Postgres without a single change to the UI.

---

## Run it

```bash
flutter pub get
flutter run
```

First launch walks through: onboarding → sign in → profile → add vehicle →
home. Sign in with Google, with an email and password, or with a phone code.
Until an SMS provider is connected the phone route shows the code on screen
rather than texting it.

Adding your first vehicle seeds a realistic sample history — one live job
waiting for your approval plus two completed services with invoices — so
tracking, inspection, estimates, invoices and history are all reachable
straight away. Remove or restore it any time from **Account → App settings →
Data**.

---

## The backend

The app is wired to Supabase and signs in with **Google, email and password,
or a phone code**. Credentials live in
[`lib/core/config/app_config.dart`](lib/core/config/app_config.dart) (the
publishable key — never the service key), and the schema is in
[`../supabase/`](../supabase/), shared with the Admin console.

There is one thing left that only a dashboard can do — running the SQL and
connecting Google. That is [`../SETUP.md`](../SETUP.md), about fifteen
minutes.

Until the SQL has been run the app still works: every write falls back to the
on-device store rather than breaking a user flow, and Account → App settings
shows which mode is live.

To point it at a different project, pass credentials at build time instead of
editing the file:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_...
```

Column names in the schema match the JSON the Dart models emit exactly, so
there is no mapping layer to keep in sync.

---

## What is in the app

| Area | Screens |
| --- | --- |
| Onboarding & auth | Splash, 3-slide intro, phone entry, OTP, profile setup |
| Vehicles | Brand → model → fuel/gearbox → details wizard, garage list, vehicle detail, documents, odometer |
| Catalogue | Home, category browser with sort/filter tabs, service detail, search with ranking |
| Booking | Cart, coupons, handover mode, address book, date + slot picker, summary, confirmation ticket |
| Live job | Stage tracker with auto-advancing timeline, 38-point inspection with health gauge and photos |
| Money | Estimate approval (per item, with revisions), GST invoice, payment methods, receipt |
| After | Rating with per-aspect scores, service history grouped by year, lifetime spend and savings |
| Support | Advisor chat, FAQ centre, complaint tickets, direct call and WhatsApp to the workshop |
| Account | Profile, addresses, offers, notifications, referral, theme, notification preferences |

### Business rules enforced in code

These come straight from the product spec and live in
[`lib/state/app_state.dart`](lib/state/app_state.dart):

- No chargeable work beyond the booked package starts without the customer's
  approval — `advanceBooking` refuses to move past `awaitingApproval`.
- Every estimate revision is a new version; previous versions are kept and
  shown in the history sheet.
- Approvals are timestamped and recorded against the customer's name.
- Payments always attach to a specific invoice.
- Cancelled bookings keep their record; removing a vehicle keeps its history.

---

## Architecture

```
lib/
  core/
    config/      backend switch (Supabase on/off)
    theme/       palette, typography, tokens, ThemeData
    widgets/     the design system — buttons, cards, fields, sheets, painters
    anim/        entrance + transition primitives
    router/      go_router graph and the tab shell
  data/
    models/      entities and enums, hand-written JSON
    seed/        bundled catalogue (43 services, 18 brands, 60+ models) and media
    repo/        AppData snapshot, local store, demo seed, Supabase gateway
  state/         AppController (all mutations + business rules), booking draft, providers
  features/      one folder per screen area
```

State is Riverpod. The entire customer dataset is one immutable `AppData`
snapshot persisted as a single JSON document, which makes restore-on-restart
and the Supabase mirror trivial and keeps rebuilds cheap via `select`.

### Design system

Nothing uses stock Material styling. There is one palette (`AppPalette`) with
hand-tuned light and dark variants, one motion scale (`Motion`), one shadow set
and one type scale (Sora for display and numerals, Inter for reading text —
both bundled, not fetched at runtime).

Every tappable surface goes through `Pressable` so the whole app shares one
press-scale-and-haptic feel. Charts and ornaments — the health gauge, the
blueprint texture, the confetti, the brand mark — are custom
painters rather than images, so they stay sharp and theme-aware at any size.

### Assets

Everything visual is bundled, so nothing renders from the network: images are
instant, identical on every device, and never break offline.

- `assets/brands/` — 18 manufacturer marks (Simple Icons, CC0), tinted to each
  brand's colour at runtime.
- `assets/cars/` — real photographs of 60 models, pulled from Wikipedia, so
  picking "Swift" shows a Swift. The catalogue itself covers **34 makes and
  289 models** — everything a workshop in India sees, including Chevrolets,
  Fiats, Datsuns and Ambassadors that are no longer sold but still on the
  road. A model without its own photograph falls back to a picture of its body
  style, never a broken image. To add one: drop `<model id>.jpg` in here and
  add the id to `Media.carsWithPhotos`.
- `assets/photos/` — workshop photography (Unsplash), named for what is
  actually in the frame so a category can't end up illustrated by something
  unrelated.

`GImage` handles bundled and remote URLs through one widget, falling back to a
tinted gradient and glyph, ready for when the workshop supplies its own imagery
from Supabase Storage.

### Design renders

`tool/screens/` renders whole screens at phone size to PNG:

```bash
flutter test tool/screens --update-goldens
```

Output lands in `tool/screens/out/`. It sits outside `test/` deliberately —
these are for eyeballing layout, not assertions, so copy changes never fail CI.
The harness loads the real fonts and precaches images, so a render matches the
device. It has already caught a handful of genuine bugs: overflowing rows at
390dp, and animation controllers being constructed inside `dispose()`.

---

## Notes for going to production

- Payments are simulated. Drop Razorpay/Stripe into
  `AppController.payInvoice` — the invoice/receipt plumbing around it is done.
- Push notifications are modelled in-app; wire FCM to the same
  `AppNotification` shape.
- Live job progression is driven by timers so the tracker feels alive in a
  demo. In production, replace `startLiveTracking` with a Supabase realtime
  subscription on the `bookings` table — the UI already reacts to state changes.
