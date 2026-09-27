-- Buy & Sell, addressed to a workshop
-- ---------------------------------------------------------------------
-- Until now the marketplace was brokered: a customer posted, a central
-- platform admin read the queue and handed the row to a garage, and only
-- then could that garage see it. With nobody holding the `platform` role
-- the queue was invisible to everyone and the admin screen sat empty.
--
-- This changes the addressing, not the rules. The customer picks the
-- workshop when they post, and that workshop reviews it. The platform
-- admin keeps every power it had; it is simply no longer the only way a
-- row can reach a garage.

-- 1. A request may be addressed on insert -----------------------------
-- The only change is the line that threw the customer's choice away.
-- Everything else the client may not decide is still decided here.
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
    -- new.garage_id is left as posted: the workshop the customer chose.
  else
    new.user_id := old.user_id;
    new.code    := old.code;
    -- The platform still moves any request along. A garage may now do the
    -- same for the requests addressed to it, and nothing else.
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

-- A garage may act on its own requests, not merely read them.
drop policy if exists part_requests_assigned on public.part_requests;
create policy part_requests_assigned on public.part_requests
  for select to authenticated
  using (garage_id is not null and public.is_garage_member(garage_id));

drop policy if exists part_requests_assigned_write on public.part_requests;
create policy part_requests_assigned_write on public.part_requests
  for update to authenticated
  using (garage_id is not null and public.is_garage_member(garage_id))
  with check (garage_id is not null and public.is_garage_member(garage_id));

-- 2. A listing may be addressed on insert -----------------------------
-- guard_part_listing already leaves garage_id alone, so nothing there
-- needs changing. What is missing is the garage's right to see the row
-- and to approve or reject it.
drop policy if exists part_listings_assigned on public.part_listings;
create policy part_listings_assigned on public.part_listings
  for select to authenticated
  using (garage_id is not null and public.is_garage_member(garage_id));

drop policy if exists part_listings_assigned_write on public.part_listings;
create policy part_listings_assigned_write on public.part_listings
  for update to authenticated
  using (garage_id is not null and public.is_garage_member(garage_id))
  with check (garage_id is not null and public.is_garage_member(garage_id));

-- The guard decides status for everybody who is not the platform, which
-- would quietly undo a garage's approval. The garage that owns the row
-- gets the same say the platform has over it.
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

-- 3. The workshops a customer may choose from -------------------------
-- Name and city only: enough to pick from, nothing that is not already
-- on the find-a-garage screen.
create or replace function public.listable_garages(max_rows int default 200)
returns jsonb language sql stable security definer
set search_path = public as $fn$
  select coalesce(jsonb_agg(t order by t ->> 'name'), '[]'::jsonb)
    from (
      select jsonb_build_object(
               'id',   g.id,
               'name', g.name,
               'city', g.city)
        from public.garages g
       limit greatest(max_rows, 1)
    ) as x(t);
$fn$;

grant execute on function public.listable_garages(int) to authenticated;
