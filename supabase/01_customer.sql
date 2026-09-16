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
