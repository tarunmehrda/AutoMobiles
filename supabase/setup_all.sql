-- =====================================================================
-- GaragePro — COMPLETE SETUP, in one file.
-- =====================================================================
-- This is 01_customer.sql + 02_garage.sql + 03_sync.sql + 04_roles.sql +
-- 05_attendance.sql + 06_notifications.sql + 07_share.sql +
-- 08_platform.sql + 09_marketplace.sql + 10_open_booking.sql
-- concatenated in
-- the order they must run. Paste the whole thing into the Supabase SQL
-- editor once. Nothing else needs running.
--
-- GENERATED FILE — do not edit. Edit the numbered files and re-run
-- ./build_setup.sh. Each still works individually; this exists so
-- the run order cannot go wrong.
--
-- Later sections deliberately redefine what earlier ones create:
-- handle_new_user() is written three times, each superseding the last.
-- That is why the order matters and why this must not be reordered.
--
-- It does NOT reset anything. To start clean, run 00_reset.sql first.
-- =====================================================================

-- #####################################################################
-- ###  BEGIN 01_customer.sql
-- #####################################################################

-- =====================================================================
-- GaragePro — customer app schema
-- =====================================================================
-- Run this once in the Supabase SQL editor. It creates every table the
-- app's SupabaseGateway reads and writes, with row level security so a
-- customer can only ever see their own rows.
--
-- Column names match the JSON keys produced by the Dart models exactly,
-- so no mapping layer is needed on either side.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Profiles (1:1 with auth.users)
-- ---------------------------------------------------------------------
create table if not exists public.profiles (
  id            uuid primary key references auth.users (id) on delete cascade,
  name          text not null default '',
  phone         text not null default '',
  email         text,
  dob           timestamptz,
  gender        text,
  avatar_url    text,
  referral_code text unique,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- Vehicles
-- ---------------------------------------------------------------------
create table if not exists public.vehicles (
  id                text primary key,
  user_id           uuid not null references auth.users (id) on delete cascade,
  brand             text not null,
  model             text not null,
  reg_number        text not null,
  fuel              text not null default 'petrol',
  transmission      text not null default 'manual',
  year              int  not null,
  body              text not null default 'hatchback',
  variant           text,
  odometer_km       int  not null default 0,
  image_url         text,
  insurance_expiry  timestamptz,
  puc_expiry        timestamptz,
  vin               text,
  is_primary        boolean not null default false,
  last_service_date timestamptz,
  last_service_km   int,
  color_hex         text,
  created_at        timestamptz not null default now()
);
create index if not exists vehicles_user_idx on public.vehicles (user_id);

-- ---------------------------------------------------------------------
-- Addresses
-- ---------------------------------------------------------------------
create table if not exists public.addresses (
  id            text primary key,
  user_id       uuid not null references auth.users (id) on delete cascade,
  label         text not null default 'Home',
  house         text not null default '',
  street        text not null default '',
  area          text not null default '',
  city          text not null default '',
  state         text not null default '',
  pin           text not null default '',
  landmark      text,
  contact_name  text,
  contact_phone text,
  is_default    boolean not null default false,
  created_at    timestamptz not null default now()
);
create index if not exists addresses_user_idx on public.addresses (user_id);

-- ---------------------------------------------------------------------
-- Bookings
-- ---------------------------------------------------------------------
create table if not exists public.bookings (
  id            text primary key,
  user_id       uuid not null references auth.users (id) on delete cascade,
  code          text not null unique,
  vehicle_id    text not null,
  lines         jsonb not null default '[]'::jsonb,
  mode          text not null default 'garage',
  slot          timestamptz not null,
  status        text not null default 'upcoming',
  stage         text not null default 'confirmed',
  timeline      jsonb not null default '[]'::jsonb,
  address_id    text,
  coupon_code   text,
  discount      int not null default 0,
  pickup_fee    int not null default 0,
  advisor       text,
  technician    text,
  eta_at        timestamptz,
  inspection_id text,
  estimate_ids  jsonb not null default '[]'::jsonb,
  invoice_id    text,
  cancel_reason text,
  rating        numeric,
  review_note   text,
  notes         text,
  created_at    timestamptz not null default now()
);
create index if not exists bookings_user_idx   on public.bookings (user_id);
create index if not exists bookings_status_idx on public.bookings (user_id, status);
create index if not exists bookings_slot_idx   on public.bookings (user_id, slot desc);

-- ---------------------------------------------------------------------
-- Digital inspections (one per booking)
-- ---------------------------------------------------------------------
create table if not exists public.inspections (
  id         text primary key,
  user_id    uuid not null references auth.users (id) on delete cascade,
  booking_id text not null references public.bookings (id) on delete cascade,
  items      jsonb not null default '[]'::jsonb,
  technician text,
  summary    text,
  created_at timestamptz not null default now()
);
create unique index if not exists inspections_booking_idx
  on public.inspections (booking_id);

-- ---------------------------------------------------------------------
-- Estimates — every revision is a new row, nothing is overwritten.
-- ---------------------------------------------------------------------
create table if not exists public.estimates (
  id             text primary key,
  user_id        uuid not null references auth.users (id) on delete cascade,
  booking_id     text not null references public.bookings (id) on delete cascade,
  version        int  not null default 1,
  items          jsonb not null default '[]'::jsonb,
  status         text not null default 'pending',
  reason         text,
  previous_total int,
  approved_at    timestamptz,
  approved_by    text,
  created_at     timestamptz not null default now(),
  unique (booking_id, version)
);
create index if not exists estimates_booking_idx
  on public.estimates (booking_id, version);

-- Estimates become immutable once approved: the customer's recorded
-- decision can never be edited after the fact.
create or replace function public.lock_approved_estimate()
returns trigger language plpgsql as $$
begin
  if old.status <> 'pending' then
    raise exception 'Approved estimates are immutable — issue a new version';
  end if;
  return new;
end $$;

drop trigger if exists estimates_immutable on public.estimates;
create trigger estimates_immutable
  before update on public.estimates
  for each row execute function public.lock_approved_estimate();

-- ---------------------------------------------------------------------
-- Invoices
-- ---------------------------------------------------------------------
create table if not exists public.invoices (
  id              text primary key,
  user_id         uuid not null references auth.users (id) on delete cascade,
  booking_id      text not null references public.bookings (id) on delete cascade,
  number          text not null unique,
  job_card_number text,
  lines           jsonb not null default '[]'::jsonb,
  discount        int not null default 0,
  pickup_fee      int not null default 0,
  paid            boolean not null default false,
  method          text,
  paid_at         timestamptz,
  transaction_id  text,
  created_at      timestamptz not null default now()
);
create unique index if not exists invoices_booking_idx
  on public.invoices (booking_id);

-- ---------------------------------------------------------------------
-- Notifications
-- ---------------------------------------------------------------------
create table if not exists public.notifications (
  id         text primary key,
  user_id    uuid not null references auth.users (id) on delete cascade,
  kind       text not null default 'service',
  title      text not null,
  body       text not null default '',
  read       boolean not null default false,
  booking_id text,
  route      text,
  at         timestamptz not null default now()
);
create index if not exists notifications_user_idx
  on public.notifications (user_id, at desc);

-- ---------------------------------------------------------------------
-- Support
-- ---------------------------------------------------------------------
create table if not exists public.tickets (
  id           text primary key,
  user_id      uuid not null references auth.users (id) on delete cascade,
  subject      text not null,
  category     text not null,
  body         text not null,
  status       text not null default 'Open',
  booking_code text,
  replies      jsonb not null default '[]'::jsonb,
  created_at   timestamptz not null default now()
);

create table if not exists public.chat_messages (
  id         text primary key,
  user_id    uuid not null references auth.users (id) on delete cascade,
  text       text not null default '',
  from_me    boolean not null default true,
  author     text,
  image_path text,
  topic      text,
  at         timestamptz not null default now()
);
create index if not exists chat_user_idx on public.chat_messages (user_id, at);

-- =====================================================================
-- Catalogue — workshop-owned, readable by every signed-in customer.
-- Seed these from lib/data/seed/catalog_seed.dart if you want the app
-- to read the catalogue remotely instead of from the bundled seed.
-- =====================================================================
create table if not exists public.service_categories (
  id       text primary key,
  name     text not null,
  tagline  text not null default '',
  icon     text,
  accent   text,
  featured boolean not null default false,
  sort     int not null default 0
);

create table if not exists public.service_packages (
  id                   text primary key,
  category_id          text not null references public.service_categories (id),
  name                 text not null,
  subtitle             text not null default '',
  description          text not null default '',
  mrp                  int not null,
  price                int not null,
  duration_hours       numeric not null default 1,
  warranty_months      int not null default 0,
  recommended_every_km int,
  includes             jsonb not null default '[]'::jsonb,
  excludes             jsonb not null default '[]'::jsonb,
  tags                 jsonb not null default '[]'::jsonb,
  groups               jsonb not null default '[]'::jsonb,
  rating               numeric not null default 4.7,
  review_count         int not null default 0,
  popular              boolean not null default false,
  active               boolean not null default true
);

create table if not exists public.add_ons (
  id            text primary key,
  name          text not null,
  blurb         text not null default '',
  price         int not null,
  mrp           int,
  duration_mins int not null default 30,
  active        boolean not null default true
);

create table if not exists public.coupons (
  code         text primary key,
  title        text not null,
  blurb        text not null default '',
  is_percent   boolean not null default false,
  value        int not null,
  min_order    int not null default 0,
  max_discount int,
  valid_till   timestamptz not null,
  active       boolean not null default true
);

-- Admin-controlled slot availability.
create table if not exists public.slots (
  id       bigserial primary key,
  day      date not null,
  time     text not null,
  capacity int not null default 4,
  booked   int not null default 0,
  unique (day, time)
);

-- =====================================================================
-- Row level security
-- =====================================================================
alter table public.profiles         enable row level security;
alter table public.vehicles         enable row level security;
alter table public.addresses        enable row level security;
alter table public.bookings         enable row level security;
alter table public.inspections      enable row level security;
alter table public.estimates        enable row level security;
alter table public.invoices         enable row level security;
alter table public.notifications    enable row level security;
alter table public.tickets          enable row level security;
alter table public.chat_messages    enable row level security;
alter table public.service_categories enable row level security;
alter table public.service_packages   enable row level security;
alter table public.add_ons            enable row level security;
alter table public.coupons            enable row level security;
alter table public.slots              enable row level security;

-- Profile: a user owns the row whose id is their uid.
drop policy if exists profiles_self on public.profiles;
create policy profiles_self on public.profiles
  for all using (auth.uid() = id) with check (auth.uid() = id);

-- Everything else: owned via user_id.
do $$
declare t text;
begin
  foreach t in array array[
    'vehicles','addresses','bookings','inspections','estimates',
    'invoices','notifications','tickets','chat_messages'
  ] loop
    execute format('drop policy if exists %I_own on public.%I', t, t);
    execute format(
      'create policy %I_own on public.%I for all
         using (auth.uid() = user_id) with check (auth.uid() = user_id)',
      t, t);
  end loop;
end $$;

-- Catalogue is read-only for customers; the workshop admin writes it
-- with the service-role key.
do $$
declare t text;
begin
  foreach t in array array[
    'service_categories','service_packages','add_ons','coupons','slots'
  ] loop
    execute format('drop policy if exists %I_read on public.%I', t, t);
    execute format(
      'create policy %I_read on public.%I for select
         using (auth.role() = ''authenticated'')', t, t);
  end loop;
end $$;

-- =====================================================================
-- Convenience: create the profile row automatically on sign-up.
-- =====================================================================
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles (id, phone, name)
  values (new.id, coalesce(new.phone, ''), '')
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();


-- #####################################################################
-- ###  BEGIN 02_garage.sql
-- #####################################################################

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
-- 0. Clear the superseded signatures
-- ---------------------------------------------------------------------
-- An earlier, standalone version of this schema shipped in
-- Admin/supabase/schema.sql. Where it has been run against a project, its
-- functions are still there and they block this one two ways:
--
--   * `create_garage(payload json)` and `save_job_card(payload json)` take
--     `json` where these take `jsonb`, so both survive side by side as
--     overloads. PostgREST cannot pick between them and answers PGRST203 —
--     which is the console failing to register a workshop at all.
--   * `my_garage()`, `garage_snapshot()` and `job_card_detail()` have the
--     same argument lists but return `json`. CREATE OR REPLACE cannot
--     change a return type, so this file used to abort on the first of
--     them and everything after it silently never ran.
--
-- Dropping them by their old signatures is what lets the definitions below
-- land. Nothing is lost: every one of them is recreated further down, and
-- CASCADE only takes the old policies that leaned on `owns_garage`, which
-- section 7 replaces.
--
-- Harmless on a clean project — there is nothing there to drop.
drop function if exists public.create_garage(json)      cascade;
drop function if exists public.save_job_card(json)      cascade;
drop function if exists public.garage_snapshot(uuid)    cascade;
drop function if exists public.job_card_detail(text)    cascade;
drop function if exists public.my_garage()              cascade;
drop function if exists public.issue_customer_code(text) cascade;
drop function if exists public.owns_garage(uuid)        cascade;

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
  shape       text not null default 'fourWheeler',
  year        int,
  vin         text not null default '',
  engine_no   text not null default '',
  colour      text not null default '',
  created_at  timestamptz not null default now()
);
-- Added after the table shipped, so `create table if not exists` above will
-- not put it on a database that already exists. Idempotent on purpose: this
-- file is re-run against live projects.
alter table public.garage_vehicles
  add column if not exists shape text not null default 'fourWheeler';
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

-- Added after the table shipped, so the `create table if not exists` above
-- will not put them on a database that already has it. The console has been
-- sending all six for a while: without them every masters upsert comes back
-- PGRST204 and the whole stock list silently stops syncing.
alter table public.masters
  add column if not exists cost       numeric(12,2) not null default 0,
  add column if not exists make       text not null default '',
  add column if not exists rack       text not null default '',
  add column if not exists part_group text not null default 'running',
  add column if not exists outsourced boolean not null default false,
  add column if not exists fits       text[] not null default '{}';

do $$ begin
  alter table public.masters
    add constraint masters_part_group_check
    check (part_group in ('running', 'engine', 'accessory'));
exception when duplicate_object then null;
end $$;

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
-- 6b. The books
-- =====================================================================
-- Everything the console tracked only on the device until now: what the
-- workshop spent, what moved through the drawer, who it buys from, what it
-- sold over the counter, what it has on order, and what it publishes on its
-- public page. All of it was lost on a reinstall.
--
-- None of it is customer-facing except `online_services`, which is the menu
-- a linked customer is offered.

create table if not exists public.expenses (
  id         text primary key,
  garage_id  uuid not null references public.garages (id) on delete cascade,
  title      text not null default '',
  amount     numeric(12,2) not null default 0,
  at         timestamptz not null default now(),
  category   text not null default 'General',
  supplier   text not null default '',
  paid       numeric(12,2) not null default 0,
  note       text not null default '',
  created_at timestamptz not null default now()
);
create index if not exists expenses_garage_idx
  on public.expenses (garage_id, at desc);

-- The day book. `inward` is money received, otherwise money paid away.
create table if not exists public.cash_book (
  id          text primary key,
  garage_id   uuid not null references public.garages (id) on delete cascade,
  party       text not null default '',
  amount      numeric(12,2) not null default 0,
  at          timestamptz not null default now(),
  inward      boolean not null default true,
  reason      text not null default '',
  mode        text not null default 'cash'
                check (mode in ('cash', 'upi', 'card', 'netbanking', 'cheque')),
  -- A plain column rather than a foreign key: a drawer entry outlives the
  -- card it came from, and deleting a card must not quietly delete the
  -- record of money that actually changed hands.
  job_card_id text,
  created_at  timestamptz not null default now()
);
create index if not exists cash_book_garage_idx
  on public.cash_book (garage_id, at desc);

create table if not exists public.suppliers (
  id          text primary key,
  garage_id   uuid not null references public.garages (id) on delete cascade,
  name        text not null default '',
  phone       text not null default '',
  address     text not null default '',
  gstin       text not null default '',
  outstanding numeric(12,2) not null default 0,
  created_at  timestamptz not null default now()
);
create index if not exists suppliers_garage_idx on public.suppliers (garage_id);

-- Items ride as jsonb on both of the next two, the way dents do on a job
-- card: the console sends and expects the whole document as one object, and
-- splitting them into child tables would buy nothing and cost atomicity.
create table if not exists public.counter_sales (
  id         text primary key,
  garage_id  uuid not null references public.garages (id) on delete cascade,
  number     text not null default '',
  customer   text not null default '',
  phone      text not null default '',
  at         timestamptz not null default now(),
  items      jsonb not null default '[]'::jsonb,
  paid       numeric(12,2) not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists counter_sales_garage_idx
  on public.counter_sales (garage_id, at desc);

create table if not exists public.purchase_orders (
  id          text primary key,
  garage_id   uuid not null references public.garages (id) on delete cascade,
  number      text not null default '',
  supplier_id text not null default '',
  at          timestamptz not null default now(),
  items       jsonb not null default '[]'::jsonb,
  received    boolean not null default false,
  received_at timestamptz,
  note        text not null default '',
  created_at  timestamptz not null default now()
);
create index if not exists purchase_orders_garage_idx
  on public.purchase_orders (garage_id, at desc);

create table if not exists public.online_services (
  id            text primary key,
  garage_id     uuid not null references public.garages (id) on delete cascade,
  name          text not null default '',
  price         numeric(12,2) not null default 0,
  blurb         text not null default '',
  duration_mins int not null default 60,
  created_at    timestamptz not null default now()
);
create index if not exists online_services_garage_idx
  on public.online_services (garage_id);

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
alter table public.expenses         enable row level security;
alter table public.cash_book        enable row level security;
alter table public.suppliers        enable row level security;
alter table public.counter_sales    enable row level security;
alter table public.purchase_orders  enable row level security;
alter table public.online_services  enable row level security;

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
--
-- Being in the garage's customer book counts, and has to: a workshop that
-- takes somebody's details at the counter and hands them a link code has
-- dealt with them. Without this the freshly linked customer could not read
-- the letterhead of the shop they had just been linked to, so the app had
-- no workshop to show them until their first job card existed.
create or replace function public.deals_with_garage(gid uuid)
returns boolean language sql stable security definer
set search_path = public as $$
  select exists (
    select 1 from public.garage_customers c
    where c.garage_id = gid and c.profile_id = auth.uid()
  ) or exists (
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
    'job_cards','garage_bookings',
    'expenses','cash_book','suppliers','counter_sales','purchase_orders',
    'online_services'
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

-- The menu a workshop publishes is the one thing in 6b a customer sees: it
-- is what the booking screen offers them. Only for a shop they actually
-- deal with, so it is not a directory of everybody's price list.
drop policy if exists online_services_customer_read on public.online_services;
create policy online_services_customer_read on public.online_services
  for select using (public.deals_with_garage(garage_id));

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


-- #####################################################################
-- ###  BEGIN 03_sync.sql
-- #####################################################################

-- =====================================================================
-- GaragePro — live sync, hardening and server-side writes
-- =====================================================================
-- Run this AFTER 01_customer.sql and 02_garage.sql. Idempotent.
--
-- It does four things:
--
--   1. Closes the phone-linking hole. Anyone could previously type a
--      stranger's number into their own profile and inherit that
--      stranger's job cards. Linking now needs proof.
--   2. Adds the garage-issued link code that replaces it: the workshop
--      hands the customer a short code, the customer redeems it.
--   3. Gives both apps one atomic write and one atomic read per job
--      card instead of six round trips that can half-succeed.
--   4. Puts every table both apps watch on the realtime publication and
--      makes the row level security policies cheap enough to run on
--      every row of every query.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. Housekeeping
-- ---------------------------------------------------------------------

-- The customer's copy of a bill carries the rate it was raised at, because
-- a bill that came from a job card is taxed the way that workshop taxes --
-- including not at all, where it is not registered.
alter table public.invoices
  add column if not exists tax_rate numeric(6,4) not null default 0.18;

create or replace function public.touch_updated_at()
returns trigger language plpgsql as $fn$
begin
  new.updated_at := now();
  return new;
end $fn$;

drop trigger if exists job_cards_touch on public.job_cards;
create trigger job_cards_touch before update on public.job_cards
  for each row execute function public.touch_updated_at();

drop trigger if exists garages_touch on public.garages;
create trigger garages_touch before update on public.garages
  for each row execute function public.touch_updated_at();

-- =====================================================================
-- 1. The phone-linking hole
-- =====================================================================
-- `profiles_self` lets a customer write any value into profiles.phone,
-- and `link_profile_to_customers()` is SECURITY DEFINER — so the old
-- trigger handed out somebody else's service history to whoever typed
-- their number. The `phone` key in sign-up metadata was just as
-- client-supplied.
--
-- From here, an automatic link needs a phone that Supabase itself
-- verified: auth.users.phone, set only by a completed SMS OTP. Anything
-- else goes through the link code in section 2.
-- ---------------------------------------------------------------------

create or replace function public.verified_phone(uid uuid)
returns text language sql stable security definer
set search_path = public, auth as $fn$
  select public.norm_phone(u.phone)
  from auth.users u
  where u.id = uid
    and u.phone_confirmed_at is not null
    and coalesce(u.phone, '') <> '';
$fn$;

-- Sign-up: create the profile, and link only on a verified phone.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer
set search_path = public as $fn$
declare
  meta      jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  full_name text;
  avatar    text;
  role_in   text;
  verified  text;
begin
  full_name := coalesce(
    meta ->> 'full_name', meta ->> 'name', meta ->> 'user_name', '');
  avatar := coalesce(meta ->> 'avatar_url', meta ->> 'picture');
  role_in := coalesce(meta ->> 'role', 'customer');
  if role_in not in ('customer', 'owner', 'staff') then
    role_in := 'customer';
  end if;

  insert into public.profiles (id, name, phone, email, avatar_url, role)
  values (
    new.id,
    full_name,
    -- The claimed number is kept for display and for the garage to
    -- search on. On its own it grants nothing.
    coalesce(new.phone, meta ->> 'phone', ''),
    new.email,
    avatar,
    role_in)
  on conflict (id) do update
    set name       = case when profiles.name = '' then excluded.name
                          else profiles.name end,
        email      = coalesce(profiles.email, excluded.email),
        avatar_url = coalesce(profiles.avatar_url, excluded.avatar_url);

  -- Only a number Supabase confirmed by SMS links a history.
  if new.phone_confirmed_at is not null
     and public.norm_phone(coalesce(new.phone, '')) <> '' then
    verified := public.norm_phone(new.phone);
    update public.garage_customers
       set profile_id = new.id
     where profile_id is null
       and public.norm_phone(phone) = verified;
  end if;

  return new;
end $fn$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Somebody who verifies their phone later still gets linked — but the
-- trigger reads the verified number from auth, never the one in the row
-- the customer can edit.
create or replace function public.link_profile_to_customers()
returns trigger language plpgsql security definer
set search_path = public as $fn$
declare verified text := public.verified_phone(new.id);
begin
  if coalesce(verified, '') <> '' then
    update public.garage_customers
       set profile_id = new.id
     where profile_id is null
       and public.norm_phone(phone) = verified;
  end if;
  return new;
end $fn$;

drop trigger if exists profiles_link_customers on public.profiles;
create trigger profiles_link_customers
  after insert or update of phone on public.profiles
  for each row execute function public.link_profile_to_customers();

-- =====================================================================
-- 2. The garage-issued link code
-- =====================================================================
-- The workshop knows who is standing at the counter; the database does
-- not. So the workshop vouches: it issues a short code against one
-- customer record, and whoever redeems it gets that record's history.
-- Single use, expires in a day, and only ever grants what one garage
-- chose to grant.
-- ---------------------------------------------------------------------

create table if not exists public.customer_link_codes (
  code        text primary key,
  garage_id   uuid not null references public.garages (id) on delete cascade,
  customer_id text not null references public.garage_customers (id)
                on delete cascade,
  issued_by   uuid not null references auth.users (id) on delete cascade,
  expires_at  timestamptz not null default now() + interval '24 hours',
  redeemed_by uuid references auth.users (id) on delete set null,
  redeemed_at timestamptz,
  created_at  timestamptz not null default now()
);
create index if not exists customer_link_codes_customer_idx
  on public.customer_link_codes (customer_id);

alter table public.customer_link_codes enable row level security;

-- Readable by the garage that issued it, never by the person redeeming
-- it: they are told the outcome by the function, so a live code cannot
-- be found by fishing.
drop policy if exists customer_link_codes_member on public.customer_link_codes;
create policy customer_link_codes_member on public.customer_link_codes
  for select to authenticated using (public.is_garage_member(garage_id));

revoke all on public.customer_link_codes from anon, authenticated;
grant select on public.customer_link_codes to authenticated;

create or replace function public.issue_customer_code(cid text)
returns text language plpgsql security definer
set search_path = public as $fn$
declare
  gid  uuid;
  made text;
begin
  select garage_id into gid from public.garage_customers where id = cid;
  if gid is null then
    raise exception 'no such customer';
  end if;
  if not public.is_garage_member(gid) then
    raise exception 'not a member of this garage';
  end if;

  -- Spent codes are kept for a week so "that code did not work" can still
  -- be explained, then dropped — otherwise the six-digit space silts up
  -- with rows nobody can use and the pick below starts spinning.
  delete from public.customer_link_codes
   where coalesce(redeemed_at, expires_at) < now() - interval '7 days';

  -- Six digits is enough: a code lives a day, is bound to one customer
  -- record, and burns on first use. The code is the primary key, so this
  -- has to avoid every row still on the table, spent ones included.
  loop
    made := lpad((floor(random() * 1000000))::int::text, 6, '0');
    exit when not exists (
      select 1 from public.customer_link_codes c where c.code = made);
  end loop;

  -- One live code per customer record.
  delete from public.customer_link_codes
   where customer_id = cid and redeemed_at is null;

  insert into public.customer_link_codes
    (code, garage_id, customer_id, issued_by)
  values (made, gid, cid, auth.uid());

  return made;
end $fn$;

create or replace function public.redeem_customer_code(entered text)
returns jsonb language plpgsql security definer
set search_path = public as $fn$
declare
  found public.customer_link_codes;
  uid   uuid := auth.uid();
begin
  if uid is null then
    raise exception 'not signed in';
  end if;

  select * into found
    from public.customer_link_codes c
   where c.code = trim(entered)
     and c.redeemed_at is null
     and c.expires_at > now()
   for update;

  if found.code is null then
    -- Deliberately not saying which of the three it was.
    return jsonb_build_object('ok', false, 'message',
      'That code is not valid any more. Ask the workshop for a new one.');
  end if;

  update public.garage_customers
     set profile_id = uid
   where id = found.customer_id;

  update public.customer_link_codes
     set redeemed_by = uid, redeemed_at = now()
   where code = found.code;

  return jsonb_build_object(
    'ok', true,
    'garage_id', found.garage_id,
    'customer_id', found.customer_id);
end $fn$;

revoke all on function public.issue_customer_code(text) from public;
revoke all on function public.redeem_customer_code(text) from public;
grant execute on function public.issue_customer_code(text)  to authenticated;
grant execute on function public.redeem_customer_code(text) to authenticated;

-- ---------------------------------------------------------------------
-- Undo what the old trigger granted
-- ---------------------------------------------------------------------
-- Every link made on an unverified number is a link somebody could have
-- made for themselves. Keep the ones a verified phone would make today,
-- keep the ones a code was redeemed for, and drop the rest — the
-- customer gets those back by asking the workshop for a code.
--
-- This sits after the code table on purpose: run the file twice and it
-- must not cut the links the first run's codes created.
update public.garage_customers c
   set profile_id = null
 where c.profile_id is not null
   and public.norm_phone(c.phone)
       is distinct from public.verified_phone(c.profile_id)
   and not exists (
     select 1 from public.customer_link_codes k
     where k.customer_id = c.id
       and k.redeemed_by = c.profile_id);

-- =====================================================================
-- 3. One write, one read
-- =====================================================================

-- One job card with its children nested, in the Dart model's shape.
create or replace function public.job_card_json(j public.job_cards)
returns jsonb language sql stable security definer
set search_path = public as $fn$
  select jsonb_build_object(
    'id', j.id,
    'garage_id', j.garage_id,
    'number', j.number,
    'customer_id', j.customer_id,
    'vehicle_id', j.vehicle_id,
    'status', j.status,
    'created_at', j.created_at,
    'completed_at', j.completed_at,
    'closed_at', j.closed_at,
    'promised_at', j.promised_at,
    'odometer_km', j.odometer_km,
    'fuel_percent', j.fuel_percent,
    'mechanic_ids', to_jsonb(j.mechanic_ids),
    'voices', to_jsonb(j.voices),
    'accessories', to_jsonb(j.accessories),
    'work_note', j.work_note,
    'dents', j.dents,
    'photos', to_jsonb(j.photos),
    'discount', j.discount,
    'tax_rate', j.tax_rate,
    'next_service_at', j.next_service_at,
    'next_service_km', j.next_service_km,
    'estimate_sent_at', j.estimate_sent_at,
    'items', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', li.id, 'kind', li.kind, 'name', li.name,
          'part_no', li.part_no, 'qty', li.qty, 'rate', li.rate,
          'mechanic_id', li.mechanic_id, 'state', li.state,
          'remark', li.remark, 'master_id', li.master_id)
        order by li.position)
      from public.line_items li where li.job_card_id = j.id), '[]'::jsonb),
    'payments', coalesce((
      select jsonb_agg(
        jsonb_build_object('id', p.id, 'amount', p.amount,
          'mode', p.mode, 'at', p.at, 'note', p.note) order by p.at)
      from public.payments p where p.job_card_id = j.id), '[]'::jsonb),
    'sms', coalesce((
      select jsonb_agg(
        jsonb_build_object('id', s.id, 'label', s.label,
          'at', s.at, 'state', s.state) order by s.at)
      from public.sms_events s where s.job_card_id = j.id), '[]'::jsonb));
$fn$;

-- A job card is edited as a whole — header, lines, payments, messages.
-- Writing it as six statements from the client means a dropped
-- connection can leave a bill with half its lines on it. This writes
-- the lot in one transaction, and emits one realtime burst the other
-- side applies at once.
create or replace function public.save_job_card(payload jsonb)
returns jsonb language plpgsql security definer
set search_path = public as $fn$
declare
  gid  uuid := nullif(payload ->> 'garage_id', '')::uuid;
  cid  text := payload ->> 'id';
  num  text := coalesce(payload ->> 'number', '');
  card public.job_cards;
  keep text[];
begin
  if gid is null or cid is null then
    raise exception 'garage_id and id are required';
  end if;
  if not public.is_garage_member(gid) then
    raise exception 'not a member of this garage';
  end if;
  if exists (select 1 from public.job_cards j
             where j.id = cid and j.garage_id <> gid) then
    raise exception 'that job card belongs to another garage';
  end if;

  -- The console mints a card's number the moment it opens, with or without
  -- a network, so two counters working the same morning can arrive with the
  -- same one. `job_cards_unique_number` used to refuse the second write, and
  -- the client could do nothing with the refusal but log it — the card sat
  -- on that device and existed nowhere else.
  --
  -- The database settles it instead: a number already spoken for by another
  -- card on this floor is replaced with the next free one, and the caller
  -- reads the number it actually got out of the row returned below. The loop
  -- is because the counter behind next_job_number() has no idea what the
  -- offline clients have handed out in the meantime.
  if num = '' or exists (
       select 1 from public.job_cards j
        where j.garage_id = gid and j.number = num and j.id <> cid) then
    loop
      num := public.next_job_number(gid);
      exit when not exists (
        select 1 from public.job_cards j
         where j.garage_id = gid and j.number = num and j.id <> cid);
    end loop;
  end if;

  insert into public.job_cards (
    id, garage_id, customer_id, vehicle_id, number, status,
    created_at, completed_at, closed_at, promised_at,
    odometer_km, fuel_percent, mechanic_ids, voices, accessories,
    work_note, dents, photos, discount, tax_rate,
    next_service_at, next_service_km, estimate_sent_at, updated_at)
  values (
    cid, gid,
    payload ->> 'customer_id',
    payload ->> 'vehicle_id',
    num,
    coalesce(payload ->> 'status', 'open'),
    coalesce((payload ->> 'created_at')::timestamptz, now()),
    (payload ->> 'completed_at')::timestamptz,
    (payload ->> 'closed_at')::timestamptz,
    (payload ->> 'promised_at')::timestamptz,
    coalesce((payload ->> 'odometer_km')::int, 0),
    coalesce((payload ->> 'fuel_percent')::int, 0),
    coalesce(array(select jsonb_array_elements_text(payload -> 'mechanic_ids')), '{}'),
    coalesce(array(select jsonb_array_elements_text(payload -> 'voices')), '{}'),
    coalesce(array(select jsonb_array_elements_text(payload -> 'accessories')), '{}'),
    coalesce(payload ->> 'work_note', ''),
    coalesce(payload -> 'dents', '[]'::jsonb),
    coalesce(array(select jsonb_array_elements_text(payload -> 'photos')), '{}'),
    coalesce((payload ->> 'discount')::numeric, 0),
    coalesce((payload ->> 'tax_rate')::numeric, 0),
    (payload ->> 'next_service_at')::timestamptz,
    (payload ->> 'next_service_km')::int,
    (payload ->> 'estimate_sent_at')::timestamptz,
    now())
  on conflict (id) do update set
    customer_id      = excluded.customer_id,
    vehicle_id       = excluded.vehicle_id,
    -- A number is minted once and never changes. Keeping the stored one
    -- means a later edit from a device that still remembers the number it
    -- proposed cannot rename a card that is already on a printed bill.
    number           = coalesce(nullif(job_cards.number, ''),
                                excluded.number),
    status           = excluded.status,
    completed_at     = excluded.completed_at,
    closed_at        = excluded.closed_at,
    promised_at      = excluded.promised_at,
    odometer_km      = excluded.odometer_km,
    fuel_percent     = excluded.fuel_percent,
    mechanic_ids     = excluded.mechanic_ids,
    voices           = excluded.voices,
    accessories      = excluded.accessories,
    work_note        = excluded.work_note,
    dents            = excluded.dents,
    photos           = excluded.photos,
    discount         = excluded.discount,
    tax_rate         = excluded.tax_rate,
    next_service_at  = excluded.next_service_at,
    next_service_km  = excluded.next_service_km,
    estimate_sent_at = excluded.estimate_sent_at,
    updated_at       = now()
  returning * into card;

  -- Children: upsert what is on the card, remove what came off it.
  keep := coalesce(array(
    select e.value ->> 'id'
    from jsonb_array_elements(coalesce(payload -> 'items', '[]'::jsonb)) e),
    '{}');

  insert into public.line_items (
    id, job_card_id, kind, name, part_no, qty, rate,
    mechanic_id, state, remark, master_id, position)
  select
    e.value ->> 'id', cid,
    coalesce(e.value ->> 'kind', 'job'),
    coalesce(e.value ->> 'name', ''),
    coalesce(e.value ->> 'part_no', ''),
    coalesce((e.value ->> 'qty')::numeric, 1),
    coalesce((e.value ->> 'rate')::numeric, 0),
    nullif(e.value ->> 'mechanic_id', ''),
    coalesce(e.value ->> 'state', 'pending'),
    coalesce(e.value ->> 'remark', ''),
    nullif(e.value ->> 'master_id', ''),
    (e.ordinality - 1)::int
  from jsonb_array_elements(coalesce(payload -> 'items', '[]'::jsonb))
       with ordinality as e(value, ordinality)
  on conflict (id) do update set
    kind = excluded.kind, name = excluded.name, part_no = excluded.part_no,
    qty = excluded.qty, rate = excluded.rate,
    mechanic_id = excluded.mechanic_id, state = excluded.state,
    remark = excluded.remark, master_id = excluded.master_id,
    position = excluded.position;

  delete from public.line_items
   where job_card_id = cid and not (id = any (keep));

  keep := coalesce(array(
    select e.value ->> 'id'
    from jsonb_array_elements(coalesce(payload -> 'payments', '[]'::jsonb)) e),
    '{}');

  insert into public.payments (id, job_card_id, amount, mode, at, note)
  select
    e.value ->> 'id', cid,
    coalesce((e.value ->> 'amount')::numeric, 0),
    coalesce(e.value ->> 'mode', 'cash'),
    coalesce((e.value ->> 'at')::timestamptz, now()),
    coalesce(e.value ->> 'note', '')
  from jsonb_array_elements(coalesce(payload -> 'payments', '[]'::jsonb)) e
  on conflict (id) do update set
    amount = excluded.amount, mode = excluded.mode,
    at = excluded.at, note = excluded.note;

  delete from public.payments
   where job_card_id = cid and not (id = any (keep));

  keep := coalesce(array(
    select e.value ->> 'id'
    from jsonb_array_elements(coalesce(payload -> 'sms', '[]'::jsonb)) e),
    '{}');

  insert into public.sms_events (id, job_card_id, label, at, state)
  select
    e.value ->> 'id', cid,
    coalesce(e.value ->> 'label', ''),
    coalesce((e.value ->> 'at')::timestamptz, now()),
    coalesce(e.value ->> 'state', 'scheduled')
  from jsonb_array_elements(coalesce(payload -> 'sms', '[]'::jsonb)) e
  on conflict (id) do update set
    label = excluded.label, at = excluded.at, state = excluded.state;

  delete from public.sms_events
   where job_card_id = cid and not (id = any (keep));

  return public.job_card_json(card);
end $fn$;

-- The whole workshop in one round trip, shaped like the Dart snapshot
-- so the console hydrates without a mapping layer.
create or replace function public.garage_snapshot(gid uuid)
returns jsonb language sql stable security definer
set search_path = public as $fn$
  select case when not public.is_garage_member(gid) then null else
    jsonb_build_object(
      'garage', (select to_jsonb(g) from public.garages g where g.id = gid),
      'staff', coalesce((
        select jsonb_agg(to_jsonb(s) - 'garage_id' - 'created_at' order by s.name)
        from public.staff s where s.garage_id = gid), '[]'::jsonb),
      'customers', coalesce((
        select jsonb_agg(to_jsonb(c) - 'garage_id' - 'profile_id')
        from public.garage_customers c where c.garage_id = gid), '[]'::jsonb),
      'vehicles', coalesce((
        select jsonb_agg(to_jsonb(v) - 'garage_id' - 'created_at')
        from public.garage_vehicles v where v.garage_id = gid), '[]'::jsonb),
      'masters', coalesce((
        select jsonb_agg(to_jsonb(m) - 'garage_id' - 'created_at')
        from public.masters m where m.garage_id = gid), '[]'::jsonb),
      'bookings', coalesce((
        select jsonb_agg(to_jsonb(b) - 'garage_id' - 'profile_id' - 'created_at')
        from public.garage_bookings b where b.garage_id = gid), '[]'::jsonb),
      'reviews', coalesce((
        select jsonb_agg(to_jsonb(r) - 'garage_id' - 'profile_id')
        from public.reviews r where r.garage_id = gid), '[]'::jsonb),
      'expenses', coalesce((
        select jsonb_agg(to_jsonb(e) - 'garage_id' - 'created_at'
                         order by e.at desc)
        from public.expenses e where e.garage_id = gid), '[]'::jsonb),
      'cash_book', coalesce((
        select jsonb_agg(to_jsonb(c) - 'garage_id' - 'created_at'
                         order by c.at desc)
        from public.cash_book c where c.garage_id = gid), '[]'::jsonb),
      'suppliers', coalesce((
        select jsonb_agg(to_jsonb(s) - 'garage_id' - 'created_at'
                         order by s.name)
        from public.suppliers s where s.garage_id = gid), '[]'::jsonb),
      'counter_sales', coalesce((
        select jsonb_agg(to_jsonb(cs) - 'garage_id' - 'created_at'
                         order by cs.at desc)
        from public.counter_sales cs where cs.garage_id = gid), '[]'::jsonb),
      'purchase_orders', coalesce((
        select jsonb_agg(to_jsonb(po) - 'garage_id' - 'created_at'
                         order by po.at desc)
        from public.purchase_orders po where po.garage_id = gid), '[]'::jsonb),
      'online_services', coalesce((
        select jsonb_agg(to_jsonb(os) - 'garage_id' - 'created_at'
                         order by os.name)
        from public.online_services os where os.garage_id = gid), '[]'::jsonb),
      'job_cards', coalesce((
        select jsonb_agg(public.job_card_json(j) order by j.created_at desc)
        from public.job_cards j where j.garage_id = gid), '[]'::jsonb))
  end;
$fn$;

-- Re-fetch a single card after a realtime ping, without pulling the
-- whole workshop again. Readable by the garage or by the car's owner.
create or replace function public.job_card_detail(card text)
returns jsonb language plpgsql stable security definer
set search_path = public as $fn$
declare j public.job_cards;
begin
  select * into j from public.job_cards where id = card;
  if j.id is null or not public.reads_job_card(card) then
    return null;
  end if;
  return public.job_card_json(j);
end $fn$;

-- One garage per owner. Calling twice updates the first rather than
-- quietly stranding the console on a second, empty workshop.
create or replace function public.create_garage(payload jsonb)
returns public.garages language plpgsql security definer
set search_path = public as $fn$
declare g public.garages;
begin
  if auth.uid() is null then
    raise exception 'not signed in';
  end if;

  select * into g from public.garages
   where owner_id = auth.uid() order by created_at limit 1;

  if g.id is not null then
    update public.garages set
      name         = coalesce(nullif(payload ->> 'name', ''), name),
      phone        = coalesce(nullif(payload ->> 'phone', ''), phone),
      alt_phone    = coalesce(payload ->> 'alt_phone', alt_phone),
      email        = coalesce(payload ->> 'email', email),
      address_line = coalesce(payload ->> 'address_line', address_line),
      city         = coalesce(payload ->> 'city', city),
      state        = coalesce(payload ->> 'state', state),
      pin          = coalesce(payload ->> 'pin', pin),
      gstin        = coalesce(payload ->> 'gstin', gstin),
      upi_id       = coalesce(payload ->> 'upi_id', upi_id),
      terms        = coalesce(payload ->> 'terms', terms)
     where id = g.id
     returning * into g;
    return g;
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
end $fn$;

-- The garage the caller works at, if any. The console asks this first.
create or replace function public.my_garage()
returns jsonb language sql stable security definer
set search_path = public as $fn$
  select to_jsonb(g)
  from public.garages g
  join public.garage_members m on m.garage_id = g.id
  where m.profile_id = auth.uid()
  order by case m.role when 'owner' then 0 else 1 end, g.created_at
  limit 1;
$fn$;

revoke all on function public.save_job_card(jsonb)     from public;
revoke all on function public.garage_snapshot(uuid)    from public;
revoke all on function public.job_card_detail(text)    from public;
revoke all on function public.my_garage()              from public;
grant execute on function public.save_job_card(jsonb)  to authenticated;
grant execute on function public.garage_snapshot(uuid) to authenticated;
grant execute on function public.job_card_detail(text) to authenticated;
grant execute on function public.my_garage()           to authenticated;
grant execute on function public.create_garage(jsonb)  to authenticated;

-- =====================================================================
-- 4. Policies that stay cheap
-- =====================================================================
-- `auth.uid()` inside a policy is re-evaluated for every row it filters.
-- Wrapping it in a scalar subquery makes Postgres run it once per
-- statement and lets the index on user_id do the work — the difference
-- shows the moment a customer has a few hundred rows.
-- ---------------------------------------------------------------------

drop policy if exists profiles_self on public.profiles;
create policy profiles_self on public.profiles
  for all to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

do $blk$
declare t text;
begin
  foreach t in array array[
    'vehicles','addresses','bookings','inspections','estimates',
    'invoices','notifications','tickets','chat_messages'
  ] loop
    execute format('drop policy if exists %I_own on public.%I', t, t);
    execute format(
      'create policy %I_own on public.%I for all to authenticated
         using ((select auth.uid()) = user_id)
         with check ((select auth.uid()) = user_id)', t, t);
  end loop;
end $blk$;

do $blk$
declare t text;
begin
  foreach t in array array[
    'service_categories','service_packages','add_ons','coupons','slots'
  ] loop
    execute format('drop policy if exists %I_read on public.%I', t, t);
    execute format(
      'create policy %I_read on public.%I for select to authenticated
         using (true)', t, t);
  end loop;
end $blk$;

drop policy if exists job_cards_customer_read on public.job_cards;
create policy job_cards_customer_read on public.job_cards
  for select to authenticated
  using (customer_profile_id = (select auth.uid()));

drop policy if exists garage_customers_self_read on public.garage_customers;
create policy garage_customers_self_read on public.garage_customers
  for select to authenticated
  using (profile_id = (select auth.uid()));

drop policy if exists garage_bookings_customer_read on public.garage_bookings;
create policy garage_bookings_customer_read on public.garage_bookings
  for select to authenticated
  using (profile_id = (select auth.uid()));

-- A customer raises a request at a workshop they are actually linked to,
-- and cannot mark it accepted or point it at a job card — those are the
-- workshop's to set. Without the link test, knowing a garage's id would
-- be enough to fill somebody else's diary.
drop policy if exists garage_bookings_customer_insert on public.garage_bookings;
create policy garage_bookings_customer_insert on public.garage_bookings
  for insert to authenticated
  with check (profile_id = (select auth.uid())
              and accepted = false
              and job_card_id is null
              and exists (
                select 1 from public.garage_customers c
                where c.garage_id = garage_bookings.garage_id
                  and c.profile_id = (select auth.uid())));

-- Nothing signed-out reaches these tables at all.
do $blk$
declare t text;
begin
  foreach t in array array[
    'garages','garage_members','staff','garage_customers','garage_vehicles',
    'masters','job_cards','line_items','payments','sms_events',
    'garage_bookings','reviews','profiles','vehicles','addresses','bookings',
    'inspections','estimates','invoices','notifications','tickets',
    'chat_messages','expenses','cash_book','suppliers',
    'counter_sales','purchase_orders','online_services'
  ] loop
    -- A table that is not there yet on a part-migrated project must not
    -- abort the rest of this file, which is how one of these scripts stops
    -- halfway and leaves a database nobody can tell is incomplete.
    begin
      execute format('revoke all on public.%I from anon', t);
    exception when undefined_table then null;
    end;
  end loop;
end $blk$;

-- =====================================================================
-- 5. Realtime
-- =====================================================================
-- Everything either app watches. A DELETE only carries the primary key
-- unless the replica identity is full, and both apps need the garage_id
-- on a delete to know whether it was theirs.
-- ---------------------------------------------------------------------
do $blk$
declare t text;
begin
  foreach t in array array[
    'job_cards','line_items','payments','sms_events','garage_bookings',
    'garage_customers','garage_vehicles','masters','staff','reviews','garages',
    'expenses','cash_book','suppliers','counter_sales','purchase_orders',
    'online_services'
  ] loop
    begin
      execute format(
        'alter publication supabase_realtime add table public.%I', t);
    exception when duplicate_object then null;
    end;
    execute format('alter table public.%I replica identity full', t);
  end loop;
end $blk$;


-- #####################################################################
-- ###  BEGIN 04_roles.sql
-- #####################################################################

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


-- #####################################################################
-- ###  BEGIN 05_attendance.sql
-- #####################################################################

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


-- #####################################################################
-- ###  BEGIN 06_notifications.sql
-- #####################################################################

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


-- #####################################################################
-- ###  BEGIN 07_share.sql
-- #####################################################################

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


-- #####################################################################
-- ###  BEGIN 08_platform.sql
-- #####################################################################

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


-- #####################################################################
-- ###  BEGIN 09_marketplace.sql
-- #####################################################################

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


-- #####################################################################
-- ###  BEGIN 10_open_booking.sql
-- #####################################################################

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

