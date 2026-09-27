-- =====================================================================
-- GaragePro — one platform account, and the commission it earns
-- =====================================================================
-- Run AFTER 18_booking_vehicle_details.sql. Idempotent: safe to re-run.
--
-- Who is who, after this file:
--
--   * The platform account — firefringe@gmail.com, the developer — is the
--     only account above the garages. It approves partner workshops into
--     the customer directory, verifies them, sets the commission rate and
--     reads what every garage owes. It is granted here, in the SQL editor,
--     and nowhere else. No screen in either app can grant it or take it
--     away.
--
--   * A partner is a workshop. Its owner runs it and adds their own staff
--     in the console. A partner cannot list itself, verify itself, or see
--     or set its commission rate.
--
--   * A customer is never charged commission and never sees it.
--
-- How commission works:
--
--   When a garage closes a job card in the console, the database books
--   one ledger line for it automatically:
--
--       amount = the bill before GST = sum(qty x rate) - discount
--       fee    = amount x rate / 100
--
--   The rate is 3% by default, may be set per garage between 3% and 10%,
--   and is frozen on the line the first time the card closes, so changing
--   the rate later never re-prices bills already booked. Re-saving a closed
--   card (a late payment, a corrected line) re-computes the amount while
--   the line is still `accrued`. Reopening the card withdraws the line
--   until it closes again. Once the platform marks a line invoiced,
--   settled or waived, nothing the garage does moves it again.
--
--   The ledger records what is owed. It moves no money: the platform
--   collects from each garage (UPI, bank transfer) and marks the lines
--   settled.
--
-- EDIT THIS if the platform account changes: the address appears once,
-- in section 2.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Nobody promotes themselves
-- ---------------------------------------------------------------------
-- `profiles_self` (03_sync.sql) lets a signed-in person write their own
-- profile row — every column of it, `role` included. So any customer
-- could send one PATCH from their own session, set `role = 'platform'`,
-- and read every garage on the register, rewrite the commission, and
-- approve their own listings. The apps never write `role` after sign-up,
-- so nothing legitimate is lost by freezing it.
--
-- It is frozen in both directions for app sessions. Gaining `platform` is
-- the attack; losing it was a bug of its own: `create_garage()` stamps
-- `owner` on whoever calls it, so the platform account registering a
-- workshop to test with would silently stop being the platform account.
--
-- Other moves (`customer` -> `owner` when someone registers a workshop)
-- still go through: `profiles.role = 'owner'` grants nothing by itself —
-- what a person may do inside a garage comes from `garage_members`.
--
-- The SQL editor and the service role carry no user (`auth.uid()` is
-- null), so this file, and anything the developer runs by hand, is not
-- affected.
create or replace function public.guard_profile_role()
returns trigger language plpgsql
set search_path = public as $fn$
begin
  if auth.uid() is null then
    return new;
  end if;

  if tg_op = 'INSERT' then
    if new.role = 'platform' then
      new.role := 'customer';
    end if;
    return new;
  end if;

  if old.role = 'platform' or new.role = 'platform' then
    new.role := old.role;
  end if;
  return new;
end $fn$;

drop trigger if exists profiles_guard_role on public.profiles;
create trigger profiles_guard_role
  before insert or update on public.profiles
  for each row execute function public.guard_profile_role();

-- ---------------------------------------------------------------------
-- 2. The platform account is exactly one Gmail
-- ---------------------------------------------------------------------
-- Grants it, and takes it off every other account. Until section 1 there
-- was no telling who else might hold it, so the safe reading is: anyone
-- who is not the developer and has it, got it by the hole above. They go
-- back to `owner` if they belong to a garage, otherwise `customer`.
do $blk$
declare
  dev_email constant text := 'firefringe@gmail.com';
  dev uuid;
  demoted int;
begin
  select id into dev from auth.users where lower(email) = lower(dev_email);

  if dev is null then
    raise notice '% has not signed in yet. Sign in once on the console with that Google account, then run this file again.', dev_email;
  else
    update public.profiles set role = 'platform' where id = dev;
    raise notice '% is the platform account.', dev_email;
  end if;

  update public.profiles p
     set role = case
                  when exists (select 1 from public.garage_members m
                                where m.profile_id = p.id)
                  then 'owner' else 'customer'
                end
   where p.role = 'platform'
     and p.id is distinct from dev;
  get diagnostics demoted = row_count;
  if demoted > 0 then
    raise notice 'Removed the platform role from % other account(s).',
                 demoted;
  end if;
end
$blk$;

-- ---------------------------------------------------------------------
-- 3. Partners are the platform's decision
-- ---------------------------------------------------------------------
-- 10_open_booking.sql listed a workshop in the customer directory the
-- moment it dropped a pin. That put every sign-up in front of customers
-- with nobody having looked at it. Listing goes back to being the
-- platform's call, made under Platform -> Partners. Workshops already
-- listed stay listed; only the automatic part stops.
drop trigger if exists garages_list_on_locate on public.garages;
drop function if exists public.list_on_locate();

-- `garages_member_all` (02_garage.sql) lets any member of a garage write
-- every column of it. The console only ever sends the letterhead, but a
-- hand-rolled request could have listed the garage, verified it, or set
-- its own commission to the floor — or, before this file, 0%. Those three are
-- the platform's, so for everybody else they are simply kept as they
-- were. The rest of the row is untouched by this.
create or replace function public.guard_garage_platform_columns()
returns trigger language plpgsql
set search_path = public as $fn$
begin
  if auth.uid() is null or public.is_platform_admin() then
    return new;
  end if;

  if tg_op = 'INSERT' then
    new.listed         := false;
    new.verified       := false;
    new.commission_pct := null;
  else
    new.listed         := old.listed;
    new.verified       := old.verified;
    new.commission_pct := old.commission_pct;
  end if;
  return new;
end $fn$;

drop trigger if exists garages_guard_platform on public.garages;
create trigger garages_guard_platform
  before insert or update on public.garages
  for each row execute function public.guard_garage_platform_columns();

-- ---------------------------------------------------------------------
-- 4. The rate: 3% by default and never less; 3% to 10% allowed
-- ---------------------------------------------------------------------
alter table public.platform_settings
  alter column commission_pct set default 3.00;

-- Only a rate outside the new band is moved, so re-running this file never
-- undoes a rate the platform has since chosen inside it.
update public.platform_settings
   set commission_pct = 3.00, updated_at = now()
 where id = 1 and commission_pct not between 3 and 10;

-- A per-garage rate outside the band goes back to "use the default".
update public.garages
   set commission_pct = null
 where commission_pct is not null and commission_pct not between 3 and 10;

do $$ begin
  alter table public.platform_settings
    add constraint platform_settings_commission_band
    check (commission_pct between 3 and 10);
exception when duplicate_object then null; end $$;

do $$ begin
  alter table public.garages
    add constraint garages_commission_band
    check (commission_pct is null or commission_pct between 3 and 10);
exception when duplicate_object then null; end $$;

create or replace function public.commission_rate(gid uuid)
returns numeric language sql stable
set search_path = public as $fn$
  select coalesce(
    (select commission_pct from public.garages where id = gid),
    (select commission_pct from public.platform_settings where id = 1),
    3.00);
$fn$;

-- The platform's switches on one garage. Same as 08_platform.sql, with one
-- change: sending `commission_pct: null` now clears a garage's own rate
-- back to the default. Before, an absent key and a null were the same
-- thing, and a garage given its own rate could never be put back.
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
    commission_pct = case
                       when payload ? 'commission_pct'
                       then nullif(payload ->> 'commission_pct', '')::numeric
                       else commission_pct
                     end
   where id = gid
   returning * into g;

  if g.id is null then
    raise exception 'no such garage';
  end if;
  return to_jsonb(g);
end $fn$;

revoke all on function public.set_garage_listing(jsonb) from public;
grant execute on function public.set_garage_listing(jsonb) to authenticated;

-- ---------------------------------------------------------------------
-- 5. A closed job card books its own commission
-- ---------------------------------------------------------------------
-- A constraint trigger, deferred to commit, and not an ordinary one.
-- `save_job_card()` writes the card row first and its line items after,
-- in the same transaction, so an ordinary trigger on `job_cards` would
-- price the bill before its lines exist. At commit everything is in.
--
-- The card is re-read rather than trusted from NEW, because one save can
-- touch the row more than once and only the final state is the bill.
create or replace function public.accrue_commission()
returns trigger language plpgsql security definer
set search_path = public as $fn$
declare
  j    public.job_cards;
  base numeric;
  rate numeric;
begin
  select * into j from public.job_cards where id = new.id;
  if not found then
    return null;
  end if;

  -- Not closed (never was, or reopened): the bill is not final, so it owes
  -- nothing yet. Only the automatic line goes; one the platform booked by
  -- hand against this card is theirs to manage.
  if j.status <> 'closed' then
    delete from public.commissions
     where job_card_id = j.id
       and id = 'jc-' || j.id
       and status = 'accrued';
    return null;
  end if;

  -- The bill before GST, exactly as the console computes `taxable`.
  select greatest(coalesce(sum(li.qty * li.rate), 0) - j.discount, 0)
    into base
    from public.line_items li
   where li.job_card_id = j.id;
  base := round(base, 2);
  rate := public.commission_rate(j.garage_id);

  insert into public.commissions as c (
    id, garage_id, job_card_id, amount, pct, fee, note, at)
  values (
    'jc-' || j.id, j.garage_id, j.id, base, rate,
    round(base * rate / 100.0, 2),
    'Job card ' || j.number,
    coalesce(j.closed_at, now()))
  on conflict (job_card_id) where job_card_id is not null
  do update set
    amount = excluded.amount,
    -- The rate stays whatever it was when the card first closed.
    fee    = round(excluded.amount * c.pct / 100.0, 2),
    note   = excluded.note
  where c.status = 'accrued';

  return null;
end $fn$;

drop trigger if exists job_cards_accrue_commission on public.job_cards;
create constraint trigger job_cards_accrue_commission
  after insert or update on public.job_cards
  deferrable initially deferred
  for each row execute function public.accrue_commission();

-- ---------------------------------------------------------------------
-- 6. Booking a line by hand
-- ---------------------------------------------------------------------
-- As 09_marketplace.sql, plus the band: a rate typed by hand must sit in
-- it too, so a slip of the finger cannot book 30% against a partner.
create or replace function public.book_commission(payload jsonb)
returns jsonb language plpgsql security definer
set search_path = public, extensions, pg_temp as $fn$
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
  if amt <= 0 then
    raise exception 'amount must be greater than zero';
  end if;

  rate := coalesce(nullif(payload ->> 'pct', '')::numeric,
                   public.commission_rate(gid));
  if rate not between 3 and 10 then
    raise exception 'commission must be between 3%% and 10%%';
  end if;

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
-- 7. What each garage owes, in one call
-- ---------------------------------------------------------------------
-- The console used to add up the last 200 ledger lines on the phone. With
-- every closed card booking a line, 200 is a week at a busy register, and
-- the totals would quietly stop being totals. The database adds them up.
-- Platform only; anybody else gets an empty list, not an error.
create or replace function public.commission_summary()
returns jsonb language sql stable security definer
set search_path = public as $fn$
  select case when not public.is_platform_admin() then '[]'::jsonb else
    coalesce((
      select jsonb_agg(jsonb_build_object(
               'garage_id',   g.id,
               'name',        g.name,
               'phone',       g.phone,
               'rate',        public.commission_rate(g.id),
               'custom_rate', g.commission_pct,
               'lines',       coalesce(s.lines, 0),
               'billed',      coalesce(s.billed, 0),
               'accrued',     coalesce(s.accrued, 0),
               'invoiced',    coalesce(s.invoiced, 0),
               'settled',     coalesce(s.settled, 0),
               'waived',      coalesce(s.waived, 0))
             order by coalesce(s.accrued, 0) + coalesce(s.invoiced, 0) desc,
                      g.name)
        from public.garages g
        left join (
          select garage_id,
                 count(*)                                  as lines,
                 sum(amount) filter (where status <> 'waived') as billed,
                 sum(fee) filter (where status = 'accrued')  as accrued,
                 sum(fee) filter (where status = 'invoiced') as invoiced,
                 sum(fee) filter (where status = 'settled')  as settled,
                 sum(fee) filter (where status = 'waived')   as waived
            from public.commissions
           group by garage_id
        ) s on s.garage_id = g.id
    ), '[]'::jsonb)
  end;
$fn$;

revoke all on function public.commission_summary() from public;
grant execute on function public.commission_summary() to authenticated;

-- ---------------------------------------------------------------------
-- 8. Cards closed before today (optional — read before running)
-- ---------------------------------------------------------------------
-- Commission starts with the next card a garage closes. To also book it
-- on every card already closed, un-comment and run this one line. It
-- touches each closed card once, which fires section 5 for it:
--
--   update public.job_cards set updated_at = updated_at where status = 'closed';

-- ---------------------------------------------------------------------
-- Check it took
-- ---------------------------------------------------------------------
-- Exactly one row, your address, role = platform:
select u.email, p.role
  from public.profiles p join auth.users u on u.id = p.id
 where p.role = 'platform';

-- The default rate (expects 3.00 on a first run):
select commission_pct from public.platform_settings where id = 1;
-- =====================================================================
