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
