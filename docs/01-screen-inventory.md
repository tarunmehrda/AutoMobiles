# GarageSaarthi — screen-by-screen inventory, and what we build instead

Source: the 64 screenshots in `F:\garage\Admin-pic-latest` (GarageSaarthi,
`com.th.garagesaarthi`), plus `Admin-pics` (63) and `user-pics` (17) for context.

Read this as two columns: **what the reference app does** (feature record — nothing here
gets dropped) and **what we ship** (same capability, fewer taps). Where the two differ the
reason is stated. "2 taps" below means: from the home screen, two taps to the input screen,
and one screen of input to finish.

---

## A. Authentication — 3 screens

| # | Reference screen | Fields / controls |
|---|---|---|
| 1 | Sign In | Email, Password (reveal toggle), Forgot Password?, Sign In, "Don't have an account? Sign Up" |
| 2 | Sign Up | Full Name, Phone (10-digit), Email, Workshop / Company Name, Password, Company Logo (optional upload) |
| 3 | OTP verify | OTP sent to +91 number **and** email, edit pencil, 6-digit box, Resend (30s countdown), Verify & Sign Up |

**We ship:** the same three, with mobile+OTP as the primary path and email/password kept as
the fallback for desktop. The workshop name and logo move out of sign-up into first-run
setup, so a new owner is inside the app in one screen instead of six fields.
Customer app: mobile + OTP only.

---

## B. Home / Dashboard — 4 captures of one screen

Header: hamburger · logo · `Balaji / Garage Workspace` · bell · branch-switch arrows.

1. **Premium trial banner** — "Your premium trial expires in 7 days" + Upgrade
2. **Welcome card** (red gradient) + **All Time** date-range dropdown + three counters:
   Job Cards, Customers, Mechanics
3. **Quick Actions** 3x2: Create Job Card · Counter Sales · Add Inventory · Finance ·
   Add Customer · Add Vehicle
4. **Business Overview** + View Report: Total Revenue and Total Expenses, each with a
   sparkline and the active range
5. **Exclusive Reward** promo card → Participate Now
6. Bottom nav: Home · Job Cards · Users · Settings
7. Success toast on save: `Job Card BA202600002 Created Successfully`

**We ship:** same skeleton, upgraded to the spec's chart requirement — the two flat
sparklines become tappable animated area charts, and the three counters become KPI cards
with count-up animation (today's sale, collection, pending, cars in workshop). The promo
card is driven by the branding config so a reseller can switch it off.

---

## C. Job Cards — 2 screens

| Screen | Contents |
|---|---|
| Job Cards list | Title + refresh · segmented **Job Cards / Insurance** · filter chips **All Jobs, Estimates, Pending, In Progress, …** · search · Filter · "Job Cards List" + list/grid toggle · empty state · FAB |
| FAB speed-dial | **Jobcard Presets** · **Create New Jobcard** |

**We ship:** identical, plus the drag-and-drop Kanban the spec asks for
(Open / In Progress / Waiting for Parts / Ready / Delivered) as the grid mode of the same
screen rather than a separate page.

---

## D. Create Job Card — the reference app's 4-step wizard

This is the single biggest simplification target. The reference walks 4 steps and roughly
40 inputs before a card exists.

**Step 1 — Customer**
- Customer Information: Customer\* (searchable select + *Add New Customer*), Vehicle\*
  (searchable select + *Add New Vehicle*), Assigned Mechanics (multi), Service Type,
  Service Subcategory
- Customer Complaints Details: `1. Complaint -> 2. Solution / Action`, **Select Complaints**,
  **+ Add Row**, numbered "#n Issue Details" rows, *Add another issue*,
  **Record Voice Complaint**
- Bottom: Draft · Next

**Step 2 — Services & Spare Parts**
- **+ Add Item**; **Insurance Job Card** toggle ("map insurance claim details and payer
  setup"); **Apply Preset** toggle
- Per item: Type\* (Service / Part / Outsourced), Service\*, Qty\* with **Qty | Hours**
  toggle, Rate, Disc, Assign Staff, **GST Apply** checkbox + GST Total + Item Total,
  Notes

**Step 3 — Details**
- Job Details: Join Date, Expected Delivery Date, Priority, Status, Next Service Reminder,
  Next Service KM, Vehicle Running Still Date (KM), Remark
- **Fuel / Range**: dial gauge E-1/4-1/2-3/4-F, slider, numeric box, level pill
- **Media Gallery**: Upload Media Files, Media Type, Description

**Step 4 — Summary**
- Have A Coupon? + Apply
- **Apply Global GST** ("Gst Number Required…")
- Finalize Job Card: **Estimate Only** ("Mechanics & Dates Are Optional")
- **Receive Payment / Advance**: Full Amount chip + Clear, Amount Received, Payment
  Mode, Advance Received, Remaining Balance (outstanding)
- **Cost Breakdown**: Services (n), Spare Parts (n), Outsourced Work (n), Subtotal,
  Final Total
- Bottom: Previous · Draft · Save Job Card

**We ship — one screen, four collapsed sections.** Nothing is removed; everything moves.

| Reference | Ours | Why |
|---|---|---|
| 4 wizard steps | 1 scrolling screen, sections auto-collapse once filled | The counter fills customer + vehicle + complaint and saves. Everything else is added while the car is in the bay. |
| Customer then Vehicle, two selects | one search box matching **name, mobile or registration** | A returning car is found by plate alone; the customer comes with it. |
| *Add New Customer* / *Add New Vehicle* as separate modals | inline "not found, create" in the same box | Removes 2 taps and a context switch on the most common new-customer path. |
| Service Type + Subcategory selects | one searchable services list (the 16 seeded services) | The subcategory is only ever used to narrow the same list. |
| Join Date, Priority, Status, Next Service x2, Running KM, Remark | behind **Advanced** | Defaults are right ~95% of the time: today, Medium, Open, +6 months / +5000 km. |
| Fuel dial + slider + box + pill | the dial, tappable | Three controls for one number. |
| Coupon, Global GST, Estimate Only, Advance, Cost Breakdown as step 4 | a sticky summary bar that is always visible, expanding to the same controls | The owner sees the running total while adding lines instead of at the end. |
| Qty / Hours toggle | kept as-is | Genuinely two different billing modes. |
| Insurance Job Card toggle | kept as-is | Drives a different payer and invoice series. |
| Voice complaint | kept as-is | Fastest input on the floor. |

---

## E. Dialogs

| Screen | Contents |
|---|---|
| Add New Customer (modal **and** full page — the reference has both) | Customer Name\*, Phone Number\*, WhatsApp-updates consent, Add Customer |
| Select Customer Complaints | search + add, checkbox list — OIL LEAKAGE, OIL LEAKAGE FROM ENGINE, BATTERY NOT CHARGING, BATTERY DRAINED, BRAKE NOT WORKING, BRAKE NOISE / SQUEAKING, HEADLIGHT NOT WORKING, INDICATORS NOT WORKING, CLUTCH HARD, CLUTCH SLIPPING, COOLANT LEAKAGE, PICKUP LOW / LOSS OF POWER … — Cancel · Apply Selected (n) |

**We ship:** one Add Customer surface, not two. The complaints picker is kept verbatim —
it is the best thing in the reference app — and seeded with the same list.

---

## F. Vehicles

**Register New Vehicle** (two variants in the deck):
- Vehicle Category: 4-Wheeler (Car/SUV) · 2-Wheeler (Bike/Scooter) · Truck (Commercial) ·
  Tractor (Agriculture)
- Registration Number\*, Select Customer\*
- **Advanced Options (Optional)**: Make (+ *Manual*), Fuel Type, VIN (17-char),
  Engine Number, Variant (+ *Manual*), Year, Color (+ *Manage Colors*),
  Insurance Expiry Date, PUC Expiry Date
- The second variant promotes VIN / Engine / Make\* into the main form.

**We ship:** the first variant only — category, plate, customer, then Advanced. Make becomes
required *inside* Advanced rather than on the front page, because the plate is what the
workshop searches by. Odometer and a vehicle photo are added (the spec asks for both and the
reference has neither on this screen).

---

## G. Users, roles and permissions

| Screen | Contents |
|---|---|
| User Management | search by name · Filter by Role · cards showing `USR…` id, Active chip, overflow menu, avatar, name, role badge, Monthly Salary, Joined · FAB |
| Invite A New User | Full Name\*, Email, Phone\*, Role\*, Login Password\* (min 6), **Permissions Matrix**, Monthly Salary\*, Address (Street, City, State, ZIP, Country), WhatsApp consent, Create User |

**Permissions matrix** — MODULE x **VIEW / CREATE / EDIT / DELETE** over: Job Cards,
Inventory, Customers, Vehicles, Reports, User Management, Insurance, Leaves, Attendance,
Payroll, Job Card Presets.

**We ship:** the same matrix, but pre-filled by role so the owner never has to tick 44 boxes.
Picking **Mechanic** ticks the mechanic row set; the matrix stays there to override. Roles:
Owner/Admin · Manager · Workshop/Mechanic · Counter/Storekeeper · Accountant. Server-side
enforcement in Supabase RLS as well as in the client — the reference enforces in the client
only.

---

## H. Settings — 11 screens

| Screen | Contents |
|---|---|
| Settings home | identity card (logo, name) + **Show Back** / **Download Card**; tiles: Garage Profile, Subscription, Invoice Themes & Templates, Invoice Series, Customer Settings, Job Card Media Settings, Notification, Signature & Logo, Change Password |
| Invoice Themes | Default (Original) *Active* · Default (Two Logos) *Dual Logo* · Luxury *Premium* · Advanced GST (Tally) *GST Standard* · Billbook *Classic* · Simple *Eco Print* — each Preview + Use Theme |
| Invoice Series | prefix and sequence per **Normal / GST / Insurance**, Add Series, empty state |
| Customer Settings | **Advanced Customer Form** toggle; field pills: Name & Phone, Alt Phone, Email, Birthday, Anniversary, GST & PAN, Address; live FORM PREVIEW with enabled count |
| Job Card Media Settings | Enforce Minimum Photos toggle + Minimum Photos Required (5) |
| Signature & Logo | Authorized Signature, Company Logo, **Secondary Logo (Right Header)** for the 2-logo theme |
| Change Password | Current, New (min 6), Confirm |
| Bank Details | GSTIN + Save GST Details; Bank Accounts + Add Bank Account |
| Subscription | plan card (Trial, 7 days left, renews), duration chips 1/3/6/12 *Popular*/24/Lifetime, price +18% GST, Save offer, Buy Now, Included Features |
| Message Credits | Usable Credits, Add Credit Request, Wallet History Card/Table, Recharge History / Transaction Details |
| Exclusive Video Reward | promo hero, Choose Script to Speak, Upload Reel (9:16, max 5 min) |

**We ship:** all of it. Two changes: **Bank Details' GSTIN merges into Garage Profile**
(one place for the business identity, as the spec's section 3 wants), and the six invoice
themes stay six — they are genuinely different documents a garage picks once.

---

## I. Counter Sale

**New Counter Sale:** Customer Information (search name or phone) · Vehicle Information
(optional) · Sale Date · **Parts & Inventory Items** (search by part name or code) ·
Payment & Billing Summary: Service Charge, Discount Amount, Payment Method, Subtotal,
Discount, **Total GST**, Grand Total · Complete Sale (disabled until valid).

**We ship:** the same screen plus what the spec requires and the reference lacks —
camera + USB barcode scan, free qty, Cash Sale party, credit (udhaar) as a payment method,
thermal 58/80 mm receipt beside A4/A5 PDF, and sale return / credit note with stock
write-back.

---

## J. Inventory & Purchase

| Screen | Contents |
|---|---|
| Inventory | + Add Category · Load Defaults / Clear Defaults · Supplier, Locations, Bulk, Export · Default Qty + Apply · Low Stock Report · KPIs: Total Items, Stock Value, Purchase Value (+History), Outstanding (+History) · **Scan Barcode** · search + filter · item cards (In Stock, name, category, Available, Unit Price) · FAB |
| Add New Inventory Item | **Items In This Purchase** (n) — per item: Item Name\*, Category, Quantity\*, Unit, Purchase Rate\*, Selling Price\*, GST % + **GST Included**, Discount, *Show Optional Details*; **Supplier & Invoice Details (shared)**: Supplier, Phone, Email, GST Number, Purchase Invoice Number, Purchase Date\*, Paid Amount, Total Bill, Outstanding, Payment Method; **Default Storage Location (shared)**: Warehouse, Shelf, Bin; Invoice Bill upload; Item Photo |

**Note:** the reference merges *purchase entry* and *part master creation* into this one
screen — several items share one supplier invoice. That is genuinely good and we keep it.
We add min-stock alert, MRP, rack location and HSN, which the spec requires.

---

## K. Finance

**Payment & Finance:** Finance Summary · **+ Create Invoice** · Job Card Payments with
search, Advanced filter and Status · bottom tabs **Job Cards | Insurance | Ledger**.

**We ship:** the same, plus the spec's daily cash book, expense entry with categories, and
receivables/payables ageing, which the reference only exposes inside reports.

---

## L. Support, reviews, branches

| Screen | Contents |
|---|---|
| Help & Support | ticket list, empty state, FAB to raise |
| Customer Reviews | Configure Modules · Average Rating · Total Reviews · Rating Breakdown 5-star to 1-star bars · search |
| Branch Management | search · empty "No branches found / Link a new branch to get started" + Retry · FAB |

---

## M. Drawer — the full navigation tree (6 captures)

```
Dashboard
Workshop            Job Cards, Appointments, Vehicles, Vehicle Inspections,
                    Services, Inventory, Media Gallery
Finance             Payments & Finance, Loans
Customers & Sales   Customers, CRM (leads), Counter Sales, Service Alerts,
                    Customer Reviews, Offer & Promotion
Team & HR           User Management, Attendance, Leaves, Payroll
Insights            Reports, PUC & Insurance Expiry
Branch Management
Settings
Support
Logout
```

**We ship:** this tree unchanged — it is the feature checklist. On Windows it becomes the
permanent sidebar rail; on phone it stays a drawer, with the four highest-traffic
destinations promoted to the bottom bar.

---

## N. What the reference does NOT have, that the brief requires

These have no screenshot to copy and are designed from the brief:

1. **Customer app** end to end — live job status timeline, estimate approve/reject/revise,
   UPI payment, chat thread, pickup & drop request, reminders.
2. **Two-way realtime** — the reference is request/response with a pull-to-refresh.
3. **Offline-first with a sync queue** and conflict handling.
4. **GST engine proper** — the reference has a per-line `GST Apply` checkbox and a
   `Total GST` figure, but no HSN/SAC per line, no CGST/SGST vs IGST decision from the
   customer's state code, no inclusive/exclusive mode, no round-off line, no amount in
   words, and no GSTR-1 / HSN-wise export.
5. **GST global on/off** — the brief wants a workshop that is not registered to see a
   clean Bill with no tax column anywhere.
6. **Windows desktop** — sidebar rail, multi-pane tables, keyboard shortcuts, USB/HID
   scanner.
7. **Charts** — the reference has two decorative sparklines and nothing else. The brief
   wants line/area, bar, donut, horizontal bar, radial gauge, calendar heat map and
   in-card sparklines, all animated and tappable.
8. **Hindi/English toggle** with bilingual labels.

---

## O. Screens we deliberately do not copy

| Reference screen | Decision | Reason |
|---|---|---|
| Add New Customer — modal **and** page | one surface | Two code paths for four fields. |
| Bank Details GSTIN block | merged into Garage Profile | The business identity belongs in one place. |
| Service Type + Service Subcategory | one searchable list | The subcategory only narrows the same list. |
| Create Job Card's 4 steps | one screen, 4 sections | The 2-tap rule in the brief. |
| "Email Invitations Are Temporarily Disabled" notice | dropped | We send the invite. |

Nothing else in the 64 is dropped.
