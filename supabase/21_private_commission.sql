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
