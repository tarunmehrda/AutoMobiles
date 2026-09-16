-- =====================================================================
-- GaragePro — workshop (Admin) schema
-- =====================================================================
-- Run this AFTER 01_customer.sql, in the Supabase SQL editor. It is
-- additive and idempotent: it creates the garage side, bridges it to the
-- customer side, and does not touch the customer tables' columns.
--
--   ../User   the customer app — owns bookings, estimates, invoices
--   ../Admin  the workshop app — owns job cards, billing, stock
--
-- The two meet at `profiles`. A garage records a customer by phone; when
-- somebody signs up with that number their auth user is linked to the
-- garage's customer row, and from then on they can read — never write —
-- the job cards that garage opened for them.
-- =====================================================================

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------
-- Digits-only phone, so '+91 96969 69696' and '9696969696' match.
-- ---------------------------------------------------------------------
create or replace function public.norm_phone(p text)
returns text language sql immutable as $$
  select right(regexp_replace(coalesce(p, ''), '[^0-9]', '', 'g'), 10);
$$;

-- ---------------------------------------------------------------------
-- Profiles gain a role, and the customer booking gains the garage's own
-- record of the visit. Both are additive.
-- ---------------------------------------------------------------------
alter table public.profiles
  add column if not exists role text not null default 'customer';

do $$ begin
  alter table public.profiles
    add constraint profiles_role_check
    check (role in ('customer', 'owner', 'staff'));
exception when duplicate_object then null;
end $$;

create index if not exists profiles_phone_idx
  on public.profiles (public.norm_phone(phone));

alter table public.bookings
  add column if not exists job_card jsonb;

-- =====================================================================
-- 1. The workshop
-- =====================================================================
create table if not exists public.garages (
  id           uuid primary key default gen_random_uuid(),
  owner_id     uuid not null references auth.users (id) on delete cascade,
  name         text not null default '',
  phone        text not null default '',
  alt_phone    text not null default '',
  email        text not null default '',
  address_line text not null default '',
  city         text not null default '',
  state        text not null default '',
  pin          text not null default '',
  gstin        text not null default '',
  upi_id       text not null default '',
  terms        text not null default '',
  logo_path    text,
  plan_expiry  timestamptz,
  -- Running counter behind the job card number, reset per calendar day.
  seq_day      date,
  seq          int not null default 0,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index if not exists garages_owner_idx on public.garages (owner_id);

-- Who may operate a garage. The owner row is created by create_garage().
create table if not exists public.garage_members (
  garage_id  uuid not null references public.garages (id) on delete cascade,
  profile_id uuid not null references auth.users (id) on delete cascade,
  role       text not null default 'staff' check (role in ('owner', 'staff')),
  created_at timestamptz not null default now(),
  primary key (garage_id, profile_id)
);
create index if not exists garage_members_profile_idx
  on public.garage_members (profile_id);

-- Mechanics on the floor. Not auth users — they do not sign in.
create table if not exists public.staff (
  id         text primary key,
  garage_id  uuid not null references public.garages (id) on delete cascade,
  name       text not null default '',
  phone      text not null default '',
  skill      text not null default '',
  active     boolean not null default true,
  created_at timestamptz not null default now()
);
create index if not exists staff_garage_idx on public.staff (garage_id);

-- =====================================================================
-- 2. The garage's customer book
-- =====================================================================
-- profile_id is filled in if and when that person signs up with the same
-- phone number. Until then the record is the garage's alone.
create table if not exists public.garage_customers (
  id         text primary key,
  garage_id  uuid not null references public.garages (id) on delete cascade,
  profile_id uuid references auth.users (id) on delete set null,
  name       text not null default '',
  phone      text not null default '',
  alt_phone  text not null default '',
  email      text not null default '',
  address    text not null default '',
  created_at timestamptz not null default now()
);
create index if not exists garage_customers_garage_idx
  on public.garage_customers (garage_id);
create index if not exists garage_customers_profile_idx
  on public.garage_customers (profile_id);
create unique index if not exists garage_customers_unique_phone
  on public.garage_customers (garage_id, public.norm_phone(phone));

create table if not exists public.garage_vehicles (
  id          text primary key,
  garage_id   uuid not null references public.garages (id) on delete cascade,
  customer_id text not null references public.garage_customers (id)
                on delete cascade,
  reg_no      text not null default '',
  brand       text not null default '',
  model       text not null default '',
  variant     text not null default '',
  fuel        text not null default 'petrol',
  year        int,
  vin         text not null default '',
  engine_no   text not null default '',
  colour      text not null default '',
  created_at  timestamptz not null default now()
);
create index if not exists garage_vehicles_garage_idx
  on public.garage_vehicles (garage_id);
create index if not exists garage_vehicles_customer_idx
  on public.garage_vehicles (customer_id);
create unique index if not exists garage_vehicles_unique_reg
  on public.garage_vehicles (garage_id, upper(replace(reg_no, ' ', '')));

-- =====================================================================
-- 3. Stock and rates
-- =====================================================================
create table if not exists public.masters (
  id         text primary key,
  garage_id  uuid not null references public.garages (id) on delete cascade,
  kind       text not null check (kind in ('job', 'spare', 'lube')),
  name       text not null default '',
  part_no    text not null default '',
  rate       numeric(12,2) not null default 0,
  stock      numeric(12,2) not null default 0,
  unit       text not null default 'nos',
  low_at     numeric(12,2) not null default 2,
  created_at timestamptz not null default now()
);
create index if not exists masters_garage_kind_idx
  on public.masters (garage_id, kind);

-- =====================================================================
-- 4. Job cards
-- =====================================================================
create table if not exists public.job_cards (
  id                  text primary key,
  garage_id           uuid not null references public.garages (id)
                        on delete cascade,
  customer_id         text not null references public.garage_customers (id)
                        on delete cascade,
  vehicle_id          text not null references public.garage_vehicles (id)
                        on delete cascade,
  -- Denormalised so a customer can read their own cards without a join
  -- that row level security would have to walk on every request.
  customer_profile_id uuid references auth.users (id) on delete set null,
  number              text not null,
  status              text not null default 'open'
                        check (status in ('open', 'complete', 'closed')),
  created_at          timestamptz not null default now(),
  completed_at        timestamptz,
  closed_at           timestamptz,
  promised_at         timestamptz,
  odometer_km         int not null default 0,
  fuel_percent        int not null default 0,
  mechanic_ids        text[] not null default '{}',
  voices              text[] not null default '{}',
  accessories         text[] not null default '{}',
  work_note           text not null default '',
  dents               jsonb not null default '[]'::jsonb,
  photos              text[] not null default '{}',
  discount            numeric(12,2) not null default 0,
  tax_rate            numeric(6,4) not null default 0,
  next_service_at     timestamptz,
  next_service_km     int,
  estimate_sent_at    timestamptz,
  updated_at          timestamptz not null default now()
);
create index if not exists job_cards_garage_status_idx
  on public.job_cards (garage_id, status, created_at desc);
create index if not exists job_cards_vehicle_idx
  on public.job_cards (vehicle_id, created_at desc);
create index if not exists job_cards_profile_idx
  on public.job_cards (customer_profile_id, created_at desc);
create unique index if not exists job_cards_unique_number
  on public.job_cards (garage_id, number);

create table if not exists public.line_items (
  id          text primary key,
  job_card_id text not null references public.job_cards (id) on delete cascade,
  kind        text not null check (kind in ('job', 'spare', 'lube')),
  name        text not null default '',
  part_no     text not null default '',
  qty         numeric(12,2) not null default 1,
  rate        numeric(12,2) not null default 0,
  mechanic_id text,
  state       text not null default 'pending'
                check (state in ('pending', 'running', 'done', 'skipped')),
  remark      text not null default '',
  master_id   text,
  position    int not null default 0
);
create index if not exists line_items_card_idx
  on public.line_items (job_card_id, position);

create table if not exists public.payments (
  id          text primary key,
  job_card_id text not null references public.job_cards (id) on delete cascade,
  amount      numeric(12,2) not null default 0,
  mode        text not null default 'cash'
                check (mode in ('cash', 'upi', 'card', 'netbanking', 'cheque')),
  at          timestamptz not null default now(),
  note        text not null default ''
);
create index if not exists payments_card_idx
  on public.payments (job_card_id, at);

create table if not exists public.sms_events (
  id          text primary key,
  job_card_id text not null references public.job_cards (id) on delete cascade,
  label       text not null default '',
  at          timestamptz not null default now(),
  state       text not null default 'scheduled'
                check (state in ('delivered', 'scheduled', 'failed', 'skipped'))
);
create index if not exists sms_events_card_idx
  on public.sms_events (job_card_id, at);

-- =====================================================================
-- 5. Front desk
-- =====================================================================
create table if not exists public.garage_bookings (
  id          text primary key,
  garage_id   uuid not null references public.garages (id) on delete cascade,
  profile_id  uuid references auth.users (id) on delete set null,
  name        text not null default '',
  phone       text not null default '',
  at          timestamptz not null default now(),
  reg_no      text not null default '',
  vehicle     text not null default '',
  note        text not null default '',
  accepted    boolean not null default false,
  job_card_id text references public.job_cards (id) on delete set null,
  created_at  timestamptz not null default now()
);
create index if not exists garage_bookings_garage_idx
  on public.garage_bookings (garage_id, accepted, at);

create table if not exists public.reviews (
  id          text primary key,
  garage_id   uuid not null references public.garages (id) on delete cascade,
  job_card_id text not null references public.job_cards (id) on delete cascade,
  profile_id  uuid references auth.users (id) on delete set null,
  stars       int not null default 5 check (stars between 1 and 5),
  at          timestamptz not null default now(),
  comment     text not null default ''
);
create index if not exists reviews_garage_idx
  on public.reviews (garage_id, at desc);
create unique index if not exists reviews_unique_card
  on public.reviews (job_card_id);

-- =====================================================================
-- 6. The bridge
-- =====================================================================

-- Keeps job_cards.customer_profile_id in step with the customer book.
create or replace function public.sync_job_card_profile()
returns trigger language plpgsql security definer
set search_path = public as $$
begin
  select c.profile_id into new.customer_profile_id
  from public.garage_customers c
  where c.id = new.customer_id;
  return new;
end $$;

drop trigger if exists job_cards_sync_profile on public.job_cards;
create trigger job_cards_sync_profile
  before insert or update of customer_id on public.job_cards
  for each row execute function public.sync_job_card_profile();

-- When a customer record gets linked to an auth user, its history follows.
create or replace function public.backfill_job_card_profiles()
returns trigger language plpgsql security definer
set search_path = public as $$
begin
  if new.profile_id is distinct from old.profile_id then
    update public.job_cards
       set customer_profile_id = new.profile_id
     where customer_id = new.id;
  end if;
  return new;
end $$;

drop trigger if exists garage_customers_backfill on public.garage_customers;
create trigger garage_customers_backfill
  after update of profile_id on public.garage_customers
  for each row execute function public.backfill_job_card_profiles();

-- =====================================================================
-- 7. Row level security
-- =====================================================================
alter table public.garages          enable row level security;
alter table public.garage_members   enable row level security;
alter table public.staff            enable row level security;
alter table public.garage_customers enable row level security;
alter table public.garage_vehicles  enable row level security;
alter table public.masters          enable row level security;
alter table public.job_cards        enable row level security;
alter table public.line_items       enable row level security;
alter table public.payments         enable row level security;
alter table public.sms_events       enable row level security;
alter table public.garage_bookings  enable row level security;
alter table public.reviews          enable row level security;

-- Membership test. SECURITY DEFINER so the policy on garage_members never
-- has to consult itself.
create or replace function public.is_garage_member(gid uuid)
returns boolean language sql stable security definer
set search_path = public as $$
  select exists (
    select 1 from public.garage_members m
    where m.garage_id = gid and m.profile_id = auth.uid()
  );
$$;

-- Does the caller work at the garage this card belongs to?
create or replace function public.owns_job_card(card text)
returns boolean language sql stable security definer
set search_path = public as $$
  select exists (
    select 1 from public.job_cards j
    where j.id = card and public.is_garage_member(j.garage_id)
  );
$$;

-- ...or is it their own car?
create or replace function public.reads_job_card(card text)
returns boolean language sql stable security definer
set search_path = public as $$
  select exists (
    select 1 from public.job_cards j
    where j.id = card
      and (public.is_garage_member(j.garage_id)
           or j.customer_profile_id = auth.uid())
  );
$$;

-- Has the caller ever dealt with this garage?
create or replace function public.deals_with_garage(gid uuid)
returns boolean language sql stable security definer
set search_path = public as $$
  select exists (
    select 1 from public.job_cards j
    where j.garage_id = gid and j.customer_profile_id = auth.uid()
  ) or exists (
    select 1 from public.garage_bookings b
    where b.garage_id = gid and b.profile_id = auth.uid()
  );
$$;

-- --- the workshop ----------------------------------------------------
drop policy if exists garages_member_all on public.garages;
create policy garages_member_all on public.garages
  for all using (public.is_garage_member(id))
  with check (owner_id = auth.uid() or public.is_garage_member(id));

-- A customer reads the letterhead of a garage they have actually used —
-- that is what heads their invoice. Not a directory of every workshop.
drop policy if exists garages_customer_read on public.garages;
create policy garages_customer_read on public.garages
  for select using (public.deals_with_garage(id));

drop policy if exists garage_members_self on public.garage_members;
create policy garage_members_self on public.garage_members
  for select using (
    profile_id = auth.uid() or public.is_garage_member(garage_id)
  );

drop policy if exists garage_members_manage on public.garage_members;
create policy garage_members_manage on public.garage_members
  for all using (
    exists (select 1 from public.garages g
            where g.id = garage_id and g.owner_id = auth.uid())
  ) with check (
    exists (select 1 from public.garages g
            where g.id = garage_id and g.owner_id = auth.uid())
  );

-- --- garage-scoped tables: members do everything ---------------------
do $$
declare t text;
begin
  foreach t in array array[
    'staff','garage_customers','garage_vehicles','masters',
    'job_cards','garage_bookings'
  ] loop
    execute format('drop policy if exists %I_member on public.%I', t, t);
    execute format(
      'create policy %I_member on public.%I for all
         using (public.is_garage_member(garage_id))
         with check (public.is_garage_member(garage_id))', t, t);
  end loop;
end $$;

-- --- job card children: reachable through the card -------------------
do $$
declare t text;
begin
  foreach t in array array['line_items','payments','sms_events'] loop
    execute format('drop policy if exists %I_member on public.%I', t, t);
    execute format(
      'create policy %I_member on public.%I for all
         using (public.owns_job_card(job_card_id))
         with check (public.owns_job_card(job_card_id))', t, t);

    execute format('drop policy if exists %I_customer_read on public.%I', t, t);
    execute format(
      'create policy %I_customer_read on public.%I for select
         using (public.reads_job_card(job_card_id))', t, t);
  end loop;
end $$;

-- --- what a customer may see of the garage side ----------------------
drop policy if exists job_cards_customer_read on public.job_cards;
create policy job_cards_customer_read on public.job_cards
  for select using (customer_profile_id = auth.uid());

drop policy if exists garage_vehicles_customer_read on public.garage_vehicles;
create policy garage_vehicles_customer_read on public.garage_vehicles
  for select using (
    exists (select 1 from public.garage_customers c
            where c.id = customer_id and c.profile_id = auth.uid())
  );

drop policy if exists garage_customers_self_read on public.garage_customers;
create policy garage_customers_self_read on public.garage_customers
  for select using (profile_id = auth.uid());

-- The mechanic's name appears on the customer's job card, so they may read
-- the staff of a garage they have used — and nobody else's.
drop policy if exists staff_customer_read on public.staff;
create policy staff_customer_read on public.staff
  for select using (public.deals_with_garage(garage_id));

-- A customer raises a booking request and reads their own.
drop policy if exists garage_bookings_customer_read on public.garage_bookings;
create policy garage_bookings_customer_read on public.garage_bookings
  for select using (profile_id = auth.uid());

drop policy if exists garage_bookings_customer_insert on public.garage_bookings;
create policy garage_bookings_customer_insert on public.garage_bookings
  for insert with check (profile_id = auth.uid());

-- --- reviews ----------------------------------------------------------
drop policy if exists reviews_read on public.reviews;
create policy reviews_read on public.reviews
  for select using (
    public.is_garage_member(garage_id) or profile_id = auth.uid()
  );

-- Only against a closed card that is genuinely theirs.
drop policy if exists reviews_customer_insert on public.reviews;
create policy reviews_customer_insert on public.reviews
  for insert with check (
    profile_id = auth.uid()
    and exists (select 1 from public.job_cards j
                where j.id = job_card_id
                  and j.customer_profile_id = auth.uid()
                  and j.status = 'closed')
  );

drop policy if exists reviews_customer_update on public.reviews;
create policy reviews_customer_update on public.reviews
  for update using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

-- =====================================================================
-- 8. The customer's view of a job card
-- =====================================================================
-- The customer app reads this, never the tables underneath. security_invoker
-- means the policies above still apply — the view only shapes the result.
create or replace view public.my_job_cards
with (security_invoker = true) as
select
  j.id,
  j.number,
  j.status,
  j.created_at        as opened_at,
  j.completed_at,
  j.closed_at,
  j.promised_at,
  j.odometer_km,
  j.fuel_percent,
  j.voices,
  j.accessories,
  j.work_note,
  j.dents,
  j.photos,
  j.next_service_at,
  j.next_service_km,
  j.discount,
  j.tax_rate,
  g.id                as garage_id,
  g.name              as garage_name,
  g.phone             as garage_phone,
  g.gstin             as garage_gstin,
  v.reg_no,
  trim(concat_ws(' ', v.brand, v.model, v.variant)) as vehicle_title,
  (
    select coalesce(string_agg(s.name, ', '), '')
    from public.staff s
    where s.id = any (j.mechanic_ids)
  )                   as mechanic,
  (
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', li.id, 'kind', li.kind, 'name', li.name,
          'part_no', li.part_no, 'qty', li.qty, 'rate', li.rate,
          'state', li.state, 'remark', li.remark
        ) order by li.position
      ), '[]'::jsonb)
    from public.line_items li
    where li.job_card_id = j.id
  )                   as items,
  (
    select coalesce(sum(p.amount), 0)
    from public.payments p
    where p.job_card_id = j.id
  )                   as paid
from public.job_cards j
join public.garages g         on g.id = j.garage_id
join public.garage_vehicles v on v.id = j.vehicle_id
where j.customer_profile_id = auth.uid();

-- =====================================================================
-- 9. Sign-up plumbing (supersedes the version in 01_customer.sql)
-- =====================================================================
-- Creates the profile, carries across whatever the provider gave us —
-- Google sends a name and a picture, email sign-up sends neither — and
-- links the new user to any garage customer record with the same phone.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer
set search_path = public as $$
declare
  meta         jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  full_name    text;
  avatar       text;
  phone_digits text;
begin
  full_name := coalesce(
    meta ->> 'full_name', meta ->> 'name', meta ->> 'user_name', '');
  avatar := coalesce(meta ->> 'avatar_url', meta ->> 'picture');
  phone_digits := public.norm_phone(coalesce(new.phone, meta ->> 'phone', ''));

  insert into public.profiles (id, name, phone, email, avatar_url, role)
  values (
    new.id,
    full_name,
    coalesce(new.phone, meta ->> 'phone', ''),
    new.email,
    avatar,
    coalesce(meta ->> 'role', 'customer'))
  on conflict (id) do update
    set name       = case when profiles.name = '' then excluded.name
                          else profiles.name end,
        email      = coalesce(profiles.email, excluded.email),
        avatar_url = coalesce(profiles.avatar_url, excluded.avatar_url);

  if phone_digits <> '' then
    update public.garage_customers
       set profile_id = new.id
     where profile_id is null
       and public.norm_phone(phone) = phone_digits;
  end if;

  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Somebody who adds their phone number later still gets linked.
create or replace function public.link_profile_to_customers()
returns trigger language plpgsql security definer
set search_path = public as $$
begin
  if public.norm_phone(new.phone) <> '' then
    update public.garage_customers
       set profile_id = new.id
     where profile_id is null
       and public.norm_phone(phone) = public.norm_phone(new.phone);
  end if;
  return new;
end $$;

drop trigger if exists profiles_link_customers on public.profiles;
create trigger profiles_link_customers
  after insert or update of phone on public.profiles
  for each row execute function public.link_profile_to_customers();

-- =====================================================================
-- 10. Server-side helpers the apps call
-- =====================================================================

-- Creates a workshop and makes the caller its owner in one transaction, so
-- a garage can never exist with nobody able to open it.
create or replace function public.create_garage(payload jsonb)
returns public.garages language plpgsql security definer
set search_path = public as $$
declare g public.garages;
begin
  if auth.uid() is null then
    raise exception 'not signed in';
  end if;

  insert into public.garages (
    owner_id, name, phone, alt_phone, email, address_line,
    city, state, pin, gstin, upi_id, terms, plan_expiry)
  values (
    auth.uid(),
    coalesce(payload ->> 'name', ''),
    coalesce(payload ->> 'phone', ''),
    coalesce(payload ->> 'alt_phone', ''),
    coalesce(payload ->> 'email', ''),
    coalesce(payload ->> 'address_line', ''),
    coalesce(payload ->> 'city', ''),
    coalesce(payload ->> 'state', ''),
    coalesce(payload ->> 'pin', ''),
    coalesce(payload ->> 'gstin', ''),
    coalesce(payload ->> 'upi_id', ''),
    coalesce(payload ->> 'terms', ''),
    nullif(payload ->> 'plan_expiry', '')::timestamptz)
  returning * into g;

  insert into public.garage_members (garage_id, profile_id, role)
  values (g.id, auth.uid(), 'owner')
  on conflict do nothing;

  update public.profiles set role = 'owner' where id = auth.uid();

  return g;
end $$;

-- Mints the next job card number: A + MMDD + the day's running count.
-- The UPDATE takes a row lock, so two counters cannot take the same one.
create or replace function public.next_job_number(gid uuid)
returns text language plpgsql security definer
set search_path = public as $$
declare
  today date := (now() at time zone 'Asia/Kolkata')::date;
  n int;
begin
  if not public.is_garage_member(gid) then
    raise exception 'not a member of this garage';
  end if;

  update public.garages
     set seq = case when seq_day = today then seq + 1 else 1 end,
         seq_day = today
   where id = gid
  returning seq into n;

  return 'A' || to_char(today, 'MMDD') || '-' || lpad(n::text, 3, '0');
end $$;

-- The dashboard counters, in one round trip.
create or replace function public.garage_summary(gid uuid)
returns jsonb language sql stable security definer
set search_path = public as $$
  select case when not public.is_garage_member(gid) then '{}'::jsonb else
    jsonb_build_object(
      'open',     count(*) filter (where status = 'open'),
      'complete', count(*) filter (where status = 'complete'),
      'closed',   count(*) filter (where status = 'closed'),
      'total',    count(*))
  end
  from public.job_cards where garage_id = gid;
$$;

grant execute on function public.create_garage(jsonb)  to authenticated;
grant execute on function public.next_job_number(uuid) to authenticated;
grant execute on function public.garage_summary(uuid)  to authenticated;
grant select on public.my_job_cards to authenticated;

-- =====================================================================
-- 11. Realtime
-- =====================================================================
do $$
declare t text;
begin
  foreach t in array array[
    'job_cards','line_items','payments','garage_bookings'
  ] loop
    begin
      execute format(
        'alter publication supabase_realtime add table public.%I', t);
    exception when duplicate_object then null;
    end;
  end loop;
end $$;
