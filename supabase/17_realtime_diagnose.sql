-- =====================================================================
-- 17_realtime_diagnose.sql — realtime subscribes, then delivers nothing
--
-- Run this AFTER 16_fix_realtime_publication.sql, which is already done:
-- all seven watched tables report `published = true`.
--
-- What is still wrong, measured on device 22 Sep 2026:
--   * `channel.subscribe()` reports `subscribed`, never `channelError`,
--     so the websocket is up and the Realtime service answered.
--   * A booking is confirmed on the customer app and lands in
--     `garage_bookings` (a refetch pulls it straight in).
--   * The console logs **no postgres_changes event at all** — not for
--     `garage_bookings`, and not for `garage_notifications` or
--     `attendance` either, which have been on the publication far longer.
--
-- Nothing arriving for *any* table rules out per-table RLS: the console
-- can read all of these, and RLS differs per table, so a policy problem
-- would silence some and not others. Something shared is stopping the
-- whole stream. The three candidates this file checks are the three that
-- would do exactly that.
--
-- Read-only except for section 2, which only widens the publication to
-- the operations it should already carry.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Which operations does the publication actually carry?
-- ---------------------------------------------------------------------
-- A publication created as `for update` — or with inserts switched off —
-- lists its tables perfectly happily and never emits an INSERT. That
-- would look exactly like what we are seeing: membership verified, rows
-- arriving in the table, nothing on the wire.
--
-- `pubinsert` must be true. So must `pubupdate` and `pubdelete`, or job
-- cards edited elsewhere will not reach this console either.
select pubname,
       puballtables,
       pubinsert,
       pubupdate,
       pubdelete,
       pubtruncate
  from pg_publication
 where pubname = 'supabase_realtime';

-- ---------------------------------------------------------------------
-- 2. Put the missing operations back
-- ---------------------------------------------------------------------
-- Only runs when something is actually off, so it is a no-op on a healthy
-- project. `alter publication ... set (publish = ...)` replaces the whole
-- set, which is why all four are named.
do $blk$
declare
  p pg_publication%rowtype;
begin
  select * into p from pg_publication where pubname = 'supabase_realtime';

  if not found then
    raise notice 'no supabase_realtime publication at all -- that is the fault';
    return;
  end if;

  if p.pubinsert and p.pubupdate and p.pubdelete then
    raise notice 'publication already carries insert/update/delete';
    return;
  end if;

  raise notice 'publication was missing operations (insert=% update=% delete=%), widening',
    p.pubinsert, p.pubupdate, p.pubdelete;
  alter publication supabase_realtime
    set (publish = 'insert, update, delete, truncate');
end
$blk$;

-- ---------------------------------------------------------------------
-- 3. Is anything reading the WAL?
-- ---------------------------------------------------------------------
-- Realtime consumes changes through a logical replication slot. If there
-- is no slot, or the slot is inactive, the service is connected to your
-- clients and to nothing else — which is precisely the symptom.
--
--   * no row at all            -> Realtime is not running for this project
--   * `active = false`         -> it is not currently consuming
--   * a large `behind_bytes`   -> it is consuming but far behind
--
-- A slot that exists and is active, with the publication correct, means
-- the fault is above Postgres and the answer is to restart Realtime from
-- the dashboard (Project Settings, or Database -> Replication).
select slot_name,
       plugin,
       slot_type,
       active,
       pg_size_pretty(
         pg_wal_lsn_diff(pg_current_wal_lsn(), confirmed_flush_lsn)
       ) as behind_bytes
  from pg_replication_slots
 order by slot_name;

-- ---------------------------------------------------------------------
-- 4. Can `authenticated` actually read these tables?
-- ---------------------------------------------------------------------
-- Realtime evaluates RLS as the subscribing role. A table with RLS
-- policies but no table-level SELECT grant to `authenticated` is readable
-- through the app's RPCs (which are security definer) and invisible to
-- Realtime. Every row below should say true.
select t                                              as table_name,
       has_table_privilege('authenticated', 'public.' || t, 'SELECT')
                                                      as authenticated_can_select,
       relrowsecurity                                 as rls_on,
       (select count(*) from pg_policies
         where schemaname = 'public' and tablename = t) as policies
  from unnest(array[
    'garage_bookings', 'job_cards', 'garage_notifications',
    'masters', 'staff', 'garage_customers', 'garage_vehicles'
  ]) as t
  join pg_class c on c.relname = t
  join pg_namespace n on n.oid = c.relnamespace and n.nspname = 'public'
 order by 2, 1;

-- ---------------------------------------------------------------------
-- What to do with the answers
-- ---------------------------------------------------------------------
-- Section 1/2 fixed it          -> nothing more to do; retest on device.
-- Section 3 shows no slot       -> Realtime is off. Turn it on for the
--                                  project, then restart it.
-- Section 3 shows active slot   -> Postgres is fine and Realtime is not
--                                  forwarding. Restart Realtime from the
--                                  dashboard; the slot most likely
--                                  predates the publication changes.
-- Section 4 shows a false       -> grant select on that table to
--                                  authenticated; RLS still applies.
--
-- The console does not wait on any of this. It refetches when it is
-- brought back to the foreground and on pull-to-refresh, so the front
-- desk sees its work either way. This file is about getting the live
-- push back, not about unblocking the counter.
