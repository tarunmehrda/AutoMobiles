-- =====================================================================
-- 16_fix_realtime_publication.sql — the front desk only saw a booking
-- after the app was restarted
--
-- Seen on device, 21 Sep 2026. A customer confirmed four bookings. All
-- four inserted into `garage_bookings` straight away — the customer app
-- logs a failure when the insert is refused, and logged nothing. The
-- workshop console showed **one**. Pull-to-refresh changed nothing. A
-- force-stop and relaunch showed all four at once.
--
-- The console does subscribe to `garage_bookings`
-- (`Admin/lib/data/repo/garage_gateway.dart`, `connect()`), so the
-- subscription was not the problem. The table simply was not publishing.
--
-- Why this project. The block that puts these tables on the realtime
-- publication lives in `03_sync.sql`:
--
--     foreach t in array array[
--       'job_cards','line_items','payments','sms_events','garage_bookings',
--       ...
--
-- `catch_up_05_to_10.sql` — the script `docs/08-first-run-testing.md`
-- tells people to run — never contains it. It adds `attendance` and
-- `garage_notifications` to the publication by hand and stops there. So a
-- project brought up the catch-up way gets a working alert feed and a
-- working attendance register, and silence from everything else: bookings,
-- job cards, masters, staff and the books all arrive only on the next cold
-- start.
--
-- That is the same shape of gap as `11_fix_job_card_save.sql`: setup that
-- `setup_all.sql` has and the catch-up script does not.
--
-- For a front desk this is worth fixing rather than documenting. A booking
-- the counter learns about only after restarting the app is a booking they
-- can miss, and the customer has already been told "the workshop sees your
-- request straight away".
--
-- Safe to run more than once, and safe on a project that is already fine.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Put every table both apps watch on the publication
-- ---------------------------------------------------------------------
-- `replica identity full` is set alongside, because without it an UPDATE
-- or DELETE event carries only the primary key and the console cannot tell
-- which row changed or what it changed to.
do $blk$
declare
  t text;
begin
  foreach t in array array[
    -- the workshop's own rows
    'job_cards', 'line_items', 'payments', 'sms_events',
    'garage_bookings', 'garage_customers', 'garage_vehicles',
    'masters', 'staff', 'reviews', 'garages',
    -- the books
    'expenses', 'cash_book', 'suppliers', 'counter_sales',
    'purchase_orders', 'online_services',
    -- raised by triggers, read-only from the console
    'attendance', 'garage_notifications',
    -- the marketplace
    'part_requests', 'part_listings', 'commissions'
  ] loop
    -- A table an earlier migration never created is skipped rather than
    -- aborting the rest: not every project has the marketplace.
    if to_regclass('public.' || quote_ident(t)) is null then
      raise notice 'skipped % (no such table)', t;
      continue;
    end if;

    begin
      execute format(
        'alter publication supabase_realtime add table public.%I', t);
      raise notice 'published %', t;
    exception
      when duplicate_object then null;   -- already on it
      when undefined_object then null;   -- no such publication
    end;

    execute format('alter table public.%I replica identity full', t);
  end loop;
end
$blk$;

-- ---------------------------------------------------------------------
-- 2. Check it
-- ---------------------------------------------------------------------
-- Every row below should come back `true`. `garage_bookings` is the one
-- this file exists for.
select t                                   as table_name,
       exists (select 1
                 from pg_publication_tables
                where pubname    = 'supabase_realtime'
                  and schemaname = 'public'
                  and tablename  = t)      as published
  from unnest(array[
    'garage_bookings', 'job_cards', 'garage_notifications',
    'masters', 'staff', 'garage_customers', 'garage_vehicles'
  ]) as t
 order by 2, 1;

-- Then, with the console open on any screen, confirm a booking from the
-- customer app. It must reach the Bookings screen without the console
-- being restarted. That is the test this file exists for.
