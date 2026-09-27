-- =====================================================================
-- GaragePro — the public job card link
-- =====================================================================
-- Run AFTER 03_sync.sql. Additive and idempotent: it can be run again on
-- a live project without losing anything.
--
-- Everything in this product so far assumes the customer signs in. That
-- is the right shape for the customer who wants their whole history, and
-- the wrong shape for the one standing at the counter who will never
-- install anything. Until now the workshop's WhatsApp message to that
-- person was plain text — "your car is due for service" — with nowhere
-- to tap.
--
-- This file gives that message somewhere to point:
--
--   * every job card gets an unguessable `share_token`, minted by the
--     database on insert, never chosen by a client,
--   * `shared_card(token)` reads one card back for an anonymous caller,
--     and only ever the one card that token names, and
--   * the payload is a deliberate subset. The customer sees what is on
--     their bill. Nothing tells them what the workshop paid for the part.
--
-- Note what is NOT here: no policy on any table is loosened, and `anon`
-- is granted nothing except the right to call one function. A token is a
-- key to a single row, not a login, and it carries no session.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. The token
-- ---------------------------------------------------------------------
-- 24 bytes of gen_random_bytes, base64url. That is 192 bits: it cannot
-- be guessed, and it survives being pasted through WhatsApp, which eats
-- '+' and '/' in URLs.

create or replace function public.mint_share_token()
returns text language sql volatile as $fn$
  select translate(encode(gen_random_bytes(24), 'base64'), '+/=', '-_');
$fn$;

alter table public.job_cards
  add column if not exists share_token text;

-- Backfill the cards that existed before this file ran, then make the
-- column total. Done in this order so a live project does not trip the
-- not-null on rows it already has.
update public.job_cards
   set share_token = public.mint_share_token()
 where share_token is null;

alter table public.job_cards
  alter column share_token set default public.mint_share_token();

do $$ begin
  alter table public.job_cards alter column share_token set not null;
exception when others then null; end $$;

create unique index if not exists job_cards_share_token_idx
  on public.job_cards (share_token);

-- A client that sends its own token — or tries to overwrite one to match
-- a card it does not own — is ignored. The column is the database's.
--
-- The one legitimate way to change it is `rotate_share_token` below, which
-- announces itself with a session setting. A client cannot forge that: it
-- is set inside a SECURITY DEFINER function that has already checked
-- membership, and `set_config(..., true)` scopes it to that transaction.
create or replace function public.guard_share_token()
returns trigger language plpgsql as $fn$
begin
  if tg_op = 'INSERT' then
    new.share_token := public.mint_share_token();
  elsif coalesce(current_setting('garagepro.rotating', true), '') <> 'on' then
    new.share_token := old.share_token;
  end if;
  return new;
end $fn$;

drop trigger if exists job_cards_share_token on public.job_cards;
create trigger job_cards_share_token
  before insert or update on public.job_cards
  for each row execute function public.guard_share_token();

-- ---------------------------------------------------------------------
-- 2. Reading one card without signing in
-- ---------------------------------------------------------------------
-- SECURITY DEFINER, so it sees past row level security — which is the
-- whole point, since the caller is nobody. The safety is that the only
-- way in is a token, the only way out is one card, and the select list
-- below is the entire contract.
--
-- Deliberately absent: mechanic_ids, work_note, voices, dents, photos,
-- the internal remark on a line, and anything from `masters`. Those are
-- the workshop's working notes, not the customer's bill.

create or replace function public.shared_card(tok text)
returns jsonb language sql stable security definer
set search_path = public as $fn$
  select jsonb_build_object(
    'number',        j.number,
    'status',        j.status,
    'created_at',    j.created_at,
    'completed_at',  j.completed_at,
    'promised_at',   j.promised_at,
    'odometer_km',   j.odometer_km,
    'next_service_at', j.next_service_at,
    'next_service_km', j.next_service_km,
    'discount',      j.discount,
    'tax_rate',      j.tax_rate,
    'garage', jsonb_build_object(
      'name',    g.name,
      'phone',   g.phone,
      'address', nullif(trim(both ', ' from concat_ws(', ',
                   nullif(g.address_line, ''), nullif(g.city, ''),
                   nullif(g.state, ''), nullif(g.pin, ''))), ''),
      'gstin',   nullif(g.gstin, ''),
      'upi_id',  nullif(g.upi_id, ''),
      'terms',   nullif(g.terms, '')
    ),
    'customer', jsonb_build_object('name', c.name),
    'vehicle', jsonb_build_object(
      'reg_no', v.reg_no, 'brand', v.brand,
      'model',  v.model,  'variant', v.variant
    ),
    'items', coalesce((
      select jsonb_agg(jsonb_build_object(
               'kind', li.kind, 'name', li.name, 'part_no', li.part_no,
               'qty',  li.qty,  'rate', li.rate, 'state',   li.state)
               order by li.position)
        from public.line_items li
       where li.job_card_id = j.id
         and li.state <> 'skipped'
    ), '[]'::jsonb),
    'paid', coalesce((
      select sum(p.amount) from public.payments p where p.job_card_id = j.id
    ), 0)
  )
  from public.job_cards j
  join public.garages         g on g.id = j.garage_id
  join public.garage_customers c on c.id = j.customer_id
  join public.garage_vehicles  v on v.id = j.vehicle_id
  where j.share_token = tok
    and length(tok) >= 20;   -- a short token is a probe, not a customer
$fn$;

-- The one grant. `anon` may call this and nothing else new.
revoke all on function public.shared_card(text) from public;
grant execute on function public.shared_card(text) to anon, authenticated;

revoke all on function public.mint_share_token() from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 2b. The console asking for a card's link
-- ---------------------------------------------------------------------
-- `job_card_json` builds its object field by field and does not carry the
-- token — deliberately. It is the payload behind every job card the
-- console holds in memory, and a token that rides along in all of them is
-- a token in every log line and crash report the app ever produces.
--
-- So the console asks for it at the moment the counter presses Share. One
-- extra round trip, on a deliberate human action, in exchange for the
-- token existing in the app only while it is being used.

create or replace function public.card_share_token(card text)
returns text language plpgsql stable security definer
set search_path = public as $fn$
declare gid uuid; tok text;
begin
  select garage_id, share_token into gid, tok
    from public.job_cards where id = card;
  if gid is null then
    return null;
  end if;
  if not public.is_garage_member(gid) then
    raise exception 'not a member of this garage';
  end if;
  return tok;
end $fn$;

revoke all on function public.card_share_token(text) from public;
grant execute on function public.card_share_token(text) to authenticated;

-- ---------------------------------------------------------------------
-- 3. Rotating a link
-- ---------------------------------------------------------------------
-- A link that went to the wrong number, or into a group chat. The garage
-- burns it and the old URL stops resolving immediately.

create or replace function public.rotate_share_token(card text)
returns text language plpgsql security definer
set search_path = public as $fn$
declare gid uuid; made text;
begin
  select garage_id into gid from public.job_cards where id = card;
  if gid is null then
    raise exception 'no such job card';
  end if;
  if not public.is_garage_member(gid) then
    raise exception 'not a member of this garage';
  end if;

  made := public.mint_share_token();

  -- The guard trigger pins share_token on update, so tell it this update
  -- is the sanctioned one. Disabling the trigger instead would take an
  -- ACCESS EXCLUSIVE lock on job_cards — every console in the workshop
  -- would stall on the counter rotating one link.
  --
  -- `true` makes the setting local to this transaction, so it is gone
  -- before the next statement on this connection, pooled or not.
  perform set_config('garagepro.rotating', 'on', true);
  update public.job_cards set share_token = made where id = card;
  perform set_config('garagepro.rotating', 'off', true);

  return made;
end $fn$;

revoke all on function public.rotate_share_token(text) from public;
grant execute on function public.rotate_share_token(text) to authenticated;
