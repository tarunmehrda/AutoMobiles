-- =====================================================================
-- CATCH-UP: migrations 05 to 10, for a project that already has 01-04.
-- =====================================================================
-- Paste the whole file into the SQL editor of
--   https://zlrmcrhwtfbwbxhfmygs.supabase.co
-- and press Run. Idempotent; drops nothing.
--
-- A quarter the size of setup_all.sql, which matters: the editor times
-- out on very long scripts, and a run that timed out half way looks
-- exactly like a run that did nothing.
--
-- If it still fails, run them one at a time in this order and say
-- which errors: 05, 06, 07, 08, 09, 10.
-- =====================================================================


-- ###  BEGIN 05_attendance.sql

-- =====================================================================
-- GaragePro — attendance, and the location checks behind it
-- =====================================================================
-- Run AFTER 02_garage.sql and 03_sync.sql. Additive and idempotent: it can
-- be run again on a live project without losing anything, and it does not
-- edit or redefine anything in the earlier files.
--
-- The whole point of this file is that it is NOT the offline-first
-- arrangement the rest of the console uses.
--
-- Everywhere else, the phone decides and the backend stores what it is
-- handed: a job card is whatever the counter says it is, and that is
-- correct, because the counter is the authority on its own paperwork.
-- Attendance is the one place where the phone is the thing being checked,
-- so the same design would be no design at all. A client that can insert
-- its own attendance row can mark itself present from a sofa, and no amount
-- of checking in Dart changes that — the Dart is on the sofa too.
--
-- So `attendance` has a select policy and nothing else. No insert, no
-- update, no delete, for anybody, owner included. The only way a row comes
-- into existence is `punch_attendance()`, which:
--
--   * re-derives the distance from the submitted coordinates instead of
--     believing the distance the phone sent,
--   * re-reads the radius from the garage row instead of a number in the
--     payload,
--   * stamps `at` from the server's clock, so a phone set to last Tuesday
--     cannot backdate a shift,
--   * refuses a fix the device itself flagged as mocked,
--   * refuses a position nobody could have travelled to since the last
--     punch, and
--   * records every refusal as a row, because a register that quietly drops
--     the interesting attempts is a register that looks clean for the wrong
--     reason.
--
-- What this cannot do is verify a coordinate that was honestly obtained.
-- A rooted device with a hook inside the app's own process can hand the
-- server a plausible, un-flagged, perfectly in-radius lie. The controls
-- here raise the cost of that from "install a free app" to "root the phone
-- and defeat the cross-provider check", and they make every attempt
-- visible. That is the achievable goal; anything claiming more is claiming
-- to solve the client-trust problem, which nobody has.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. The designated location
-- ---------------------------------------------------------------------
-- On the garage row rather than in a table of its own: there is one per
-- workshop, it belongs to the workshop the way its GSTIN does, and keeping
-- it here means `garage_snapshot` and `my_garage` carry it already —
-- neither function needs touching.
--
-- It also means the radius lives somewhere the client cannot rewrite
-- without going through the garages policy, which is the whole reason
-- `punch_attendance` reads it from here instead of from the payload.

alter table public.garages
  add column if not exists attendance_lat double precision;
alter table public.garages
  add column if not exists attendance_lng double precision;

-- Five metres is what the brief asks for and what a fresh workshop gets.
-- It is also smaller than a consumer GPS fix is accurate to, which is why
-- it is a column and not a constant: an owner whose staff keep being turned
-- away in a shed with a steel roof needs to be able to widen it without a
-- new build.
alter table public.garages
  add column if not exists attendance_radius_m numeric(7,1) not null
  default 5;

-- A fix vaguer than this proves nothing about a five metre circle, so it is
-- refused rather than rounded in the employee's favour.
alter table public.garages
  add column if not exists attendance_max_accuracy_m numeric(7,1) not null
  default 25;

alter table public.garages
  add column if not exists attendance_label text not null default '';

-- A negative or zero radius would let nobody punch in anywhere; an
-- unbounded one would let everybody punch in from anywhere. Both are
-- almost certainly a typo rather than an intention.
do $blk$
begin
  alter table public.garages
    add constraint garages_attendance_radius_ck
    check (attendance_radius_m > 0 and attendance_radius_m <= 5000);
exception when duplicate_object then null;
end $blk$;

do $blk$
begin
  alter table public.garages
    add constraint garages_attendance_accuracy_ck
    check (attendance_max_accuracy_m > 0 and attendance_max_accuracy_m <= 5000);
exception when duplicate_object then null;
end $blk$;

-- ---------------------------------------------------------------------
-- 2. The register
-- ---------------------------------------------------------------------
-- Rejected attempts live here too, with `accepted = false` and the reason
-- in `block`. Payroll reads the accepted rows; the owner reads the rest.

create table if not exists public.attendance (
  id          text primary key,
  garage_id   uuid not null references public.garages (id) on delete cascade,

  -- Not a foreign key to `staff`, and deliberately. A mechanic who leaves
  -- is removed from the team, and last quarter's register must still say
  -- who was on the floor — a cascade would erase exactly the history
  -- payroll is most likely to be asked about.
  staff_id    text not null default '',
  staff_name  text not null default '',

  -- Who was holding the phone, as opposed to whose attendance it is. On a
  -- shared counter handset these differ, and when they do it is the only
  -- record of who marked somebody else present.
  actor_id    uuid,

  kind        text not null check (kind in ('in', 'out')),

  -- The server's clock, always. Never the phone's — see `punch_attendance`.
  at          timestamptz not null default now(),

  lat         double precision,
  lng         double precision,

  -- What the device claimed its fix was good to.
  accuracy_m  numeric(9,2) not null default 0,

  -- What the SERVER measured from the coordinates. The phone's own figure,
  -- when it disagrees, goes in `note`.
  distance_m  numeric(11,2) not null default 0,

  -- Whether the device reported its own position as simulated.
  mocked      boolean not null default false,

  accepted    boolean not null default true,

  -- 'ok' on an accepted row, otherwise the refusal code the client maps to
  -- a sentence. Matches `PunchBlockX.wire` in lib/data/models/attendance.dart.
  block       text not null default 'ok',

  note        text not null default '',
  created_at  timestamptz not null default now()
);

create index if not exists attendance_garage_idx
  on public.attendance (garage_id, at desc);

-- The shift lookup: "what did this person last do?", which is what decides
-- whether the button says In or Out.
create index if not exists attendance_staff_idx
  on public.attendance (garage_id, staff_id, at desc)
  where accepted;

-- ---------------------------------------------------------------------
-- 3. Distance
-- ---------------------------------------------------------------------
-- Haversine on a sphere, in metres. Plain SQL rather than earthdistance or
-- PostGIS so this file needs no extension enabled and cannot fail on a
-- project that has not got one.
--
-- It is a spherical approximation where the client's `Geolocator
-- .distanceBetween` is an ellipsoidal one, so the two disagree by a
-- fraction of a percent. At the ranges that matter here that is under a
-- centimetre, and `punch_attendance` never compares the two figures more
-- finely than metres.

create or replace function public.geo_distance_m(
  lat1 double precision, lng1 double precision,
  lat2 double precision, lng2 double precision)
returns double precision language sql immutable parallel safe as $fn$
  select case
    when lat1 is null or lng1 is null or lat2 is null or lng2 is null
      then null
    else 12742000 * asin(least(1.0, sqrt(
           power(sin(radians(lat2 - lat1) / 2), 2) +
           cos(radians(lat1)) * cos(radians(lat2)) *
           power(sin(radians(lng2 - lng1) / 2), 2))))
  end;
$fn$;

-- ---------------------------------------------------------------------
-- 4. Punching
-- ---------------------------------------------------------------------
-- Returns { code, message, row } rather than raising, for everything except
-- "you do not work here". A refusal is a normal outcome that the screen has
-- a sentence for and the register has a row for; making it an exception
-- would abort the transaction that is supposed to be recording it.

create or replace function public.punch_attendance(payload jsonb)
returns jsonb language plpgsql security definer
set search_path = public as $fn$
declare
  gid        uuid := nullif(payload ->> 'garage_id', '')::uuid;
  g          public.garages;
  v_staff    text := coalesce(payload ->> 'staff_id', '');
  v_name     text := coalesce(payload ->> 'staff_name', '');
  v_kind     text := coalesce(payload ->> 'kind', 'in');
  v_lat      double precision := (payload ->> 'lat')::double precision;
  v_lng      double precision := (payload ->> 'lng')::double precision;
  v_acc      double precision :=
               coalesce((payload ->> 'accuracy_m')::double precision, 0);
  v_claimed  double precision :=
               coalesce((payload ->> 'distance_m')::double precision, 0);
  v_mocked   boolean := coalesce((payload ->> 'mocked')::boolean, false);
  v_fix_at   timestamptz := nullif(payload ->> 'fix_at', '')::timestamptz;
  v_note     text := left(coalesce(payload ->> 'note', ''), 500);

  v_dist     double precision;
  v_prev     public.attendance;
  v_moved    double precision;
  v_secs     double precision;
  v_skew     double precision;
  v_code     text := 'ok';
  v_msg      text := '';
  v_row      public.attendance;
begin
  -- The security boundary, and the only thing here that raises. Everything
  -- past this point is a workshop's own business.
  if gid is null or not public.is_garage_member(gid) then
    raise exception 'not a member of this garage' using errcode = '42501';
  end if;
  if v_kind not in ('in', 'out') then
    raise exception 'unknown punch kind: %', v_kind using errcode = '22023';
  end if;
  if v_staff = '' then
    raise exception 'no staff id on the punch' using errcode = '22023';
  end if;

  select * into g from public.garages where id = gid;

  -- 1. Is there anywhere to punch in at?
  if g.attendance_lat is null or g.attendance_lng is null then
    v_code := 'no_site';
    v_msg  := 'No attendance location has been set for this workshop yet.';

  -- 2. The device's own confession. Android flags every fix that came out
  --    of a mock location provider, which is what the entire Play Store
  --    shelf of "Fake GPS" apps registers itself as.
  elsif v_mocked then
    v_code := 'mocked';
    v_msg  := 'This device reported a simulated position. Attendance cannot '
              || 'be marked while a mock location app is active.';

  -- 3. A punch with no coordinates is not a punch.
  elsif v_lat is null or v_lng is null then
    v_code := 'no_fix';
    v_msg  := 'No position came with this punch.';

  else
    v_dist := public.geo_distance_m(v_lat, v_lng,
                g.attendance_lat, g.attendance_lng);

    -- 4. The phone's clock against ours. A device set forward or back can
    --    backdate a shift or replay a fix captured at the workshop hours
    --    ago, and `at` being server-stamped only closes half of that: the
    --    fix's own timestamp has to be recent too.
    if v_fix_at is not null then
      v_skew := abs(extract(epoch from (now() - v_fix_at)));
      if v_skew > 300 then
        v_code := 'clock_off';
        v_msg  := 'The position is stamped ' || round(v_skew / 60)
                  || ' minutes away from the server''s clock.';
      end if;
    end if;

    -- 5. A fix too vague to place anybody inside the radius. Checked
    --    server-side as well as on the phone because the phone is what we
    --    are checking.
    if v_code = 'ok' and (v_acc <= 0 or v_acc > g.attendance_max_accuracy_m)
    then
      v_code := 'inaccurate';
      v_msg  := 'The fix is only good to ' || round(v_acc::numeric, 1)
                || ' m, which cannot place you inside a '
                || trim(to_char(g.attendance_radius_m, 'FM9999990.9'))
                || ' m circle.';
    end if;

    -- 6. The distance that counts: ours, from the coordinates, against the
    --    radius on the garage row. The client's own figure is recorded but
    --    never used to decide anything.
    if v_code = 'ok' and v_dist > g.attendance_radius_m then
      v_code := 'too_far';
      v_msg  := 'You are ' || round(v_dist::numeric, 1)
                || ' m from the workshop. Attendance can be marked within '
                || trim(to_char(g.attendance_radius_m, 'FM9999990.9')) || ' m.';
    end if;

    -- 7. Physics, against this person's own last accepted punch.
    if v_code = 'ok' then
      select * into v_prev from public.attendance a
       where a.garage_id = gid and a.staff_id = v_staff and a.accepted
       order by a.at desc limit 1;

      if v_prev.id is not null and v_prev.lat is not null then
        v_secs  := extract(epoch from (now() - v_prev.at));
        v_moved := public.geo_distance_m(v_prev.lat, v_prev.lng, v_lat, v_lng);
        -- 60 m/s is about 216 km/h. Generous on purpose: somebody
        -- legitimately arriving off a highway bus must not be accused of
        -- anything.
        if v_secs > 0 and v_moved / v_secs > 60 then
          v_code := 'jumped';
          v_msg  := 'This device was ' || round((v_moved / 1000)::numeric, 1)
                    || ' km away ' || round((v_secs / 60)::numeric)
                    || ' minutes ago, too far to have travelled here since.';
        end if;
      end if;
    end if;

    -- 8. Does it follow the last one? Checked after the location tests so
    --    that somebody spoofing their way to a punch they could not make
    --    anyway is still recorded as having spoofed, rather than tidied
    --    away as a sequencing mistake.
    if v_code = 'ok' and v_prev.id is not null and v_prev.kind = v_kind then
      v_code := 'out_of_order';
      v_msg  := case v_kind
                  when 'in' then v_name || ' is already punched in.'
                  else v_name || ' is not punched in.'
                end;
    end if;
    if v_code = 'ok' and v_prev.id is null and v_kind = 'out' then
      v_code := 'out_of_order';
      v_msg  := v_name || ' has not punched in yet.';
    end if;
  end if;

  -- A device whose own arithmetic disagrees with ours is worth a line in
  -- the register even when the punch is fine: it is one of the few traces
  -- a tampered client leaves that does not depend on the client admitting
  -- anything.
  if v_dist is not null and abs(v_dist - v_claimed) > 25 then
    v_note := left(trim(both ' ' from v_note || ' · device reported '
              || round(v_claimed::numeric) || ' m, server measured '
              || round(v_dist::numeric) || ' m'), 500);
  end if;

  insert into public.attendance (
    id, garage_id, staff_id, staff_name, actor_id, kind, at,
    lat, lng, accuracy_m, distance_m, mocked, accepted, block, note)
  values (
    -- Minted here, not by the client. An id the phone chose would let a
    -- retry overwrite the refusal it got the first time.
    'at-' || replace(gen_random_uuid()::text, '-', ''),
    gid, v_staff, v_name, auth.uid(), v_kind, now(),
    v_lat, v_lng, round(v_acc::numeric, 2),
    round(coalesce(v_dist, 0)::numeric, 2),
    v_mocked, v_code = 'ok', v_code, v_note)
  returning * into v_row;

  return jsonb_build_object(
    'code', v_code,
    'message', v_msg,
    'row', to_jsonb(v_row) - 'garage_id' - 'actor_id' - 'created_at');
end $fn$;

-- ---------------------------------------------------------------------
-- 5. Reading the register
-- ---------------------------------------------------------------------

create or replace function public.attendance_log(gid uuid, since timestamptz)
returns jsonb language sql stable security definer
set search_path = public as $fn$
  select case when not public.is_garage_member(gid) then null else
    coalesce((
      select jsonb_agg(to_jsonb(a) - 'garage_id' - 'actor_id' - 'created_at'
                       order by a.at desc)
      from public.attendance a
      where a.garage_id = gid and a.at >= since), '[]'::jsonb)
  end;
$fn$;

-- ---------------------------------------------------------------------
-- 6. Row level security
-- ---------------------------------------------------------------------
-- One policy, for select, and that is the design. The absence of an insert
-- policy is what forces every write through `punch_attendance`, and the
-- absence of update and delete is what stops a register being tidied up
-- after the fact — by the owner as much as by anybody else.

alter table public.attendance enable row level security;

drop policy if exists attendance_member_read on public.attendance;
create policy attendance_member_read on public.attendance
  for select to authenticated
  using (public.is_garage_member(garage_id));

revoke all on public.attendance from anon;
revoke insert, update, delete on public.attendance from authenticated;

revoke all on function public.punch_attendance(jsonb)          from public;
revoke all on function public.attendance_log(uuid, timestamptz) from public;
grant execute on function public.punch_attendance(jsonb)          to authenticated;
grant execute on function public.attendance_log(uuid, timestamptz) to authenticated;
grant execute on function public.geo_distance_m(
  double precision, double precision, double precision, double precision)
  to authenticated;

-- ---------------------------------------------------------------------
-- 7. Realtime
-- ---------------------------------------------------------------------
-- So a punch on the floor shows up on the owner's console without a
-- refresh. Replica identity full for the same reason as every other table
-- here: a delete otherwise carries only the primary key, and the console
-- needs the garage_id to know whether it was theirs.

do $blk$
begin
  begin
    alter publication supabase_realtime add table public.attendance;
  exception when duplicate_object then null;
  end;
  alter table public.attendance replica identity full;
end $blk$;


-- ###  BEGIN 06_notifications.sql

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


-- ###  BEGIN 07_share.sql

-- =====================================================================
-- GaragePro — the public job card link
-- =====================================================================
-- Run AFTER 03_sync.sql. Additive and idempotent: it can be run again on
-- a live project without losing anything.
--
-- Everything in this product so far assumes the customer signs in. That
-- is the right shape for the customer who wants their whole history, and
-- the wrong shape for the one standing at the counter who will never
-- install anything. Until now the workshop's WhatsApp message to that
-- person was plain text — "your car is due for service" — with nowhere
-- to tap.
--
-- This file gives that message somewhere to point:
--
--   * every job card gets an unguessable `share_token`, minted by the
--     database on insert, never chosen by a client,
--   * `shared_card(token)` reads one card back for an anonymous caller,
--     and only ever the one card that token names, and
--   * the payload is a deliberate subset. The customer sees what is on
--     their bill. Nothing tells them what the workshop paid for the part.
--
-- Note what is NOT here: no policy on any table is loosened, and `anon`
-- is granted nothing except the right to call one function. A token is a
-- key to a single row, not a login, and it carries no session.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. The token
-- ---------------------------------------------------------------------
-- 24 bytes of gen_random_bytes, base64url. That is 192 bits: it cannot
-- be guessed, and it survives being pasted through WhatsApp, which eats
-- '+' and '/' in URLs.

create or replace function public.mint_share_token()
returns text language sql volatile as $fn$
  select translate(encode(gen_random_bytes(24), 'base64'), '+/=', '-_');
$fn$;

alter table public.job_cards
  add column if not exists share_token text;

-- Backfill the cards that existed before this file ran, then make the
-- column total. Done in this order so a live project does not trip the
-- not-null on rows it already has.
update public.job_cards
   set share_token = public.mint_share_token()
 where share_token is null;

alter table public.job_cards
  alter column share_token set default public.mint_share_token();

do $$ begin
  alter table public.job_cards alter column share_token set not null;
exception when others then null; end $$;

create unique index if not exists job_cards_share_token_idx
  on public.job_cards (share_token);

-- A client that sends its own token — or tries to overwrite one to match
-- a card it does not own — is ignored. The column is the database's.
--
-- The one legitimate way to change it is `rotate_share_token` below, which
-- announces itself with a session setting. A client cannot forge that: it
-- is set inside a SECURITY DEFINER function that has already checked
-- membership, and `set_config(..., true)` scopes it to that transaction.
create or replace function public.guard_share_token()
returns trigger language plpgsql as $fn$
begin
  if tg_op = 'INSERT' then
    new.share_token := public.mint_share_token();
  elsif coalesce(current_setting('garagepro.rotating', true), '') <> 'on' then
    new.share_token := old.share_token;
  end if;
  return new;
end $fn$;

drop trigger if exists job_cards_share_token on public.job_cards;
create trigger job_cards_share_token
  before insert or update on public.job_cards
  for each row execute function public.guard_share_token();

-- ---------------------------------------------------------------------
-- 2. Reading one card without signing in
-- ---------------------------------------------------------------------
-- SECURITY DEFINER, so it sees past row level security — which is the
-- whole point, since the caller is nobody. The safety is that the only
-- way in is a token, the only way out is one card, and the select list
-- below is the entire contract.
--
-- Deliberately absent: mechanic_ids, work_note, voices, dents, photos,
-- the internal remark on a line, and anything from `masters`. Those are
-- the workshop's working notes, not the customer's bill.

create or replace function public.shared_card(tok text)
returns jsonb language sql stable security definer
set search_path = public as $fn$
  select jsonb_build_object(
    'number',        j.number,
    'status',        j.status,
    'created_at',    j.created_at,
    'completed_at',  j.completed_at,
    'promised_at',   j.promised_at,
    'odometer_km',   j.odometer_km,
    'next_service_at', j.next_service_at,
    'next_service_km', j.next_service_km,
    'discount',      j.discount,
    'tax_rate',      j.tax_rate,
    'garage', jsonb_build_object(
      'name',    g.name,
      'phone',   g.phone,
      'address', nullif(trim(both ', ' from concat_ws(', ',
                   nullif(g.address_line, ''), nullif(g.city, ''),
                   nullif(g.state, ''), nullif(g.pin, ''))), ''),
      'gstin',   nullif(g.gstin, ''),
      'upi_id',  nullif(g.upi_id, ''),
      'terms',   nullif(g.terms, '')
    ),
    'customer', jsonb_build_object('name', c.name),
    'vehicle', jsonb_build_object(
      'reg_no', v.reg_no, 'brand', v.brand,
      'model',  v.model,  'variant', v.variant
    ),
    'items', coalesce((
      select jsonb_agg(jsonb_build_object(
               'kind', li.kind, 'name', li.name, 'part_no', li.part_no,
               'qty',  li.qty,  'rate', li.rate, 'state',   li.state)
               order by li.position)
        from public.line_items li
       where li.job_card_id = j.id
         and li.state <> 'skipped'
    ), '[]'::jsonb),
    'paid', coalesce((
      select sum(p.amount) from public.payments p where p.job_card_id = j.id
    ), 0)
  )
  from public.job_cards j
  join public.garages         g on g.id = j.garage_id
  join public.garage_customers c on c.id = j.customer_id
  join public.garage_vehicles  v on v.id = j.vehicle_id
  where j.share_token = tok
    and length(tok) >= 20;   -- a short token is a probe, not a customer
$fn$;

-- The one grant. `anon` may call this and nothing else new.
revoke all on function public.shared_card(text) from public;
grant execute on function public.shared_card(text) to anon, authenticated;

revoke all on function public.mint_share_token() from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 2b. The console asking for a card's link
-- ---------------------------------------------------------------------
-- `job_card_json` builds its object field by field and does not carry the
-- token — deliberately. It is the payload behind every job card the
-- console holds in memory, and a token that rides along in all of them is
-- a token in every log line and crash report the app ever produces.
--
-- So the console asks for it at the moment the counter presses Share. One
-- extra round trip, on a deliberate human action, in exchange for the
-- token existing in the app only while it is being used.

create or replace function public.card_share_token(card text)
returns text language plpgsql stable security definer
set search_path = public as $fn$
declare gid uuid; tok text;
begin
  select garage_id, share_token into gid, tok
    from public.job_cards where id = card;
  if gid is null then
    return null;
  end if;
  if not public.is_garage_member(gid) then
    raise exception 'not a member of this garage';
  end if;
  return tok;
end $fn$;

revoke all on function public.card_share_token(text) from public;
grant execute on function public.card_share_token(text) to authenticated;

-- ---------------------------------------------------------------------
-- 3. Rotating a link
-- ---------------------------------------------------------------------
-- A link that went to the wrong number, or into a group chat. The garage
-- burns it and the old URL stops resolving immediately.

create or replace function public.rotate_share_token(card text)
returns text language plpgsql security definer
set search_path = public as $fn$
declare gid uuid; made text;
begin
  select garage_id into gid from public.job_cards where id = card;
  if gid is null then
    raise exception 'no such job card';
  end if;
  if not public.is_garage_member(gid) then
    raise exception 'not a member of this garage';
  end if;

  made := public.mint_share_token();

  -- The guard trigger pins share_token on update, so tell it this update
  -- is the sanctioned one. Disabling the trigger instead would take an
  -- ACCESS EXCLUSIVE lock on job_cards — every console in the workshop
  -- would stall on the counter rotating one link.
  --
  -- `true` makes the setting local to this transaction, so it is gone
  -- before the next statement on this connection, pooled or not.
  perform set_config('garagepro.rotating', 'on', true);
  update public.job_cards set share_token = made where id = card;
  perform set_config('garagepro.rotating', 'off', true);

  return made;
end $fn$;

revoke all on function public.rotate_share_token(text) from public;
grant execute on function public.rotate_share_token(text) to authenticated;


-- ###  BEGIN 08_platform.sql

-- =====================================================================
-- GaragePro — the garage directory, real coordinates, and the platform
-- admin who runs the register
-- =====================================================================
-- Run AFTER 05_attendance.sql (it reuses `geo_distance_m` from that file)
-- and 07_share.sql. Additive and idempotent.
--
-- Two things change shape here.
--
-- 1. A customer could previously only see a garage they had already dealt
--    with — `garages_customer_read` says so in as many words: "Not a
--    directory of every workshop." That was right while the app served
--    one workshop. It is wrong now that a customer is meant to find the
--    nearest one.
--
--    The policy is left exactly as it was. Widening it would expose every
--    column of every garage, including the UPI id and the plan expiry, to
--    anyone with an account. Instead the directory is one function that
--    returns a fixed, public subset and nothing else. What a table does
--    not hand out cannot leak from it.
--
-- 2. Every role until now lived inside one garage. Running a register of
--    partners is the first job that has to see across all of them, so
--    there is now exactly one role that can: `platform`.
--
-- On distance: garages store a real latitude and longitude. A PIN code is
-- kept for searching by text and for the partner who has not dropped a pin
-- yet, but it is never the thing distance is measured from — a PIN in this
-- country can span twenty kilometres, which would put a garage across the
-- city inside a "within 1 km" result.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Where a garage actually is
-- ---------------------------------------------------------------------
-- `address_line`, `city`, `state` and `pin` already exist on the table.
-- These are the two that make a distance search honest, plus the flags
-- that decide whether the register lists the garage at all.

alter table public.garages
  add column if not exists lat        double precision,
  add column if not exists lng        double precision,
  add column if not exists located_at timestamptz,
  -- Off by default: a garage joins the customer-facing directory when the
  -- platform admin puts it there, never by signing up. An empty register
  -- is a better first day than one full of unchecked workshops.
  add column if not exists listed     boolean not null default false,
  add column if not exists verified   boolean not null default false,
  -- What the platform takes on work booked through the directory. Null
  -- means "use the platform default" rather than "nothing".
  add column if not exists commission_pct numeric(5,2);

-- A coordinate that is not on Earth is a typo, and a (0,0) is the Gulf of
-- Guinea — which is what an uninitialised pair of doubles looks like.
do $$ begin
  alter table public.garages add constraint garages_latlng_sane check (
    (lat is null and lng is null) or (
      lat between -90 and 90 and lng between -180 and 180
      and not (lat = 0 and lng = 0)
    )
  );
exception when duplicate_object then null; end $$;

-- Only a listed garage with a real pin can be found, so that is the index.
create index if not exists garages_directory_idx
  on public.garages (listed, lat, lng) where listed and lat is not null;
create index if not exists garages_pin_idx on public.garages (pin);

-- ---------------------------------------------------------------------
-- 2. The platform admin
-- ---------------------------------------------------------------------
-- One role, above every garage. It is granted by hand in the SQL editor
-- (section 6) and by nothing in either app — there is no screen anywhere
-- that promotes somebody to it, on purpose.

-- Widen the constraint rather than replacing it blind. Dropping first and
-- swallowing a failure on the re-add would leave the table with no check
-- at all — the drop having succeeded — which is worse than the constraint
-- this file is trying to widen. So: drop, add, and let a failure raise.
-- The only way the add can fail is a row holding a role none of these
-- four names, and that is something to see, not to bury.
alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles add constraint profiles_role_check
  check (role in ('customer', 'owner', 'staff', 'platform'));

create or replace function public.is_platform_admin()
returns boolean language sql stable security definer
set search_path = public as $fn$
  select exists (
    select 1 from public.profiles
     where id = auth.uid() and role = 'platform'
  );
$fn$;

grant execute on function public.is_platform_admin() to authenticated;

-- The register: every garage, for the one role that runs it. Added
-- alongside the existing policies, which are untouched — a garage member
-- still reaches their own garage by `garages_member_all`, exactly as
-- before, whether or not this policy exists.
drop policy if exists garages_platform_all on public.garages;
create policy garages_platform_all on public.garages
  for all to authenticated
  using (public.is_platform_admin())
  with check (public.is_platform_admin());

drop policy if exists garage_members_platform on public.garage_members;
create policy garage_members_platform on public.garage_members
  for select to authenticated using (public.is_platform_admin());

drop policy if exists profiles_platform_read on public.profiles;
create policy profiles_platform_read on public.profiles
  for select to authenticated using (public.is_platform_admin());

-- ---------------------------------------------------------------------
-- 3. Finding a garage
-- ---------------------------------------------------------------------
-- The customer's phone sends where it is; the database does the sorting,
-- because the alternative is shipping every garage in the country to a
-- phone so it can measure them itself.
--
-- `radius_km => null` means no limit, which is what the screen asks for
-- before the customer has picked one of the 1 / 5 / 10 chips.
--
-- Called with a null lat/lng — the customer refused location and typed a
-- PIN instead — it falls back to matching the text and returns rows with
-- a null distance. The screen shows those without a "x km away".

create or replace function public.nearby_garages(
  in_lat    double precision default null,
  in_lng    double precision default null,
  radius_km double precision default null,
  q         text             default null,
  max_rows  int              default 60)
returns jsonb language sql stable security definer
set search_path = public as $fn$
  with hits as (
    select
      g.id, g.name, g.phone, g.address_line, g.city, g.state, g.pin,
      g.lat, g.lng, g.logo_path, g.verified,
      public.geo_distance_m(in_lat, in_lng, g.lat, g.lng) / 1000.0 as km
    from public.garages g
    where g.listed
      -- A text search matches the name or the place. Plain ILIKE: the
      -- index above does not serve it, but the register is thousands of
      -- rows, not millions, and this keeps the file free of pg_trgm.
      and (
        q is null or q = '' or
        g.name ilike '%' || q || '%' or
        g.city ilike '%' || q || '%' or
        g.address_line ilike '%' || q || '%' or
        g.pin = q
      )
  )
  select coalesce(jsonb_agg(to_jsonb(h) order by h.km nulls last, h.name),
                  '[]'::jsonb)
    from (
      select * from hits
       -- Nearest first. A garage with no coordinate sorts last rather than
       -- vanishing, so a workshop that has not dropped its pin is still
       -- reachable by name — but a radius filter does exclude it, because
       -- "within 1 km" cannot honestly include a garage of unknown place.
       where radius_km is null or (km is not null and km <= radius_km)
       order by km nulls last, name
       limit greatest(1, least(coalesce(max_rows, 60), 200))
    ) h;
$fn$;

revoke all on function public.nearby_garages(
  double precision, double precision, double precision, text, int) from public;
grant execute on function public.nearby_garages(
  double precision, double precision, double precision, text, int)
  to anon, authenticated;

-- One garage's public page, for the customer who tapped a result and has
-- not booked yet — so `deals_with_garage` is still false for them.
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
  where g.id = gid and g.listed;
$fn$;

revoke all on function public.garage_card(uuid) from public;
grant execute on function public.garage_card(uuid) to anon, authenticated;

-- ---------------------------------------------------------------------
-- 4. A partner moving their own pin
-- ---------------------------------------------------------------------
-- From the console's profile screen. A partner may set where they are and
-- what their address says; they may not list themselves in the directory,
-- verify themselves, or set their own commission. Those three are the
-- platform's, and the update below simply never reads them from the
-- payload — so a hand-rolled request carrying `listed: true` changes
-- nothing.

create or replace function public.set_garage_location(payload jsonb)
returns jsonb language plpgsql security definer
set search_path = public as $fn$
declare
  gid uuid := (payload ->> 'garage_id')::uuid;
  la  double precision := nullif(payload ->> 'lat', '')::double precision;
  lo  double precision := nullif(payload ->> 'lng', '')::double precision;
  g   public.garages;
begin
  if gid is null then
    raise exception 'garage_id is required';
  end if;
  if not (public.is_garage_member(gid) or public.is_platform_admin()) then
    raise exception 'not a member of this garage';
  end if;
  if la is not null and (la < -90 or la > 90 or lo is null
                         or lo < -180 or lo > 180) then
    raise exception 'coordinates out of range';
  end if;

  update public.garages set
    address_line = coalesce(payload ->> 'address_line', address_line),
    city         = coalesce(payload ->> 'city',  city),
    state        = coalesce(payload ->> 'state', state),
    pin          = coalesce(payload ->> 'pin',   pin),
    lat          = coalesce(la, lat),
    lng          = coalesce(lo, lng),
    located_at   = case when la is not null then now() else located_at end
   where id = gid
   returning * into g;

  return to_jsonb(g);
end $fn$;

revoke all on function public.set_garage_location(jsonb) from public;
grant execute on function public.set_garage_location(jsonb) to authenticated;

-- ---------------------------------------------------------------------
-- 5. The register, for the platform admin
-- ---------------------------------------------------------------------
-- Listing, verifying and the commission rate — the three a garage cannot
-- set for itself.

create or replace function public.set_garage_listing(payload jsonb)
returns jsonb language plpgsql security definer
set search_path = public as $fn$
declare gid uuid := (payload ->> 'garage_id')::uuid; g public.garages;
begin
  if not public.is_platform_admin() then
    raise exception 'not a platform admin';
  end if;

  update public.garages set
    listed         = coalesce((payload ->> 'listed')::boolean, listed),
    verified       = coalesce((payload ->> 'verified')::boolean, verified),
    commission_pct = coalesce(
                       nullif(payload ->> 'commission_pct', '')::numeric,
                       commission_pct)
   where id = gid
   returning * into g;

  if g.id is null then
    raise exception 'no such garage';
  end if;
  return to_jsonb(g);
end $fn$;

revoke all on function public.set_garage_listing(jsonb) from public;
grant execute on function public.set_garage_listing(jsonb) to authenticated;

-- Every garage with the numbers the register is judged on. Platform only,
-- and it returns an empty list rather than raising for anybody else, so a
-- console that calls it without the role simply shows nothing.
create or replace function public.platform_garages()
returns jsonb language sql stable security definer
set search_path = public as $fn$
  select case when not public.is_platform_admin() then '[]'::jsonb else
    coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', g.id, 'name', g.name, 'phone', g.phone, 'email', g.email,
        'city', g.city, 'state', g.state, 'pin', g.pin,
        'lat', g.lat, 'lng', g.lng, 'located_at', g.located_at,
        'listed', g.listed, 'verified', g.verified,
        'commission_pct', g.commission_pct,
        'plan_expiry', g.plan_expiry, 'created_at', g.created_at,
        'owner', (select p.name from public.profiles p where p.id = g.owner_id),
        'members', (select count(*) from public.garage_members m
                     where m.garage_id = g.id),
        'cards',   (select count(*) from public.job_cards j
                     where j.garage_id = g.id))
      order by g.created_at desc)
      from public.garages g
    ), '[]'::jsonb)
  end;
$fn$;

revoke all on function public.platform_garages() from public;
grant execute on function public.platform_garages() to authenticated;

-- ---------------------------------------------------------------------
-- 6. Making the first platform admin
-- ---------------------------------------------------------------------
-- There is deliberately no screen for this. Run it once in the Supabase
-- SQL editor, with the email of the account that runs the register:
--
--   update public.profiles set role = 'platform'
--    where id = (select id from auth.users where email = 'you@example.com');
--
-- To check it took:
--   select id, name, role from public.profiles where role = 'platform';
-- =====================================================================


-- ###  BEGIN 09_marketplace.sql

-- =====================================================================
-- GaragePro — parts wanted, parts for sale, what the platform earns, and
-- the video a new customer sees
-- =====================================================================
-- Run AFTER 08_platform.sql. Additive and idempotent. It adds four things
-- that did not exist before and changes nothing that did.
--
-- The shape of every table here follows the two rules the rest of the
-- schema already keeps:
--
--   * a row belongs to somebody, and the policy says who in one line, and
--   * money the workshop should not see is not on a row the workshop can
--     read. Commission is the platform's business with the partner; the
--     customer never sees it and is never charged it.
--
-- On ids: text primary keys minted by the client, like `job_cards` and
-- `line_items`, so a phone can create a row offline and sync it later
-- without a round trip for an id it already has.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. "I need this part"
-- ---------------------------------------------------------------------
-- A customer describes what they are after; the platform quotes it back
-- by hand, through the code. The code is what the customer reads out on
-- the phone, so it is short and unambiguous — no O/0, no I/1.

create table if not exists public.part_requests (
  id          text primary key,
  user_id     uuid not null references auth.users (id) on delete cascade,
  -- Which car it is for. Kept as loose text as well as an optional link,
  -- because somebody asks for a part for a car that is not in the app.
  vehicle_id  text,
  vehicle_text text not null default '',
  part_name   text not null default '',
  detail      text not null default '',
  photos      text[] not null default '{}',
  -- The quotable code. Assigned by the database on insert, never chosen.
  code        text not null unique,
  status      text not null default 'pending'
                check (status in ('pending', 'processing', 'completed',
                                  'cancelled')),
  -- The platform's working notes and the number it quoted back. The
  -- customer reads `quote` and `note`; `status` is what drives their screen.
  quote       numeric(12,2),
  note        text not null default '',
  -- Which partner, if any, the platform handed it to.
  garage_id   uuid references public.garages (id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists part_requests_user_idx
  on public.part_requests (user_id, created_at desc);
create index if not exists part_requests_status_idx
  on public.part_requests (status, created_at desc);
create index if not exists part_requests_garage_idx
  on public.part_requests (garage_id, created_at desc);

-- Crockford-ish alphabet: the ten digits and the letters that cannot be
-- misheard or mistyped for one of them.
create or replace function public.mint_request_code()
returns text language plpgsql volatile
set search_path = public as $fn$
declare
  alphabet constant text := '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  made text;
  i    int;
begin
  for attempt in 1 .. 12 loop
    made := 'R';
    for i in 1 .. 6 loop
      made := made || substr(alphabet,
                1 + floor(random() * length(alphabet))::int, 1);
    end loop;
    exit when not exists (
      select 1 from public.part_requests where code = made);
    made := null;
  end loop;
  if made is null then
    raise exception 'could not mint a free request code';
  end if;
  return made;
end $fn$;

-- The code and the owner are the database's, not the client's. A phone
-- that posts `user_id` of somebody else, or picks its own code, is
-- overruled here rather than rejected — there is nothing to negotiate.
create or replace function public.guard_part_request()
returns trigger language plpgsql
set search_path = public as $fn$
begin
  if tg_op = 'INSERT' then
    new.user_id := coalesce(auth.uid(), new.user_id);
    new.code    := public.mint_request_code();
    new.status  := 'pending';
    new.quote   := null;
    new.note    := '';
    new.garage_id := null;
  else
    new.user_id := old.user_id;
    new.code    := old.code;
    -- Only the platform moves a request along or prices it. A customer
    -- editing their own row keeps whatever the platform last set.
    if not public.is_platform_admin() then
      new.status    := old.status;
      new.quote     := old.quote;
      new.note      := old.note;
      new.garage_id := old.garage_id;
    end if;
    new.updated_at := now();
  end if;
  return new;
end $fn$;

drop trigger if exists part_requests_guard on public.part_requests;
create trigger part_requests_guard
  before insert or update on public.part_requests
  for each row execute function public.guard_part_request();

alter table public.part_requests enable row level security;

drop policy if exists part_requests_own on public.part_requests;
create policy part_requests_own on public.part_requests
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists part_requests_platform on public.part_requests;
create policy part_requests_platform on public.part_requests
  for all to authenticated
  using (public.is_platform_admin())
  with check (public.is_platform_admin());

-- The partner the platform handed it to may read it, and nothing else in
-- the queue. This is the Partner A / Partner B line for this table.
drop policy if exists part_requests_assigned on public.part_requests;
create policy part_requests_assigned on public.part_requests
  for select to authenticated
  using (garage_id is not null and public.is_garage_member(garage_id));

-- ---------------------------------------------------------------------
-- 2. Parts for sale
-- ---------------------------------------------------------------------
-- The other direction: somebody has a part to move. A listing is private
-- until the platform approves it, so the browse screen can never show a
-- listing nobody has looked at.

create table if not exists public.part_listings (
  id          text primary key,
  user_id     uuid not null references auth.users (id) on delete cascade,
  -- Set when a partner lists from the console rather than a customer from
  -- the app. It is what the commission on a sale is booked against.
  garage_id   uuid references public.garages (id) on delete set null,
  vehicle_id  text,
  vehicle_text text not null default '',
  title       text not null default '',
  detail      text not null default '',
  part_no     text not null default '',
  condition   text not null default 'used'
                check (condition in ('new', 'used', 'refurbished')),
  price       numeric(12,2) not null default 0,
  photos      text[] not null default '{}',
  city        text not null default '',
  pin         text not null default '',
  status      text not null default 'pending'
                check (status in ('pending', 'approved', 'rejected',
                                  'sold', 'withdrawn')),
  reject_note text not null default '',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists part_listings_user_idx
  on public.part_listings (user_id, created_at desc);
create index if not exists part_listings_browse_idx
  on public.part_listings (status, created_at desc) where status = 'approved';
create index if not exists part_listings_garage_idx
  on public.part_listings (garage_id, created_at desc);

-- A seller may withdraw or mark sold. Approving and rejecting are the
-- platform's, and an edit to a live listing sends it back for review —
-- otherwise an approved listing could be rewritten into anything.
create or replace function public.guard_part_listing()
returns trigger language plpgsql
set search_path = public as $fn$
begin
  if tg_op = 'INSERT' then
    new.user_id := coalesce(auth.uid(), new.user_id);
    new.status  := 'pending';
    new.reject_note := '';
    return new;
  end if;

  new.user_id := old.user_id;
  new.updated_at := now();

  if public.is_platform_admin() then
    return new;
  end if;

  new.reject_note := old.reject_note;

  -- The two moves a seller may make on their own listing.
  if new.status not in ('sold', 'withdrawn') then
    if old.status = 'approved' and (
         new.title <> old.title or new.detail <> old.detail
         or new.price <> old.price or new.part_no <> old.part_no
         or new.condition <> old.condition or new.photos <> old.photos) then
      new.status := 'pending';
    else
      new.status := old.status;
    end if;
  end if;
  return new;
end $fn$;

drop trigger if exists part_listings_guard on public.part_listings;
create trigger part_listings_guard
  before insert or update on public.part_listings
  for each row execute function public.guard_part_listing();

alter table public.part_listings enable row level security;

drop policy if exists part_listings_own on public.part_listings;
create policy part_listings_own on public.part_listings
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists part_listings_platform on public.part_listings;
create policy part_listings_platform on public.part_listings
  for all to authenticated
  using (public.is_platform_admin())
  with check (public.is_platform_admin());

-- Everybody signed in browses what has been approved. Reading a listing
-- deliberately does not reveal who posted it — the contact route is the
-- platform, not a phone number sitting in a public row.
drop policy if exists part_listings_browse on public.part_listings;
create policy part_listings_browse on public.part_listings
  for select to authenticated using (status = 'approved');

-- What the browse screen may see. `user_id` is not in it.
create or replace function public.browse_listings(
  q text default null, max_rows int default 60)
returns jsonb language sql stable security definer
set search_path = public as $fn$
  select coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', l.id, 'title', l.title, 'detail', l.detail,
             'part_no', l.part_no, 'condition', l.condition,
             'price', l.price, 'photos', l.photos,
             'vehicle_text', l.vehicle_text,
             'city', l.city, 'pin', l.pin, 'created_at', l.created_at)
           order by l.created_at desc)
      from (
        select * from public.part_listings
         where status = 'approved'
           and (q is null or q = ''
                or title ilike '%' || q || '%'
                or detail ilike '%' || q || '%'
                or part_no ilike '%' || q || '%'
                or vehicle_text ilike '%' || q || '%')
         order by created_at desc
         limit greatest(1, least(coalesce(max_rows, 60), 200))
      ) l
  ), '[]'::jsonb);
$fn$;

revoke all on function public.browse_listings(text, int) from public;
grant execute on function public.browse_listings(text, int) to authenticated;

-- ---------------------------------------------------------------------
-- 3. Commission
-- ---------------------------------------------------------------------
-- A ledger the platform keeps about a partner. Nobody is charged by it —
-- settlement is a later decision, and this file deliberately stops at
-- recording what would be owed.
--
-- The rate resolves in three steps: whatever is written on the row, else
-- the garage's own `commission_pct`, else the platform default.

create table if not exists public.platform_settings (
  id             int primary key default 1 check (id = 1),
  commission_pct numeric(5,2) not null default 1.00,
  intro_video_url text not null default '',
  intro_video_on  boolean not null default false,
  updated_at     timestamptz not null default now()
);
insert into public.platform_settings (id) values (1) on conflict do nothing;

alter table public.platform_settings enable row level security;

-- Everybody signed in reads the settings — the customer app needs the
-- video out of it. Only the platform writes.
drop policy if exists platform_settings_read on public.platform_settings;
create policy platform_settings_read on public.platform_settings
  for select to authenticated using (true);

drop policy if exists platform_settings_write on public.platform_settings;
create policy platform_settings_write on public.platform_settings
  for all to authenticated
  using (public.is_platform_admin())
  with check (public.is_platform_admin());

create table if not exists public.commissions (
  id          text primary key,
  garage_id   uuid not null references public.garages (id) on delete cascade,
  -- What it was earned on. Exactly one of these is set in practice, but
  -- neither is required — the platform can book a manual line.
  job_card_id text references public.job_cards (id) on delete set null,
  listing_id  text references public.part_listings (id) on delete set null,
  amount      numeric(12,2) not null default 0,   -- the transaction
  pct         numeric(5,2)  not null default 1.00,
  fee         numeric(12,2) not null default 0,   -- amount * pct / 100
  status      text not null default 'accrued'
                check (status in ('accrued', 'invoiced', 'settled',
                                  'waived')),
  note        text not null default '',
  at          timestamptz not null default now()
);
create index if not exists commissions_garage_idx
  on public.commissions (garage_id, at desc);
create index if not exists commissions_status_idx
  on public.commissions (status, at desc);
create unique index if not exists commissions_card_once
  on public.commissions (job_card_id) where job_card_id is not null;

alter table public.commissions enable row level security;

-- The platform writes the ledger. A partner reads their own lines and
-- nothing of anybody else's — which is the Partner A / Partner B line
-- for this table, enforced here rather than in the console.
drop policy if exists commissions_platform on public.commissions;
create policy commissions_platform on public.commissions
  for all to authenticated
  using (public.is_platform_admin())
  with check (public.is_platform_admin());

drop policy if exists commissions_own on public.commissions;
create policy commissions_own on public.commissions
  for select to authenticated using (public.is_garage_member(garage_id));

create or replace function public.commission_rate(gid uuid)
returns numeric language sql stable
set search_path = public as $fn$
  select coalesce(
    (select commission_pct from public.garages where id = gid),
    (select commission_pct from public.platform_settings where id = 1),
    1.00);
$fn$;

-- Booking a line. `security definer` so the platform can write against a
-- garage it is not a member of, which is every garage.
create or replace function public.book_commission(payload jsonb)
returns jsonb language plpgsql security definer
set search_path = public as $fn$
declare
  gid uuid    := (payload ->> 'garage_id')::uuid;
  amt numeric := coalesce((payload ->> 'amount')::numeric, 0);
  rate numeric;
  row public.commissions;
begin
  if not public.is_platform_admin() then
    raise exception 'not a platform admin';
  end if;
  if gid is null then
    raise exception 'garage_id is required';
  end if;

  rate := coalesce(nullif(payload ->> 'pct', '')::numeric,
                   public.commission_rate(gid));

  insert into public.commissions (
    id, garage_id, job_card_id, listing_id, amount, pct, fee, note)
  values (
    coalesce(nullif(payload ->> 'id', ''),
             encode(gen_random_bytes(12), 'hex')),
    gid,
    nullif(payload ->> 'job_card_id', ''),
    nullif(payload ->> 'listing_id', ''),
    amt,
    rate,
    round(amt * rate / 100.0, 2),
    coalesce(payload ->> 'note', ''))
  -- One line per job card. Booking the same card twice updates the first
  -- rather than doubling what the partner appears to owe.
  on conflict (job_card_id) where job_card_id is not null
  do update set amount = excluded.amount,
                pct    = excluded.pct,
                fee    = excluded.fee,
                note   = excluded.note
  returning * into row;

  return to_jsonb(row);
end $fn$;

revoke all on function public.book_commission(jsonb) from public;
grant execute on function public.book_commission(jsonb) to authenticated;

-- ---------------------------------------------------------------------
-- 3b. Where the photos go
-- ---------------------------------------------------------------------
-- One public bucket for the pictures on a part request and a part listing.
--
-- Public for reads, because a listing is meant to be browsed and a signed
-- URL per thumbnail would be a round trip per tile. Writes are another
-- matter: a person may only write inside a folder named after their own
-- user id, which is what stops one account overwriting another's photos.
--
-- Paths are therefore `<uid>/<listing-or-request-id>/<file>`, and the
-- policies below read that first segment.

insert into storage.buckets (id, name, public, file_size_limit,
                             allowed_mime_types)
values ('marketplace', 'marketplace', true, 5242880,
        array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set
  public             = true,
  file_size_limit    = 5242880,
  allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp'];

drop policy if exists marketplace_read on storage.objects;
create policy marketplace_read on storage.objects
  for select to anon, authenticated
  using (bucket_id = 'marketplace');

drop policy if exists marketplace_write on storage.objects;
create policy marketplace_write on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'marketplace'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Replacing and removing your own photo, and nobody else's. The platform
-- admin can remove any of them, because taking down a listing has to take
-- down what was pictured on it.
drop policy if exists marketplace_update on storage.objects;
create policy marketplace_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'marketplace'
    and ((storage.foldername(name))[1] = auth.uid()::text
         or public.is_platform_admin())
  );

drop policy if exists marketplace_delete on storage.objects;
create policy marketplace_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'marketplace'
    and ((storage.foldername(name))[1] = auth.uid()::text
         or public.is_platform_admin())
  );

-- ---------------------------------------------------------------------
-- 4. The first-run video
-- ---------------------------------------------------------------------
-- The URL lives in `platform_settings` above, so the admin can change or
-- clear it without a release. `intro_video_on` false is the off switch —
-- clearing the URL would work too, but then the old one is lost.
--
-- Whether a given customer has already watched it is their own row, not a
-- setting, because the answer differs per person and must survive a
-- reinstall.

alter table public.profiles
  add column if not exists intro_seen_at timestamptz;

create or replace function public.mark_intro_seen()
returns void language sql volatile security definer
set search_path = public as $fn$
  update public.profiles set intro_seen_at = now()
   where id = auth.uid() and intro_seen_at is null;
$fn$;

revoke all on function public.mark_intro_seen() from public;
grant execute on function public.mark_intro_seen() to authenticated;

-- What the app asks on launch: is there a video, and should this person
-- see it? One call rather than a settings read plus a profile read.
create or replace function public.intro_video()
returns jsonb language sql stable security definer
set search_path = public as $fn$
  select jsonb_build_object(
    'url',  s.intro_video_url,
    'show', s.intro_video_on
            and s.intro_video_url <> ''
            and (select p.intro_seen_at is null
                   from public.profiles p where p.id = auth.uid()))
  from public.platform_settings s where s.id = 1;
$fn$;

revoke all on function public.intro_video() from public;
grant execute on function public.intro_video() to authenticated;

-- ---------------------------------------------------------------------
-- 5. Live sync
-- ---------------------------------------------------------------------
-- The same treatment 03_sync.sql gives the tables both apps watch, so a
-- request moving to `processing` reaches the customer's screen without a
-- pull-to-refresh.

do $$
declare t text;
begin
  foreach t in array array['part_requests', 'part_listings', 'commissions']
  loop
    begin
      execute format(
        'alter publication supabase_realtime add table public.%I', t);
    exception when duplicate_object then null;
             when undefined_object  then null;
    end;
  end loop;
end $$;


-- ###  BEGIN 10_open_booking.sql

-- =====================================================================
-- GaragePro — booking without a code
-- =====================================================================
-- Run AFTER 09_marketplace.sql. Additive and idempotent.
--
-- `03_sync.sql` closed a real hole. Anyone could type a stranger's number
-- into their own profile and inherit that stranger's job cards, so linking
-- was made to need proof, and the proof was a six-digit code the workshop
-- read out at the counter.
--
-- It worked, and it cost too much. A code has to be asked for before it
-- can be given, which means the customer has to reach the counter before
-- the app is any use to them — and not having to is the one thing the app
-- is for. Worse, the code sat upstream of everything: no code, no link;
-- no link, no booking; no booking, nothing on the workshop's front desk.
-- A customer who found a garage in the directory was told to ring them
-- up, which is the same phone call the product exists to replace.
--
-- So the code goes, and the booking takes its job. The reasoning it rests
-- on has not changed — a claim still needs somebody to vouch for it, and
-- the workshop is still the only one who can — but the vouching now
-- happens inside work the counter was already doing:
--
--   1. Raising a booking creates the customer's own record at that
--      workshop, where none existed for their number. A record made a
--      moment ago has no history on it, so there is nothing to inherit
--      and nothing to prove.
--
--   2. Accepting that booking — opening a job card from it, which the
--      counter does anyway — is what attaches the person to a record that
--      was already there. That is the counter vouching, exactly as
--      reading out a code was, minus the reading out.
--
--   3. A record another account already holds is never reassigned, by
--      either path. The hole 03_sync closed stays closed: the most an
--      unverified number can now do is put a request on a front desk,
--      which is what a front desk is for.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. The code system goes
-- ---------------------------------------------------------------------
-- Dropped rather than left dormant. A redeemable code that no screen
-- issues any more is a live credential nobody is watching.

drop function if exists public.issue_customer_code(text)  cascade;
drop function if exists public.redeem_customer_code(text) cascade;
drop table    if exists public.customer_link_codes        cascade;

-- ---------------------------------------------------------------------
-- 1b. The customer's booking remembers its workshop
-- ---------------------------------------------------------------------
-- `bookings` is the customer's own copy, synced from their phone. It never
-- needed a workshop before, because there was only ever one a customer
-- could be attached to and a code was what attached them. Now they pick one
-- out of the directory per booking, so which one has to be on the row --
-- otherwise a reinstall restores a booking with nowhere to have been sent.
--
-- Without this column the whole `bookings` push is rejected on the unknown
-- key and every booking silently stops syncing, which is a bigger failure
-- than the one this column exists to prevent.
alter table public.bookings
  add column if not exists garage_id text not null default '';

-- ---------------------------------------------------------------------
-- 2. A booking makes a customer
-- ---------------------------------------------------------------------
-- Fires on the row the customer app inserts. `garage_customers` already
-- carries a unique `(garage_id, norm_phone(phone))`, so "is there a
-- record for this number at this workshop" is one lookup on an index.
--
-- Three outcomes, and the middle one is the point:
--
--   * no record         -> create it, owned by this account. Nothing to
--                          inherit, so nothing to prove.
--   * record, unclaimed -> leave it alone. It may carry years of somebody
--                          else's service history, and a phone number
--                          typed into a profile is not evidence of whose.
--                          The counter attaches it in section 3.
--   * record, claimed   -> never touched.
--
-- SECURITY DEFINER because the customer inserting the booking has no
-- write of their own on `garage_customers`, and must not be given one:
-- this writes exactly one shape of row and nothing else.
create or replace function public.customer_from_booking()
returns trigger language plpgsql security definer
set search_path = public as $fn$
declare
  existing text;
begin
  -- A booking with no account behind it was raised at the workshop's own
  -- front desk, not in the customer app. There is nobody to link.
  if new.profile_id is null then
    return new;
  end if;

  select c.id into existing
    from public.garage_customers c
   where c.garage_id = new.garage_id
     and public.norm_phone(c.phone) = public.norm_phone(new.phone)
   limit 1;

  if existing is null then
    insert into public.garage_customers (id, garage_id, profile_id, name, phone)
    values ('cus-' || new.id, new.garage_id, new.profile_id,
            new.name, new.phone)
    on conflict do nothing;
  end if;

  return new;
end $fn$;

drop trigger if exists garage_bookings_customer on public.garage_bookings;
create trigger garage_bookings_customer
  after insert on public.garage_bookings
  for each row execute function public.customer_from_booking();

-- ---------------------------------------------------------------------
-- 3. Accepting a booking is the vouch
-- ---------------------------------------------------------------------
-- The counter opens a job card from a request. That job card names a
-- customer record, and the request names an account. Putting the two
-- together is the judgement the code used to carry: the person who read
-- the digits out was a member of staff looking at the customer, and so is
-- the person tapping "Open job card".
--
-- Only ever onto an unclaimed record. A record another account holds is
-- somebody else's, and no amount of counter authority makes it not.
-- `garage_customers_backfill` from 02_garage.sql then carries that
-- record's job cards across to the newly attached account on its own.
create or replace function public.link_on_booking_accept()
returns trigger language plpgsql security definer
set search_path = public as $fn$
declare
  cust text;
begin
  if new.job_card_id is null or new.profile_id is null then
    return new;
  end if;
  if new.job_card_id is not distinct from old.job_card_id then
    return new;
  end if;

  select j.customer_id into cust
    from public.job_cards j
   where j.id = new.job_card_id
     and j.garage_id = new.garage_id;

  if cust is null then
    return new;
  end if;

  update public.garage_customers
     set profile_id = new.profile_id
   where id = cust
     and profile_id is null;

  return new;
end $fn$;

drop trigger if exists garage_bookings_link on public.garage_bookings;
create trigger garage_bookings_link
  after update of job_card_id on public.garage_bookings
  for each row execute function public.link_on_booking_accept();

-- ---------------------------------------------------------------------
-- 3b. A workshop that knows where it is, lists itself
-- ---------------------------------------------------------------------
-- `08_platform.sql` made `listed` default false and left it for a platform
-- admin: "An empty register is a better first day than one full of
-- unchecked workshops." That is the right call for a marketplace with
-- strangers in it. It is the wrong call here, where the workshop signing
-- up is the customer of this product -- registering a garage in the
-- console and then not appearing in the customer app reads as the app
-- being broken, because from the owner's side it is.
--
-- So the register lets a workshop in on the one fact that makes it worth
-- finding: a real coordinate. Nothing else changes. `verified` is still
-- the platform's alone -- the tick means somebody checked, and nobody has
-- -- and so is the commission rate.
--
-- Dropping a pin is a deliberate act by a signed-in member of that garage,
-- which is the same standard the rest of this file uses for "the workshop
-- vouched for it".
create or replace function public.list_on_locate()
returns trigger language plpgsql security definer
set search_path = public as $fn$
begin
  if new.lat is not null and new.lng is not null and not new.listed then
    new.listed := true;
  end if;
  return new;
end $fn$;

drop trigger if exists garages_list_on_locate on public.garages;
create trigger garages_list_on_locate
  before insert or update of lat, lng on public.garages
  for each row execute function public.list_on_locate();

-- The ones that were already located before this trigger existed.
update public.garages
   set listed = true
 where not listed and lat is not null and lng is not null;

-- ---------------------------------------------------------------------
-- 4. What the customer may still not do
-- ---------------------------------------------------------------------
-- The insert policy from 02_garage.sql allowed any row the account owns.
-- With the code gone that insert is the whole front door, so it is worth
-- saying plainly what it must not carry: a booking cannot arrive already
-- accepted, and it cannot arrive pointing at a job card. Otherwise the
-- customer app could book itself onto the floor and, through section 3,
-- attach itself to a record of its own choosing.
drop policy if exists garage_bookings_customer_insert on public.garage_bookings;
create policy garage_bookings_customer_insert on public.garage_bookings
  for insert with check (
    profile_id = auth.uid()
    and accepted = false
    and job_card_id is null
  );

-- A customer may call off a request the counter has not taken up yet.
-- Not one it has: that is a job card now, and calling off work already
-- under way is a conversation, not a button.
drop policy if exists garage_bookings_customer_cancel on public.garage_bookings;
create policy garage_bookings_customer_cancel on public.garage_bookings
  for delete using (
    profile_id = auth.uid() and accepted = false and job_card_id is null
  );

notify pgrst, 'reload schema';
