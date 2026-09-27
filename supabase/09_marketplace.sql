-- =====================================================================
-- GaragePro — parts wanted, parts for sale, what the platform earns, and
-- the video a new customer sees
-- =====================================================================
-- Run AFTER 08_platform.sql. Additive and idempotent. It adds four things
-- that did not exist before and changes nothing that did.
--
-- The shape of every table here follows the two rules the rest of the
-- schema already keeps:
--
--   * a row belongs to somebody, and the policy says who in one line, and
--   * money the workshop should not see is not on a row the workshop can
--     read. Commission is the platform's business with the partner; the
--     customer never sees it and is never charged it.
--
-- On ids: text primary keys minted by the client, like `job_cards` and
-- `line_items`, so a phone can create a row offline and sync it later
-- without a round trip for an id it already has.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. "I need this part"
-- ---------------------------------------------------------------------
-- A customer describes what they are after; the platform quotes it back
-- by hand, through the code. The code is what the customer reads out on
-- the phone, so it is short and unambiguous — no O/0, no I/1.

create table if not exists public.part_requests (
  id          text primary key,
  user_id     uuid not null references auth.users (id) on delete cascade,
  -- Which car it is for. Kept as loose text as well as an optional link,
  -- because somebody asks for a part for a car that is not in the app.
  vehicle_id  text,
  vehicle_text text not null default '',
  part_name   text not null default '',
  detail      text not null default '',
  photos      text[] not null default '{}',
  -- The quotable code. Assigned by the database on insert, never chosen.
  code        text not null unique,
  status      text not null default 'pending'
                check (status in ('pending', 'processing', 'completed',
                                  'cancelled')),
  -- The platform's working notes and the number it quoted back. The
  -- customer reads `quote` and `note`; `status` is what drives their screen.
  quote       numeric(12,2),
  note        text not null default '',
  -- Which partner, if any, the platform handed it to.
  garage_id   uuid references public.garages (id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists part_requests_user_idx
  on public.part_requests (user_id, created_at desc);
create index if not exists part_requests_status_idx
  on public.part_requests (status, created_at desc);
create index if not exists part_requests_garage_idx
  on public.part_requests (garage_id, created_at desc);

-- Crockford-ish alphabet: the ten digits and the letters that cannot be
-- misheard or mistyped for one of them.
create or replace function public.mint_request_code()
returns text language plpgsql volatile
set search_path = public as $fn$
declare
  alphabet constant text := '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  made text;
  i    int;
begin
  for attempt in 1 .. 12 loop
    made := 'R';
    for i in 1 .. 6 loop
      made := made || substr(alphabet,
                1 + floor(random() * length(alphabet))::int, 1);
    end loop;
    exit when not exists (
      select 1 from public.part_requests where code = made);
    made := null;
  end loop;
  if made is null then
    raise exception 'could not mint a free request code';
  end if;
  return made;
end $fn$;

-- The code and the owner are the database's, not the client's. A phone
-- that posts `user_id` of somebody else, or picks its own code, is
-- overruled here rather than rejected — there is nothing to negotiate.
create or replace function public.guard_part_request()
returns trigger language plpgsql
set search_path = public as $fn$
begin
  if tg_op = 'INSERT' then
    new.user_id := coalesce(auth.uid(), new.user_id);
    new.code    := public.mint_request_code();
    new.status  := 'pending';
    new.quote   := null;
    new.note    := '';
    new.garage_id := null;
  else
    new.user_id := old.user_id;
    new.code    := old.code;
    -- Only the platform moves a request along or prices it. A customer
    -- editing their own row keeps whatever the platform last set.
    if not public.is_platform_admin() then
      new.status    := old.status;
      new.quote     := old.quote;
      new.note      := old.note;
      new.garage_id := old.garage_id;
    end if;
    new.updated_at := now();
  end if;
  return new;
end $fn$;

drop trigger if exists part_requests_guard on public.part_requests;
create trigger part_requests_guard
  before insert or update on public.part_requests
  for each row execute function public.guard_part_request();

alter table public.part_requests enable row level security;

drop policy if exists part_requests_own on public.part_requests;
create policy part_requests_own on public.part_requests
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists part_requests_platform on public.part_requests;
create policy part_requests_platform on public.part_requests
  for all to authenticated
  using (public.is_platform_admin())
  with check (public.is_platform_admin());

-- The partner the platform handed it to may read it, and nothing else in
-- the queue. This is the Partner A / Partner B line for this table.
drop policy if exists part_requests_assigned on public.part_requests;
create policy part_requests_assigned on public.part_requests
  for select to authenticated
  using (garage_id is not null and public.is_garage_member(garage_id));

-- ---------------------------------------------------------------------
-- 2. Parts for sale
-- ---------------------------------------------------------------------
-- The other direction: somebody has a part to move. A listing is private
-- until the platform approves it, so the browse screen can never show a
-- listing nobody has looked at.

create table if not exists public.part_listings (
  id          text primary key,
  user_id     uuid not null references auth.users (id) on delete cascade,
  -- Set when a partner lists from the console rather than a customer from
  -- the app. It is what the commission on a sale is booked against.
  garage_id   uuid references public.garages (id) on delete set null,
  vehicle_id  text,
  vehicle_text text not null default '',
  title       text not null default '',
  detail      text not null default '',
  part_no     text not null default '',
  condition   text not null default 'used'
                check (condition in ('new', 'used', 'refurbished')),
  price       numeric(12,2) not null default 0,
  photos      text[] not null default '{}',
  city        text not null default '',
  pin         text not null default '',
  status      text not null default 'pending'
                check (status in ('pending', 'approved', 'rejected',
                                  'sold', 'withdrawn')),
  reject_note text not null default '',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists part_listings_user_idx
  on public.part_listings (user_id, created_at desc);
create index if not exists part_listings_browse_idx
  on public.part_listings (status, created_at desc) where status = 'approved';
create index if not exists part_listings_garage_idx
  on public.part_listings (garage_id, created_at desc);

-- A seller may withdraw or mark sold. Approving and rejecting are the
-- platform's, and an edit to a live listing sends it back for review —
-- otherwise an approved listing could be rewritten into anything.
create or replace function public.guard_part_listing()
returns trigger language plpgsql
set search_path = public as $fn$
begin
  if tg_op = 'INSERT' then
    new.user_id := coalesce(auth.uid(), new.user_id);
    new.status  := 'pending';
    new.reject_note := '';
    return new;
  end if;

  new.user_id := old.user_id;
  new.updated_at := now();

  if public.is_platform_admin() then
    return new;
  end if;

  new.reject_note := old.reject_note;

  -- The two moves a seller may make on their own listing.
  if new.status not in ('sold', 'withdrawn') then
    if old.status = 'approved' and (
         new.title <> old.title or new.detail <> old.detail
         or new.price <> old.price or new.part_no <> old.part_no
         or new.condition <> old.condition or new.photos <> old.photos) then
      new.status := 'pending';
    else
      new.status := old.status;
    end if;
  end if;
  return new;
end $fn$;

drop trigger if exists part_listings_guard on public.part_listings;
create trigger part_listings_guard
  before insert or update on public.part_listings
  for each row execute function public.guard_part_listing();

alter table public.part_listings enable row level security;

drop policy if exists part_listings_own on public.part_listings;
create policy part_listings_own on public.part_listings
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists part_listings_platform on public.part_listings;
create policy part_listings_platform on public.part_listings
  for all to authenticated
  using (public.is_platform_admin())
  with check (public.is_platform_admin());

-- Everybody signed in browses what has been approved. Reading a listing
-- deliberately does not reveal who posted it — the contact route is the
-- platform, not a phone number sitting in a public row.
drop policy if exists part_listings_browse on public.part_listings;
create policy part_listings_browse on public.part_listings
  for select to authenticated using (status = 'approved');

-- What the browse screen may see. `user_id` is not in it.
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
             'city', l.city, 'pin', l.pin, 'created_at', l.created_at)
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
-- 3. Commission
-- ---------------------------------------------------------------------
-- A ledger the platform keeps about a partner. Nobody is charged by it —
-- settlement is a later decision, and this file deliberately stops at
-- recording what would be owed.
--
-- The rate resolves in three steps: whatever is written on the row, else
-- the garage's own `commission_pct`, else the platform default.

create table if not exists public.platform_settings (
  id             int primary key default 1 check (id = 1),
  commission_pct numeric(5,2) not null default 1.00,
  intro_video_url text not null default '',
  intro_video_on  boolean not null default false,
  updated_at     timestamptz not null default now()
);
insert into public.platform_settings (id) values (1) on conflict do nothing;

alter table public.platform_settings enable row level security;

-- Everybody signed in reads the settings — the customer app needs the
-- video out of it. Only the platform writes.
drop policy if exists platform_settings_read on public.platform_settings;
create policy platform_settings_read on public.platform_settings
  for select to authenticated using (true);

drop policy if exists platform_settings_write on public.platform_settings;
create policy platform_settings_write on public.platform_settings
  for all to authenticated
  using (public.is_platform_admin())
  with check (public.is_platform_admin());

create table if not exists public.commissions (
  id          text primary key,
  garage_id   uuid not null references public.garages (id) on delete cascade,
  -- What it was earned on. Exactly one of these is set in practice, but
  -- neither is required — the platform can book a manual line.
  job_card_id text references public.job_cards (id) on delete set null,
  listing_id  text references public.part_listings (id) on delete set null,
  amount      numeric(12,2) not null default 0,   -- the transaction
  pct         numeric(5,2)  not null default 1.00,
  fee         numeric(12,2) not null default 0,   -- amount * pct / 100
  status      text not null default 'accrued'
                check (status in ('accrued', 'invoiced', 'settled',
                                  'waived')),
  note        text not null default '',
  at          timestamptz not null default now()
);
create index if not exists commissions_garage_idx
  on public.commissions (garage_id, at desc);
create index if not exists commissions_status_idx
  on public.commissions (status, at desc);
create unique index if not exists commissions_card_once
  on public.commissions (job_card_id) where job_card_id is not null;

alter table public.commissions enable row level security;

-- The platform writes the ledger. A partner reads their own lines and
-- nothing of anybody else's — which is the Partner A / Partner B line
-- for this table, enforced here rather than in the console.
drop policy if exists commissions_platform on public.commissions;
create policy commissions_platform on public.commissions
  for all to authenticated
  using (public.is_platform_admin())
  with check (public.is_platform_admin());

drop policy if exists commissions_own on public.commissions;
create policy commissions_own on public.commissions
  for select to authenticated using (public.is_garage_member(garage_id));

create or replace function public.commission_rate(gid uuid)
returns numeric language sql stable
set search_path = public as $fn$
  select coalesce(
    (select commission_pct from public.garages where id = gid),
    (select commission_pct from public.platform_settings where id = 1),
    1.00);
$fn$;

-- Booking a line. `security definer` so the platform can write against a
-- garage it is not a member of, which is every garage.
create or replace function public.book_commission(payload jsonb)
returns jsonb language plpgsql security definer
set search_path = public as $fn$
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

  rate := coalesce(nullif(payload ->> 'pct', '')::numeric,
                   public.commission_rate(gid));

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
  -- One line per job card. Booking the same card twice updates the first
  -- rather than doubling what the partner appears to owe.
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
-- 3b. Where the photos go
-- ---------------------------------------------------------------------
-- One public bucket for the pictures on a part request and a part listing.
--
-- Public for reads, because a listing is meant to be browsed and a signed
-- URL per thumbnail would be a round trip per tile. Writes are another
-- matter: a person may only write inside a folder named after their own
-- user id, which is what stops one account overwriting another's photos.
--
-- Paths are therefore `<uid>/<listing-or-request-id>/<file>`, and the
-- policies below read that first segment.

insert into storage.buckets (id, name, public, file_size_limit,
                             allowed_mime_types)
values ('marketplace', 'marketplace', true, 5242880,
        array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set
  public             = true,
  file_size_limit    = 5242880,
  allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp'];

drop policy if exists marketplace_read on storage.objects;
create policy marketplace_read on storage.objects
  for select to anon, authenticated
  using (bucket_id = 'marketplace');

drop policy if exists marketplace_write on storage.objects;
create policy marketplace_write on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'marketplace'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Replacing and removing your own photo, and nobody else's. The platform
-- admin can remove any of them, because taking down a listing has to take
-- down what was pictured on it.
drop policy if exists marketplace_update on storage.objects;
create policy marketplace_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'marketplace'
    and ((storage.foldername(name))[1] = auth.uid()::text
         or public.is_platform_admin())
  );

drop policy if exists marketplace_delete on storage.objects;
create policy marketplace_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'marketplace'
    and ((storage.foldername(name))[1] = auth.uid()::text
         or public.is_platform_admin())
  );

-- ---------------------------------------------------------------------
-- 4. The first-run video
-- ---------------------------------------------------------------------
-- The URL lives in `platform_settings` above, so the admin can change or
-- clear it without a release. `intro_video_on` false is the off switch —
-- clearing the URL would work too, but then the old one is lost.
--
-- Whether a given customer has already watched it is their own row, not a
-- setting, because the answer differs per person and must survive a
-- reinstall.

alter table public.profiles
  add column if not exists intro_seen_at timestamptz;

create or replace function public.mark_intro_seen()
returns void language sql volatile security definer
set search_path = public as $fn$
  update public.profiles set intro_seen_at = now()
   where id = auth.uid() and intro_seen_at is null;
$fn$;

revoke all on function public.mark_intro_seen() from public;
grant execute on function public.mark_intro_seen() to authenticated;

-- What the app asks on launch: is there a video, and should this person
-- see it? One call rather than a settings read plus a profile read.
create or replace function public.intro_video()
returns jsonb language sql stable security definer
set search_path = public as $fn$
  select jsonb_build_object(
    'url',  s.intro_video_url,
    'show', s.intro_video_on
            and s.intro_video_url <> ''
            and (select p.intro_seen_at is null
                   from public.profiles p where p.id = auth.uid()))
  from public.platform_settings s where s.id = 1;
$fn$;

revoke all on function public.intro_video() from public;
grant execute on function public.intro_video() to authenticated;

-- ---------------------------------------------------------------------
-- 5. Live sync
-- ---------------------------------------------------------------------
-- The same treatment 03_sync.sql gives the tables both apps watch, so a
-- request moving to `processing` reaches the customer's screen without a
-- pull-to-refresh.

do $$
declare t text;
begin
  foreach t in array array['part_requests', 'part_listings', 'commissions']
  loop
    begin
      execute format(
        'alter publication supabase_realtime add table public.%I', t);
    exception when duplicate_object then null;
             when undefined_object  then null;
    end;
  end loop;
end $$;
