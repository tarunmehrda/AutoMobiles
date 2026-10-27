-- =====================================================================
-- GaragePro — a partner head can add another head from the app
-- =====================================================================
-- Run AFTER 27_partner_heads.sql (and 30_super_admins.sql). Idempotent:
-- safe to re-run.
--
-- Until now the list in platform_heads was only ever changed in the SQL
-- editor. This adds add_platform_head(email): a head that is on types a
-- Gmail address in Buy & Sell -> Heads and that address becomes a head,
-- switched on. It counts once its owner signs in to the admin app with
-- that address and the address is confirmed, exactly as in 27.
--
-- Nothing here removes a head. A head added by mistake is switched off
-- from the same screen.
--
-- CAREFUL: 30_super_admins.sql deletes every head that is not one of its
-- two addresses. Re-running 30 removes every head added from the app.
-- =====================================================================

create or replace function public.add_platform_head(head_email text)
returns void language plpgsql security definer
set search_path = public as $fn$
declare
  e text := lower(btrim(coalesce(head_email, '')));
begin
  if not public.is_platform_admin() then
    raise exception 'Only a partner head can change this.'
      using errcode = 'insufficient_privilege';
  end if;

  -- The messages are the ones the admin app shows as they are.
  if e !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    raise exception 'That does not look like an email address.'
      using errcode = 'invalid_parameter_value';
  end if;

  insert into public.platform_heads (email, enabled)
  values (e, true)
  on conflict (email) do nothing;
  if not found then
    raise exception 'That address is already a partner head.'
      using errcode = 'unique_violation';
  end if;
end $fn$;

revoke execute on function public.add_platform_head(text)
  from public, anon;
grant execute on function public.add_platform_head(text) to authenticated;

-- Check: the function is there and only signed-in accounts can call it.
select has_function_privilege('anon', 'public.add_platform_head(text)',
         'execute') as anon_can,
       has_function_privilege('authenticated',
         'public.add_platform_head(text)', 'execute') as authenticated_can;
