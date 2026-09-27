-- =====================================================================
-- GaragePro — block a partner, and file every workshop under a district
-- =====================================================================
-- Run after 27_partner_heads.sql. Idempotent: safe to re-run.
--
--   1. `garages.blocked`: a partner head can block a workshop. A blocked
--      workshop is out of customer search and cannot be listed again
--      until it is unblocked. Its own staff keep their console and data.
--   2. `garages.district`: filled from the phone's location lookup, so
--      the Platform screen can filter by State → District → PIN code.
--   3. `platform_garages()` returns both; `set_garage_listing()` takes
--      `blocked`; `set_garage_location()` takes `district`.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Columns
-- ---------------------------------------------------------------------
alter table public.garages
  add column if not exists blocked    boolean not null default false,
  add column if not exists blocked_at timestamptz,
  add column if not exists district   text not null default '';

-- Every customer read of the register (`nearby_garages`) goes through
-- `listed`, so "blocked is never listed" is the whole of the hiding.
-- Held by the table, not only by the function below.
update public.garages set listed = false where blocked and listed;
alter table public.garages
  drop constraint if exists garages_blocked_not_listed;
alter table public.garages
  add constraint garages_blocked_not_listed check (not (blocked and listed));

-- ---------------------------------------------------------------------
-- 2. The platform's switches (19_commission_and_roles.sql, plus blocked)
-- ---------------------------------------------------------------------
-- Blocking also un-lists. Listing a blocked workshop is refused with a
-- sentence the admin app shows as it is.
create or replace function public.set_garage_listing(payload jsonb)
returns jsonb language plpgsql security definer
set search_path = public as $fn$
declare
  gid     uuid    := (payload ->> 'garage_id')::uuid;
  blk     boolean := (payload ->> 'blocked')::boolean;
  lst     boolean := (payload ->> 'listed')::boolean;
  g public.garages;
begin
  if not public.is_platform_admin() then
    raise exception 'not a platform admin';
  end if;

  select * into g from public.garages where id = gid;
  if g.id is null then
    raise exception 'no such garage';
  end if;

  if lst and coalesce(blk, g.blocked) then
    raise exception 'Unblock this workshop before listing it.'
      using errcode = 'check_violation';
  end if;

  update public.garages set
    blocked        = coalesce(blk, blocked),
    blocked_at     = case
                       when blk is true and not blocked then now()
                       when blk is false then null
                       else blocked_at
                     end,
    listed         = case when blk is true then false
                          else coalesce(lst, listed) end,
    verified       = coalesce((payload ->> 'verified')::boolean, verified),
    commission_pct = case
                       when payload ? 'commission_pct'
                       then nullif(payload ->> 'commission_pct', '')::numeric
                       else commission_pct
                     end
   where id = gid
   returning * into g;

  return to_jsonb(g);
end $fn$;

revoke execute on function public.set_garage_listing(jsonb) from public, anon;
grant execute on function public.set_garage_listing(jsonb) to authenticated;

-- ---------------------------------------------------------------------
-- 3. A workshop's pin (08_platform.sql, plus district)
-- ---------------------------------------------------------------------
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
    district     = coalesce(nullif(btrim(payload ->> 'district'), ''),
                            district),
    state        = coalesce(payload ->> 'state', state),
    pin          = coalesce(payload ->> 'pin',   pin),
    lat          = coalesce(la, lat),
    lng          = coalesce(lo, lng),
    located_at   = case when la is not null then now() else located_at end
   where id = gid
   returning * into g;

  return to_jsonb(g);
end $fn$;

revoke execute on function public.set_garage_location(jsonb) from public, anon;
grant execute on function public.set_garage_location(jsonb) to authenticated;

-- ---------------------------------------------------------------------
-- 4. The register (08_platform.sql, plus district and blocked)
-- ---------------------------------------------------------------------
create or replace function public.platform_garages()
returns jsonb language sql stable security definer
set search_path = public as $fn$
  select case when not public.is_platform_admin() then '[]'::jsonb else
    coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', g.id, 'name', g.name, 'phone', g.phone, 'email', g.email,
        'city', g.city, 'district', g.district, 'state', g.state,
        'pin', g.pin,
        'lat', g.lat, 'lng', g.lng, 'located_at', g.located_at,
        'listed', g.listed, 'verified', g.verified,
        'blocked', g.blocked, 'blocked_at', g.blocked_at,
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

revoke execute on function public.platform_garages() from public, anon;
grant execute on function public.platform_garages() to authenticated;

-- ---------------------------------------------------------------------
-- 5. Check
-- ---------------------------------------------------------------------
-- No row should come back with blocked and listed both true.
select name, city, district, state, pin, listed, verified, blocked
  from public.garages
 order by blocked desc, created_at desc;
