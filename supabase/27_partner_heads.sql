-- =====================================================================
-- GaragePro — partner heads: Gmail accounts, each switched on or off
-- =====================================================================
-- Run AFTER 26_require_garage_pin.sql. Idempotent: safe to re-run.
--
-- The platform section (Settings -> Platform: Partners, Requests,
-- Listings, Content, and every partner's commission) used to belong to
-- one account, the profile with role = 'platform' (19_*.sql). It now
-- belongs to whoever is on this list AND switched on:
--
--   firefringe@gmail.com
--   balajiautomobiles088@gmail.com
--   vjalaria@gmail.com
--
-- Any head can switch another off or on again from
-- Platform -> Heads. The list itself is only ever changed here, in the SQL
-- editor: no screen in either app adds an address to it, on purpose.
-- The last head that is on cannot be switched off, so the platform can
-- never lock itself out.
--
-- A head keeps their own workshop: being on this list does not touch
-- their garage, their staff or their job cards.
--
-- An address only counts once its owner has signed in with it and the
-- address is confirmed. Have each head sign in to the admin app once.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. The list
-- ---------------------------------------------------------------------
create table if not exists public.platform_heads (
  email      text primary key check (email = lower(btrim(email))),
  enabled    boolean not null default true,
  updated_at timestamptz not null default now()
);

-- No policy: nobody reads or writes the table directly, only through
-- is_platform_admin() and the two functions below.
alter table public.platform_heads enable row level security;
revoke all on public.platform_heads from public, anon, authenticated;

-- EDIT THIS to change who the heads are. A re-run never switches back on
-- a head that was switched off.
insert into public.platform_heads (email) values
  ('firefringe@gmail.com'),
  ('balajiautomobiles088@gmail.com'),
  ('vjalaria@gmail.com')
on conflict (email) do nothing;

-- ---------------------------------------------------------------------
-- 2. Who is a head, from the list instead of profiles.role
-- ---------------------------------------------------------------------
-- Every policy and function that guards the platform already asks
-- is_platform_admin(), so replacing its body is the whole switch.
create or replace function public.is_platform_admin()
returns boolean language sql stable security definer
set search_path = public as $fn$
  select exists (
    select 1
      from public.platform_heads h
      join auth.users u on lower(u.email) = h.email
     where u.id = auth.uid()
       and u.email_confirmed_at is not null
       and h.enabled
  );
$fn$;

revoke execute on function public.is_platform_admin() from public, anon;
grant execute on function public.is_platform_admin() to authenticated;

-- ---------------------------------------------------------------------
-- 3. The switches
-- ---------------------------------------------------------------------
-- Every head, on or off, with `me` marking the caller's own row. Empty
-- for anyone who is not a head that is on.
create or replace function public.list_platform_heads()
returns jsonb language sql stable security definer
set search_path = public as $fn$
  select case when not public.is_platform_admin() then '[]'::jsonb else
    coalesce((
      select jsonb_agg(jsonb_build_object(
               'email', h.email,
               'enabled', h.enabled,
               'me', h.email = (select lower(email) from auth.users
                                 where id = auth.uid())
             ) order by h.email)
        from public.platform_heads h
    ), '[]'::jsonb)
  end;
$fn$;

-- The messages are the ones the admin app shows as they are.
create or replace function public.set_platform_head(
  head_email text, head_enabled boolean)
returns void language plpgsql security definer
set search_path = public as $fn$
begin
  if not public.is_platform_admin() then
    raise exception 'Only a partner head can change this.'
      using errcode = 'insufficient_privilege';
  end if;

  update public.platform_heads
     set enabled = head_enabled, updated_at = now()
   where email = lower(btrim(head_email));
  if not found then
    raise exception 'That address is not a partner head.'
      using errcode = 'no_data_found';
  end if;

  -- Checked after the update, inside the same call, so the refusal
  -- rolls the switch back.
  if not exists (select 1 from public.platform_heads where enabled) then
    raise exception 'At least one partner head has to stay on.'
      using errcode = 'check_violation';
  end if;
end $fn$;

revoke execute on function public.list_platform_heads() from public, anon;
revoke execute on function public.set_platform_head(text, boolean)
  from public, anon;
grant execute on function public.list_platform_heads() to authenticated;
grant execute on function public.set_platform_head(text, boolean)
  to authenticated;

-- ---------------------------------------------------------------------
-- 4. Check
-- ---------------------------------------------------------------------
-- One row per head. `signed_in` false means that person has not signed in to the
-- admin app with that Gmail yet; they are a head the moment they do.
select h.email, h.enabled, u.id is not null as signed_in
  from public.platform_heads h
  left join auth.users u on lower(u.email) = h.email
 order by h.email;
