-- =====================================================================
-- Is this project actually migrated?
-- =====================================================================
-- Paste the whole file into the SQL editor of the project the apps talk
-- to and run it. It changes nothing except the PostgREST cache.
--
-- IMPORTANT — the project must be:
--
--     https://zlrmcrhwtfbwbxhfmygs.supabase.co
--
-- That is the URL compiled into both apps (`app_config.dart`). SQL run in
-- any other project cannot affect them, and this is the single most
-- common reason for "I ran the setup and nothing changed".
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Force PostgREST to re-read the schema
-- ---------------------------------------------------------------------
-- A function can exist in the database and still be invisible to the
-- apps. PostgREST answers from a cached picture of the schema, and until
-- it reloads, a brand new function comes back as PGRST202 -- "could not
-- find the function" -- which reads exactly like never having run the
-- setup at all. Usually it reloads on its own. This makes sure.
notify pgrst, 'reload schema';

-- ---------------------------------------------------------------------
-- 2. What is actually installed
-- ---------------------------------------------------------------------
-- One row per thing the apps need. `present` false is the answer: that
-- file has not been run on this project.
select * from (
  values
    ('nearby_garages',        'supabase/08_platform.sql',
     to_regprocedure('public.nearby_garages(double precision,double precision,double precision,text,integer)') is not null),
    ('garage_card',           'supabase/08_platform.sql',
     to_regprocedure('public.garage_card(uuid)') is not null),
    ('set_garage_location',   'supabase/08_platform.sql',
     to_regprocedure('public.set_garage_location(jsonb)') is not null),
    ('garage_notifications',  'supabase/06_notifications.sql',
     to_regclass('public.garage_notifications') is not null),
    ('register_garage_device','supabase/06_notifications.sql',
     to_regprocedure('public.register_garage_device(uuid,text,text)') is not null),
    ('attendance_log',        'supabase/05_attendance.sql',
     to_regprocedure('public.attendance_log(uuid,timestamptz)') is not null),
    ('intro_video',           'supabase/09_marketplace.sql',
     to_regprocedure('public.intro_video()') is not null),
    ('bookings.garage_id',    'supabase/10_open_booking.sql',
     exists (select 1 from information_schema.columns
              where table_schema = 'public' and table_name = 'bookings'
                and column_name = 'garage_id')),
    ('customer_from_booking', 'supabase/10_open_booking.sql',
     to_regprocedure('public.customer_from_booking()') is not null)
) as t(object, comes_from, present)
order by present, object;

-- Any row with present = false -> run supabase/setup_all.sql, whole file,
-- in THIS project, then run this one again.

-- ---------------------------------------------------------------------
-- 3. Is the workshop findable?
-- ---------------------------------------------------------------------
-- Only meaningful once section 2 is all true.
select id, name, city, listed, lat, lng
  from public.garages
 order by created_at desc;

-- `listed` false  -> supabase/dev_list_my_garage.sql step 2. It defaults
--                    to false and no screen flips it.
-- `lat`/`lng` null-> Admin app: Settings -> Workshop -> Use current
--                    location -> Save.

-- ---------------------------------------------------------------------
-- 4. The search, exactly as the customer app makes it
-- ---------------------------------------------------------------------
-- Put your own coordinates in. A row with a small `km` means the customer
-- app will show it too -- at that point the app and the database agree
-- and anything still wrong is in the app, not here.
--
--   select public.nearby_garages(
--     in_lat => 30.7333, in_lng => 76.7794,
--     radius_km => 10, q => null);
