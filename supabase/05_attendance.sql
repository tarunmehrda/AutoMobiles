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
