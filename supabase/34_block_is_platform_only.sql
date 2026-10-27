-- =====================================================================
-- GaragePro — only the platform can block or unblock a workshop
-- =====================================================================
-- Run after 29_block_and_district.sql. Idempotent: safe to re-run.
--
-- The console now shuts a blocked workshop out entirely and shows the
-- support number instead. That makes `blocked` worth undoing, and
-- `garages_member_all` (02_garage.sql) lets any member write every
-- column of their own garage: one hand-rolled
--   update garages set blocked = false where id = '<mine>'
-- would unblock it. 19_commission_and_roles.sql already keeps `listed`,
-- `verified` and `commission_pct` for the platform; 29 added `blocked`
-- without adding it here. This is that trigger again, with `blocked`
-- and `blocked_at` kept as they were for everybody else.
-- =====================================================================

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
    new.blocked        := false;
    new.blocked_at     := null;
  else
    new.listed         := old.listed;
    new.verified       := old.verified;
    new.commission_pct := old.commission_pct;
    new.blocked        := old.blocked;
    new.blocked_at     := old.blocked_at;
  end if;
  return new;
end $fn$;

drop trigger if exists garages_guard_platform on public.garages;
create trigger garages_guard_platform
  before insert or update on public.garages
  for each row execute function public.guard_garage_platform_columns();

-- ---------------------------------------------------------------------
-- Check: every blocked workshop, newest first.
-- ---------------------------------------------------------------------
select name, city, phone, blocked_at
  from public.garages
 where blocked
 order by blocked_at desc nulls last;
