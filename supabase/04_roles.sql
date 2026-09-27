-- =====================================================================
-- GaragePro — roles, permissions and the activity log
-- =====================================================================
-- Run AFTER 02_garage.sql. Additive and idempotent: it can be run again
-- on a live project without losing anything.
--
-- Until now every member of a garage could do everything. That was fine
-- while a garage was one person. It is not fine once a workshop hires a
-- mechanic, because the client is the only thing standing between him and
-- the purchase rates — and the client is on his phone.
--
-- So the same five roles the app knows about exist here too, and the
-- policies below are the real boundary. The Dart in `lib/data/models/
-- roles.dart` decides which screens to draw; this decides which rows come
-- back. A tampered client gains nothing.
--
--   owner       everything, including cost and profit
--   manager     operations and billing, no owner settings, no payroll
--   mechanic    only the job cards assigned to him, nothing financial
--   counter     counter sale, stock, purchases
--   accountant  invoices, payments, ledgers, reports
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Who somebody is
-- ---------------------------------------------------------------------
-- `garage_members` is the auth-linked row: one per person who can sign in.
-- `staff` is the workshop's own record of a person, which a mechanic has
-- whether or not he ever opens the app. `staff_id` ties the two together,
-- and it is what the mechanic row filter matches on.

alter table public.garage_members
  add column if not exists staff_id text,
  add column if not exists permissions jsonb not null default '{}'::jsonb;

-- The old check allowed only owner/staff. Widen it to the five roles and
-- read the existing rows forward: everybody who was 'staff' becomes a
-- manager, which is what they effectively were.
do $$ begin
  alter table public.garage_members drop constraint if exists
    garage_members_role_check;
exception when undefined_object then null;
end $$;

update public.garage_members set role = 'manager' where role = 'staff';

-- Anything else that predates the five roles is read forward as a manager
-- too. Without this, one unrecognised value makes the constraint below
-- raise check_violation, which aborts the rest of this file — and the
-- columns and policies after it never land.
update public.garage_members
   set role = 'manager'
 where role is null
    or role not in ('owner','manager','mechanic','counter','accountant');

do $$ begin
  alter table public.garage_members
    add constraint garage_members_role_check
    check (role in ('owner','manager','mechanic','counter','accountant'));
exception when duplicate_object then null;
end $$;

-- The staff record gains everything the invite form collects.
alter table public.staff
  add column if not exists code            text not null default '',
  add column if not exists email           text not null default '',
  add column if not exists role            text not null default 'mechanic',
  add column if not exists permissions     jsonb not null default '{}'::jsonb,
  add column if not exists salary          numeric(12,2) not null default 0,
  add column if not exists street          text not null default '',
  add column if not exists city            text not null default '',
  add column if not exists state           text not null default '',
  add column if not exists pin             text not null default '',
  add column if not exists country         text not null default 'India',
  add column if not exists whatsapp_opt_in boolean not null default true,
  add column if not exists joined_at       timestamptz not null default now();

update public.staff
   set role = 'mechanic'
 where role is null
    or role not in ('owner','manager','mechanic','counter','accountant');

do $$ begin
  alter table public.staff
    add constraint staff_role_check
    check (role in ('owner','manager','mechanic','counter','accountant'));
exception when duplicate_object then null;
end $$;

-- Passwords are deliberately NOT here. Staff sign-in on a device is a
-- local gate; anybody who needs to reach Postgres gets a real auth user
-- and a row in garage_members. Storing a second password store beside
-- Supabase Auth would be two things to get wrong instead of one.

create index if not exists garage_members_staff_idx
  on public.garage_members (garage_id, staff_id);

-- ---------------------------------------------------------------------
-- 2. The activity log
-- ---------------------------------------------------------------------
-- Append-only by policy, not by convention: there is no update and no
-- delete grant below, for anybody, including the owner. A log somebody
-- can tidy up is worse than no log, because it still looks like evidence.

create table if not exists public.activity (
  id         text primary key,
  garage_id  uuid not null references public.garages (id) on delete cascade,
  at         timestamptz not null default now(),
  kind       text not null default 'updated',
  summary    text not null default '',
  subject    text not null default '',
  -- The name is stored alongside the id so somebody who leaves and is
  -- removed does not erase their own history.
  staff_id   text not null default '',
  staff_name text not null default ''
);
create index if not exists activity_garage_idx
  on public.activity (garage_id, at desc);

alter table public.activity enable row level security;

-- ---------------------------------------------------------------------
-- 3. Asking what somebody may do
-- ---------------------------------------------------------------------

-- The caller's role at this garage, or null if they do not work there.
create or replace function public.member_role(gid uuid)
returns text language sql stable security definer
set search_path = public as $$
  select m.role from public.garage_members m
  where m.garage_id = gid and m.profile_id = auth.uid()
  limit 1;
$$;

-- The staff row the caller is, if any. Null for an owner who was never
-- also entered as a mechanic.
create or replace function public.member_staff_id(gid uuid)
returns text language sql stable security definer
set search_path = public as $$
  select m.staff_id from public.garage_members m
  where m.garage_id = gid and m.profile_id = auth.uid()
  limit 1;
$$;

-- The stored override grid, in the same `{"jobCards":"vce"}` shape the
-- client writes. Empty means "use the role's defaults".
create or replace function public.member_grid(gid uuid)
returns jsonb language sql stable security definer
set search_path = public as $$
  select coalesce(m.permissions, '{}'::jsonb) from public.garage_members m
  where m.garage_id = gid and m.profile_id = auth.uid()
  limit 1;
$$;

-- What a role may do by default. Mirrors `Permissions.forRole` in Dart.
-- Kept as one function so the two can be read side by side and compared.
create or replace function public.role_grid(r text)
returns jsonb language sql immutable as $$
  select case r
    when 'owner' then '{
      "jobCards":"vced","inventory":"vced","customers":"vced",
      "vehicles":"vced","reports":"vced","users":"vced",
      "insurance":"vced","leaves":"vced","attendance":"vced",
      "payroll":"vced","jobCardPresets":"vced","counterSale":"vced",
      "purchases":"vced","finance":"vced","settings":"vced"}'::jsonb
    when 'manager' then '{
      "jobCards":"vced","inventory":"vce","customers":"vced",
      "vehicles":"vced","reports":"v","users":"v","insurance":"vce",
      "leaves":"vce","attendance":"vce","jobCardPresets":"vce",
      "counterSale":"vce","purchases":"vce","finance":"vce"}'::jsonb
    when 'mechanic' then '{
      "jobCards":"ve","inventory":"v","vehicles":"v","customers":"v",
      "attendance":"v","leaves":"vc"}'::jsonb
    when 'counter' then '{
      "jobCards":"vce","inventory":"vced","customers":"vce",
      "vehicles":"vce","counterSale":"vced","purchases":"vce",
      "attendance":"v"}'::jsonb
    when 'accountant' then '{
      "jobCards":"v","customers":"v","inventory":"v","reports":"v",
      "insurance":"v","finance":"vced","purchases":"vce",
      "attendance":"v"}'::jsonb
    else '{}'::jsonb
  end;
$$;

-- May the caller do `action` on `module` at this garage?
-- `action` is one of 'v','c','e','d'.
create or replace function public.member_can(
  gid uuid, module text, action text
) returns boolean language sql stable security definer
set search_path = public as $$
  select coalesce(
    position(action in coalesce(
      nullif(public.member_grid(gid) ->> module, ''),
      public.role_grid(public.member_role(gid)) ->> module,
      ''
    )) > 0,
    false
  );
$$;

-- Does the caller see only the cards assigned to them?
create or replace function public.own_jobs_only(gid uuid)
returns boolean language sql stable security definer
set search_path = public as $$
  select public.member_role(gid) = 'mechanic';
$$;

-- May the caller see cost and margin? Never a mechanic.
create or replace function public.sees_cost(gid uuid)
returns boolean language sql stable security definer
set search_path = public as $$
  select public.member_role(gid) in
    ('owner','manager','counter','accountant');
$$;

-- ---------------------------------------------------------------------
-- 4. Role-aware policies
-- ---------------------------------------------------------------------
-- These replace the blanket "any member does anything" policies from
-- 02_garage.sql on the tables where the distinction matters. Tables not
-- listed here keep the member-wide policy, which is correct for them.

-- --- job cards: a mechanic sees only his own ------------------------
drop policy if exists job_cards_member on public.job_cards;

drop policy if exists job_cards_member_read on public.job_cards;
create policy job_cards_member_read on public.job_cards
  for select using (
    public.is_garage_member(garage_id)
    and public.member_can(garage_id, 'jobCards', 'v')
    and (
      not public.own_jobs_only(garage_id)
      or public.member_staff_id(garage_id) = any (mechanic_ids)
    )
  );

drop policy if exists job_cards_member_insert on public.job_cards;
create policy job_cards_member_insert on public.job_cards
  for insert with check (
    public.is_garage_member(garage_id)
    and public.member_can(garage_id, 'jobCards', 'c')
  );

drop policy if exists job_cards_member_update on public.job_cards;
create policy job_cards_member_update on public.job_cards
  for update using (
    public.is_garage_member(garage_id)
    and public.member_can(garage_id, 'jobCards', 'e')
    and (
      not public.own_jobs_only(garage_id)
      or public.member_staff_id(garage_id) = any (mechanic_ids)
    )
  ) with check (public.is_garage_member(garage_id));

drop policy if exists job_cards_member_delete on public.job_cards;
create policy job_cards_member_delete on public.job_cards
  for delete using (
    public.is_garage_member(garage_id)
    and public.member_can(garage_id, 'jobCards', 'd')
  );

-- --- the money: a mechanic cannot reach it at all -------------------
-- Payments hang off a job card, so the card's own visibility already
-- applies. What this adds is that a payment needs either the finance
-- permission or the right to edit the card it belongs to.
--
-- Both, rather than finance alone, because the counter takes advances at
-- the desk without being the accountant — and a rule the app has to work
-- around is a rule somebody eventually turns off. A mechanic has neither,
-- which is the case this is here for.
drop policy if exists payments_member on public.payments;

create policy payments_member on public.payments
  for all using (
    public.owns_job_card(job_card_id)
    and exists (
      select 1 from public.job_cards j
      where j.id = job_card_id
        and (public.member_can(j.garage_id, 'finance', 'v')
             or public.member_can(j.garage_id, 'jobCards', 'e'))
    )
  ) with check (
    public.owns_job_card(job_card_id)
    and exists (
      select 1 from public.job_cards j
      where j.id = job_card_id
        and (public.member_can(j.garage_id, 'finance', 'c')
             or public.member_can(j.garage_id, 'jobCards', 'e'))
    )
  );

-- --- the masters: everyone reads, fewer people write ----------------
drop policy if exists masters_member on public.masters;

drop policy if exists masters_member_read on public.masters;
create policy masters_member_read on public.masters
  for select using (
    public.is_garage_member(garage_id)
    and public.member_can(garage_id, 'inventory', 'v')
  );

drop policy if exists masters_member_write on public.masters;
create policy masters_member_write on public.masters
  for all using (
    public.is_garage_member(garage_id)
    and public.member_can(garage_id, 'inventory', 'e')
  ) with check (
    public.is_garage_member(garage_id)
    and public.member_can(garage_id, 'inventory', 'e')
  );

-- --- the team list: only people who manage users --------------------
drop policy if exists staff_member on public.staff;

drop policy if exists staff_member_read on public.staff;
create policy staff_member_read on public.staff
  for select using (
    public.is_garage_member(garage_id)
    and (
      public.member_can(garage_id, 'users', 'v')
      -- A mechanic still needs to read his own row and his colleagues'
      -- names, because a job card prints who worked on it.
      or public.member_can(garage_id, 'jobCards', 'v')
    )
  );

drop policy if exists staff_member_write on public.staff;
create policy staff_member_write on public.staff
  for all using (
    public.is_garage_member(garage_id)
    and public.member_can(garage_id, 'users', 'e')
  ) with check (
    public.is_garage_member(garage_id)
    and public.member_can(garage_id, 'users', 'e')
  );

-- --- who may hand out permissions -----------------------------------
-- Only an owner. Otherwise a manager could quietly promote themselves,
-- which makes the whole grid decorative.
drop policy if exists garage_members_manage on public.garage_members;

drop policy if exists garage_members_owner_manage on public.garage_members;
create policy garage_members_owner_manage on public.garage_members
  for all using (public.member_role(garage_id) = 'owner')
  with check (public.member_role(garage_id) = 'owner');

-- --- the activity log: write and read, never edit -------------------
drop policy if exists activity_member_read on public.activity;
create policy activity_member_read on public.activity
  for select using (
    public.is_garage_member(garage_id)
    and public.member_can(garage_id, 'users', 'v')
  );

drop policy if exists activity_member_insert on public.activity;
create policy activity_member_insert on public.activity
  for insert with check (public.is_garage_member(garage_id));

-- Nothing signed-out reaches the log either. The equivalent sweep in
-- 03_sync.sql cannot cover this table, because it runs before this file
-- creates it.
revoke all on public.activity from anon;

-- There is deliberately no update and no delete policy on this table.
-- With row level security on and no policy granting them, both are
-- refused for everybody — including the owner, including the service
-- role's absence. That is the point.

-- ---------------------------------------------------------------------
-- 5. Reading the caller's own access back
-- ---------------------------------------------------------------------
-- The client calls this once on sign-in so it can draw the right menu,
-- rather than guessing from a role string it stored locally.

create or replace function public.my_access(gid uuid)
returns jsonb language sql stable security definer
set search_path = public as $$
  select jsonb_build_object(
    'role',        coalesce(public.member_role(gid), ''),
    'staff_id',    coalesce(public.member_staff_id(gid), ''),
    'permissions', case
                     when public.member_grid(gid) = '{}'::jsonb
                       then public.role_grid(public.member_role(gid))
                     else public.member_grid(gid)
                   end,
    'sees_cost',   public.sees_cost(gid),
    'own_jobs_only', public.own_jobs_only(gid)
  );
$$;

grant execute on function public.my_access(uuid) to authenticated;
grant execute on function public.member_can(uuid, text, text) to authenticated;

-- ---------------------------------------------------------------------
-- 6. The owner of an existing garage keeps being the owner
-- ---------------------------------------------------------------------
-- 02_garage.sql wrote 'owner' for whoever created the garage, so nothing
-- to do there. This is the safety net for any row that lost its role.

update public.garage_members m
   set role = 'owner'
 where m.role is null
    or m.role = ''
    or not exists (
      select 1 from public.garage_members o
      where o.garage_id = m.garage_id and o.role = 'owner'
    );
