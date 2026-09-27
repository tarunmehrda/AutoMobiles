-- =====================================================================
-- Verify a live project against the SQL in this folder.
-- =====================================================================
-- Read-only. Paste into the Supabase SQL editor and run. Every row should
-- say OK; anything that says MISSING is a file in this folder that has not
-- reached this database yet.
--
-- Written because probing from outside with the anon key cannot tell the
-- difference between "this does not exist" and "anon is not allowed to see
-- it" — both come back 404. This runs inside the database, where there is
-- no such ambiguity.
-- =====================================================================

with checks(part, what, present) as (
  values
    -- 01_customer.sql
    ('01_customer', 'table profiles',
      to_regclass('public.profiles') is not null),
    ('01_customer', 'table bookings',
      to_regclass('public.bookings') is not null),

    -- 02_garage.sql
    ('02_garage',   'table job_cards',
      to_regclass('public.job_cards') is not null),
    ('02_garage',   'view my_job_cards',
      to_regclass('public.my_job_cards') is not null),
    ('02_garage',   'table garage_bookings',
      to_regclass('public.garage_bookings') is not null),

    -- 03_sync.sql — the customer app's link flow lives here
    ('03_sync',     'table customer_link_codes',
      to_regclass('public.customer_link_codes') is not null),
    ('03_sync',     'function issue_customer_code(text)',
      to_regprocedure('public.issue_customer_code(text)') is not null),
    ('03_sync',     'function redeem_customer_code(text)',
      to_regprocedure('public.redeem_customer_code(text)') is not null),
    ('03_sync',     'function save_job_card(jsonb)',
      to_regprocedure('public.save_job_card(jsonb)') is not null),

    -- 04_roles.sql
    ('04_roles',    'column garage_members.staff_id',
      exists (select 1 from information_schema.columns
               where table_schema = 'public' and table_name = 'garage_members'
                 and column_name = 'staff_id')),
    ('04_roles',    'column garage_members.permissions',
      exists (select 1 from information_schema.columns
               where table_schema = 'public' and table_name = 'garage_members'
                 and column_name = 'permissions')),
    ('04_roles',    'table activity',
      to_regclass('public.activity') is not null),

    -- 05_attendance.sql — without these, punches cannot be verified and the
    -- console falls back to recording the phone's unchecked word for it
    ('05_attendance', 'table attendance',
      to_regclass('public.attendance') is not null),
    ('05_attendance', 'column garages.attendance_lat',
      exists (select 1 from information_schema.columns
               where table_schema = 'public' and table_name = 'garages'
                 and column_name = 'attendance_lat')),
    ('05_attendance', 'column garages.attendance_radius_m',
      exists (select 1 from information_schema.columns
               where table_schema = 'public' and table_name = 'garages'
                 and column_name = 'attendance_radius_m')),
    ('05_attendance', 'function punch_attendance(jsonb)',
      to_regprocedure('public.punch_attendance(jsonb)') is not null),
    ('05_attendance', 'function attendance_log(uuid, timestamptz)',
      to_regprocedure('public.attendance_log(uuid, timestamptz)') is not null),

    -- The control the whole feature rests on: if anything ever grants
    -- authenticated an insert path into `attendance`, a client can write
    -- its own register and `punch_attendance` becomes decoration.
    ('05_attendance', 'attendance has no client write policy',
      not exists (select 1 from pg_policies
                   where schemaname = 'public' and tablename = 'attendance'
                     and cmd <> 'SELECT')),

    -- 06_notifications.sql — the console's bell. Without the trigger the
    -- feed stays empty and nothing is ever announced, which looks exactly
    -- like a quiet week.
    ('06_notifications', 'table garage_notifications',
      to_regclass('public.garage_notifications') is not null),
    ('06_notifications', 'table garage_devices',
      to_regclass('public.garage_devices') is not null),
    ('06_notifications', 'trigger garage_bookings_notify',
      exists (select 1 from pg_trigger
               where tgname = 'garage_bookings_notify' and not tgisinternal)),
    ('06_notifications', 'trigger reviews_notify',
      exists (select 1 from pg_trigger
               where tgname = 'reviews_notify' and not tgisinternal)),
    ('06_notifications', 'function read_garage_notifications(text[])',
      to_regprocedure('public.read_garage_notifications(text[])') is not null),
    ('06_notifications', 'function register_garage_device(text, uuid, text)',
      to_regprocedure('public.register_garage_device(text, uuid, text)')
        is not null),

    -- The same control as attendance, for the same reason: a notification
    -- is a record of something that already happened, so a client that can
    -- insert one can invent the past.
    ('06_notifications', 'garage_notifications has no client write policy',
      not exists (select 1 from pg_policies
                   where schemaname = 'public'
                     and tablename = 'garage_notifications'
                     and cmd <> 'SELECT')),

    -- Realtime is the whole delivery mechanism for a console that is open.
    ('06_notifications', 'garage_notifications is on the realtime publication',
      exists (select 1 from pg_publication_tables
               where pubname = 'supabase_realtime'
                 and schemaname = 'public'
                 and tablename = 'garage_notifications'))
)
select part,
       what,
       case when present then 'OK' else 'MISSING' end as status
from checks
order by part, what;

-- Who may call the two link functions. `redeem_customer_code` must be
-- executable by `authenticated`, or the customer app's sheet cannot run it.
select p.proname,
       coalesce(
         (select string_agg(a.grantee, ', ' order by a.grantee)
          from information_schema.routine_privileges a
          where a.specific_name = p.proname || '_' || p.oid
            and a.privilege_type = 'EXECUTE'),
         '(nobody)') as may_execute
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('issue_customer_code', 'redeem_customer_code')
order by p.proname;
