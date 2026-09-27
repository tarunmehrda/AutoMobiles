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
