-- ONE PASTE: make Buy & Sell work end to end.
-- ---------------------------------------------------------------------
-- Run the whole file in the Supabase SQL editor, then sign out and back
-- in on the phone. Safe to run twice.
--
-- It does three things:
--   1. makes the admin account a platform admin (sees every listing)
--   2. lets a customer address a listing/request to a workshop, and lets
--      that workshop see and decide it without any platform role
--   3. prints what it did, at the bottom
--
-- EDIT THIS if the admin signs in with a different address. It appears
-- three times below; change all three (Ctrl+H in the editor).

-- ---------------------------------------------------------------------
-- 0. Prerequisites, in case 08_platform.sql never reached this database
-- ---------------------------------------------------------------------
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

-- ---------------------------------------------------------------------
-- 1. The admin account becomes the platform admin
-- ---------------------------------------------------------------------
update public.profiles
   set role = 'platform'
 where id = (select id from auth.users where email = 'firefringe@gmail.com');

-- ---------------------------------------------------------------------
-- 2. A customer may address a request to a workshop
-- ---------------------------------------------------------------------
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
    -- garage_id is left as posted: the workshop the customer chose.
  else
    new.user_id := old.user_id;
    new.code    := old.code;
    if not (public.is_platform_admin()
            or (old.garage_id is not null
                and public.is_garage_member(old.garage_id))) then
      new.status    := old.status;
      new.quote     := old.quote;
      new.note      := old.note;
      new.garage_id := old.garage_id;
    end if;
    new.updated_at := now();
  end if;
  return new;
end $fn$;

drop policy if exists part_requests_assigned on public.part_requests;
create policy part_requests_assigned on public.part_requests
  for select to authenticated
  using (garage_id is not null and public.is_garage_member(garage_id));

drop policy if exists part_requests_assigned_write on public.part_requests;
create policy part_requests_assigned_write on public.part_requests
  for update to authenticated
  using (garage_id is not null and public.is_garage_member(garage_id))
  with check (garage_id is not null and public.is_garage_member(garage_id));

-- ---------------------------------------------------------------------
-- 3. The same for a listing, and the garage may approve or reject it
-- ---------------------------------------------------------------------
drop policy if exists part_listings_assigned on public.part_listings;
create policy part_listings_assigned on public.part_listings
  for select to authenticated
  using (garage_id is not null and public.is_garage_member(garage_id));

drop policy if exists part_listings_assigned_write on public.part_listings;
create policy part_listings_assigned_write on public.part_listings
  for update to authenticated
  using (garage_id is not null and public.is_garage_member(garage_id))
  with check (garage_id is not null and public.is_garage_member(garage_id));

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

  if public.is_platform_admin()
     or (old.garage_id is not null
         and public.is_garage_member(old.garage_id)) then
    return new;
  end if;

  new.reject_note := old.reject_note;

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

-- ---------------------------------------------------------------------
-- 4. The workshops a customer may choose from
-- ---------------------------------------------------------------------
create or replace function public.listable_garages(max_rows int default 200)
returns jsonb language sql stable security definer
set search_path = public as $fn$
  select coalesce(jsonb_agg(t order by t ->> 'name'), '[]'::jsonb)
    from (
      select jsonb_build_object(
               'id', g.id, 'name', g.name, 'city', g.city)
        from public.garages g
       limit greatest(max_rows, 1)
    ) as x(t);
$fn$;

grant execute on function public.listable_garages(int) to authenticated;

-- ---------------------------------------------------------------------
-- 5. What it did
-- ---------------------------------------------------------------------
-- Expect one row, role = 'platform'. Zero rows means the email above is
-- not the one the admin signs in with — fix it and run again.
select u.email, p.role as now_role
  from public.profiles p
  join auth.users u on u.id = p.id
 where u.email = 'firefringe@gmail.com';

-- Every listing in the database, and who can see it.
select count(*) filter (where status = 'pending')  as pending,
       count(*) filter (where status = 'approved') as approved,
       count(*)                                    as total
  from public.part_listings;
