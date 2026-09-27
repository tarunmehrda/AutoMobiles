-- =====================================================================
-- Put your own workshop on the customer app's map
-- =====================================================================
-- Not part of the schema. This is the hand-run snippet that answers one
-- question: "I registered my garage in the console, I opened the customer
-- app standing in the same room, and the search found nothing."
--
-- Two separate things hide a garage from `nearby_garages()`, and a new
-- workshop has both:
--
--   1. `listed` is false. It defaults to false and there is deliberately
--      no screen that flips it — see 08_platform.sql section 2. A garage
--      joins the customer-facing register when the platform admin puts it
--      there. Until then it is invisible at any distance, with or without
--      a pin.
--
--   2. `lat`/`lng` are null. The console now sends a real fix up when the
--      owner taps "Use current location" (setup, or Settings -> Workshop
--      -> Use current location). Before that it read the coordinate, used
--      it to fill the address in, and threw it away. A garage with no
--      coordinate is dropped by every radius filter, because "within 10
--      km" cannot honestly include a workshop of unknown place.
--
-- Fix 2 in the app, by tapping the button. Fix 1 here.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Step 1 — see what is actually stored
-- ---------------------------------------------------------------------
-- Run this first. It tells you which of the two is biting.
select id, name, city, listed, verified, lat, lng, located_at
  from public.garages
 order by created_at desc;

-- `listed = false`          -> step 2 or 3.
-- `lat`/`lng` null          -> tap "Use current location" in the console,
--                              save, then run the select again.

-- ---------------------------------------------------------------------
-- Step 2 — the quick way: list one garage by name
-- ---------------------------------------------------------------------
-- For your own workshop on your own project. Edit the name to match the
-- row you saw above.
update public.garages
   set listed = true, verified = true
 where name ilike '%Balaji%';

-- ---------------------------------------------------------------------
-- Step 3 — the proper way: become the platform admin
-- ---------------------------------------------------------------------
-- Do this instead of step 2 if you want the register screen in the
-- console to work, which is where listing is meant to be done once there
-- is more than one workshop. Put in the email you sign in to the Admin
-- app with.
--
--   update public.profiles set role = 'platform'
--    where id = (select id from auth.users where email = 'you@example.com');
--
-- Check it took:
--   select id, name, role from public.profiles where role = 'platform';
--
-- Then sign out and back in, open the platform page in the console, and
-- list the garage from there.

-- ---------------------------------------------------------------------
-- Step 4 — prove it from the customer's side
-- ---------------------------------------------------------------------
-- This is the exact call the customer app makes. Put your own coordinate
-- in; it should come back with your workshop and a small `km`.
--
--   select public.nearby_garages(
--     in_lat    => 22.7196,   -- your latitude
--     in_lng    => 75.8577,   -- your longitude
--     radius_km => 10,
--     q         => null);
--
-- Empty result with a correct coordinate means `listed` is still false.
-- A row with `"km": null` means the garage has no pin yet, and the 1/5/10
-- km chips in the app will keep hiding it even though a search with no
-- radius shows it.
