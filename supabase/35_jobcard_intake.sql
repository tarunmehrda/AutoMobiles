-- =====================================================================
-- GaragePro — the client's October 2026 workflow
-- =====================================================================
-- Run AFTER 34_block_is_platform_only.sql (and after 20 and 24, which it
-- builds on). Additive and idempotent: safe to re-run on the live project.
--
-- The console writes every new field before this file has been run: the
-- table sync sheds a column the database does not have yet, and
-- save_job_card() ignores keys it does not name, so nothing breaks — the
-- new fields just wait on the phone until this is run.
--
--   1. Insurance on the vehicle: policy start, insurer address and GSTIN
--   2. Staff: designation and remarks
--   3. Expenses paid online; cash-book lines tied to a bank account
--   4. Per-line GST and unit on job card lines
--   5. Social links on the workshop
--   6. Bank accounts and cash in hand
--   7. Estimates, sales and purchase documents
--   8. save_job_card() / job_card_json() carry the per-line GST and unit
--   9. The customer's job card view: GST per line, advance, payments,
--      insurance, year, and who the bill is made out to
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Insurance on the vehicle
-- ---------------------------------------------------------------------
-- Repeated from 20_workflow_fixes.sql, so this file stands on its own on
-- a project where 20 was never run.
alter table public.garage_customers
  add column if not exists gstin text not null default '';

alter table public.garage_vehicles
  add column if not exists insurer          text not null default '',
  add column if not exists policy_no        text not null default '',
  add column if not exists insurance_expiry timestamptz,
  add column if not exists insurance_from  timestamptz,
  add column if not exists insurer_address text not null default '',
  add column if not exists insurer_gstin   text not null default '';

-- ---------------------------------------------------------------------
-- 2. Staff: what they are employed as, and a note
-- ---------------------------------------------------------------------
alter table public.staff
  add column if not exists designation text not null default '',
  add column if not exists remarks     text not null default '';

-- ---------------------------------------------------------------------
-- 3. Money that went through the bank
-- ---------------------------------------------------------------------
alter table public.expenses
  add column if not exists mode text not null default 'cash';

-- Null: by the line's mode — cash is the drawer, anything else the
-- primary bank account.
alter table public.cash_book
  add column if not exists account_id text;

-- ---------------------------------------------------------------------
-- 4. Per-line GST and unit
-- ---------------------------------------------------------------------
-- gst_rate is a fraction (0.18). Null bills the line at the card's rate.
alter table public.line_items
  add column if not exists gst_rate numeric,
  add column if not exists unit     text not null default '';

-- ---------------------------------------------------------------------
-- 5. Social links
-- ---------------------------------------------------------------------
alter table public.garages
  add column if not exists social jsonb not null default '{}'::jsonb;

-- ---------------------------------------------------------------------
-- 6. Bank accounts and cash in hand
-- ---------------------------------------------------------------------
-- One row per place money is kept. The drawer is the row with cash = true
-- and id 'cash-in-hand'; balances are worked out on the phone from the
-- opening balance and the cash book.
create table if not exists public.bank_accounts (
  id               text not null,
  garage_id        uuid not null references public.garages (id)
                     on delete cascade,
  name             text not null default '',
  cash             boolean not null default false,
  holder           text not null default '',
  account_no       text not null default '',
  ifsc             text not null default '',
  branch           text not null default '',
  upi_id           text not null default '',
  opening          numeric not null default 0,
  opening_at       timestamptz,
  is_primary       boolean not null default false,
  print_on_invoice boolean not null default false,
  print_upi_qr     boolean not null default false,
  created_at       timestamptz not null default now(),
  -- 'cash-in-hand' is the same id in every workshop, so the key is the pair.
  primary key (garage_id, id)
);

-- ---------------------------------------------------------------------
-- 7. Sales and purchase documents
-- ---------------------------------------------------------------------
create table if not exists public.trade_docs (
  id          text primary key,
  garage_id   uuid not null references public.garages (id) on delete cascade,
  kind        text not null
                check (kind in ('estimate', 'saleReturn', 'saleOrder',
                                'purchaseBill', 'purchaseReturn')),
  number      text not null default '',
  at          timestamptz not null default now(),
  party       text not null default '',
  phone       text not null default '',
  gstin       text not null default '',
  address     text not null default '',
  supplier_id text,
  customer_id text,
  lines       jsonb not null default '[]'::jsonb,
  split       text not null default 'intra',
  discount    numeric not null default 0,
  paid        numeric not null default 0,
  mode        text not null default 'cash',
  account_id  text,
  note        text not null default '',
  ref_no      text not null default '',
  due_at      timestamptz,
  fulfilled   boolean not null default false,
  created_at  timestamptz not null default now()
);
create index if not exists trade_docs_garage_idx
  on public.trade_docs (garage_id, at desc);

alter table public.bank_accounts enable row level security;
alter table public.trade_docs    enable row level security;

-- Members do everything, as with the rest of the books (02_garage.sql).
do $blk$
declare t text;
begin
  foreach t in array array['bank_accounts', 'trade_docs'] loop
    execute format('drop policy if exists %I_member on public.%I', t, t);
    execute format(
      'create policy %I_member on public.%I for all
         using (public.is_garage_member(garage_id))
         with check (public.is_garage_member(garage_id))', t, t);
  end loop;
end
$blk$;

-- Narrowed by staff role where 31_staff_logins.sql has been run: money is
-- 'finance', documents are 'purchases'. Skipped on a database without it.
do $blk$
declare
  t record;
begin
  if to_regprocedure('public.role_allows(uuid, text, text)') is null then
    raise notice 'role_allows() not found; 31 not run, role policies skipped';
    return;
  end if;
  for t in
    select * from (values
      ('bank_accounts', 'finance'),
      ('trade_docs',    'purchases')
    ) as x(tbl, module)
  loop
    execute format('drop policy if exists %I on public.%I',
                   t.tbl || '_role_read', t.tbl);
    execute format('drop policy if exists %I on public.%I',
                   t.tbl || '_role_add', t.tbl);
    execute format('drop policy if exists %I on public.%I',
                   t.tbl || '_role_edit', t.tbl);
    execute format('drop policy if exists %I on public.%I',
                   t.tbl || '_role_remove', t.tbl);
    execute format(
      'create policy %I on public.%I as restrictive for select
         to authenticated using (public.role_allows(garage_id, %L, ''v''))',
      t.tbl || '_role_read', t.tbl, t.module);
    execute format(
      'create policy %I on public.%I as restrictive for insert
         to authenticated with check (public.role_allows(garage_id, %L, ''c''))',
      t.tbl || '_role_add', t.tbl, t.module);
    execute format(
      'create policy %I on public.%I as restrictive for update
         to authenticated
         using (public.role_allows(garage_id, %L, ''e''))
         with check (public.role_allows(garage_id, %L, ''e''))',
      t.tbl || '_role_edit', t.tbl, t.module, t.module);
    execute format(
      'create policy %I on public.%I as restrictive for delete
         to authenticated using (public.role_allows(garage_id, %L, ''d''))',
      t.tbl || '_role_remove', t.tbl, t.module);
  end loop;
end
$blk$;

grant select, insert, update, delete on public.bank_accounts to authenticated;
grant select, insert, update, delete on public.trade_docs    to authenticated;

-- Realtime, like the rest of the books (16_fix_realtime_publication.sql).
do $blk$
declare t text;
begin
  foreach t in array array['bank_accounts', 'trade_docs'] loop
    begin
      execute format(
        'alter publication supabase_realtime add table public.%I', t);
    exception
      when duplicate_object then null;
      when undefined_object then null;
    end;
    execute format('alter table public.%I replica identity full', t);
  end loop;
end
$blk$;

-- ---------------------------------------------------------------------
-- 8. A job card's lines carry their own GST and unit
-- ---------------------------------------------------------------------
-- job_card_json() as 03_sync.sql, with gst_rate and unit on each line.
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
          'remark', li.remark, 'master_id', li.master_id,
          'gst_rate', li.gst_rate, 'unit', li.unit)
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

revoke execute on function public.job_card_json(public.job_cards)
  from public, anon, authenticated;

-- save_job_card() exactly as 24_close_audit_findings.sql, with the two
-- line columns written.
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

  keep := coalesce(array(
    select e.value ->> 'id'
    from jsonb_array_elements(coalesce(payload -> 'items', '[]'::jsonb)) e),
    '{}');

  insert into public.line_items (
    id, job_card_id, kind, name, part_no, qty, rate,
    mechanic_id, state, remark, master_id, position, gst_rate, unit)
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
    (e.ordinality - 1)::int,
    (e.value ->> 'gst_rate')::numeric,
    coalesce(e.value ->> 'unit', '')
  from jsonb_array_elements(coalesce(payload -> 'items', '[]'::jsonb))
       with ordinality as e(value, ordinality)
  on conflict (id) do update set
    kind = excluded.kind, name = excluded.name, part_no = excluded.part_no,
    qty = excluded.qty, rate = excluded.rate,
    mechanic_id = excluded.mechanic_id, state = excluded.state,
    remark = excluded.remark, master_id = excluded.master_id,
    position = excluded.position,
    gst_rate = excluded.gst_rate, unit = excluded.unit
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
end;
$fn$;

revoke all on function public.save_job_card(jsonb) from public, anon;
grant execute on function public.save_job_card(jsonb) to authenticated;

-- ---------------------------------------------------------------------
-- 9. What the customer sees of their job card
-- ---------------------------------------------------------------------
-- As 20_workflow_fixes.sql. Each line now carries its GST and unit, and
-- new columns are added at the END (a view can only grow that way):
--   payment_list   every payment with its mode and date, advance flagged
--   advance        the money taken when the card was opened
--   vehicle_year, insurer, policy_no, insurance_from, insurance_expiry,
--   insurer_address, insurer_gstin
--   bill_name, bill_phone, bill_email, bill_address, bill_gstin
--   bank           the account the workshop prints on its invoice, if any
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
          'state', li.state, 'remark', li.remark,
          'gst_rate', li.gst_rate, 'unit', li.unit
        ) order by li.position
      ), '[]'::jsonb)
    from public.line_items li
    where li.job_card_id = j.id
  )                   as items,
  (
    select coalesce(sum(p.amount), 0)
    from public.payments p
    where p.job_card_id = j.id
  )                   as paid,
  (
    select r.stars from public.reviews r
     where r.job_card_id = j.id and r.profile_id = auth.uid()
  )                   as my_stars,
  (
    select r.comment from public.reviews r
     where r.job_card_id = j.id and r.profile_id = auth.uid()
  )                   as my_comment,
  g.address_line      as garage_address,
  g.city              as garage_city,
  g.state             as garage_state,
  g.pin               as garage_pin,
  g.email             as garage_email,
  g.terms             as garage_terms,
  -- --- 35 ---------------------------------------------------------------
  (
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', p.id, 'amount', p.amount, 'mode', p.mode, 'at', p.at,
          'advance', (p.id like 'adv-%' or p.note ilike '%advance%')
        ) order by p.at
      ), '[]'::jsonb)
    from public.payments p
    where p.job_card_id = j.id
  )                   as payment_list,
  (
    select coalesce(sum(p.amount), 0)
    from public.payments p
    where p.job_card_id = j.id
      and (p.id like 'adv-%' or p.note ilike '%advance%')
  )                   as advance,
  v.year              as vehicle_year,
  v.insurer,
  v.policy_no,
  v.insurance_from,
  v.insurance_expiry,
  v.insurer_address,
  v.insurer_gstin,
  c.name              as bill_name,
  c.phone             as bill_phone,
  c.email             as bill_email,
  c.address           as bill_address,
  c.gstin             as bill_gstin,
  (
    select jsonb_build_object(
             'name', b.name, 'holder', b.holder, 'account_no', b.account_no,
             'ifsc', b.ifsc, 'branch', b.branch, 'upi_id', b.upi_id)
      from public.bank_accounts b
     where b.garage_id = j.garage_id and not b.cash and b.print_on_invoice
     order by b.is_primary desc
     limit 1
  )                   as bank
from public.job_cards j
join public.garages g          on g.id = j.garage_id
join public.garage_vehicles v  on v.id = j.vehicle_id
join public.garage_customers c on c.id = j.customer_id
where j.customer_profile_id = auth.uid();

-- The view runs as the customer, who has no policy on bank_accounts. The
-- one account a workshop chose to print is public by its own choice, so
-- the customer is let read exactly that row and nothing else.
drop policy if exists bank_accounts_printed_read on public.bank_accounts;
create policy bank_accounts_printed_read on public.bank_accounts
  for select to authenticated
  using (
    not cash and print_on_invoice
    and exists (select 1 from public.job_cards j
                 where j.garage_id = bank_accounts.garage_id
                   and j.customer_profile_id = auth.uid())
  );

-- The view also reads the vehicle's and the customer's rows as the
-- customer; 20_workflow_fixes.sql already lets them read their own.

grant select on public.my_job_cards to authenticated;

-- ---------------------------------------------------------------------
-- Check it
-- ---------------------------------------------------------------------
-- Every row should come back true.
select 'vehicles.insurer_gstin' as what,
       exists (select 1 from information_schema.columns
                where table_schema = 'public' and table_name = 'garage_vehicles'
                  and column_name = 'insurer_gstin') as ok
union all
select 'line_items.gst_rate',
       exists (select 1 from information_schema.columns
                where table_schema = 'public' and table_name = 'line_items'
                  and column_name = 'gst_rate')
union all
select 'bank_accounts', to_regclass('public.bank_accounts') is not null
union all
select 'trade_docs', to_regclass('public.trade_docs') is not null
union all
select 'my_job_cards.payment_list',
       exists (select 1 from information_schema.columns
                where table_schema = 'public' and table_name = 'my_job_cards'
                  and column_name = 'payment_list');
