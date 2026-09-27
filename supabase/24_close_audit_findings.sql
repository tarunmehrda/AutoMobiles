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
