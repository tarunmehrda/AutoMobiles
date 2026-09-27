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
