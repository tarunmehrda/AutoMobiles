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
