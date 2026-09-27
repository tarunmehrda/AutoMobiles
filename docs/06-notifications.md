# Notifications — how the workshop finds out

Three layers, each one covering a case the one before it cannot. They are
independent: the first two work on the Supabase project alone, and the
third can be left off entirely without changing anything else.

| Console is… | Told by | Needs |
|---|---|---|
| open, on any screen | in-app banner over the navigator | nothing extra |
| open, later | the bell and its feed | nothing extra |
| backgrounded or closed | an OS notification | Firebase (layer 3) |

---

## The path a booking takes

```
customer taps Confirm
  └─ app_state.createBooking()                          User app
       └─ _tellTheWorkshop()
            └─ INSERT garage_bookings (accepted = false)
                 │
                 ├─ trigger garage_bookings_notify       06_notifications.sql
                 │    └─ INSERT garage_notifications
                 │         │
                 │         ├─ realtime → channel garage:<id>   ── console open
                 │         │    └─ AdminController._remoteRow
                 │         │         ├─ state.notifications  → bell + feed
                 │         │         └─ alerts stream        → AlertHost banner
                 │         │
                 │         └─ DB webhook → notify-garage       ── console closed
                 │              └─ FCM → tray notification
                 │                   └─ tap → PushService → route
                 │
                 └─ realtime → openBookingsProvider → Bookings screen
```

The row in `garage_notifications` is the durable record. Everything else —
the banner, the tray, the badge — is a view of it. That is deliberate: a
push that never arrives, a socket that was down, an app that was closed
for a week all converge on the same feed the next time the console opens.

## Why notifications are written by the database

`garage_notifications` has a select policy and nothing else. No insert, no
update, no delete, for anybody, owner included — the same arrangement as
`attendance`, and for the same reason. A notification is a record of
something that already happened in another table. A client that can insert
one can invent the past; a client that can delete one can hide a booking
request from the person it was meant for. So rows are raised by triggers,
and `read` is moved by `read_garage_notifications()`, which will not touch
any other column.

---

## Layers 1 and 2 — nothing to set up

Run `supabase/06_notifications.sql` (or the regenerated `setup_all.sql`).
That is the whole installation. It creates the table, the triggers, the
read function and the device register, puts the table on the realtime
publication, and backfills a notification for every booking request that
was already waiting.

Check it with `supabase/99_verify.sql` — six `06_notifications` rows,
all `OK`.

In the console:

- **`AlertHost`** (`lib/core/widgets/alert_host.dart`) wraps the navigator
  inside `MaterialApp.builder`, so a banner appears over whatever is on
  screen, including a full-screen sheet. It is not a SnackBar: a SnackBar
  belongs to the nearest `ScaffoldMessenger` and would vanish with the
  route under it.
- **The bell** on the dashboard now counts unread feed rows, not open
  bookings, and opens `/notifications`. An unaccepted booking from last
  week should not keep the dot lit once somebody has seen it.
- **Opening the feed marks it read**, on every handset at the counter at
  once, because `read` lives on the row rather than on the device.

---

## Layer 3 — push

Optional. Without it the console builds, runs and notifies exactly as
described above; it just cannot ring a phone that is not running it.
`PushService.enabled` stays false and every entry point is a no-op.

### 1. Firebase project

1. Create a Firebase project (or reuse one) and add an **Android app** with
   package name `com.garagepro.garagepro_admin`.
2. Download `google-services.json` into `Admin/android/app/`.
3. Apply the Google services Gradle plugin — it is deliberately *not*
   applied in the repo, so that a checkout without the JSON still builds:

   `Admin/android/settings.gradle.kts`, in the `plugins` block:
   ```kotlin
   id("com.google.gms.google-services") version "4.4.2" apply false
   ```

   `Admin/android/app/build.gradle.kts`, in its `plugins` block:
   ```kotlin
   id("com.google.gms.google-services")
   ```

The notification channel (`garage_alerts`, importance HIGH) is created in
`MainActivity.onCreate` and named in the manifest as Firebase's default, so
a pushed alert gets sound and a heads-up banner rather than the silent
fallback channel.

### 2. Service account

Firebase console → Project settings → Service accounts → **Generate new
private key**. That JSON is the credential the edge function signs with.

### 3. Edge function

With the CLI:

```bash
cd supabase
supabase secrets set FCM_SERVICE_ACCOUNT="$(cat /path/to/service-account.json)"
supabase secrets set WEBHOOK_SECRET="$(openssl rand -hex 32)"
supabase functions deploy notify-garage --no-verify-jwt
```

Or entirely in the dashboard: Edge Functions → **Secrets** (add the two
above), then **Deploy a new function → Via editor**, name it
`notify-garage`, paste `supabase/functions/notify-garage/index.ts`, deploy,
and turn **off** "Enforce JWT verification" in its settings.

`--no-verify-jwt` because the caller is a database webhook, not a signed-in
user. The `WEBHOOK_SECRET` header is what stands between the function and
the open internet — without it, anyone who learned the URL could push
arbitrary text to every phone in the workshop.

### 4. The webhooks — one per app

Supabase dashboard → Database → Webhooks → **Create a new hook**, twice.
Same function, same secret; only the table differs:

| Field | Workshop console | Customer app |
|---|---|---|
| Table | `public.garage_notifications` | `public.customer_alerts` |
| Events | Insert | Insert |
| Type | Supabase Edge Functions | Supabase Edge Functions |
| Edge Function | `notify-garage` | `notify-garage` |
| HTTP headers | `x-webhook-secret: <secret>` | `x-webhook-secret: <secret>` |

The function reads the webhook's `table` to decide whose phones to ring:
`garage_devices` for the console, `customer_devices` for the customer.

### The customer app

`supabase/22_customer_push.sql` gives the customer the same arrangement as
the workshop: a `customer_devices` register, filled by
`register_customer_device()` on sign-in and emptied by
`forget_customer_device()` on sign-out, and a `customer_alerts` table
filled by triggers on the workshop's own actions:

| The workshop… | The customer's phone says |
|---|---|
| accepts a booking request | Booking confirmed |
| moves a booking's time | Booking time changed |
| deletes a request it never accepted | Booking declined |
| marks the job card complete | Your vehicle is ready |
| closes the job card | Visit closed |
| records a payment | Payment received |

Nothing fires for the customer's own changes, or for anything done in the
SQL editor. `customer_alerts` feeds only the tray: the in-app bell is still
built by the app itself, so writing these rows into `notifications` as
well would show every update twice.

The customer app's `google-services.json` client is
`com.balajiautomobiles.customer`; its channel, `customer_updates_v1`, is
created in its `MainActivity`.

### 5. Check it

Insert a booking request from the customer app with the console **closed**.
Within a second or two the phone should show a heads-up notification;
tapping it opens the console on `/bookings`.

If nothing arrives, in order:

- `supabase functions logs notify-garage` — a 403 means the header does not
  match; `no devices` means step 6 below.
- `select count(*) from garage_devices;` — zero means no console has
  registered a token. A token is filed on the launch *after* the console
  joins its workshop, so sign in once with push configured.
- Android 13+: check the app has notification permission. A refusal is
  respected and never re-prompted by the app.
- Xiaomi, Vivo, Oppo: these stop an idle app hard enough that a push for a
  shut app can wait until it is opened. Right after notifications are
  allowed, both apps show Android's one-tap "let the app always run in the
  background?" dialog, once per install (`PushService._askToRunUnrestricted`,
  channel `garagepro/power` in each `MainActivity`). Nobody is sent into
  Settings. Xiaomi's separate "Autostart" switch has no API and cannot be
  asked for.

### 6. What a device registration is worth

Tokens are registered per handset and refreshed on every launch, dropped
after 60 days idle, deleted on sign-out, and deleted by the edge function
the moment FCM reports one `UNREGISTERED`. A network failure never drops a
token — that would permanently unsubscribe a working phone over a blip.

---

## What is deliberately not done

- **The foreground does not push.** `FirebaseMessaging.onMessage` is not
  listened to. A console that is open already has the row over its realtime
  channel and has already raised the banner; showing a tray notification as
  well would announce every booking twice.
- **Estimates raise nothing**, because the Admin app does not write
  estimates at all yet — the table and the customer-side approval screen
  exist, and nothing fills them.
