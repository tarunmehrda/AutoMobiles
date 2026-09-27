-- =====================================================================
-- GaragePro -- files 18 to 22 in one paste
-- =====================================================================
-- A copy of the numbered files, in order, for running in one go in the
-- Supabase SQL editor: select all, copy, paste, Run. Every file is
-- idempotent, so this is safe even if some of them already ran.
--
-- Do not edit this copy; edit the numbered files and regenerate it.
-- The Results panel shows only the last query: expect 3.
-- =====================================================================


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>> 18_booking_vehicle_details.sql

-- =====================================================================
-- GaragePro — a booking carries the car, not just its name
-- =====================================================================
-- Run AFTER 10_open_booking.sql. Additive and idempotent: safe to re-run
-- on the live project.
--
-- A customer adds their car once — brand, model, variant, fuel, gearbox,
-- year and the odometer — and then books it. Until now only one string
-- of that reached the workshop: `vehicle`, set to "Brand Model", plus the
-- plate. The counter opened a job card that said "Maruti" for the brand
-- and "Suzuki Swift" for the model (the console split the string on its
-- first space), no gearbox, petrol by default, and a blank KM reading —
-- for a car whose owner had typed 60,000 km into the app the day before.
--
-- The fix is to send the car as the customer described it, one column
-- per fact, and let the console read the columns instead of guessing.
-- `vehicle` and `note` are still filled in exactly as before, so a
-- console that has not been updated yet keeps working unchanged.
--
-- ORDER MATTERS: run this before installing the new customer app and the
-- new console. The customer app falls back to the old shape if these
-- columns are missing, and the console skips a column the database does
-- not have, so nothing is lost — but the details only arrive once this
-- file has run.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. The booking request
-- ---------------------------------------------------------------------
-- Text columns default to '' rather than null, the convention the rest of
-- this table keeps. `year` and `odometer_km` stay nullable: zero is a
-- reading, "not given" is not.
alter table public.garage_bookings
  add column if not exists brand         text not null default '',
  add column if not exists model         text not null default '',
  add column if not exists variant       text not null default '',
  add column if not exists fuel          text not null default '',
  add column if not exists transmission  text not null default '',
  add column if not exists year          int,
  add column if not exists odometer_km   int,
  -- 'garage' (the customer drives in) or 'pickup' (pick & drop).
  add column if not exists mode          text not null default '',
  -- What the customer typed in "Additional notes". `note` keeps carrying
  -- the services they ticked, as it always has.
  add column if not exists customer_note text not null default '';

-- A reading the app would never send is a typo or a hand-rolled request.
do $$ begin
  alter table public.garage_bookings add constraint garage_bookings_km_sane
    check (odometer_km is null or odometer_km between 0 and 2000000);
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------
-- 2. The workshop's own record of the car
-- ---------------------------------------------------------------------
-- The console never had a gearbox field, so "Manual" or "Automatic" had
-- nowhere to land even once the booking carried it. '' means not recorded.
alter table public.garage_vehicles
  add column if not exists transmission text not null default '';

-- ---------------------------------------------------------------------
-- 3. Invoice numbers are per customer, not per planet
-- ---------------------------------------------------------------------
-- The customer app files each bill under the job card's number, and job
-- card numbers (`A0921-003`) are only unique inside one workshop. The
-- column was unique across every customer of every workshop, so the second
-- customer anywhere to get an `A0921-003` had their whole invoice upload
-- refused with 23505 — every time, for every invoice, because the app
-- sends them as one batch. Paid bills then never synced and came back
-- unpaid on a reinstall.
--
-- One customer cannot hold two bills with the same number from the same
-- card, so that is where uniqueness belongs.
alter table public.invoices drop constraint if exists invoices_number_key;
create unique index if not exists invoices_user_number
  on public.invoices (user_id, number);

-- ---------------------------------------------------------------------
-- 4. Your own workshop is bookable even when it is not in the directory
-- ---------------------------------------------------------------------
-- The booking screen loads the chosen workshop through `garage_card()`,
-- which answered only for listed garages. A customer who already deals with
-- a workshop that the platform has not listed (yet, or at all) tapped "Book
-- Service" on it and got an empty screen. Being in the directory is about
-- being found by strangers; it was never meant to stop a garage's own
-- customers from booking it. Same function as 08_platform.sql, one clause
-- wider.
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
  where g.id = gid
    and (g.listed or public.deals_with_garage(g.id));
$fn$;

revoke all on function public.garage_card(uuid) from public;
grant execute on function public.garage_card(uuid) to anon, authenticated;

-- ---------------------------------------------------------------------
-- Check it took (expects 9 booking columns and 1 vehicle column):
--
--   select table_name, column_name from information_schema.columns
--    where table_schema = 'public'
--      and ((table_name = 'garage_bookings' and column_name in
--            ('brand','model','variant','fuel','transmission','year',
--             'odometer_km','mode','customer_note'))
--        or (table_name = 'garage_vehicles' and column_name = 'transmission'))
--    order by 1, 2;
-- =====================================================================

-- >>>>>>>>>>>>>>>>>>>>>>>>>>>> 19_commission_and_roles.sql

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

-- >>>>>>>>>>>>>>>>>>>>>>>>>>>> 20_workflow_fixes.sql

-- =====================================================================
-- GaragePro — the gaps found in the full workflow check
-- =====================================================================
-- Run AFTER 19_commission_and_roles.sql. Additive and idempotent: safe to
-- re-run on the live project. Each section is one thing that was broken
-- between the console and the customer app, and says what it was.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. What the job card form collected and threw away
-- ---------------------------------------------------------------------
-- The console's new-card form asks for the customer's GSTIN and the car's
-- insurer, policy number and expiry. None of it was saved anywhere; an
-- insurance claim job needed it typed in again, every visit.
alter table public.garage_customers
  add column if not exists gstin text not null default '';

alter table public.garage_vehicles
  add column if not exists insurer          text not null default '',
  add column if not exists policy_no        text not null default '',
  add column if not exists insurance_expiry timestamptz;

-- ---------------------------------------------------------------------
-- 2. The online shopfront switch
-- ---------------------------------------------------------------------
-- "My Online Garage → Disable" lived on the counter's phone alone, and the
-- customer app went on offering the menu. Default true: every workshop
-- that has a menu today switched the shopfront on to build it.
alter table public.garages
  add column if not exists online_on boolean not null default true;

-- One workshop's public page (08_platform.sql, widened in 18_*.sql). Now
-- with no menu while the shopfront is off: the workshop can still be found
-- and booked, it just is not selling a menu.
create or replace function public.garage_card(gid uuid)
returns jsonb language sql stable security definer
set search_path = public as $fn$
  select jsonb_build_object(
    'id', g.id, 'name', g.name, 'phone', g.phone,
    'address_line', g.address_line, 'city', g.city, 'state', g.state,
    'pin', g.pin, 'lat', g.lat, 'lng', g.lng,
    'logo_path', g.logo_path, 'verified', g.verified,
    'services', case when not g.online_on then '[]'::jsonb else coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', s.id, 'name', s.name, 'price', s.price,
               'blurb', s.blurb, 'duration_mins', s.duration_mins)
             order by s.name)
        from public.online_services s where s.garage_id = g.id
    ), '[]'::jsonb) end
  )
  from public.garages g
  where g.id = gid
    and (g.listed or public.deals_with_garage(g.id));
$fn$;

revoke all on function public.garage_card(uuid) from public;
grant execute on function public.garage_card(uuid) to anon, authenticated;

-- ---------------------------------------------------------------------
-- 3. Job card photos leave the phone
-- ---------------------------------------------------------------------
-- Photos were stored on the card as file paths on the phone that took
-- them: every other phone, the PDF and the customer got a broken picture.
-- They now upload to this bucket at `<garage id>/<card id>/<file>`.
--
-- Public for reads, like the marketplace bucket: the path carries a
-- garage id, a card id and a microsecond timestamp, and a signed URL per
-- thumbnail would be a round trip per photo. Writes only into a folder
-- named after a garage the person works at.
insert into storage.buckets (id, name, public, file_size_limit,
                             allowed_mime_types)
values ('job-photos', 'job-photos', true, 10485760,
        array['image/jpeg', 'image/png', 'image/webp', 'image/heic'])
on conflict (id) do update set
  public             = true,
  file_size_limit    = 10485760,
  allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp',
                             'image/heic'];

drop policy if exists job_photos_read on storage.objects;
create policy job_photos_read on storage.objects
  for select to anon, authenticated
  using (bucket_id = 'job-photos');

drop policy if exists job_photos_write on storage.objects;
create policy job_photos_write on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'job-photos'
    and (storage.foldername(name))[1] in (
      select m.garage_id::text from public.garage_members m
       where m.profile_id = auth.uid())
  );

drop policy if exists job_photos_update on storage.objects;
create policy job_photos_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'job-photos'
    and (storage.foldername(name))[1] in (
      select m.garage_id::text from public.garage_members m
       where m.profile_id = auth.uid())
  );

drop policy if exists job_photos_delete on storage.objects;
create policy job_photos_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'job-photos'
    and (storage.foldername(name))[1] in (
      select m.garage_id::text from public.garage_members m
       where m.profile_id = auth.uid())
  );

-- ---------------------------------------------------------------------
-- 4. The customer can see every card of theirs
-- ---------------------------------------------------------------------
-- `my_job_cards` joins the card's vehicle, and a customer could read a
-- vehicle only when that vehicle's own record was theirs. A family car, a
-- resold car, or a car first brought in under someone else's name has a
-- vehicle record belonging to another customer — and the card, though it
-- was this customer's, vanished from their history, invoices and booking
-- progress. The card being theirs is enough to see the car on it.
drop policy if exists garage_vehicles_card_read on public.garage_vehicles;
create policy garage_vehicles_card_read on public.garage_vehicles
  for select using (
    exists (select 1 from public.job_cards j
             where j.vehicle_id = garage_vehicles.id
               and j.customer_profile_id = auth.uid())
  );

-- The view gains, at the end (a view can only grow at the end): the
-- customer's own rating of the card, and the card's own workshop
-- letterhead — the invoice used to print the address and terms of
-- whichever workshop the app happened to fetch first.
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
  g.terms             as garage_terms
from public.job_cards j
join public.garages g         on g.id = j.garage_id
join public.garage_vehicles v on v.id = j.vehicle_id
where j.customer_profile_id = auth.uid();

-- ---------------------------------------------------------------------
-- 5. A customer moves their own booking
-- ---------------------------------------------------------------------
-- Rescheduling moved the phone's copy only; the counter still expected the
-- car at the old time. The customer may now change the slot of a request
-- the counter has not accepted — the time, and nothing else on the row.
drop policy if exists garage_bookings_customer_move on public.garage_bookings;
create policy garage_bookings_customer_move on public.garage_bookings
  for update using (
    profile_id = auth.uid() and accepted = false and job_card_id is null
  )
  with check (
    profile_id = auth.uid() and accepted = false and job_card_id is null
  );

create or replace function public.guard_booking_customer_edit()
returns trigger language plpgsql
set search_path = public as $fn$
declare
  moved timestamptz := new.at;
begin
  -- The counter and the SQL editor edit freely.
  if auth.uid() is null or public.is_garage_member(old.garage_id) then
    return new;
  end if;
  new := old;
  new.at := moved;
  return new;
end $fn$;

drop trigger if exists garage_bookings_customer_edit on public.garage_bookings;
create trigger garage_bookings_customer_edit
  before update on public.garage_bookings
  for each row execute function public.guard_booking_customer_edit();

-- The counter hears about it, the way it hears about a new booking — and
-- about a request the customer called off, which used to simply vanish
-- from the front desk.
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
      '/bookings',
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

drop trigger if exists garage_bookings_moved on public.garage_bookings;
create trigger garage_bookings_moved
  after update of at or delete on public.garage_bookings
  for each row execute function public.notify_booking_moved();

-- ---------------------------------------------------------------------
-- 6. "Delete my account" deletes the account
-- ---------------------------------------------------------------------
-- It used to sign out and nothing more: the account and every car,
-- booking and invoice on it came back at the next sign-in. Deleting the
-- sign-in cascades to everything the customer owns (profiles, vehicles,
-- bookings, invoices, part requests and listings); the workshop keeps its
-- own records of the visits, with the link to this account cleared.
--
-- Refused for anyone who runs or works at a workshop: `garages.owner_id`
-- cascades, so deleting an owner's sign-in would delete the workshop and
-- every job card in it. That is a conversation, not a button.
create or replace function public.delete_my_account()
returns void language plpgsql security definer
set search_path = public as $fn$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'not signed in';
  end if;
  if public.is_platform_admin()
     or exists (select 1 from public.garage_members m where m.profile_id = uid)
     or exists (select 1 from public.garages g where g.owner_id = uid) then
    raise exception 'This account runs a workshop';
  end if;
  delete from auth.users where id = uid;
end $fn$;

revoke all on function public.delete_my_account() from public;
grant execute on function public.delete_my_account() to authenticated;

-- ---------------------------------------------------------------------
-- 7. Asking about a listed part
-- ---------------------------------------------------------------------
-- Buying was a dead end: a listing could be looked at and nothing else.
-- The app now turns "Ask about this part" into a part request addressed to
-- the listing's workshop, which needs to know which workshop that is. The
-- seller's own account is still never handed out.
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
             'city', l.city, 'pin', l.pin, 'created_at', l.created_at,
             'garage_id', l.garage_id)
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
-- Check it took
-- ---------------------------------------------------------------------
--   select count(*) from information_schema.columns
--    where table_schema = 'public'
--      and ((table_name = 'garage_customers' and column_name = 'gstin')
--        or (table_name = 'garage_vehicles'
--            and column_name in ('insurer','policy_no','insurance_expiry'))
--        or (table_name = 'garages' and column_name = 'online_on'));
--   -- expects 5
--   select id from storage.buckets where id = 'job-photos';  -- one row
-- =====================================================================

-- >>>>>>>>>>>>>>>>>>>>>>>>>>>> 21_private_commission.sql

-- =====================================================================
-- GaragePro — commission is private, and never less than 3%
-- =====================================================================
-- Run AFTER 20_workflow_fixes.sql. Idempotent: safe to re-run.
--
-- Partner A's owner sees what Partner A owes the platform and nothing of
-- Partner B's; B's owner the same the other way. A customer sees
-- neither, and neither do the front-desk logins a workshop's owner adds.
-- The platform sees each one — one partner at a time on the console.
--
-- The rate: 3% by default and never less. A partner may be given a
-- higher rate, up to 10% (a ceiling against a typo, not a price).
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. The ledger: the owner, not the whole front desk
-- ---------------------------------------------------------------------
-- 09_marketplace.sql let every member of a garage read its lines: the
-- owner, and every staff login the owner added. Narrowed to the owner.
-- The platform's own policy (`commissions_platform`) is unchanged.
drop policy if exists commissions_own on public.commissions;
create policy commissions_own on public.commissions
  for select to authenticated using (
    exists (select 1 from public.garage_members m
             where m.garage_id = commissions.garage_id
               and m.profile_id = auth.uid()
               and m.role = 'owner')
  );

-- ---------------------------------------------------------------------
-- 2. One workshop's commission, added up, for its owner
-- ---------------------------------------------------------------------
-- The totals are the database's, over every line, not whatever page of
-- lines the phone happened to load. `recent` is the latest 50 lines.
-- Null for anybody who does not own `gid` — staff, customers, and other
-- workshops' owners alike.
create or replace function public.my_commission(gid uuid)
returns jsonb language sql stable security definer
set search_path = public as $fn$
  select case
    when not exists (select 1 from public.garage_members m
                      where m.garage_id = gid
                        and m.profile_id = auth.uid()
                        and m.role = 'owner')
    then null
    else (
      select jsonb_build_object(
               'garage_id', g.id,
               'name',      g.name,
               'rate',      public.commission_rate(g.id),
               'lines',     count(c.id),
               'billed',    coalesce(sum(c.amount) filter (where c.status <> 'waived'), 0),
               'accrued',   coalesce(sum(c.fee) filter (where c.status = 'accrued'), 0),
               'invoiced',  coalesce(sum(c.fee) filter (where c.status = 'invoiced'), 0),
               'settled',   coalesce(sum(c.fee) filter (where c.status = 'settled'), 0),
               'waived',    coalesce(sum(c.fee) filter (where c.status = 'waived'), 0),
               'recent',    coalesce((
                 select jsonb_agg(to_jsonb(r) order by r.at desc)
                   from (select * from public.commissions
                          where garage_id = g.id
                          order by at desc
                          limit 50) r
               ), '[]'::jsonb))
        from public.garages g
        left join public.commissions c on c.garage_id = g.id
       where g.id = gid
       group by g.id
    )
  end;
$fn$;

revoke all on function public.my_commission(uuid) from public;
grant execute on function public.my_commission(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- 3. The rate: at least 3%
-- ---------------------------------------------------------------------
-- 19_commission_and_roles.sql first allowed 2% to 3%. Anything under 3%
-- goes up to it: the default to 3%, a partner's own rate back to "use
-- the default". Lines already booked keep the rate they were booked at.
update public.platform_settings
   set commission_pct = 3.00, updated_at = now()
 where id = 1 and commission_pct not between 3 and 10;

update public.garages
   set commission_pct = null
 where commission_pct is not null and commission_pct not between 3 and 10;

alter table public.platform_settings
  drop constraint if exists platform_settings_commission_band;
alter table public.platform_settings
  add constraint platform_settings_commission_band
  check (commission_pct between 3 and 10);

alter table public.garages
  drop constraint if exists garages_commission_band;
alter table public.garages
  add constraint garages_commission_band
  check (commission_pct is null or commission_pct between 3 and 10);

-- As 19_commission_and_roles.sql, with the new band.
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
-- Check it took
-- ---------------------------------------------------------------------
-- The policy now names the owner role (expects one row, true):
select polname, pg_get_expr(polqual, polrelid) like '%owner%' as owner_only
  from pg_policy
 where polrelid = 'public.commissions'::regclass
   and polname = 'commissions_own';

-- The default rate is at least 3 (expects 3.00 unless you raised it):
select commission_pct from public.platform_settings where id = 1;
-- =====================================================================

-- >>>>>>>>>>>>>>>>>>>>>>>>>>>> 22_customer_push.sql

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
      shop || ' confirmed your booking for ' || public.alert_when(new.at) || '.');
  elsif new.at is distinct from old.at then
    perform public.push_customer_alert(
      new.profile_id, 'booking', 'Booking time changed',
      shop || ' moved your booking to ' || public.alert_when(new.at) || '.');
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
        || '. Job card ' || new.number || '.');
  elsif new.status = 'closed' then
    perform public.push_customer_alert(
      new.customer_profile_id, 'service', 'Visit closed',
      'Thank you for visiting ' || shop || '. Job card ' || new.number
        || ' is closed; the bill is in the app.');
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
      || ' received by ' || shop || ' for job card ' || j.number || '.');
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

revoke all on function public.push_customer_alert(uuid, text, text, text, text) from public;
revoke all on function public.register_customer_device(text, text) from public;
revoke all on function public.forget_customer_device(text) from public;
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
