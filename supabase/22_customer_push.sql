-- =====================================================================
-- GaragePro — the customer's phone rings too
-- =====================================================================
-- Run AFTER 21_private_commission.sql. Idempotent: safe to re-run.
--
-- The workshop console is rung by `garage_notifications` (06_*.sql) and
-- the `notify-garage` edge function. The customer app had nothing like
-- it: everything it knew, it worked out for itself while it was open, so
-- a customer whose app was shut heard nothing until they opened it.
--
-- This is the customer's half, built the same way:
--
--   * `customer_devices`  — this customer's phones (one FCM token each);
--   * `customer_alerts`   — one row per thing worth ringing them for,
--                           raised by the triggers in section 3;
--   * a Database Webhook on `customer_alerts` INSERT calls the same
--     `notify-garage` edge function, which sends to the customer's
--     phones instead of the workshop's (docs/06-notifications.md).
--
-- `customer_alerts` is only the tray. The in-app bell still comes from
-- the app's own feed (`public.notifications`), which the app builds and
-- uploads itself — writing these rows there as well would show every
-- update twice.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. The customer's phones
-- ---------------------------------------------------------------------
create table if not exists public.customer_devices (
  token        text primary key,
  profile_id   uuid not null references auth.users (id) on delete cascade,
  platform     text not null default 'android',
  last_seen_at timestamptz not null default now(),
  created_at   timestamptz not null default now()
);
create index if not exists customer_devices_profile_idx
  on public.customer_devices (profile_id);

-- Called on every launch, so an upsert: a phone that changes hands follows
-- whoever signed in on it last.
create or replace function public.register_customer_device(
  tok text,
  plat text default 'android'
)
returns void language plpgsql security definer
set search_path = public as $fn$
declare uid uuid := auth.uid();
begin
  if uid is null or coalesce(trim(tok), '') = '' then
    return;
  end if;

  insert into public.customer_devices (token, profile_id, platform)
  values (trim(tok), uid, coalesce(nullif(trim(plat), ''), 'android'))
  on conflict (token) do update
    set profile_id   = excluded.profile_id,
        platform     = excluded.platform,
        last_seen_at = now();

  delete from public.customer_devices d
   where d.last_seen_at < now() - interval '60 days';
end $fn$;

-- Signing out stops the ringing on that phone, and only that one.
create or replace function public.forget_customer_device(tok text)
returns void language plpgsql security definer
set search_path = public as $fn$
begin
  delete from public.customer_devices d
   where d.token = trim(tok) and d.profile_id = auth.uid();
end $fn$;

-- ---------------------------------------------------------------------
-- 2. What to ring them for
-- ---------------------------------------------------------------------
create table if not exists public.customer_alerts (
  id         uuid primary key default gen_random_uuid(),
  profile_id uuid not null references auth.users (id) on delete cascade,
  kind       text not null default 'service',
  title      text not null,
  body       text not null default '',
  route      text not null default '/bookings',
  at         timestamptz not null default now()
);
create index if not exists customer_alerts_at_idx
  on public.customer_alerts (at);

create or replace function public.push_customer_alert(
  uid   uuid,
  kind  text,
  title text,
  body  text,
  route text default '/bookings'
)
returns void language plpgsql security definer
set search_path = public as $fn$
begin
  if uid is null then
    return;
  end if;
  insert into public.customer_alerts (profile_id, kind, title, body, route)
  values (uid, kind, title, coalesce(body, ''), coalesce(route, '/bookings'));

  -- Only the tray reads these, and only once, at insert. A month is plenty.
  delete from public.customer_alerts a
   where a.at < now() - interval '30 days';
end $fn$;

-- A slot the way a person reads it.
create or replace function public.alert_when(t timestamptz)
returns text language sql stable as $fn$
  select to_char(t at time zone 'Asia/Kolkata', 'Dy DD Mon, HH12:MI am');
$fn$;

-- ---------------------------------------------------------------------
-- 3. The triggers
-- ---------------------------------------------------------------------
-- Every one of them fires only for the workshop's own actions — the
-- caller is a member of the garage. The customer's own changes (booking,
-- moving, cancelling) are news to nobody on their phone, and the SQL
-- editor (no caller at all) rings nobody.

-- Bookings: confirmed, moved, declined.
create or replace function public.alert_customer_booking()
returns trigger language plpgsql security definer
set search_path = public as $fn$
declare
  shop text;
begin
  if tg_op = 'DELETE' then
    -- The counter turned a request down: a member deleted a request that
    -- was never accepted and never became a job card.
    if old.profile_id is null or old.accepted or old.job_card_id is not null
       or not public.is_garage_member(old.garage_id) then
      return old;
    end if;
    select coalesce(nullif(g.name, ''), 'The workshop') into shop
      from public.garages g where g.id = old.garage_id;
    perform public.push_customer_alert(
      old.profile_id, 'booking', 'Booking declined',
      shop || ' could not take your booking for ' || public.alert_when(old.at)
        || '. Please book another slot.');
    return old;
  end if;

  if new.profile_id is null or not public.is_garage_member(new.garage_id) then
    return new;
  end if;
  select coalesce(nullif(g.name, ''), 'The workshop') into shop
    from public.garages g where g.id = new.garage_id;

  if not coalesce(old.accepted, false) and new.accepted then
    perform public.push_customer_alert(
      new.profile_id, 'booking', 'Booking confirmed',
      shop || ' confirmed your booking for ' || public.alert_when(new.at) || '.',
      '/bookings?open=' || regexp_replace(new.id, '^req-', ''));
  elsif new.at is distinct from old.at then
    perform public.push_customer_alert(
      new.profile_id, 'booking', 'Booking time changed',
      shop || ' moved your booking to ' || public.alert_when(new.at) || '.',
      '/bookings?open=' || regexp_replace(new.id, '^req-', ''));
  end if;
  return new;
end $fn$;

drop trigger if exists garage_bookings_alert_customer on public.garage_bookings;
create trigger garage_bookings_alert_customer
  after update of accepted, at or delete on public.garage_bookings
  for each row execute function public.alert_customer_booking();

-- Job cards: the car is ready, the visit is closed.
create or replace function public.alert_customer_job()
returns trigger language plpgsql security definer
set search_path = public as $fn$
declare
  shop text;
  reg  text;
begin
  if new.customer_profile_id is null
     or new.status is not distinct from old.status
     or not public.is_garage_member(new.garage_id) then
    return new;
  end if;
  select coalesce(nullif(g.name, ''), 'The workshop') into shop
    from public.garages g where g.id = new.garage_id;
  select upper(v.reg_no) into reg
    from public.garage_vehicles v where v.id = new.vehicle_id;

  if new.status = 'complete' then
    perform public.push_customer_alert(
      new.customer_profile_id, 'service', 'Your vehicle is ready',
      shop || ' has finished the work on '
        || coalesce(nullif(reg, ''), 'your vehicle')
        || '. Job card ' || new.number || '.',
      '/workshop/' || new.id || '/invoice');
  elsif new.status = 'closed' then
    perform public.push_customer_alert(
      new.customer_profile_id, 'service', 'Visit closed',
      'Thank you for visiting ' || shop || '. Job card ' || new.number
        || ' is closed; the bill is in the app.',
      '/workshop/' || new.id || '/invoice');
  end if;
  return new;
end $fn$;

drop trigger if exists job_cards_alert_customer on public.job_cards;
create trigger job_cards_alert_customer
  after update of status on public.job_cards
  for each row execute function public.alert_customer_job();

-- Payments: money received. `save_job_card()` upserts payments by id, so
-- this fires once per new payment, not once per save.
create or replace function public.alert_customer_payment()
returns trigger language plpgsql security definer
set search_path = public as $fn$
declare
  j    public.job_cards;
  shop text;
begin
  if new.amount is null or new.amount <= 0 then
    return new;
  end if;
  select * into j from public.job_cards where id = new.job_card_id;
  if j.customer_profile_id is null or not public.is_garage_member(j.garage_id) then
    return new;
  end if;
  select coalesce(nullif(g.name, ''), 'The workshop') into shop
    from public.garages g where g.id = j.garage_id;

  perform public.push_customer_alert(
    j.customer_profile_id, 'payment', 'Payment received',
    'Rs ' || trim(trailing '.' from to_char(new.amount, 'FM999999990.99'))
      || ' received by ' || shop || ' for job card ' || j.number || '.',
    '/workshop/' || j.id || '/invoice');
  return new;
end $fn$;

drop trigger if exists payments_alert_customer on public.payments;
create trigger payments_alert_customer
  after insert on public.payments
  for each row execute function public.alert_customer_payment();

-- ---------------------------------------------------------------------
-- 4. Row level security: nobody reads or writes these from an app
-- ---------------------------------------------------------------------
-- Written by the functions above, read by the edge function with the
-- service role. No policy at all, for anybody.
alter table public.customer_devices enable row level security;
alter table public.customer_alerts  enable row level security;
revoke all on public.customer_devices from anon, authenticated;
revoke all on public.customer_alerts  from anon, authenticated;

-- By name, not just `from public`: Supabase grants EXECUTE to anon and
-- authenticated directly, and `from public` leaves those grants in place
-- (see 23_lock_internal_functions.sql).
revoke all on function public.push_customer_alert(uuid, text, text, text, text)
  from public, anon, authenticated;
revoke all on function public.register_customer_device(text, text) from public, anon;
revoke all on function public.forget_customer_device(text) from public, anon;
grant execute on function public.register_customer_device(text, text) to authenticated;
grant execute on function public.forget_customer_device(text) to authenticated;

-- ---------------------------------------------------------------------
-- Check it took
-- ---------------------------------------------------------------------
-- Expects 3 (the three triggers):
select count(*) as alert_triggers from pg_trigger
 where tgname in ('garage_bookings_alert_customer',
                  'job_cards_alert_customer',
                  'payments_alert_customer');
-- =====================================================================
