-- =====================================================================
-- GaragePro — the workshop's own notifications, and the devices they
-- are pushed to
-- =====================================================================
-- Run AFTER 02_garage.sql and 03_sync.sql. Additive and idempotent: it can
-- be run again on a live project without losing anything, and it does not
-- edit or redefine anything in the earlier files.
--
-- The customer app has had a `notifications` table since 01_customer.sql.
-- The workshop never did. A booking request landed in `garage_bookings`,
-- the console's realtime channel merged it into a list, and that was the
-- whole of the workshop being told — a row count changing behind whatever
-- screen the counter happened to be on.
--
-- This file gives the garage side the same thing the customer side has:
--
--   * a durable, per-garage feed with a read flag, so "was anybody told?"
--     has an answer that survives a restart and is the same answer on
--     every device at the counter,
--   * rows written by the database at the moment the thing happened,
--     never by a client, so a notification cannot be forged, suppressed,
--     or missed because the console was closed, and
--   * a device register, so the same event can be pushed to a phone that
--     is not running the app at all.
--
-- Like `attendance`, this runs the opposite way round to the rest of the
-- console. Everywhere else the phone decides and the backend stores what
-- it is handed. Here the backend decides: a notification is a fact about
-- something that already happened in another table, so letting a client
-- insert one would only ever let it lie about the past. There is no
-- insert policy, for anybody, owner included.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. The feed
-- ---------------------------------------------------------------------
-- `route` is the console path this notification opens, resolved when the
-- row is written rather than guessed by the client. It means a future
-- notification kind can point somewhere new without shipping an app
-- update to teach the bell where that is.

create table if not exists public.garage_notifications (
  id          text primary key,
  garage_id   uuid not null references public.garages (id) on delete cascade,
  kind        text not null default 'booking',
  title       text not null,
  body        text not null default '',
  route       text,
  booking_id  text,
  job_card_id text references public.job_cards (id) on delete set null,
  read        boolean not null default false,
  at          timestamptz not null default now()
);

-- Added after the table shipped, so the `create table if not exists` above
-- will not put them on a database that already has an earlier version of
-- this table. That is not hypothetical: 00_reset.sql dropped every other
-- table this project creates and left these two standing, so a project
-- that has been reset still has whatever shape `garage_notifications` had
-- the first time it was created. The statement that used to find out was
-- the backfill at the bottom of this file, with `column "booking_id" does
-- not exist` — which is the whole of section 8 failing on a database that
-- looked freshly reset.
alter table public.garage_notifications
  add column if not exists kind        text not null default 'booking',
  add column if not exists title       text not null default '',
  add column if not exists body        text not null default '',
  add column if not exists route       text,
  add column if not exists booking_id  text,
  add column if not exists job_card_id text
                                       references public.job_cards (id)
                                       on delete set null,
  add column if not exists read        boolean not null default false,
  add column if not exists at          timestamptz not null default now();

-- The bell's two questions — "what is unread?" and "what happened
-- lately?" — are one index each way round.
create index if not exists garage_notifications_feed_idx
  on public.garage_notifications (garage_id, at desc);
create index if not exists garage_notifications_unread_idx
  on public.garage_notifications (garage_id, read, at desc);

comment on table public.garage_notifications is
  'Server-authored alerts for a workshop. Written only by triggers; no
   client may insert.';

-- ---------------------------------------------------------------------
-- 2. Writing one
-- ---------------------------------------------------------------------
-- SECURITY DEFINER because the writer is usually the *customer*: they are
-- the one inserting the booking row that fires the trigger, and they are
-- not a member of the garage being told about it.
--
-- The retention sweep rides along on the insert rather than needing a
-- scheduled job. A feed nobody prunes grows until the bell takes a second
-- to open; read rows older than a month have been seen and dealt with,
-- and unread ones are kept for a quarter regardless, because "nobody
-- looked at this for six weeks" is itself worth being able to see.

create or replace function public.push_garage_notification(
  gid   uuid,
  kind  text,
  title text,
  body  text default '',
  route text default null,
  booking_id text default null,
  job_card_id text default null
)
returns text language plpgsql security definer
set search_path = public as $fn$
declare made text;
begin
  if gid is null then return null; end if;

  made := 'gn-' || replace(gen_random_uuid()::text, '-', '');

  insert into public.garage_notifications
    (id, garage_id, kind, title, body, route, booking_id, job_card_id)
  values
    (made, gid, kind, title, body, route, booking_id, job_card_id);

  delete from public.garage_notifications n
   where n.garage_id = gid
     and ((n.read and n.at < now() - interval '30 days')
          or n.at < now() - interval '90 days');

  return made;
end $fn$;

-- ---------------------------------------------------------------------
-- 3. What raises one
-- ---------------------------------------------------------------------

-- A booking request from the customer app.
--
-- The slot is formatted here, in Asia/Kolkata, rather than left to the
-- client. A pushed notification is read on a lock screen by an OS that
-- never loaded this app's formatters, so the row has to carry a sentence
-- that is already readable. Everything else in this product is priced in
-- rupees and taxed under GST; the workshop is not in another timezone.
create or replace function public.notify_booking_request()
returns trigger language plpgsql security definer
set search_path = public as $fn$
declare
  who  text := nullif(trim(new.name), '');
  what text := trim(coalesce(new.vehicle, ''));
begin
  -- Only a genuine request from outside. A row raised by the counter
  -- itself — a walk-in typed in at the desk, or one created already
  -- accepted — is the workshop telling itself something it just did, and a
  -- phone that buzzes in your hand as you finish typing is how people learn
  -- to ignore the buzz.
  if new.accepted or public.is_garage_member(new.garage_id) then
    return new;
  end if;

  if new.reg_no is not null and trim(new.reg_no) <> '' then
    what := trim(what || ' • ' || upper(trim(new.reg_no)));
  end if;

  perform public.push_garage_notification(
    new.garage_id,
    'booking',
    coalesce(who, 'Someone') || ' requested a slot',
    trim(both ' •' from
      coalesce(nullif(what, ''), '') || ' • ' ||
      to_char(new.at at time zone 'Asia/Kolkata', 'Dy DD Mon, hh12:mi am')),
    '/bookings',
    new.id,
    null);

  return new;
end $fn$;

drop trigger if exists garage_bookings_notify on public.garage_bookings;
create trigger garage_bookings_notify
  after insert on public.garage_bookings
  for each row execute function public.notify_booking_request();

-- A rating left against a closed card.
create or replace function public.notify_new_review()
returns trigger language plpgsql security definer
set search_path = public as $fn$
begin
  perform public.push_garage_notification(
    new.garage_id,
    'review',
    new.stars || '-star review',
    coalesce(nullif(trim(new.comment), ''), 'No comment left.'),
    '/feedback',
    null,
    new.job_card_id);
  return new;
end $fn$;

drop trigger if exists reviews_notify on public.reviews;
create trigger reviews_notify
  after insert on public.reviews
  for each row execute function public.notify_new_review();

-- ---------------------------------------------------------------------
-- 4. Marking them read
-- ---------------------------------------------------------------------
-- A function rather than an update policy, so `read` is the only column a
-- console can ever change. The text of a notification is a record of what
-- the garage was told and when; it is not editable by the party it was
-- addressed to.

-- Membership is tested per row rather than by resolving "this caller's
-- garage" first. `garage_members` allows a person to be at more than one
-- workshop, and picking one of them arbitrarily would silently refuse to
-- clear the bell at the other.
create or replace function public.read_garage_notifications(ids text[])
returns int language plpgsql security definer
set search_path = public as $fn$
declare hit int;
begin
  if auth.uid() is null then
    raise exception 'not signed in';
  end if;

  update public.garage_notifications n
     set read = true
   where not n.read
     and public.is_garage_member(n.garage_id)
     and (ids is null or n.id = any (ids));

  get diagnostics hit = row_count;
  return hit;
end $fn$;

-- ---------------------------------------------------------------------
-- 5. Devices to push to
-- ---------------------------------------------------------------------
-- Keyed by the FCM token, because that is what is actually unique: the
-- same phone reinstalled is a new token and an old one that will start
-- bouncing, and the same person signing in on a second handset is a
-- second row that should also ring.
--
-- `last_seen_at` is what makes a token disposable. A registration that
-- has not been refreshed in two months belongs to a device that has not
-- opened the console in two months, and sending to it costs a round trip
-- to be told it is gone.

create table if not exists public.garage_devices (
  token        text primary key,
  garage_id    uuid not null references public.garages (id) on delete cascade,
  profile_id   uuid not null references auth.users (id) on delete cascade,
  platform     text not null default 'android',
  last_seen_at timestamptz not null default now(),
  created_at   timestamptz not null default now()
);
-- Same reason as the block above: a project that ran an earlier version of
-- this file still has its own `garage_devices`, and `create table if not
-- exists` will not reshape it.
alter table public.garage_devices
  add column if not exists platform     text not null default 'android',
  add column if not exists last_seen_at timestamptz not null default now(),
  add column if not exists created_at   timestamptz not null default now();

create index if not exists garage_devices_garage_idx
  on public.garage_devices (garage_id);

-- Called on every launch, so it is an upsert: a token that moved to a
-- different garage or a different person follows them.
-- The garage is named by the caller and then checked, rather than looked
-- up as "whichever one they belong to": a person at two workshops would
-- otherwise have their phone registered to whichever row sorted first,
-- and be rung for the shop they are not standing in.
create or replace function public.register_garage_device(
  tok text,
  gid uuid,
  plat text default 'android'
)
returns void language plpgsql security definer
set search_path = public as $fn$
declare uid uuid := auth.uid();
begin
  if uid is null or coalesce(trim(tok), '') = '' or gid is null then
    return;
  end if;
  if not public.is_garage_member(gid) then
    raise exception 'not a member of this garage';
  end if;

  insert into public.garage_devices (token, garage_id, profile_id, platform)
  values (trim(tok), gid, uid, coalesce(nullif(trim(plat), ''), 'android'))
  on conflict (token) do update
    set garage_id    = excluded.garage_id,
        profile_id   = excluded.profile_id,
        platform     = excluded.platform,
        last_seen_at = now();

  delete from public.garage_devices d
   where d.last_seen_at < now() - interval '60 days';
end $fn$;

-- Signing out should stop the ringing on that handset, and only that one.
create or replace function public.forget_garage_device(tok text)
returns void language plpgsql security definer
set search_path = public as $fn$
begin
  delete from public.garage_devices d
   where d.token = trim(tok) and d.profile_id = auth.uid();
end $fn$;

-- ---------------------------------------------------------------------
-- 6. Row level security
-- ---------------------------------------------------------------------

alter table public.garage_notifications enable row level security;
alter table public.garage_devices       enable row level security;

-- Read-only, to the garage it belongs to. No insert, update or delete
-- policy exists: sections 2 and 4 are the only ways in.
drop policy if exists garage_notifications_member on public.garage_notifications;
create policy garage_notifications_member on public.garage_notifications
  for select to authenticated
  using (public.is_garage_member(garage_id));

-- A device register is not something the console needs to read. It is
-- written by `register_garage_device()` and read by the edge function
-- with the service role, and nothing else touches it.
drop policy if exists garage_devices_none on public.garage_devices;

revoke all on public.garage_notifications from anon, authenticated;
grant select on public.garage_notifications to authenticated;

revoke all on public.garage_devices from anon, authenticated;

revoke all on function public.push_garage_notification(
  uuid, text, text, text, text, text, text) from public;
revoke all on function public.read_garage_notifications(text[]) from public;
revoke all on function public.register_garage_device(text, uuid, text) from public;
revoke all on function public.forget_garage_device(text) from public;

grant execute on function public.read_garage_notifications(text[])
  to authenticated;
grant execute on function public.register_garage_device(text, uuid, text)
  to authenticated;
grant execute on function public.forget_garage_device(text)
  to authenticated;

-- ---------------------------------------------------------------------
-- 7. Realtime
-- ---------------------------------------------------------------------
-- The whole point of the feed: a booking raised on a customer's phone
-- reaches the counter's screen while they are looking at something else.
-- Replica identity full for the same reason as every other table here —
-- a delete otherwise carries only the primary key, and the console needs
-- the garage_id to know whether it was theirs.

do $blk$
begin
  begin
    alter publication supabase_realtime add table public.garage_notifications;
  exception when duplicate_object then null;
  end;
  alter table public.garage_notifications replica identity full;
end $blk$;

-- ---------------------------------------------------------------------
-- 8. Backfill
-- ---------------------------------------------------------------------
-- Requests that were already waiting when this file was run. Without
-- this, a console that upgrades to the bell sees an empty feed sitting
-- above a Bookings screen with six unaccepted rows on it.

insert into public.garage_notifications
  (id, garage_id, kind, title, body, route, booking_id, at)
select
  'gn-seed-' || b.id,
  b.garage_id,
  'booking',
  coalesce(nullif(trim(b.name), ''), 'Someone') || ' requested a slot',
  trim(both ' •' from
    trim(coalesce(b.vehicle, '')) ||
    case when coalesce(trim(b.reg_no), '') = '' then ''
         else ' • ' || upper(trim(b.reg_no)) end || ' • ' ||
    to_char(b.at at time zone 'Asia/Kolkata', 'Dy DD Mon, hh12:mi am')),
  '/bookings',
  b.id,
  b.created_at
from public.garage_bookings b
where not b.accepted
on conflict (id) do nothing;
