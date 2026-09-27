# Backend setup — one Supabase project, two apps

Everything in the code is already wired. What is left is the part that can
only be done from a dashboard: running the SQL, switching on the sign-in
methods, and telling Google and Supabase about each other.

Work through it in order. It takes about fifteen minutes.

Project: [**zlrmcrhwtfbwbxhfmygs**](https://supabase.com/dashboard/project/zlrmcrhwtfbwbxhfmygs) — `https://zlrmcrhwtfbwbxhfmygs.supabase.co`

---

## 0. Rotate your secret keys first

Project `zlrmcrhwtfbwbxhfmygs` had two keys pasted into a chat transcript that
should never leave the dashboard:

- the secret key `sb_secret_…`
- the legacy `service_role` JWT

Either one bypasses every row-level-security rule in the database — anyone
holding it can read and write every row in every table.

1. [**Settings → API Keys**](https://supabase.com/dashboard/project/zlrmcrhwtfbwbxhfmygs/settings/api-keys) → rotate the secret key.
2. [**Settings → JWT Keys**](https://supabase.com/dashboard/project/zlrmcrhwtfbwbxhfmygs/settings/jwt) → revoke or disable the legacy
   `service_role` JWT.

Nothing in either app uses either key, so this breaks nothing here.

The apps ship the **publishable** key (`sb_publishable_…`), which is what a
client app is supposed to carry: every request it makes is still filtered by
the policies in `supabase/02_garage.sql`. That one is safe where it is.

---

## 1. Run the schema

[**SQL Editor → new query**](https://supabase.com/dashboard/project/zlrmcrhwtfbwbxhfmygs/sql/new) → paste and run, **in this order**:

1. `supabase/01_customer.sql` — the customer app's tables
2. `supabase/02_garage.sql` — the workshop tables, the bridge between the two,
   and the sign-up trigger
3. `supabase/03_sync.sql` — **required.** Live sync, the link code, and the
   fix for the phone-linking hole described below.

All three are idempotent, so re-running them is safe.

The order is not a suggestion: each file builds on the tables the one before
it creates, so running 02 or 03 first fails with `relation "public.profiles"
does not exist` or `relation "public.invoices" does not exist`. If you would
rather not think about it, paste `supabase/setup_all.sql` instead — it is the
three files concatenated in the right order, and it is the only thing you need
to run.

Check it worked: the [**Table Editor**](https://supabase.com/dashboard/project/zlrmcrhwtfbwbxhfmygs/editor) should list `garages`, `job_cards`,
`line_items`, `garage_customers`, `customer_link_codes` alongside `bookings`,
`invoices`, `vehicles`.

> **Do not skip 03.** Until it has run, any signed-in customer can type
> somebody else's phone number into their own profile and inherit that
> person's entire service history — see *What 03 fixes*, below.

### Starting over

`supabase/00_reset.sql` drops everything the three files create, so you can
run them again on an empty project. **It destroys all data and cannot be
undone** — job cards, customers, vehicles, invoices, the lot.

Run it, then `supabase/setup_all.sql` (or 01 → 02 → 03, in that order).

Its last section also deletes every signed-up user, which signs everyone out
of both apps and forgets their Google links. Delete those lines before running
if you want to keep your logins and only reset the data — the file says which
ones.

---

## 2. Email sign-in

[**Authentication → Providers → Email**](https://supabase.com/dashboard/project/zlrmcrhwtfbwbxhfmygs/auth/providers) — it is on by default.

Decide one thing: **Confirm email**.

| Setting | What happens |
| --- | --- |
| On (default) | New users get a confirmation link and cannot sign in until they click it. The apps handle this — they show "Check your email and tap the confirmation link". |
| Off | Sign-up signs you straight in. Easier for testing; turn it back on before real customers use it. |

---

## 3. Google sign-in

Two halves. Google needs to know about Supabase, and Supabase needs to know
about Google.

### 3a. Google Cloud Console

1. <https://console.cloud.google.com> → create a project (or reuse one).
2. **APIs & Services → OAuth consent screen** → External → fill in the app
   name, your support email, and a developer email. Save.
3. **APIs & Services → Credentials → Create credentials → OAuth client ID**
   → Application type: **Web application**.
4. Under **Authorised redirect URIs** add exactly this:

   ```
   https://zlrmcrhwtfbwbxhfmygs.supabase.co/auth/v1/callback
   ```

5. Create. Copy the **Client ID** and **Client secret**.

> Use a **Web** client, not Android or iOS. Both apps sign in through the
> browser and come back on a deep link, so Google is talking to Supabase, not
> to the app — which also means you do not need a SHA-1 fingerprint.

### 3a-ii. An Android client too (native sign-in)

Both apps now sign in natively — Android's own account sheet, no browser —
and hand Supabase an ID token. For that, Google has to trust the app itself,
which means one **Android** OAuth client per app, on top of the Web one:

**APIs & Services → Credentials → Create credentials → OAuth client ID** →
Application type: **Android**. Make two:

| Name | Package name | SHA-1 certificate fingerprint |
| --- | --- | --- |
| Balaji Admin | `com.garagepro.garagepro_admin` | `83:99:64:B6:0E:36:1D:AB:E1:92:2A:F5:8D:BC:41:21:0B:20:19:41` |
| Balaji Automobiles | `com.garagepro.garagepro` | `83:99:64:B6:0E:36:1D:AB:E1:92:2A:F5:8D:BC:41:21:0B:20:19:41` |

That SHA-1 is the debug keystore on the build machine, which both apps
currently use for release builds as well. When you move to a real release
keystore, add its SHA-1 as a second Android client (or edit these). Get it
with:

```
keytool -list -v -keystore <your.keystore> -alias <alias>
```

Nothing from the Android clients is pasted anywhere — Google matches on
package + fingerprint at sign-in time. The **Web** client's ID is what the
apps carry (`googleWebClientId` in each `app_config.dart`) and what goes into
Supabase below; they must be the same client.

Until the Android clients exist, native sign-in fails on the device and the
apps fall back to the browser flow, which on phones with a second user space
(Xiaomi XSpace, Samsung Secure Folder, work profiles) can open a copy of
Chrome that cannot hand the result back.

### 3b. Supabase

[**Authentication → Providers → Google**](https://supabase.com/dashboard/project/zlrmcrhwtfbwbxhfmygs/auth/providers) → enable, paste the Client ID and
Client secret, save.

### 3c. Tell Supabase where to send people back

[**Authentication → URL Configuration**](https://supabase.com/dashboard/project/zlrmcrhwtfbwbxhfmygs/auth/url-configuration) → **Redirect URLs** — add all four:

```
com.garagepro.garagepro://login-callback
com.garagepro.garageproadmin://login-callback
http://localhost:3000
http://localhost:*
```

The first two are the deep links already registered in
`android/app/src/main/AndroidManifest.xml` and `ios/Runner/Info.plist` for
each app. The localhost entries are only needed if you run the web build.

---

## 4. Phone sign-in (optional)

Both apps still offer "sign in with a phone code". Until you connect an SMS
provider, Supabase cannot send the text — so the apps fall back to generating
a code locally and showing it on screen, which keeps the flow demoable.

To make it real: [**Authentication → Providers → Phone**](https://supabase.com/dashboard/project/zlrmcrhwtfbwbxhfmygs/auth/providers) → enable and connect
Twilio, MessageBird or Vonage.

---

## 5. Check it

Run either app. `flutter run` from `User/` or `Admin/`.

- **Continue with Google** should open a browser, let you pick an account, and
  drop you back in the app signed in.
- **Create account** with an email should either sign you straight in or tell
  you to confirm, depending on step 2.
- In Supabase, [**Authentication → Users**](https://supabase.com/dashboard/project/zlrmcrhwtfbwbxhfmygs/auth/users) should show the new user,
  and [**Table Editor → profiles**](https://supabase.com/dashboard/project/zlrmcrhwtfbwbxhfmygs/editor) a matching row with the name and
  picture Google supplied.

---

## How the two apps meet

They share `profiles` and nothing else directly.

- The **Admin** app owns `garages`, `garage_customers`, `garage_vehicles`,
  `job_cards`, `line_items`, `payments`, `masters`. A workshop member can read
  and write every row belonging to their garage, and nothing belonging to
  anyone else's.
- The **User** app owns `vehicles`, `addresses`, `bookings`, `estimates`,
  `invoices` — all keyed to `user_id`, all invisible to everybody else.
- A garage records a customer by **phone number**. When somebody signs up with
  that number, `handle_new_user()` links their auth user to the garage's
  customer record, and every job card that garage ever opened for them becomes
  readable — through the `my_job_cards` view, read-only, and with the garage's
  own letterhead attached.

The practical effect: the workshop opens a job card at the counter, and the
customer sees it in their app without anybody typing it twice.

### The link code

A phone number is not proof of anything: anybody can type yours. So the
workshop vouches instead.

1. Admin app → **Customers** → the customer → **Link app**. A six-digit code
   appears. Read it out at the counter.
2. Customer app → **Account** → **Link your workshop** → type the code.

From then on every job card that garage opens for them appears in their app
by itself, live — the progress bar moves as lines are ticked off at the
counter, and the bill updates as it is built. The code is good for 24 hours
and burns on first use.

A phone number that Supabase itself verified — a completed SMS OTP, once you
connect a provider in step 4 — links automatically, with no code.

### What 03 fixes

`profiles_self` lets a customer write any value into `profiles.phone`, and the
old `link_profile_to_customers()` trigger ran as `SECURITY DEFINER` and linked
`garage_customers` rows on that number. Together they meant: sign in, type a
stranger's number into your profile, and read every job card, every vehicle
and every bill their garage ever recorded for them. The same held for the
`phone` key in sign-up metadata, which the client supplies.

`03_sync.sql` closes it. An automatic link now requires
`auth.users.phone_confirmed_at`, which only a completed SMS OTP sets; every
other link goes through the code above. Running the file also cuts the links
the old trigger made on unverified numbers — anyone affected redeems a code to
get theirs back.

### Roles

`profiles.role` is one of `customer`, `owner`, `staff`. It is set from the
sign-up metadata — the Admin app sends `owner`, the User app sends `customer`
— and the `create_garage()` function promotes whoever calls it to `owner`.

Nothing security-critical depends on the role: access is decided by
`garage_members` and `user_id`, not by a string a client could lie about.

---

## How the sync behaves

Both apps stay offline-first. Every edit lands in the on-device snapshot and
paints immediately; the wire catches up a moment later. Nothing in either app
waits on a round trip, and a failed call leaves local state authoritative —
it goes up on the next edit, or the next time the app connects.

- **The console pushes what changed, not everything.** Each row carries a
  fingerprint of how it was last written or read; only rows that no longer
  match are sent.
- **A job card is one write.** Header, lines, payments and messages go through
  `save_job_card()` in a single transaction, so a dropped connection can never
  leave half a bill in the database.
- **Both sides listen.** The console subscribes to its garage's rows and the
  customer app to `customer_profile_id = auth.uid()`, both filtered in
  Postgres. A change at the counter reaches the customer's phone in well under
  a second, and a booking made in the customer app appears on the workshop's
  front desk the same way.
- **Two counters, one workshop.** Sign the console in on a second device and
  the two stay in step; a row's fingerprint is what stops them from pushing
  the same edit at each other.

## What is still manual

- **SMS.** Job card messages are modelled, not sent. Each card records what
  *would* go out; wire a gateway to `AdminController.markComplete` and
  `closeJobCard`.
- **Photos.** Stored as device file paths, so they stay on the counter's
  device. Move them to Supabase Storage before the customer app can show them
  — the column and the customer-side plumbing are already there.
- **Payments.** The UPI QR is a real intent string built from the workshop's
  UPI ID, so any UPI app reads it — but reconciliation is manual. Payments are
  recorded by hand in the ledger.
- **Job card numbers** are minted on the device that opens the card. The
  database enforces one number per garage per day, and `next_job_number()` is
  there for a server-side mint, but the console does not call it yet: two
  counters opening a card in the same second would collide.
