-- =====================================================================
-- GaragePro — RESET. Deletes everything, so 01 → 02 → 03 can run clean.
-- =====================================================================
--
--   ██  THIS DESTROYS DATA. THERE IS NO UNDO.  ██
--
-- Run this only when you want a genuinely fresh start. It drops every
-- table, view and function the three schema files create, and with them
-- every job card, customer, vehicle, invoice and booking in the project.
--
-- Supabase's own machinery (auth, storage, realtime) is left alone —
-- only the `public` objects this project created are removed.
--
-- Afterwards, run setup_all.sql — or the numbered files in order:
--   01_customer.sql
--   02_garage.sql
--   03_sync.sql
--   04_roles.sql
--   05_attendance.sql
--   06_notifications.sql
--   07_share.sql
--   08_platform.sql
--   09_marketplace.sql
--
-- Section 4 at the bottom also deletes every signed-up user. It is the
-- only part that touches anything outside `public`, and it is separated
-- deliberately: delete those lines if you want to keep your logins and
-- only reset the data.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Views
-- ---------------------------------------------------------------------
drop view if exists public.my_job_cards cascade;


-- ---------------------------------------------------------------------
-- 2. Functions
-- ---------------------------------------------------------------------
-- Dropped before the tables, because `job_card_json` takes a job_cards
-- row as its argument and cannot be named once that table is gone.
--
-- CASCADE also removes the triggers that depend on these, including
-- `on_auth_user_created` on auth.users — which is why that trigger is
-- not dropped separately anywhere here.
-- 07_share.sql — the public job card link
drop function if exists public.shared_card(text) cascade;
drop function if exists public.card_share_token(text) cascade;
drop function if exists public.rotate_share_token(text) cascade;
drop function if exists public.mint_share_token() cascade;
drop function if exists public.guard_share_token() cascade;

-- 08_platform.sql — the directory and the platform admin
drop function if exists public.is_platform_admin() cascade;
drop function if exists public.nearby_garages(
  double precision, double precision, double precision, text, int) cascade;
drop function if exists public.garage_card(uuid) cascade;
drop function if exists public.set_garage_location(jsonb) cascade;
drop function if exists public.set_garage_listing(jsonb) cascade;
drop function if exists public.platform_garages() cascade;

-- 09_marketplace.sql — parts, commission, the welcome video
drop function if exists public.mint_request_code() cascade;
drop function if exists public.guard_part_request() cascade;
drop function if exists public.guard_part_listing() cascade;
drop function if exists public.browse_listings(text, int) cascade;
drop function if exists public.commission_rate(uuid) cascade;
drop function if exists public.book_commission(jsonb) cascade;
drop function if exists public.mark_intro_seen() cascade;
drop function if exists public.intro_video() cascade;

-- 19_commission_and_roles.sql — the platform account and the ledger
drop function if exists public.guard_profile_role() cascade;
drop function if exists public.guard_garage_platform_columns() cascade;
drop function if exists public.accrue_commission() cascade;
drop function if exists public.commission_summary() cascade;

-- 20_workflow_fixes.sql — reschedule, cancel notices, account deletion
drop function if exists public.guard_booking_customer_edit() cascade;
drop function if exists public.notify_booking_moved() cascade;
drop function if exists public.delete_my_account() cascade;

-- 21_private_commission.sql — one workshop's commission, for its owner
drop function if exists public.my_commission(uuid) cascade;

-- 22_customer_push.sql — the customer's phone rings too
drop function if exists public.register_customer_device(text, text) cascade;
drop function if exists public.forget_customer_device(text) cascade;
drop function if exists public.push_customer_alert(uuid, text, text, text, text) cascade;
drop function if exists public.alert_when(timestamptz) cascade;
drop function if exists public.alert_customer_booking() cascade;
drop function if exists public.alert_customer_job() cascade;
drop function if exists public.alert_customer_payment() cascade;

-- 05_attendance.sql — the register and the distance behind it
drop function if exists public.punch_attendance(jsonb) cascade;
drop function if exists public.attendance_log(uuid, timestamptz) cascade;
drop function if exists public.geo_distance_m(
  double precision, double precision, double precision,
  double precision) cascade;

-- 06_notifications.sql — the workshop's bell, and the handsets it rings
drop function if exists public.push_garage_notification(
  uuid, text, text, text, text, text, text) cascade;
drop function if exists public.read_garage_notifications(text[]) cascade;
drop function if exists public.notify_booking_request() cascade;
drop function if exists public.notify_new_review() cascade;
drop function if exists public.register_garage_device(text, uuid, text) cascade;
drop function if exists public.forget_garage_device(text) cascade;

drop function if exists public.job_card_json(public.job_cards) cascade;
drop function if exists public.save_job_card(jsonb) cascade;
drop function if exists public.job_card_detail(text) cascade;
drop function if exists public.garage_snapshot(uuid) cascade;
drop function if exists public.garage_summary(uuid) cascade;
drop function if exists public.create_garage(jsonb) cascade;
drop function if exists public.next_job_number(uuid) cascade;
drop function if exists public.my_garage() cascade;

drop function if exists public.issue_customer_code(text) cascade;
drop function if exists public.redeem_customer_code(text) cascade;
-- Gone from the schema as of 10_open_booking.sql; still dropped here so a
-- reset of a project that predates it leaves nothing redeemable behind.
drop function if exists public.customer_from_booking() cascade;
drop function if exists public.link_on_booking_accept() cascade;
drop function if exists public.verified_phone(uuid) cascade;

drop function if exists public.my_access(uuid) cascade;
drop function if exists public.member_can(uuid, text, text) cascade;
drop function if exists public.member_grid(uuid) cascade;
drop function if exists public.member_role(uuid) cascade;
drop function if exists public.member_staff_id(uuid) cascade;
drop function if exists public.own_jobs_only(uuid) cascade;
drop function if exists public.sees_cost(uuid) cascade;
drop function if exists public.role_grid(text) cascade;

drop function if exists public.is_garage_member(uuid) cascade;
drop function if exists public.owns_job_card(text) cascade;
drop function if exists public.reads_job_card(text) cascade;
drop function if exists public.deals_with_garage(uuid) cascade;

drop function if exists public.handle_new_user() cascade;
drop function if exists public.link_profile_to_customers() cascade;
drop function if exists public.sync_job_card_profile() cascade;
drop function if exists public.backfill_job_card_profiles() cascade;
drop function if exists public.lock_approved_estimate() cascade;
drop function if exists public.touch_updated_at() cascade;
drop function if exists public.norm_phone(text) cascade;


-- ---------------------------------------------------------------------
-- 3. Tables
-- ---------------------------------------------------------------------
-- CASCADE takes the foreign keys, indexes, policies and realtime
-- publication memberships with them, so the order here does not matter.
-- 09_marketplace.sql, 08_platform.sql, 07_share.sql. Dropped first
-- because they reference garages and job_cards below.
drop table if exists public.commissions cascade;
drop table if exists public.part_listings cascade;
drop table if exists public.part_requests cascade;
drop table if exists public.platform_settings cascade;
drop table if exists public.garage_devices cascade;
drop table if exists public.garage_notifications cascade;
drop table if exists public.attendance cascade;
drop table if exists public.activity cascade;
drop table if exists public.online_services cascade;
drop table if exists public.purchase_orders cascade;
drop table if exists public.counter_sales cascade;
drop table if exists public.suppliers cascade;
drop table if exists public.cash_book cascade;
drop table if exists public.expenses cascade;
drop table if exists public.customer_link_codes cascade;
drop table if exists public.reviews cascade;
drop table if exists public.garage_bookings cascade;
drop table if exists public.sms_events cascade;
drop table if exists public.payments cascade;
drop table if exists public.line_items cascade;
drop table if exists public.job_cards cascade;
drop table if exists public.masters cascade;
drop table if exists public.garage_vehicles cascade;
drop table if exists public.garage_customers cascade;
drop table if exists public.staff cascade;
drop table if exists public.garage_members cascade;
drop table if exists public.garages cascade;

drop table if exists public.sos_requests cascade;
drop table if exists public.chat_messages cascade;
drop table if exists public.tickets cascade;
drop table if exists public.notifications cascade;
drop table if exists public.invoices cascade;
drop table if exists public.estimates cascade;
drop table if exists public.inspections cascade;
drop table if exists public.bookings cascade;
drop table if exists public.addresses cascade;
drop table if exists public.vehicles cascade;
drop table if exists public.profiles cascade;

drop table if exists public.slots cascade;
drop table if exists public.coupons cascade;
drop table if exists public.add_ons cascade;
drop table if exists public.service_packages cascade;
drop table if exists public.service_categories cascade;


-- ---------------------------------------------------------------------
-- 4. Sign-ups
-- ---------------------------------------------------------------------
--   ██  DELETE THIS SECTION IF YOU WANT TO KEEP YOUR LOGINS.  ██
--
-- Everything above only resets the data. This removes the accounts too:
-- every user, every session, every linked Google identity. Anyone signed
-- in on a phone is signed out, and they sign up again as a new person.
--
-- Keep it if you have been testing with throwaway accounts and want the
-- project genuinely empty. Delete it if there are real sign-ups you care
-- about, or if you want to keep your own login.
delete from auth.users;


-- ---------------------------------------------------------------------
-- 5. Check
-- ---------------------------------------------------------------------
-- Both should come back empty. If either returns rows, something above
-- did not drop — send the output and it can be dealt with by name.
select tablename  as leftover_table
  from pg_tables
 where schemaname = 'public'
 order by tablename;

select routine_name as leftover_function
  from information_schema.routines
 where routine_schema = 'public'
 order by routine_name;

-- ---------------------------------------------------------------------
-- 6. The marketplace photo bucket
-- ---------------------------------------------------------------------
-- Outside `public`, so nothing above removes it. Dropping the objects
-- first is required: a bucket with contents will not delete.
--
-- Skipped silently on a project that never ran 09_marketplace.sql.
--
-- Two blocks rather than one, and both swallow their failures, because
-- this file runs as a single transaction in the SQL editor: anything that
-- raises down here takes every drop above it with it, and the reset then
-- reports a failure while having reset nothing.
--
-- Newer Supabase projects carry a `storage.protect_delete` trigger that
-- refuses a direct delete from storage.objects outright — there is no way
-- past it from SQL, and it must not be what stops a reset.
do $blk$ begin
  delete from storage.objects where bucket_id = 'marketplace';
exception
  when undefined_table       then null;
  when insufficient_privilege then null;
end $blk$;

-- A bucket that still holds objects will not delete. If the block above
-- was refused, empty the bucket from Storage in the dashboard and run this
-- file again — or leave it, since 09_marketplace.sql re-uses the bucket it
-- finds rather than insisting on a new one.
do $blk$ begin
  delete from storage.buckets where id = 'marketplace';
exception
  when undefined_table        then null;
  when insufficient_privilege then null;
  when foreign_key_violation  then null;
end $blk$;

-- Guarded for the same reason as the blocks above: on a project where the
-- storage schema is not ours to alter, a refusal here would roll back every
-- drop in section 3. The policies are re-created by 09_marketplace.sql
-- either way, so leaving them standing costs nothing.
do $blk$ begin
  drop policy if exists marketplace_read   on storage.objects;
  drop policy if exists marketplace_write  on storage.objects;
  drop policy if exists marketplace_update on storage.objects;
  drop policy if exists marketplace_delete on storage.objects;
exception
  when undefined_table        then null;
  when insufficient_privilege then null;
end $blk$;
