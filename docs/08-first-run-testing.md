# Testing the two apps from scratch

How to take a clean phone, install both apps, and walk a customer's booking all
the way onto the workshop's front desk. Follow it in order — later steps depend
on earlier ones, and the one that trips everybody is step 0.

---

## Step 0 — Check the database (usually already done)

**Re-verified on device 21 Sep 2026: the migrations are in.** The table below
used to say these were missing; they are not. Do not re-run migrations on the
strength of this section alone — check first.

| What the app calls | Live DB has it? |
| --- | --- |
| `nearby_garages()` | **Yes** |
| `set_garage_location()` | **Yes** — the pin saves and distance is measured |
| `garage_notifications` | **Yes** |

To confirm in one call, against `zlrmcrhwtfbwbxhfmygs`:

```sql
select public.nearby_garages(
  in_lat => 30.7333, in_lng => 76.7794,   -- your coordinates
  radius_km => 10, q => null);
```

Rows back means the directory is installed. `"km": null` on a row means that
workshop has no pin — fix that with **Use Current Location** in step 2, not by
re-running SQL.

If you are standing up a brand new project, `supabase/setup_all.sql` is still
the right script, and `supabase/verify_setup.sql` still prints one row per
required object.

> **Order matters.** `03_sync.sql` and `10_open_booking.sql` both define
> `garage_bookings_customer_insert`, and they disagree. `10_open_booking.sql`
> must be applied **last** — running `03_sync.sql` after it reinstates the old
> rule that a customer must already be linked to a workshop before they can
> book it, which breaks booking for every new customer. See
> `qa-evidence/RUN-2026-09-21.md`.

---

## Step 1 — Put the apps on the phone

Turn on **Developer options → USB debugging**, and on Xiaomi/Redmi also
**Install via USB**. Without the second one the install is refused with
`INSTALL_FAILED_USER_RESTRICTED` and nothing you do on the computer helps.

```sh
# from f:\garage
cd Admin && flutter build apk --debug && cd ..
cd User  && flutter build apk --debug && cd ..

adb install -r -t Admin/build/app/outputs/flutter-apk/app-debug.apk
adb install -r -t User/build/app/outputs/flutter-apk/app-debug.apk
```

Use **two different Google accounts** — one for the workshop, one for the
customer. The same account on both is not a case any real user is in, and it
hides linking bugs because the profile already sees everything.

---

## Step 2 — The workshop, in the Admin app

1. Language → **Continue**.
2. Permissions. Four cards, one tap each: contacts, location, **notifications**,
   camera and photos. Notifications is the one that matters here — it is what
   makes a booking ring at the counter. If the phone refuses one for good, a
   **Skip for now** appears; the app no longer traps you on a card you cannot
   clear.
3. **Continue with Google** → the workshop's account.
4. Registration, three steps: mobile and workshop name → owner's name and email
   → address.
5. On the address step tap **Use Current Location**. Do not type the address by
   hand and skip this.

   > This is the step that decides whether customers can find you. The button
   > stores a real latitude and longitude, and `nearby_garages()` measures
   > distance from it. A workshop with an address but no pin is dropped by
   > every radius filter — "within 10 km" cannot include a workshop of unknown
   > place. Until recently the console read the coordinate, used it to fill the
   > address in and then threw it away, which is why this had to be fixed.

6. **Continue** → Agree to the terms → the dashboard.

Already registered from before? Settings → Workshop → **Use current
location** → Save. Same effect, no need to re-register.

---

## Step 3 — The customer, in the User app

1. Onboarding slides → **Next** through, or Skip.
2. **Continue with Google** → the *customer's* account.
3. Add a vehicle if the account has none.
4. **Find a garage near me** → allow location → the workshop from step 2 should
   appear with a distance next to it.

   If it says *"Garage search is not switched on for this project yet"*, go
   back to step 0 — that message means exactly one thing.
   If it searches but finds nothing, the workshop is not `listed`, or has no
   pin.

5. Tap the workshop → its page opens → **Book here**.
6. Pick the vehicle, confirm the workshop, choose services and a slot →
   **Confirm**.

There is no code anywhere in this. The customer never asks the counter for six
digits, and the counter never reads any out. Raising the booking is what puts
the customer on that workshop's books.

---

## Step 4 — Check it landed

> **Re-tested 21 Sep 2026.** The booking *does* reach the workshop — but it
> did not appear until the admin app was force-stopped and relaunched, roughly
> 40 minutes after Confirm. Pull-to-refresh on the Bookings screen did not
> bring it in. If it is not there, restart the admin app before assuming it is
> lost. See `qa-evidence/RUN-2026-09-21.md`.
>
> **Separately, and more seriously:** a job card created in the admin app was
> lost — gone from every list and from the dashboard after a restart. Do not
> rely on this build to hold job cards. Section 6 of that report.

Back in the Admin app, within a second or two you *should* see:

- a notification banner, and the bell in the header carrying a count
- **Appointment → Bookings** showing the request: name, phone, vehicle, slot
  and the note
- tap **Open job card** — the card opens pre-filled

Accepting is also what attaches the customer to the workshop's record of them.

Then, back in the User app, the job card appears under that booking and tracks
live as the counter works on it.

## When something is wrong

Read the log — both apps say plainly what failed:

```sh
adb logcat -c                       # clear, then reproduce
adb logcat -d | grep -i "flutter"
```

| What the log says | What it means |
| --- | --- |
| `PGRST202 ... could not find the function` | That migration has not been run. Step 0. |
| `PGRST205 ... could not find the table` | Same. Step 0. |
| `set_garage_location failed` | The pin did not save; the workshop stays unfindable. |
| `nearby_garages failed` | The directory is not installed. Step 0. |

A `PGRST202` is never something the person using the app can fix by retrying,
and neither app pretends otherwise — that is why the search screen says the
project is not set up rather than "no garages near you".
