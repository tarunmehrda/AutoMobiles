-- =====================================================================
-- GaragePro — staff logins: an owner invites an employee by email
-- =====================================================================
-- Run after 30_super_admins.sql. Idempotent: safe to re-run.
--
-- The three levels:
--
--   Super Admin  platform_heads (27 / 30). The platform, nothing else.
--   Admin        the garage's owner. Everything in their own workshop.
--   Sub-Admin    an employee the owner invited, as one of four roles:
--
--     manager     jobs, bookings, customers, stock, purchases, money;
--                 no workshop settings, no commission
--     mechanic    only the job cards assigned to them (card or line),
--                 no prices, no money, punches only their own attendance
--     counter     jobs, bookings, customers, stock, counter sale
--     accountant  reads jobs and customers; the books and reports
--
-- The role grid itself is 04_roles.sql (`role_grid`). This file is what
-- makes it true:
--
--   1. invites: the owner names an email and a role for one staff record;
--      when that email signs in to the admin app it joins the workshop
--      instead of being asked to register one;
--   2. `garage_snapshot()` (03) handed every member the whole workshop
--      and bypassed every policy. It now leaves out what the role may not
--      read, and a mechanic gets only their own job cards;
--   3. `save_job_card()` checked "is a member" only. A guard on the table
--      now holds create / edit / delete to the role, however it is called;
--   4. restrictive policies on the other workshop tables, so a direct API
--      call gets no more than the app would show;
--   5. attendance: without the right to manage it, a person punches only
--      themselves;
--   6. the owner's team controls: list, change role, remove access.
--
-- The owner, customers, Super Admins and the SQL editor are not affected
-- by any of the checks here: they apply only to a signed-in person whose
-- membership of that garage is one of the four staff roles.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Asking about a staff member
-- ---------------------------------------------------------------------

-- True unless the caller is staff (not the owner) at `gid` and their role
-- does not allow `action` on `module`. Anybody who is not a member at all
-- — a customer, a Super Admin — passes, and the table's own policies
-- decide about them as before.
create or replace function public.role_allows(
  gid uuid, module text, action text)
returns boolean language sql stable security definer
set search_path = public as $fn$
  select case
    when coalesce(public.member_role(gid), 'owner') = 'owner' then true
    else public.member_can(gid, module, action)
  end;
$fn$;

-- May the caller see this job card? A mechanic sees a card they are on,
-- either for the whole card or for one of its lines.
create or replace function public.member_sees_card(
  gid uuid, card text, mechs text[])
returns boolean language sql stable security definer
set search_path = public as $fn$
  select public.member_can(gid, 'jobCards', 'v')
     and (
       not public.own_jobs_only(gid)
       or public.member_staff_id(gid) = any (coalesce(mechs, '{}'))
       or exists (select 1 from public.line_items li
                   where li.job_card_id = card
                     and li.mechanic_id = public.member_staff_id(gid))
     );
$fn$;

revoke execute on function public.role_allows(uuid, text, text) from public, anon;
revoke execute on function public.member_sees_card(uuid, text, text[])
  from public, anon;
grant execute on function public.role_allows(uuid, text, text) to authenticated;
grant execute on function public.member_sees_card(uuid, text, text[])
  to authenticated;

-- ---------------------------------------------------------------------
-- 2. Job cards: what a member reads (02 / 04, now per card)
-- ---------------------------------------------------------------------
-- Lines, payments and messages ride on these two, so narrowing them
-- narrows everything hanging off a card.
create or replace function public.owns_job_card(card text)
returns boolean language sql stable security definer
set search_path = public as $$
  select exists (
    select 1 from public.job_cards j
    where j.id = card
      and public.is_garage_member(j.garage_id)
      and public.member_sees_card(j.garage_id, j.id, j.mechanic_ids)
  );
$$;

create or replace function public.reads_job_card(card text)
returns boolean language sql stable security definer
set search_path = public as $$
  select exists (
    select 1 from public.job_cards j
    where j.id = card
      and ((public.is_garage_member(j.garage_id)
            and public.member_sees_card(j.garage_id, j.id, j.mechanic_ids))
           or j.customer_profile_id = auth.uid())
  );
$$;

drop policy if exists job_cards_member_read on public.job_cards;
create policy job_cards_member_read on public.job_cards
  for select using (
    public.is_garage_member(garage_id)
    and public.member_sees_card(garage_id, id, mechanic_ids)
  );

drop policy if exists job_cards_member_update on public.job_cards;
create policy job_cards_member_update on public.job_cards
  for update using (
    public.is_garage_member(garage_id)
    and public.member_can(garage_id, 'jobCards', 'e')
    and public.member_sees_card(garage_id, id, mechanic_ids)
  ) with check (public.is_garage_member(garage_id));

-- ---------------------------------------------------------------------
-- 3. Job cards: what a member writes, however it is written
-- ---------------------------------------------------------------------
-- `save_job_card()` runs with the definer's rights, so the policies above
-- never see its writes. A trigger does. An upsert of a card that already
-- exists fires the insert trigger first; that is let through here and
-- judged as the edit it is when the update half fires.
create or replace function public.guard_job_card_role()
returns trigger language plpgsql security definer
set search_path = public as $fn$
declare
  gid uuid := case when tg_op = 'DELETE' then old.garage_id
                   else new.garage_id end;
  r   text := public.member_role(gid);
begin
  if r is null or r = 'owner' then
    return coalesce(new, old);
  end if;

  if tg_op = 'INSERT' then
    if exists (select 1 from public.job_cards where id = new.id) then
      return new;
    end if;
    if not public.member_can(gid, 'jobCards', 'c') then
      raise exception 'Your role cannot open job cards.'
        using errcode = 'insufficient_privilege';
    end if;
  elsif tg_op = 'UPDATE' then
    if not public.member_can(gid, 'jobCards', 'e')
       or not public.member_sees_card(gid, old.id, old.mechanic_ids) then
      raise exception 'Your role cannot change this job card.'
        using errcode = 'insufficient_privilege';
    end if;
  else
    if not public.member_can(gid, 'jobCards', 'd') then
      raise exception 'Your role cannot delete job cards.'
        using errcode = 'insufficient_privilege';
    end if;
  end if;
  return coalesce(new, old);
end $fn$;

drop trigger if exists job_cards_guard_role on public.job_cards;
create trigger job_cards_guard_role
  before insert or update or delete on public.job_cards
  for each row execute function public.guard_job_card_role();

-- ---------------------------------------------------------------------
-- 4. The rest of the workshop, table by table
-- ---------------------------------------------------------------------
-- Restrictive policies: they grant nothing, and only ever take away from
-- staff whose role does not allow the action. Everybody else is judged by
-- the table's existing policies exactly as before. A null action means
-- that command is not narrowed.
do $blk$
declare
  t record;
begin
  for t in
    select * from (values
      ('garage_customers', 'customers',   'v',  'c', 'e', 'd'),
      ('garage_vehicles',  'vehicles',    'v',  'c', 'e', 'd'),
      ('garage_bookings',  'jobCards',    'v',  'c', 'c', 'd'),
      ('expenses',         'finance',     'v',  'c', 'e', 'd'),
      ('cash_book',        'finance',     'v',  'c', 'e', 'd'),
      ('suppliers',        'purchases',   'v',  'c', 'e', 'd'),
      ('purchase_orders',  'purchases',   'v',  'c', 'e', 'd'),
      ('counter_sales',    'counterSale', 'v',  'c', 'e', 'd'),
      ('online_services',  'settings',    null, 'e', 'e', 'e')
    ) as x(tbl, module, sel, ins, upd, del)
  loop
    continue when to_regclass('public.' || t.tbl) is null;

    execute format('drop policy if exists %I on public.%I',
                   t.tbl || '_role_read', t.tbl);
    execute format('drop policy if exists %I on public.%I',
                   t.tbl || '_role_add', t.tbl);
    execute format('drop policy if exists %I on public.%I',
                   t.tbl || '_role_edit', t.tbl);
    execute format('drop policy if exists %I on public.%I',
                   t.tbl || '_role_remove', t.tbl);

    if t.sel is not null then
      execute format(
        'create policy %I on public.%I as restrictive for select
           to authenticated
           using (public.role_allows(garage_id, %L, %L))',
        t.tbl || '_role_read', t.tbl, t.module, t.sel);
    end if;
    execute format(
      'create policy %I on public.%I as restrictive for insert
         to authenticated
         with check (public.role_allows(garage_id, %L, %L))',
      t.tbl || '_role_add', t.tbl, t.module, t.ins);
    execute format(
      'create policy %I on public.%I as restrictive for update
         to authenticated
         using (public.role_allows(garage_id, %L, %L))
         with check (public.role_allows(garage_id, %L, %L))',
      t.tbl || '_role_edit', t.tbl, t.module, t.upd, t.module, t.upd);
    execute format(
      'create policy %I on public.%I as restrictive for delete
         to authenticated
         using (public.role_allows(garage_id, %L, %L))',
      t.tbl || '_role_remove', t.tbl, t.module, t.del);
  end loop;
end
$blk$;

-- The workshop's own row: its name, address, terms, shopfront switch.
drop policy if exists garages_role_edit on public.garages;
create policy garages_role_edit on public.garages
  as restrictive for update to authenticated
  using (public.role_allows(id, 'settings', 'e'))
  with check (public.role_allows(id, 'settings', 'e'));

-- ---------------------------------------------------------------------
-- 5. What a phone downloads (03_sync.sql, now per role)
-- ---------------------------------------------------------------------
-- A section the role may not read comes back as an empty list, not a
-- missing key: the app takes a missing key as "keep what this phone has".
-- Purchase cost is left off stock for anybody who may not see cost.
create or replace function public.garage_snapshot(gid uuid)
returns jsonb language sql stable security definer
set search_path = public as $fn$
  select case when not public.is_garage_member(gid) then null else
    jsonb_build_object(
      'garage', (select to_jsonb(g) from public.garages g where g.id = gid),
      -- Whoever manages people gets the whole record. Anybody else gets the
      -- names a job card prints, and not a colleague's salary or address.
      'staff', case
        when public.member_can(gid, 'users', 'v') then
          coalesce((
            select jsonb_agg(to_jsonb(s) - 'garage_id' - 'created_at'
                             order by s.name)
            from public.staff s where s.garage_id = gid), '[]'::jsonb)
        when public.member_can(gid, 'jobCards', 'v') then
          coalesce((
            select jsonb_agg(jsonb_build_object(
                     'id', s.id, 'name', s.name, 'phone', s.phone,
                     'skill', s.skill, 'active', s.active)
                   order by s.name)
            from public.staff s where s.garage_id = gid), '[]'::jsonb)
        else '[]'::jsonb end,
      'customers', case when public.member_can(gid, 'customers', 'v') then
        coalesce((
          select jsonb_agg(to_jsonb(c) - 'garage_id' - 'profile_id')
          from public.garage_customers c where c.garage_id = gid), '[]'::jsonb)
        else '[]'::jsonb end,
      'vehicles', case when public.member_can(gid, 'vehicles', 'v') then
        coalesce((
          select jsonb_agg(to_jsonb(v) - 'garage_id' - 'created_at')
          from public.garage_vehicles v where v.garage_id = gid), '[]'::jsonb)
        else '[]'::jsonb end,
      'masters', case when public.member_can(gid, 'inventory', 'v') then
        coalesce((
          select jsonb_agg(
                   to_jsonb(m) - 'garage_id' - 'created_at'
                   - (case when public.sees_cost(gid)
                             or public.member_role(gid) = 'owner'
                           then '' else 'cost' end))
          from public.masters m where m.garage_id = gid), '[]'::jsonb)
        else '[]'::jsonb end,
      'bookings', case when public.member_can(gid, 'jobCards', 'v') then
        coalesce((
          select jsonb_agg(to_jsonb(b) - 'garage_id' - 'profile_id'
                           - 'created_at')
          from public.garage_bookings b where b.garage_id = gid), '[]'::jsonb)
        else '[]'::jsonb end,
      'reviews', case when public.member_can(gid, 'customers', 'v') then
        coalesce((
          select jsonb_agg(to_jsonb(r) - 'garage_id' - 'profile_id')
          from public.reviews r where r.garage_id = gid), '[]'::jsonb)
        else '[]'::jsonb end,
      'expenses', case when public.member_can(gid, 'finance', 'v') then
        coalesce((
          select jsonb_agg(to_jsonb(e) - 'garage_id' - 'created_at'
                           order by e.at desc)
          from public.expenses e where e.garage_id = gid), '[]'::jsonb)
        else '[]'::jsonb end,
      'cash_book', case when public.member_can(gid, 'finance', 'v') then
        coalesce((
          select jsonb_agg(to_jsonb(c) - 'garage_id' - 'created_at'
                           order by c.at desc)
          from public.cash_book c where c.garage_id = gid), '[]'::jsonb)
        else '[]'::jsonb end,
      'suppliers', case when public.member_can(gid, 'purchases', 'v') then
        coalesce((
          select jsonb_agg(to_jsonb(s) - 'garage_id' - 'created_at'
                           order by s.name)
          from public.suppliers s where s.garage_id = gid), '[]'::jsonb)
        else '[]'::jsonb end,
      'counter_sales', case when public.member_can(gid, 'counterSale', 'v') then
        coalesce((
          select jsonb_agg(to_jsonb(cs) - 'garage_id' - 'created_at'
                           order by cs.at desc)
          from public.counter_sales cs where cs.garage_id = gid), '[]'::jsonb)
        else '[]'::jsonb end,
      'purchase_orders', case when public.member_can(gid, 'purchases', 'v') then
        coalesce((
          select jsonb_agg(to_jsonb(po) - 'garage_id' - 'created_at'
                           order by po.at desc)
          from public.purchase_orders po where po.garage_id = gid), '[]'::jsonb)
        else '[]'::jsonb end,
      'online_services', coalesce((
        select jsonb_agg(to_jsonb(os) - 'garage_id' - 'created_at'
                         order by os.name)
        from public.online_services os where os.garage_id = gid), '[]'::jsonb),
      'job_cards', coalesce((
        select jsonb_agg(public.job_card_json(j) order by j.created_at desc)
        from public.job_cards j
        where j.garage_id = gid
          and public.member_sees_card(gid, j.id, j.mechanic_ids)), '[]'::jsonb))
  end;
$fn$;

revoke execute on function public.garage_snapshot(uuid) from public, anon;
grant execute on function public.garage_snapshot(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- 6. Attendance: only your own, unless you manage it
-- ---------------------------------------------------------------------
-- `punch_attendance()` is the only way a row is written (05). On a shared
-- counter phone the owner or a manager punches for whoever is standing
-- there; anybody else punches only the staff record that is them.
create or replace function public.guard_attendance_self()
returns trigger language plpgsql security definer
set search_path = public as $fn$
declare r text := public.member_role(new.garage_id);
begin
  if r is null or r = 'owner'
     or public.member_can(new.garage_id, 'attendance', 'e') then
    return new;
  end if;
  if new.staff_id is distinct from public.member_staff_id(new.garage_id) then
    raise exception 'You can only mark your own attendance.'
      using errcode = 'insufficient_privilege';
  end if;
  return new;
end $fn$;

drop trigger if exists attendance_guard_self on public.attendance;
create trigger attendance_guard_self
  before insert on public.attendance
  for each row execute function public.guard_attendance_self();

-- ---------------------------------------------------------------------
-- 7. Invitations
-- ---------------------------------------------------------------------
-- One pending invitation per email, anywhere. Nobody reads or writes the
-- table directly; only the functions below.
create table if not exists public.garage_invites (
  email      text primary key
               check (email = lower(btrim(email)) and email like '%_@_%._%'),
  garage_id  uuid not null references public.garages (id) on delete cascade,
  role       text not null
               check (role in ('manager', 'mechanic', 'counter', 'accountant')),
  staff_id   text not null,
  invited_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now()
);
create index if not exists garage_invites_garage_idx
  on public.garage_invites (garage_id);

alter table public.garage_invites enable row level security;
revoke all on public.garage_invites from public, anon, authenticated;

-- Only the owner. The messages are the ones the admin app shows as they
-- are.
create or replace function public.invite_staff(payload jsonb)
returns jsonb language plpgsql security definer
set search_path = public as $fn$
declare
  gid  uuid := nullif(payload ->> 'garage_id', '')::uuid;
  em   text := lower(btrim(coalesce(payload ->> 'email', '')));
  rl   text := coalesce(payload ->> 'role', '');
  sid  text := nullif(btrim(coalesce(payload ->> 'staff_id', '')), '');
  who  uuid;
  inv  public.garage_invites;
begin
  if gid is null or public.member_role(gid) is distinct from 'owner' then
    raise exception 'Only the workshop owner can give app access.'
      using errcode = 'insufficient_privilege';
  end if;
  if em !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    raise exception 'Enter a valid email address.'
      using errcode = 'check_violation';
  end if;
  if rl not in ('manager', 'mechanic', 'counter', 'accountant') then
    raise exception 'Pick a role: manager, mechanic, counter or accountant.'
      using errcode = 'check_violation';
  end if;
  if sid is null or not exists (select 1 from public.staff s
                                 where s.id = sid and s.garage_id = gid) then
    raise exception 'Save this person on the team first.'
      using errcode = 'check_violation';
  end if;

  select id into who from auth.users where lower(email) = em limit 1;
  if who = auth.uid() then
    raise exception 'That is your own email.'
      using errcode = 'check_violation';
  end if;
  if who is not null and exists (select 1 from public.garage_members m
                                  where m.profile_id = who) then
    raise exception 'That email already uses GaragePro for a workshop. Use a different email.'
      using errcode = 'unique_violation';
  end if;
  if exists (select 1 from public.garage_members m
              where m.garage_id = gid and m.staff_id = sid) then
    raise exception 'This person already has app access.'
      using errcode = 'unique_violation';
  end if;
  if exists (select 1 from public.garage_invites i
              where i.email = em and i.garage_id <> gid) then
    raise exception 'That email already has an invitation from another workshop.'
      using errcode = 'unique_violation';
  end if;

  -- One invitation per staff record: a new email replaces the old one.
  delete from public.garage_invites
   where garage_id = gid and staff_id = sid and email <> em;

  insert into public.garage_invites (email, garage_id, role, staff_id, invited_by)
  values (em, gid, rl, sid, auth.uid())
  on conflict (email) do update
    set role = excluded.role, staff_id = excluded.staff_id,
        invited_by = excluded.invited_by, created_at = now()
  returning * into inv;

  update public.staff set email = em, role = rl
   where id = sid and garage_id = gid;

  return to_jsonb(inv);
end $fn$;

-- Called by the admin app on every sign-in, before it looks for the
-- workshop. Somebody with a pending invitation, a confirmed email and no
-- workshop of their own joins the one that invited them. Returns that
-- garage's id, or null when there was nothing to join.
create or replace function public.claim_staff_invite()
returns uuid language plpgsql security definer
set search_path = public as $fn$
declare
  uid uuid := auth.uid();
  em  text;
  inv public.garage_invites;
  nm  text;
begin
  if uid is null then
    return null;
  end if;
  select lower(u.email) into em from auth.users u
   where u.id = uid and u.email_confirmed_at is not null;
  if em is null then
    return null;
  end if;
  if exists (select 1 from public.garage_members m where m.profile_id = uid) then
    return null;
  end if;
  select * into inv from public.garage_invites where email = em;
  if inv.email is null then
    return null;
  end if;

  select s.name into nm from public.staff s
   where s.id = inv.staff_id and s.garage_id = inv.garage_id;
  insert into public.profiles (id, name, email)
  values (uid, coalesce(nm, ''), em)
  on conflict (id) do update
    set name  = case when public.profiles.name = '' then excluded.name
                     else public.profiles.name end,
        email = coalesce(public.profiles.email, excluded.email);

  insert into public.garage_members (garage_id, profile_id, role, staff_id)
  values (inv.garage_id, uid, inv.role, inv.staff_id)
  on conflict (garage_id, profile_id) do nothing;

  delete from public.garage_invites where email = em;
  return inv.garage_id;
end $fn$;

-- ---------------------------------------------------------------------
-- 8. The owner's team controls
-- ---------------------------------------------------------------------
-- Everybody who can sign in to this workshop, and every invitation still
-- waiting. The owner and anybody allowed to see users (a manager).
create or replace function public.garage_team(gid uuid)
returns jsonb language sql stable security definer
set search_path = public as $fn$
  select case
    when not public.member_can(gid, 'users', 'v') then null
    else jsonb_build_object(
      'members', coalesce((
        select jsonb_agg(jsonb_build_object(
                 'profile_id', m.profile_id,
                 'email', lower(u.email),
                 'name', coalesce(nullif(p.name, ''), s.name, ''),
                 'role', m.role,
                 'staff_id', coalesce(m.staff_id, ''),
                 'last_sign_in_at', u.last_sign_in_at,
                 'me', m.profile_id = auth.uid())
               order by (m.role = 'owner') desc, m.created_at)
          from public.garage_members m
          join auth.users u on u.id = m.profile_id
          left join public.profiles p on p.id = m.profile_id
          left join public.staff s on s.id = m.staff_id and s.garage_id = gid
         where m.garage_id = gid), '[]'::jsonb),
      'invites', coalesce((
        select jsonb_agg(jsonb_build_object(
                 'email', i.email, 'role', i.role, 'staff_id', i.staff_id,
                 'created_at', i.created_at)
               order by i.created_at)
          from public.garage_invites i where i.garage_id = gid), '[]'::jsonb))
  end;
$fn$;

create or replace function public.set_staff_role(
  gid uuid, member uuid, new_role text)
returns void language plpgsql security definer
set search_path = public as $fn$
begin
  if public.member_role(gid) is distinct from 'owner' then
    raise exception 'Only the workshop owner can change roles.'
      using errcode = 'insufficient_privilege';
  end if;
  if new_role not in ('manager', 'mechanic', 'counter', 'accountant') then
    raise exception 'Pick a role: manager, mechanic, counter or accountant.'
      using errcode = 'check_violation';
  end if;
  update public.garage_members
     set role = new_role, permissions = '{}'::jsonb
   where garage_id = gid and profile_id = member and role <> 'owner';
  if not found then
    raise exception 'That person is not on this team.'
      using errcode = 'no_data_found';
  end if;
  update public.staff s set role = new_role
    from public.garage_members m
   where m.garage_id = gid and m.profile_id = member
     and s.id = m.staff_id and s.garage_id = gid;
end $fn$;

-- Takes the app away from one person: they are signed out of this
-- workshop on their next sync, and their phone stops getting its alerts.
-- The staff record, and every job card they worked on, stay.
create or replace function public.remove_staff_access(gid uuid, member uuid)
returns void language plpgsql security definer
set search_path = public as $fn$
begin
  if public.member_role(gid) is distinct from 'owner' then
    raise exception 'Only the workshop owner can remove app access.'
      using errcode = 'insufficient_privilege';
  end if;
  delete from public.garage_members
   where garage_id = gid and profile_id = member and role <> 'owner';
  if not found then
    raise exception 'That person is not on this team.'
      using errcode = 'no_data_found';
  end if;
  delete from public.garage_devices
   where garage_id = gid and profile_id = member;
end $fn$;

create or replace function public.cancel_staff_invite(gid uuid, invite_email text)
returns void language plpgsql security definer
set search_path = public as $fn$
begin
  if public.member_role(gid) is distinct from 'owner' then
    raise exception 'Only the workshop owner can cancel an invitation.'
      using errcode = 'insufficient_privilege';
  end if;
  delete from public.garage_invites
   where garage_id = gid and email = lower(btrim(invite_email));
end $fn$;

revoke execute on function public.invite_staff(jsonb) from public, anon;
revoke execute on function public.claim_staff_invite() from public, anon;
revoke execute on function public.garage_team(uuid) from public, anon;
revoke execute on function public.set_staff_role(uuid, uuid, text)
  from public, anon;
revoke execute on function public.remove_staff_access(uuid, uuid)
  from public, anon;
revoke execute on function public.cancel_staff_invite(uuid, text)
  from public, anon;
revoke execute on function public.guard_job_card_role() from public, anon, authenticated;
revoke execute on function public.guard_attendance_self() from public, anon, authenticated;
grant execute on function public.invite_staff(jsonb) to authenticated;
grant execute on function public.claim_staff_invite() to authenticated;
grant execute on function public.garage_team(uuid) to authenticated;
grant execute on function public.set_staff_role(uuid, uuid, text) to authenticated;
grant execute on function public.remove_staff_access(uuid, uuid) to authenticated;
grant execute on function public.cancel_staff_invite(uuid, text) to authenticated;

-- `my_access()` (04) is what the app reads to draw its menus.
revoke execute on function public.my_access(uuid) from public, anon;
grant execute on function public.my_access(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- 9. Check
-- ---------------------------------------------------------------------
-- Every workshop's team: one owner each, then staff and invitations.
select g.name as workshop, m.role, u.email, 'member' as status
  from public.garage_members m
  join public.garages g on g.id = m.garage_id
  join auth.users u on u.id = m.profile_id
union all
select g.name, i.role, i.email, 'invited'
  from public.garage_invites i
  join public.garages g on g.id = i.garage_id
 order by 1, 2;
