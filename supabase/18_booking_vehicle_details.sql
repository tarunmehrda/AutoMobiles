-- =====================================================================
-- GaragePro — a booking carries the car, not just its name
-- =====================================================================
-- Run AFTER 10_open_booking.sql. Additive and idempotent: safe to re-run
-- on the live project.
--
-- A customer adds their car once — brand, model, variant, fuel, gearbox,
-- year and the odometer — and then books it. Until now only one string
-- of that reached the workshop: `vehicle`, set to "Brand Model", plus the
-- plate. The counter opened a job card that said "Maruti" for the brand
-- and "Suzuki Swift" for the model (the console split the string on its
-- first space), no gearbox, petrol by default, and a blank KM reading —
-- for a car whose owner had typed 60,000 km into the app the day before.
--
-- The fix is to send the car as the customer described it, one column
-- per fact, and let the console read the columns instead of guessing.
-- `vehicle` and `note` are still filled in exactly as before, so a
-- console that has not been updated yet keeps working unchanged.
--
-- ORDER MATTERS: run this before installing the new customer app and the
-- new console. The customer app falls back to the old shape if these
-- columns are missing, and the console skips a column the database does
-- not have, so nothing is lost — but the details only arrive once this
-- file has run.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. The booking request
-- ---------------------------------------------------------------------
-- Text columns default to '' rather than null, the convention the rest of
-- this table keeps. `year` and `odometer_km` stay nullable: zero is a
-- reading, "not given" is not.
alter table public.garage_bookings
  add column if not exists brand         text not null default '',
  add column if not exists model         text not null default '',
  add column if not exists variant       text not null default '',
  add column if not exists fuel          text not null default '',
  add column if not exists transmission  text not null default '',
  add column if not exists year          int,
  add column if not exists odometer_km   int,
  -- 'garage' (the customer drives in) or 'pickup' (pick & drop).
  add column if not exists mode          text not null default '',
  -- What the customer typed in "Additional notes". `note` keeps carrying
  -- the services they ticked, as it always has.
  add column if not exists customer_note text not null default '';

-- A reading the app would never send is a typo or a hand-rolled request.
do $$ begin
  alter table public.garage_bookings add constraint garage_bookings_km_sane
    check (odometer_km is null or odometer_km between 0 and 2000000);
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------
-- 2. The workshop's own record of the car
-- ---------------------------------------------------------------------
-- The console never had a gearbox field, so "Manual" or "Automatic" had
-- nowhere to land even once the booking carried it. '' means not recorded.
alter table public.garage_vehicles
  add column if not exists transmission text not null default '';

-- ---------------------------------------------------------------------
-- 3. Invoice numbers are per customer, not per planet
-- ---------------------------------------------------------------------
-- The customer app files each bill under the job card's number, and job
-- card numbers (`A0921-003`) are only unique inside one workshop. The
-- column was unique across every customer of every workshop, so the second
-- customer anywhere to get an `A0921-003` had their whole invoice upload
-- refused with 23505 — every time, for every invoice, because the app
-- sends them as one batch. Paid bills then never synced and came back
-- unpaid on a reinstall.
--
-- One customer cannot hold two bills with the same number from the same
-- card, so that is where uniqueness belongs.
alter table public.invoices drop constraint if exists invoices_number_key;
create unique index if not exists invoices_user_number
  on public.invoices (user_id, number);

-- ---------------------------------------------------------------------
-- 4. Your own workshop is bookable even when it is not in the directory
-- ---------------------------------------------------------------------
-- The booking screen loads the chosen workshop through `garage_card()`,
-- which answered only for listed garages. A customer who already deals with
-- a workshop that the platform has not listed (yet, or at all) tapped "Book
-- Service" on it and got an empty screen. Being in the directory is about
-- being found by strangers; it was never meant to stop a garage's own
-- customers from booking it. Same function as 08_platform.sql, one clause
-- wider.
create or replace function public.garage_card(gid uuid)
returns jsonb language sql stable security definer
set search_path = public as $fn$
  select jsonb_build_object(
    'id', g.id, 'name', g.name, 'phone', g.phone,
    'address_line', g.address_line, 'city', g.city, 'state', g.state,
    'pin', g.pin, 'lat', g.lat, 'lng', g.lng,
    'logo_path', g.logo_path, 'verified', g.verified,
    'services', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', s.id, 'name', s.name, 'price', s.price,
               'blurb', s.blurb, 'duration_mins', s.duration_mins)
             order by s.name)
        from public.online_services s where s.garage_id = g.id
    ), '[]'::jsonb)
  )
  from public.garages g
  where g.id = gid
    and (g.listed or public.deals_with_garage(g.id));
$fn$;

revoke all on function public.garage_card(uuid) from public;
grant execute on function public.garage_card(uuid) to anon, authenticated;

-- ---------------------------------------------------------------------
-- Check it took (expects 9 booking columns and 1 vehicle column):
--
--   select table_name, column_name from information_schema.columns
--    where table_schema = 'public'
--      and ((table_name = 'garage_bookings' and column_name in
--            ('brand','model','variant','fuel','transmission','year',
--             'odometer_km','mode','customer_note'))
--        or (table_name = 'garage_vehicles' and column_name = 'transmission'))
--    order by 1, 2;
-- =====================================================================
