# Build plan — where this stands and what is left

Against the brief in full. Honest status, not a wish list: "done" here means the
code exists, `flutter analyze` is clean, tests cover it and both APKs build.

---

## Phase 1 — Foundation — **DONE**

| Item | Where |
|---|---|
| Screen-by-screen inventory of all 64 reference screenshots, with the simplify/merge mapping and the reason for each | `docs/01-screen-inventory.md` |
| White-label branding file, one per app — names, colour, art, contact, feature switches, first-run business profile | `Admin/lib/config/brand.dart`, `User/lib/config/brand.dart` |
| Palette and `AppConfig` read from it — no accent literal left anywhere else | `core/theme/app_colors.dart`, `core/config/app_config.dart` |
| Rebranding guide | `docs/03-rebranding.md` |
| App identity: `com.balajiautomobiles.garage` / `com.balajiautomobiles.customer`, launcher names "Balaji Garage" / "Balaji Car", OAuth schemes, Kotlin packages moved | `android/` in both |
| **GST engine** — CGST/SGST vs IGST from state code, inclusive and exclusive, per-line and bill-level discount apportioned across slabs, round-off, HSN rollup for GSTR-1, GSTIN validation with check digit, GST on/off | `Admin/lib/core/tax/gst.dart`, mirrored in `User/` |
| **Roles and permissions** — 5 roles, the reference app's MODULE x VIEW/CREATE/EDIT/DELETE grid pre-filled per role, cost/profit/own-jobs-only rules | `Admin/lib/data/models/roles.dart` |
| 16-service master with SAC codes, rates, bay hours, icons | `Admin/lib/data/seed/services_master.dart` |
| Windows desktop target for the console | `Admin/windows/` |
| Tests: 25 GST, 23 roles | `Admin/test/gst_test.dart`, `roles_test.dart`, `User/test/gst_test.dart` |

Admin 95 tests pass, User 67 pass, both APKs build.

**Not verified:** the Windows build. This machine has no Visual Studio toolchain, so
`flutter build windows` cannot run here. The scaffold and the runner edits are correct
but unproven — build it once on a machine with VS 2022 + "Desktop development with C++"
before relying on it.

---

## Phase 2 — GST through every document — **DONE**

**GST is opt-in.** A workshop that never switches it on bills plain Bills with no tax
column, no HSN column and no GSTIN line — that is the default for a fresh install, and it
is pinned by tests.

| Item | Where |
|---|---|
| `LineItem` gains `hsn`, `gstRate`, `discount`, `net` | `data/models/entities.dart` |
| `JobCard` gains `gstOverride`, `gstInclusive`, `homeState`, `supplyState`; every total routed through `Gst.bill` | same |
| `Garage` gains `legalName`, `stateCode`, `gstEnabled`, `gstInclusive`, bank details, signature and secondary logo | same |
| `Customer` gains `gstin` + `stateCode` — the B2B / IGST decision | same |
| `MasterItem` gains `hsn`, `gstRate`, `costRate`, `mrp`, `brand`, `category`, `rack` | same |
| `CounterSale` gains service charge, discount, pay mode, tax; `PurchaseOrder` gains input-tax credit | same |
| Place of supply frozen onto each document when it is raised | `state/admin_state.dart` |
| Totals block shared by the screen preview and the PDF | `jobcard/documents/tax_summary.dart` |
| Invoice PDF: HSN/SAC + GST% columns, CGST/SGST or IGST, taxable value, round off, place of supply, HSN-wise tax table, bank block, legal name | `jobcard/documents/pdf_builder.dart` |
| **Six invoice themes** with a picker, live preview and a drawn thumbnail per design | `jobcard/documents/invoice_theme.dart`, `settings/invoice_themes_page.dart` |
| Same engine and same money block in the customer app | `User/lib/core/tax/gst.dart`, `features/invoice/invoice_money.dart` |
| GST master switch + inclusive/exclusive in Settings | `settings/settings_options_page.dart` |
| Tests: 30 billing, 23 PDF render | `test/billing_test.dart`, `test/invoice_pdf_test.dart` |
| Sample output for all six themes, taxed and untaxed | `flutter test tool/invoices` -> `tool/invoices/out/` |

Admin 148 tests pass, User 67 pass, both APKs build.

**Still open from this phase:** GSTR-1 B2B/B2C export to Excel/CSV/JSON. The HSN-wise
rollup it needs is built and tested (`GstInvoice.hsnSummary`); only the file writer is
missing.

## Phase 3 — Users, roles, multi-tenancy — **DONE**

| Item | Where |
|---|---|
| `Staff` carries everything the Invite form collects: `USR…` code, email, role, permission grid, salary, address, WhatsApp consent, join date, salted password hash | `data/models/entities.dart` |
| Salted SHA-256 sign-in. The password itself is never stored, and two people who pick the same one get different hashes | `core/auth/passcode.dart` |
| **User Management** — search, filter by role, USR code, Active chip, avatar, role badge, salary, joined date, per-user menu | `settings/users_page.dart` |
| **Invite A New User** — the reference app's MODULE x VIEW/CREATE/EDIT/DELETE grid, pre-filled from the role instead of forty empty boxes | `settings/widgets/invite_user_sheet.dart` |
| Hand the console over: the next person types their own password, and everything from then on is logged against them | `users_page.dart`, `admin_state.dart` |
| **Router gate** — longest-prefix route-to-module map; a location somebody has no business at never gets built | `core/router/route_access.dart` |
| **Mechanic row filter at the source** — `jobCardsProvider` returns only his cards, so every bucket, count, search and report inherits it | `state/providers.dart` |
| Dashboard tiles, Settings entries and the pending-balance card drawn only when the signed-in user may open them | `dashboard_page.dart`, `settings_page.dart` |
| **Activity log** — append-only, newest first, with a timeline screen | `data/models/activity.dart`, `settings/activity_page.dart` |
| **Supabase RLS** — the same five roles and the same grid in Postgres, mechanic row filter included; activity has no update or delete policy for anybody | `supabase/04_roles.sql` |
| Tests: 29 covering sign-in, hashing, the row filter, the route gate and the log | `test/access_test.dart` |

Admin 177 tests pass, User 67 pass, both APKs build.

**Deliberately not done:** staff passwords are not stored in Postgres. Device sign-in is a
local gate that decides which screens open and whose name goes on the log; anybody who
needs to reach the database gets a real Supabase Auth user and a `garage_members` row.
A second password store beside Supabase Auth would be two things to get wrong.

---

## What is left

The four phases below were scoped but not built. Nothing above depends on them.

## Phase 4 — The live connection

- Supabase Realtime on both sides, no manual refresh anywhere
- FCM both ways: status change, estimate ready, invoice generated, payment received,
  service reminder, new booking
- The customer record links the two apps by mobile number
- `supabase/` schema extended: `garages.services`, staff, permissions, chat, estimates

## Phase 5 — Offline-first

- Local DB (Drift) behind the repository layer, replacing `SharedPreferences`
- Write-ahead queue, optimistic UI, conflict handling on reconnect
- Same account live on phone, laptop and PC at once

## Phase 6 — Charts and the premium pass

- `fl_chart`: animated area (sales trend with day/week/month/year), bar (service-wise,
  mechanic-wise), donut (payment mode, GST vs non-GST, parts vs labour), horizontal bar
  (top 10 parts), radial gauge (monthly target), calendar heat map, KPI sparklines
- Shimmer skeletons, Lottie empty states and success ticks, Hero transitions,
  confetti on invoice paid
- Hindi/English toggle with bilingual labels

## Phase 7 — The customer app

- Live job timeline with mechanic photos
- Estimate approve / reject / ask-to-revise
- UPI payment + outstanding balance
- Chat thread with the workshop
- Pickup & drop request, call-back request
- Service / insurance / PUC reminders

## Phase 8 — Windows console

- Sidebar rail + multi-pane data tables at desktop width
- Keyboard shortcuts, USB/HID barcode scanner
- MSIX packaging

## Phase 9 — Counter sale, stock and print

- Barcode scan (camera + USB), free qty, Cash Sale party, credit sales
- Thermal 58 mm / 80 mm receipts beside A4/A5
- Sale return / credit note with stock write-back
- Purchase return, vendor ledger, payables

## Phase 10 — Ship

- Sample parts, customers, vehicles and demo data
- Launcher icons at every density + Android adaptive icon
- Android APK + AAB for both, Windows EXE/MSIX for the console
- README: setup, env keys, a test login per role

---

## Known gaps carried in from before this brief

- The Supabase `garages` table has no `services` column, so services published in the
  console never reach the customer app. Step 3 of Book Appointment correctly shows
  "No services available". Fixed in Phase 4.
- The Downloads-folder write goes through a MediaStore channel that compiles and builds
  but has never run on a handset.
- `User/.legacy/` holds 34 retired marketplace files, kept rather than deleted.
