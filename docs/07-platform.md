# Directory, marketplace and the platform admin

What was added on top of the two apps, what you have to run by hand, and
the handful of things that will bite if they are skipped.

Everything here is additive. Nothing in the existing customer or console
flow changed behaviour: a customer still links to a workshop with a code, a
garage owner still sees only their own garage, and both apps still run
offline against their on-device store.

---

## 1. Run the SQL

Paste `supabase/setup_all.sql` into the Supabase SQL editor and run it. It
is idempotent, so re-running it on a live project is safe.

It now ends with three files that did not exist before:

| File | What it adds |
|---|---|
| `07_share.sql` | The public job-card link — `/j/<token>` |
| `08_platform.sql` | Garage coordinates, the customer-facing directory, the `platform` role |
| `09_marketplace.sql` | Part requests, part listings, commission, the welcome video |

To regenerate `setup_all.sql` after editing any numbered file:

```sh
cd supabase && sh ./build_setup.sh
```

## 2. Make yourself the platform admin

There is deliberately **no screen** for this. The role is what separates
the person who runs the register from every garage owner on it, and an app
that could grant it would be the first thing worth attacking.

The platform account is **firefringe@gmail.com**, set by
`supabase/19_commission_and_roles.sql`. That file grants it, removes the
role from every other account, and locks the `role` column so no app
session can gain `platform` or lose it. To move it to another Gmail, edit
`dev_email` in section 2 of that file and run it again.

Check it took (exactly one row):

```sql
select u.email, p.role from public.profiles p
  join auth.users u on u.id = p.id where p.role = 'platform';
```

Then sign out and back in on the console. A **Platform** row appears in
Settings. Nobody else sees it. A garage owner who opens the dashboard's
**Buy & Sell** tile reaches the same screen with only the Requests and
Listings tabs, and the database refuses them everything else anyway.

## 3. Nothing is in the directory until you put it there

`garages.listed` defaults to **false**. A workshop that registers as a
partner does not appear in customer search until you switch it on under
**Platform → Partners**. This is on purpose: an empty register is a better
first day than one full of unchecked workshops.

`10_open_booking.sql` once listed a workshop automatically the moment it
dropped a pin. `19_commission_and_roles.sql` removes that: partners are
the platform's decision. Workshops already listed stay listed. A partner
can never list, verify or set a commission rate for itself; the database
keeps those three columns as they were for anybody but the platform.

A customer who already deals with a workshop can still book it when it
is not listed (`garage_card()` in `18_booking_vehicle_details.sql`).

**Distance comes from `lat`/`lng`, never from the PIN code.** A PIN in
India can span twenty kilometres, which would put a garage across the city
inside a "within 1 km" result. A workshop with no coordinate can still be
found by name, but it can never appear in a radius search — the Partners
list flags these as *No location*, and listing one asks you to confirm.

The partner sets their own coordinate from the customer app under
**Account → Register as a partner → Use my location**, standing in the
workshop.

---

## The parts of this that are not obvious

### Notification sounds are fixed at channel creation

Android freezes a notification channel's sound, importance and vibration
the first time the channel is created on a handset. Nothing the app does
afterwards changes them — `createNotificationChannel` with new settings is
accepted and silently ignored.

That is why the channel ids in `MainActivity.kt` carry a version:
`garage_booking_v1`, `garage_payment_v1`, `garage_reminder_v1`,
`garage_general_v1`. **Changing a chime means shipping `_v2`.** Editing the
sound of `_v1` looks right in review and does nothing on every phone in the
field.

Which channel a message lands in is chosen by the sender, in
`supabase/functions/notify-garage/index.ts` (the `CHANNELS` map). The four
chimes are generated, not licensed — see the note in `MainActivity.kt`.

### The website CSP had to be widened

`public/_headers` carried `connect-src 'self'`, which blocks the shared
job-card page from reaching Supabase at all. It now allows the project
origin. If the Supabase project ever moves, that header moves with it or
`/j/<token>` silently stops loading.

`/j/*` is also `X-Robots-Tag: noindex, nofollow` and `Disallow`ed in
`robots.txt`. A shared job card is one customer's bill and must never
appear in a search result.

### Share tokens are not carried on job cards

`job_card_json` does not include `share_token`, deliberately. It is the
payload behind every job card the console holds in memory, and a token in
all of them is a token in every log line and crash report the app produces.
The console asks for one at the moment the counter presses Share, via
`card_share_token()`.

A link that went to the wrong number is burned with
`rotate_share_token()` — the old URL stops resolving immediately.

### Commission records; it does not charge

`commissions` is a ledger. Nothing in this product moves money, and no
customer is charged anything.

- **When:** a garage closes a job card in the console. The database books
  the line itself (a deferred trigger in `19_commission_and_roles.sql`), so
  nobody has to remember to.
- **How much:** the rate × the bill before GST, `sum(qty × rate) − discount`.
  The default is **3%**, and no rate is ever lower. A partner can be given
  a higher rate of its own, up to 10% (a ceiling against a typo); the
  database refuses anything outside 3%–10%.
- **Frozen:** the rate is fixed on the line the first time the card
  closes. Re-saving a closed card updates the amount while the line is
  still `accrued`; reopening it withdraws the line until it closes again.
- **Who sees it:** it is shown in one place, **Settings → Commission** in
  the console. The platform account picks one partner at a time and sees
  that partner's balance, rate and latest lines, plus the default rate. A
  workshop's owner sees their own workshop's commission and nobody else's
  (`my_commission()`, `21_private_commission.sql`); its staff logins and
  every customer see none. The customer app never shows it.
- **Settling:** collect from the partner (UPI or bank), then **Mark
  settled** on their row. Lines can also be marked `invoiced` or `waived`
  one at a time. Once a line is out of `accrued`, nothing the garage does
  moves it again.
- **Earlier cards:** commission starts with the next card closed. Section 8
  of the SQL file has a one-line, commented-out backfill for cards closed
  before it ran.

### The welcome video needs a direct file link

`intro_video_on` plays a video once for each customer, the first time they
sign in. It must be a direct `.mp4` or `.m3u8` — a YouTube watch page is a
web page, not a video, and the in-app player shows a black rectangle for
it. The Content screen checks for this and says so.

Whether a person has seen it lives on their profile row, not on the device,
so it does not replay on a reinstall or on a second handset.

---

## Still needs doing

- **Push requires the edge function deployed.** `notify-garage` needs the
  Firebase service account and the webhook secret — see
  `docs/06-notifications.md`. Until then the console still gets its alerts
  over the realtime channel while it is open; it just will not ring when
  closed.
- **Vehicle lookup by registration number is not wired.** There is no free
  Indian RC API — Surepass, APIClub and Signzy are all paid, and Vahan is
  not open to private apps. Adding a vehicle is manual, with photos.
- **The marketplace storage bucket is created by `09_marketplace.sql`.**
  Photos upload to `marketplace/<uid>/<id>/<n>.jpg`; the policy only lets a
  person write inside the folder named after their own user id.
