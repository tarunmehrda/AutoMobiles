-- =====================================================================
-- GaragePro — the database's own helpers are not an API
-- =====================================================================
-- Run AFTER 22_customer_push.sql. Idempotent: safe to re-run.
--
-- Supabase grants EXECUTE on every function in `public` to `anon` and
-- `authenticated` by default. `revoke all ... from public` does not undo
-- that — those are grants to the two roles by name — so a function the
-- earlier files meant to keep internal was still callable by anybody
-- holding the app's public key, which ships inside both apps.
--
-- Checked on the live project on 26 Sep 2026 with nothing but that key:
--
--   * push_garage_notification  (06_notifications.sql) — ran. Anyone could
--     put any text on any workshop's phones and in its bell.
--   * push_customer_alert       (22_customer_push.sql) — ran. Anyone could
--     push any text to any customer's phone.
--
-- Both are only ever called by the database's own triggers, which run as
-- the table owner and keep their access; nothing in either app calls them.
-- =====================================================================

revoke execute on function public.push_garage_notification(
  uuid, text, text, text, text, text, text) from public, anon, authenticated;

revoke execute on function public.push_customer_alert(
  uuid, text, text, text, text) from public, anon, authenticated;

-- Harmless to an anonymous caller (they have no account to register), but
-- there is no reason for them to reach it either.
revoke execute on function public.register_customer_device(text, text) from anon;
revoke execute on function public.forget_customer_device(text) from anon;
revoke execute on function public.register_garage_device(text, uuid, text) from anon;
revoke execute on function public.forget_garage_device(text) from anon;

-- ---------------------------------------------------------------------
-- Check it took
-- ---------------------------------------------------------------------
-- Expects false, false (neither role may call either function):
select has_function_privilege('anon',
         'public.push_customer_alert(uuid, text, text, text, text)', 'execute')
       or has_function_privilege('authenticated',
         'public.push_customer_alert(uuid, text, text, text, text)', 'execute')
         as customer_alert_open,
       has_function_privilege('anon',
         'public.push_garage_notification(uuid, text, text, text, text, text, text)', 'execute')
       or has_function_privilege('authenticated',
         'public.push_garage_notification(uuid, text, text, text, text, text, text)', 'execute')
         as garage_alert_open;
-- =====================================================================
