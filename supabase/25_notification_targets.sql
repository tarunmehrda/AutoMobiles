-- =====================================================================
-- GaragePro — a tapped notification opens the thing it is about
-- =====================================================================
-- Run AFTER 24_close_audit_findings.sql. Idempotent: safe to re-run.
--
-- Every notification carries a `route`: the screen a tap opens. They all
-- pointed at a list — the whole Bookings list, the whole Feedback list —
-- so a tap on "Ravi requested a slot" still left the counter hunting for
-- Ravi. Each one now names its own item:
--
--   Workshop console
--     new booking / booking moved  -> /bookings?open=<booking id>
--                                     (that booking first, highlighted)
--     review                       -> /job/<job card id>
--   Customer app
--     booking confirmed / moved    -> /bookings?open=<booking id>
--     vehicle ready / visit closed -> /workshop/<job card id>/invoice
--     payment received             -> /workshop/<job card id>/invoice
--
-- A booking that no longer exists (cancelled, declined) still opens the
-- plain list: there is nothing left to point at.
--
-- The functions below are the ones from 06_, 20_ and 22_, unchanged except
-- for the route each passes.
-- =====================================================================

-- ---------------------------------------------------------------------
-- The workshop console
-- ---------------------------------------------------------------------
create or replace function public.notify_booking_request()
returns trigger language plpgsql security definer
set search_path = public as $fn$
declare
  who  text := nullif(trim(new.name), '');
  what text := trim(coalesce(new.vehicle, ''));
begin
  -- Only a genuine request from outside, not the counter's own entries.
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
    '/bookings?open=' || new.id,
    new.id,
    null);

  return new;
end $fn$;

create or replace function public.notify_new_review()
returns trigger language plpgsql security definer
set search_path = public as $fn$
begin
  perform public.push_garage_notification(
    new.garage_id,
    'review',
    new.stars || '-star review',
    coalesce(nullif(trim(new.comment), ''), 'No comment left.'),
    case when new.job_card_id is not null
         then '/job/' || new.job_card_id
         else '/feedback' end,
    null,
    new.job_card_id);
  return new;
end $fn$;

create or replace function public.notify_booking_moved()
returns trigger language plpgsql security definer
set search_path = public as $fn$
begin
  -- The counter's own edits and declines are not news to the counter.
  if tg_op = 'UPDATE' then
    if public.is_garage_member(new.garage_id)
       or new.at is not distinct from old.at then
      return new;
    end if;
    perform public.push_garage_notification(
      new.garage_id,
      'booking',
      coalesce(nullif(new.name, ''), 'A customer') || ' moved their booking',
      to_char(new.at at time zone 'Asia/Kolkata', 'Dy DD Mon, hh12:mi am'),
      '/bookings?open=' || new.id,
      new.id,
      null);
    return new;
  end if;

  if public.is_garage_member(old.garage_id) then
    return old;
  end if;
  perform public.push_garage_notification(
    old.garage_id,
    'booking',
    coalesce(nullif(old.name, ''), 'A customer') || ' cancelled their booking',
    to_char(old.at at time zone 'Asia/Kolkata', 'Dy DD Mon, hh12:mi am'),
    '/bookings',
    null,
    null);
  return old;
end $fn$;

-- ---------------------------------------------------------------------
-- The customer app
-- ---------------------------------------------------------------------
-- The customer app files its request as `req-<its own booking id>`
-- (User/lib/state/app_state.dart), so the prefix comes off to name the
-- booking the app knows.
create or replace function public.alert_customer_booking()
returns trigger language plpgsql security definer
set search_path = public as $fn$
declare
  shop text;
begin
  if tg_op = 'DELETE' then
    if old.profile_id is null or old.accepted or old.job_card_id is not null
       or not public.is_garage_member(old.garage_id) then
      return old;
    end if;
    select coalesce(nullif(g.name, ''), 'The workshop') into shop
      from public.garages g where g.id = old.garage_id;
    perform public.push_customer_alert(
      old.profile_id, 'booking', 'Booking declined',
      shop || ' could not take your booking for ' || public.alert_when(old.at)
        || '. Please book another slot.',
      '/bookings');
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

-- ---------------------------------------------------------------------
-- Check it took
-- ---------------------------------------------------------------------
-- Expects 6: every function above now builds a route to its own item.
select count(*) as targeted_functions
  from pg_proc
 where proname in ('notify_booking_request', 'notify_new_review',
                   'notify_booking_moved', 'alert_customer_booking',
                   'alert_customer_job', 'alert_customer_payment')
   and (prosrc like '%?open=%' or prosrc like '%/invoice%' or prosrc like '%/job/%');
-- =====================================================================
