# Balaji Automobiles Admin — workshop console

The garage-owner side of Balaji Automobiles. Open a job card at the counter, build the
bill as the work happens, hand over an estimate, invoice or mechanic copy, take
the money and chase what is still owed.

It is a **separate Flutter app** from the customer app in `../User`, sharing
that app's design system rather than its code paths. Two products, one look.

```bash
flutter pub get
flutter run
```

First launch walks through: intro → sign in → workshop setup. Sign in with
Google, with an email and password, or with a phone code. On the setup screen,
**Load the demo workshop** fills the console with Vikas Automobiles, three
customers and three job cards — one on the floor, two billed — so every screen
is reachable immediately.

---

## What is in the app

| Area | Screens |
| --- | --- |
| Dashboard | Plan countdown, billed/collected today, Open / Complete / Closed counters, service due, new bookings, pending balance, console grid |
| Job cards | Three buckets behind one segmented control, search by number, name, phone or registration; create card with registration lookup and a 34-make, 289-model vehicle picker |
| One job card | Vehicle header with last-history and call/WhatsApp, panel strip, Estimate / Invoice / Mechanic copy, SMS trail, transactions, payment QR |
| Panels | Items (Jobs / Spare / Lube), Customer voice, Accessories, Work note, Dent marks, Photos |
| Money | Record payment, close-with-balance, pending balance list, service-due follow-up with one-tap WhatsApp |
| Stock | Labour / spare / lube masters, live stock, low-stock filter, receive stock |
| Reports | Billed vs collected, cards opened, average bill, turnaround, revenue split by kind, most-billed lines |
| Attendance | Punch in / punch out against a pinned workshop location, live distance dial, day register with hours worked, blocked-attempt log |
| Contacts | The phone's address book, searchable, with existing customers marked; call, WhatsApp or save straight to the customer book |
| Admin | Workshop details, mechanics, attendance location, messaging, default GST, theme, demo data, support |

### Business rules enforced in code

These live in [`lib/state/admin_state.dart`](lib/state/admin_state.dart) and
are covered by [`test/admin_test.dart`](test/admin_test.dart):

- A job card number is minted once, at creation, and never changes.
- Nothing completes with an empty bill; nothing closes before it completes.
- Stock moves the moment a part is put on a card, and comes back if the line is
  removed, the quantity drops, or the whole card is deleted. Labour never
  touches stock.
- A closed card is frozen — no more billing until it is reopened, and
  reopening drops reminders that have not gone out yet.
- Payments attach to a job card and never exceed the outstanding balance.
- Closing schedules three service reminders around the next service date.
- A card may close carrying a balance; it stays under Pending balance until
  the money is collected.

### The three documents

All three are the same sheet with different rules about what is on it:

- **Estimate** — what the work is expected to cost, before approval.
- **Invoice** — the same lines plus paid and balance.
- **Mechanic copy** — the complaint, the accessories, the work list and a
  column for the floor to write in, and deliberately **no pricing at all**.

Each renders on screen ([`documents/job_document.dart`](lib/features/jobcard/documents/job_document.dart))
and as an A4 PDF ([`documents/pdf_builder.dart`](lib/features/jobcard/documents/pdf_builder.dart)).
The PDF is built from the same model rather than screenshotting the UI, so it
stays crisp and its text stays selectable. Share, print, save, email, or send
the on-screen card as an image.

---

## Architecture

```
lib/
  core/
    config/      backend switch (Supabase on/off)
    theme/       palette, typography, tokens, ThemeData  <- shared with ../User
    widgets/     the design system                       <- shared with ../User
    anim/        entrance + transition primitives        <- shared with ../User
    utils/       formatters, amount-in-words, file saving
    router/      go_router graph and the tab shell
  data/
    models/      entities and enums, hand-written JSON
    repo/        AdminData snapshot, local store
    seed/        master lists and the demo workshop
  state/         AdminController (all mutations + business rules), providers
  features/      one folder per screen area
```

State is Riverpod. The whole workshop is one immutable `AdminData` snapshot
persisted as a single JSON document, which keeps restore-on-restart trivial and
rebuilds cheap via `select`.

`lib/core/{theme,widgets,anim}` are copied verbatim from `../User` on purpose —
the two apps must look like one product, and a shared package is not worth the
build complexity for two apps in one folder. If you change a token or a widget,
change it in both.

---

## Attendance, and what "verified" means

Punching in is the one thing in this console that the phone is **not**
trusted to decide. Everything else here is offline-first — the counter is
the authority on its own paperwork — but attendance is the case where the
device is the thing being checked, so the same design would be no design.

The rules therefore live in the database.
[`../supabase/05_attendance.sql`](../supabase/05_attendance.sql) gives
`attendance` a select policy and **nothing else**: no insert, no update, no
delete, for anybody, owner included. Rows come into existence only through
`punch_attendance()`, which re-derives the distance from the submitted
coordinates, re-reads the radius from the garage row, stamps the time from
the server's clock, and writes every refusal down as a row rather than
dropping it.

On the device, [`repo/attendance_gate.dart`](lib/data/repo/attendance_gate.dart)
checks three things the server cannot see:

1. **The platform mock flag** (`Position.isMocked`). Since Android 6 the
   supported way to feed a device a false position is to register as a mock
   location provider, and every fix from one is flagged. This is what the
   Play Store shelf of "Fake GPS" apps trips.
2. **A second provider.** The same question is put to the platform
   `LocationManager` as well as Google's fused client; a hook usually sits
   on only one. Two providers further apart than their own accuracy explains
   is the finding.
3. **Physics.** A phone that was at the workshop a minute ago cannot be
   forty kilometres away now.

An attempt the device catches as abuse is still sent upstream, so it lands
in the register as a blocked attempt instead of being swallowed by the phone
that made it.

**What this does not do.** A rooted device running a hook inside the app's
own process can hand the server a plausible, un-flagged, in-radius lie, and
on iOS `isMocked` is always false — spoofing there needs a jailbreak or a
Mac on a cable. These controls raise the cost from "install a free app" to
"root the phone and defeat the cross-provider check", and make every attempt
visible. That is the achievable goal.

**On the 5 m radius.** It is the default, and it is smaller than the
instrument measuring it: a phone fix is good to roughly 5–15 m in the open
and worse under a roof. A circle that tight will sometimes turn away
somebody genuinely standing in it. The radius and the accuracy ceiling are
both columns on `garages`, editable from **Attendance → location**, and the
screen says so at the point where it can still be acted on.

---

## The backend

The console is wired to Supabase and signs in with **Google, email and
password, or a phone code**. Credentials live in
[`lib/core/config/app_config.dart`](lib/core/config/app_config.dart) (the
publishable key — never the service key), and the schema is in
[`../supabase/`](../supabase/), shared with the customer app.

One thing is left that only a dashboard can do — running the SQL and
connecting Google. That is [`../SETUP.md`](../SETUP.md).

Until then the console still runs: everything falls back to the on-device
store rather than failing to start.

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_...
```

The two apps share `profiles` and meet at the customer's phone number: this
app's `job_cards` are the authority, and the customer app reads a filtered,
read-only view of them. See **How the two apps meet** in `../SETUP.md`.

---

## Notes for going to production

- SMS is modelled, not sent. The trail on each card records what *would* go
  out; wire a gateway to `AdminController.markComplete` / `closeJobCard`.
- The payment QR is a standard UPI intent string built from the workshop's UPI
  ID, so any UPI app already reads it. Reconciliation is still manual —
  payments are recorded by hand in the ledger.
- Photos are stored as device file paths. Move them to Supabase Storage before
  the customer app can show them.
- Stock is single-location and has no purchase-order trail. `restock()` is the
  hook to hang one on.
- Attendance is marked against a `staff` row chosen on the device, not against
  an authenticated identity — anybody holding the phone can punch in as
  anybody on the team. The location controls stop a punch from the wrong
  *place*, not from the wrong *person*. `garage_members.staff_id` in
  `04_roles.sql` is where per-person sign-in would attach.
- Without `05_attendance.sql` on the project, punches still record but land in
  the register marked **Not verified** — the phone's unchecked word for it.
  Run `../supabase/99_verify.sql` to see which files a database is missing.
