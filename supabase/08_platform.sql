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
