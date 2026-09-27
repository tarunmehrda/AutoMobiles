# Balaji Automobiles — workshop console and customer app

Two Flutter apps and one Supabase project.

```
Admin/      the workshop console   com.balajiautomobiles.garage    "Balaji Garage"
User/       the customer app       com.balajiautomobiles.customer  "Balaji Car"
supabase/   the shared database, RLS policies and seed SQL
docs/       screen inventory, build plan, rebranding guide
```

---

## Run it

Flutter 3.x stable. Nothing else to install.

```bash
cd Admin && flutter pub get && flutter run
cd User  && flutter pub get && flutter run
```

Both apps run end to end **with no backend at all**, on an on-device store. That is the
fastest way to look at them, and it is how the tests run. Fill in Supabase credentials and
the same data mirrors to Postgres; nothing else changes.

### Backend credentials

`Admin/lib/core/config/app_config.dart` and the same file under `User/`. Either edit the
fallbacks or pass them at build time — the second is what you want for a release:

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_xxxx
```

The anon key belongs in the client — every request it makes is still filtered by row level
security. The `service_role` key never goes in an app; it bypasses RLS entirely.

### Database

Run in order in the Supabase SQL editor, or paste `setup_all.sql`, which is all six
concatenated:

```
supabase/01_customer.sql     the customer side
supabase/02_garage.sql       the workshop side and the bridge between them
supabase/03_sync.sql         the sync RPCs
supabase/04_roles.sql        roles, permissions and the activity log
supabase/05_attendance.sql   the register, and the location checks behind it
supabase/06_notifications.sql the workshop's alert feed and its push devices
```

Every file is additive and idempotent — safe to re-run on a live project. Rebuild the
combined file with `bash supabase/build_setup.sh`.

`setup_all.sql` now covers 01 to 10. After it, run these, in this order — both apps
depend on them:

```
supabase/11_fix_job_card_save.sql        pgcrypto, without which no job card saves
supabase/13_garage_direct_marketplace.sql Buy & Sell addressed to a workshop
supabase/14_buy_sell_complete.sql         the rest of Buy & Sell
supabase/16_fix_realtime_publication.sql  every watched table on the realtime feed
supabase/18_booking_vehicle_details.sql   a booking carries the car: model, gearbox, KM
supabase/19_commission_and_roles.sql      the one platform account, and 3% commission
supabase/20_workflow_fixes.sql            photos, reschedule, reviews, delete account
```

This exact sequence has been run end to end against Postgres, with checks on every
rule it adds. `12`, `15` and `17` are one-off repairs and diagnostics, not setup.

### Auth redirect URLs

Supabase → Authentication → URL Configuration must list both:

```
com.balajiautomobiles.garage://login-callback
com.balajiautomobiles.customer://login-callback
```

Google sign-in additionally needs an Android OAuth client per package name in Google Cloud
Console, each with the signing SHA-1. Changing an `applicationId` means redoing both.

---

## Roles

The console has five. Picking one fills in the permission grid; the grid stays editable for
the workshop that wants something different.

| Role | What they get |
|---|---|
| **Owner / Admin** | Everything, including purchase rates and profit |
| **Manager** | Operations and billing. No owner settings, no payroll, no profit |
| **Workshop / Mechanic** | Only the job cards assigned to him. Nothing financial, no cost |
| **Counter / Storekeeper** | Counter sale, stock, parts issue, purchase entry |
| **Accountant** | Invoices, payments, ledgers, reports. Not the workshop floor |

**There are no seeded test logins, deliberately.** Shipping an app with a known password in
it is how that password ends up in production. Make your own in one minute:

1. Open the console — a fresh install signs you in as the **Owner** with no password.
2. `Settings → User Management → +`
3. Name, phone, pick a role, set a password, **Create User**.
4. The overflow menu on their card → **Hand the console over**.
5. `Settings → Hand the console back` returns you to the Owner.

Whoever is signed in is named on every line of `Settings → Activity Log`.

Enforcement runs three deep: the router refuses a location, the screen refuses again on its
own account, and Postgres refuses a third time. The first two are for a good experience; the
third is the one that matters.

---

## GST

**Off by default.** A workshop that never switches it on prints a plain **Bill** with no tax
column, no HSN column and no GSTIN line anywhere.

Turn it on at `Settings → Settings Option → Billing → Charge GST`. Then:

- CGST + SGST inside the state, IGST across a state line, decided from the customer's state
  code and frozen onto the document when it is raised
- Inclusive or exclusive pricing — "₹1200 all in" against "₹1200 plus GST"
- Per-line HSN/SAC and slab, falling back to the card's rate
- Round off to the rupee, printed as its own row
- HSN-wise rollup for GSTR-1

The engine is `Admin/lib/core/tax/gst.dart`, mirrored in `User/` so the customer's copy of
an invoice matches the printed one to the rupee. It is covered by 25 tests; do not
reimplement any of it anywhere else.

---

## Invoice templates

Six, at `Settings → Invoice Themes & Templates`: Default (Original), Default (Two Logos),
Luxury, Advanced GST (Tally), Billbook, Simple. Preview renders the real PDF against your
own latest job card.

To look at all of them without a device:

```bash
cd Admin && flutter test tool/invoices     # writes tool/invoices/out/*.pdf
```

---

## Rebranding for another garage

One file per app: `Admin/lib/config/brand.dart` and `User/lib/config/brand.dart`. Names,
colour, art, support contacts, feature switches and the first-run business profile all live
there, and there is no accent-colour literal anywhere else in either codebase.

Full instructions, including the two platform values Dart cannot set:
[docs/03-rebranding.md](docs/03-rebranding.md).

---

## Tests

```bash
cd Admin && flutter analyze && flutter test        # 177
cd User  && flutter analyze && flutter test test/  # 67
```

Worth knowing about two of them:

- `test/smoke_test.dart` walks **every route in the app** against a seeded workshop and
  fails on any exception or layout overflow. It is the cheapest guard against the screen
  that throws the moment it is built, which is what "the app crashed" usually means.
- `test/invoice_pdf_test.dart` renders all six themes, taxed and untaxed, plus the awkward
  cases — inter-state, stacked discounts, an empty card.

---

## Where things are

```
lib/config/brand.dart               everything that changes for a different garage
lib/core/tax/gst.dart               the tax engine. One place, on purpose
lib/core/auth/passcode.dart         salted hashing for staff sign-in
lib/core/router/route_access.dart   which route needs which permission
lib/data/models/roles.dart          the five roles and the permission grid
lib/data/models/entities.dart       every stored type
lib/state/admin_state.dart          the single write path
lib/features/<module>/              screens, one folder per module
```

More: [docs/01-screen-inventory.md](docs/01-screen-inventory.md) maps all 64 reference
screenshots to what we built and why they differ.
[docs/02-build-plan.md](docs/02-build-plan.md) is the honest status of every phase,
including the four that were scoped and not built.
