-- =====================================================================
-- GaragePro -- files 24 to 26 in one paste
-- =====================================================================
-- A copy of the numbered files, in order, for running in one go in the
-- Supabase SQL editor: select all, copy, paste, Run. Every file is
-- idempotent, so this is safe even if 24 or 25 already ran.
--
-- Do not edit this copy; edit the numbered files and regenerate it.
-- The Results panel shows only the last query: the workshops that still
-- have no valid PIN code. "No rows" means every workshop has one.
-- =====================================================================


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>> 24_close_audit_findings.sql

-- =====================================================================
-- GaragePro — what the function audit of 26 Sep 2026 found
-- =====================================================================
-- Run AFTER 23_lock_internal_functions.sql. Idempotent: safe to re-run.
--
-- Every function a phone can call (55 of them) was read against its live
-- definition, and each finding was checked by two independent reviewers
-- trying to disprove it. 23_*.sql closed the two notification functions.
-- This closes the rest:
--
--   1. job_card_json   — anyone with the app key could read another
--                        workshop's bill lines, payments and SMS log for
--                        a card whose id they knew.
--   2. verified_phone  — anyone could read any account's verified phone
--                        number from its id.
--   3. listable_garages — handed anyone the full workshop register,
--                        including workshops the platform never approved.
--   4. save_job_card   — any signed-in user (a customer can register a
--                        throwaway workshop in one call) could overwrite
--                        another workshop's bill lines and payments by
--                        sending their ids, or hang a card on another
--                        workshop's customer and vehicle.
--
-- Supabase grants EXECUTE on every function in `public` to `anon` and
-- `authenticated` by name, so the revokes below name both roles.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1 & 2. Internal helpers, off the API
-- ---------------------------------------------------------------------
-- Only ever called from inside other SECURITY DEFINER functions
-- (save_job_card, garage_snapshot, job_card_detail; the profile-linking
-- trigger), which run as the owner and keep their access. Neither app
-- calls either one.
revoke execute on function public.job_card_json(public.job_cards)
  from public, anon, authenticated;
revoke execute on function public.verified_phone(uuid)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 3. The workshop picker shows what the customer may already see
-- ---------------------------------------------------------------------
-- The same rule as booking (18_/20_ garage_card): listed by the platform,
-- or a workshop this customer already deals with. Signed-in only, and
-- never more than 200 rows.
create or replace function public.listable_garages(max_rows int default 200)
returns jsonb language sql stable security definer
set search_path = public as $fn$
  select coalesce(jsonb_agg(t order by t ->> 'name'), '[]'::jsonb)
    from (
      select jsonb_build_object('id', g.id, 'name', g.name, 'city', g.city)
        from public.garages g
       where g.listed or public.deals_with_garage(g.id)
       order by g.name
       limit least(greatest(coalesce(max_rows, 200), 1), 200)
    ) as x(t);
$fn$;

revoke execute on function public.listable_garages(int) from public, anon;
grant execute on function public.listable_garages(int) to authenticated;

-- ---------------------------------------------------------------------
-- 4. A job card writes only its own lines, and only this shop's people
-- ---------------------------------------------------------------------
-- As 03_sync.sql, with two checks before anything is written:
--
--   * no line item, payment or SMS entry in the payload may already sit
--     on a DIFFERENT card. The children are upserted by id, and the
--     upsert used to update whatever row had that id, on any card of any
--     workshop;
--   * the customer and the vehicle must be on this workshop's own books.
--
-- The messages avoid the phrase "belongs to another garage" on purpose:
-- the console reads that exact text as "this card is another workshop's,
-- drop it from the phone" (garage_gateway.dart), and a genuine card that
-- tripped one of these checks must stay on the phone, not vanish.
--
-- The DO UPDATE clauses also only touch a row on this card, as a second
-- line of defence behind the check.
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

  if exists (select 1 from public.line_items li
               join jsonb_array_elements(coalesce(payload -> 'items', '[]'::jsonb)) e
                 on li.id = e.value ->> 'id'
              where li.job_card_id <> cid)
  or exists (select 1 from public.payments p
               join jsonb_array_elements(coalesce(payload -> 'payments', '[]'::jsonb)) e
                 on p.id = e.value ->> 'id'
              where p.job_card_id <> cid)
  or exists (select 1 from public.sms_events s
               join jsonb_array_elements(coalesce(payload -> 'sms', '[]'::jsonb)) e
                 on s.id = e.value ->> 'id'
              where s.job_card_id <> cid) then
    raise exception 'a line, payment or message on this card is already on a different card';
  end if;

  if not exists (select 1 from public.garage_customers c
                  where c.id = payload ->> 'customer_id' and c.garage_id = gid)
  or not exists (select 1 from public.garage_vehicles v
                  where v.id = payload ->> 'vehicle_id' and v.garage_id = gid) then
    raise exception 'the customer or vehicle on this card is not on this workshop''s books';
  end if;

  -- The console mints a card's number the moment it opens, with or without
  -- a network, so two counters can arrive with the same one. A number
  -- already spoken for by another card on this floor is replaced with the
  -- next free one, and the caller reads back the number it actually got.
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
    -- A number is minted once and never changes.
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
    position = excluded.position
  where line_items.job_card_id = excluded.job_card_id;

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
    at = excluded.at, note = excluded.note
  where payments.job_card_id = excluded.job_card_id;

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
    label = excluded.label, at = excluded.at, state = excluded.state
  where sms_events.job_card_id = excluded.job_card_id;

  delete from public.sms_events
   where job_card_id = cid and not (id = any (keep));

  return public.job_card_json(card);
end $fn$;

revoke all on function public.save_job_card(jsonb) from public, anon;
grant execute on function public.save_job_card(jsonb) to authenticated;

-- ---------------------------------------------------------------------
-- Check it took
-- ---------------------------------------------------------------------
-- Expects false, false, false:
select has_function_privilege('anon', 'public.job_card_json(public.job_cards)', 'execute')
    or has_function_privilege('authenticated', 'public.job_card_json(public.job_cards)', 'execute')
       as job_card_json_open,
       has_function_privilege('anon', 'public.verified_phone(uuid)', 'execute')
    or has_function_privilege('authenticated', 'public.verified_phone(uuid)', 'execute')
       as verified_phone_open,
       has_function_privilege('anon', 'public.listable_garages(int)', 'execute')
       as garage_list_open_to_anyone;
-- =====================================================================


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>> 25_notification_targets.sql

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


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>> 26_require_garage_pin.sql

-- =====================================================================
-- GaragePro — a registered workshop has a name and a real PIN code
-- =====================================================================
-- Run AFTER 25_notification_targets.sql. Idempotent: safe to re-run.
--
-- The customer app shows every workshop by its name and PIN code: on each
-- search result, on the garage's own page and on the booking screen, and a
-- customer can search by PIN. Both apps now refuse to register or save a
-- workshop without one, but a phone on an older build, or a hand-rolled
-- request, still writes the `garages` row. This holds the same rule where
-- every path meets:
--
--   * the name is trimmed, runs of spaces closed up, and may not be blank;
--   * the PIN keeps its digits only ("302 001" -> "302001") and must then
--     be six digits not starting with 0 — the Indian PIN format, and the
--     rule `Fmt.isPin` holds in both apps.
--
-- A workshop registered before this keeps working with what it has. The
-- rule applies on insert, and on an update that changes the name or PIN:
-- an old workshop with no PIN can still go online, be listed or move its
-- map pin, but it cannot save a blank or broken PIN, and the first PIN it
-- does save must be a real one. Platform -> Partners marks the workshops
-- still without one ("No PIN code").
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Tidy what is already there
-- ---------------------------------------------------------------------
-- Only rows that come out valid are touched. A blank or broken PIN is left
-- for its owner to correct; there is nothing to guess it from.
update public.garages
   set pin = regexp_replace(pin, '\D', '', 'g')
 where pin ~ '\D'
   and regexp_replace(pin, '\D', '', 'g') ~ '^[1-9][0-9]{5}$';

update public.garages
   set name = btrim(regexp_replace(name, '\s+', ' ', 'g'))
 where name <> btrim(regexp_replace(name, '\s+', ' ', 'g'))
   and btrim(regexp_replace(name, '\s+', ' ', 'g')) <> '';

-- ---------------------------------------------------------------------
-- 2. The rule, on every write
-- ---------------------------------------------------------------------
-- The messages are the ones the apps show under "Could not register the
-- workshop.", so they are written for the person at the counter.
create or replace function public.check_garage_name_pin()
returns trigger language plpgsql
set search_path = public as $fn$
declare
  name_changed boolean := tg_op = 'INSERT';
  pin_changed  boolean := tg_op = 'INSERT';
begin
  new.name := btrim(regexp_replace(coalesce(new.name, ''), '\s+', ' ', 'g'));
  new.pin  := regexp_replace(coalesce(new.pin, ''), '\D', '', 'g');

  -- Compared tidied to tidied. A stored "3020 1" sent back unchanged would
  -- otherwise count as a change, and a workshop that has never fixed its
  -- PIN could not save anything else on its row.
  if tg_op = 'UPDATE' then
    name_changed := new.name is distinct from
      btrim(regexp_replace(coalesce(old.name, ''), '\s+', ' ', 'g'));
    pin_changed  := new.pin is distinct from
      regexp_replace(coalesce(old.pin, ''), '\D', '', 'g');
  end if;

  if name_changed and new.name = '' then
    raise exception 'A workshop needs a name.'
      using errcode = 'check_violation';
  end if;
  if pin_changed and new.pin !~ '^[1-9][0-9]{5}$' then
    raise exception 'A workshop needs a valid 6-digit PIN code.'
      using errcode = 'check_violation';
  end if;
  return new;
end $fn$;

-- Only ever fired by the trigger; nothing calls it by name.
revoke execute on function public.check_garage_name_pin()
  from public, anon, authenticated;

drop trigger if exists garages_check_name_pin on public.garages;
create trigger garages_check_name_pin
  before insert or update of name, pin on public.garages
  for each row execute function public.check_garage_name_pin();

-- ---------------------------------------------------------------------
-- Check it took
-- ---------------------------------------------------------------------
-- Expects 1.
select count(*) as pin_trigger
  from pg_trigger
 where tgname = 'garages_check_name_pin'
   and not tgisinternal;

-- The workshops still without a valid PIN: the ones to call. The same
-- list Platform -> Partners marks "No PIN code".
select id, name, phone, pin, listed
  from public.garages
 where pin !~ '^[1-9][0-9]{5}$'
 order by listed desc, created_at;
-- =====================================================================
