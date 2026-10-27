-- =====================================================================
-- GaragePro — "Delete account" in the admin app
-- =====================================================================
-- Run after 31_staff_logins.sql. Idempotent: safe to re-run.
--
-- `delete_workshop_account()` removes the signed-in person completely.
-- (The customer app has its own `delete_my_account()` (20), which refuses
-- an account that runs a workshop. That stays: only the admin app, after
-- the owner types DELETE, can take a workshop down.)
--
--
--   * an owner: their workshop and everything in it (job cards, lines,
--     payments, customers, vehicles, stock, bookings, expenses, cash book,
--     attendance, staff and staff logins, invitations, commission lines,
--     notifications), then the login;
--   * a staff member: only their login and their access. The workshop and
--     its job cards are the owner's and stay;
--   * anyone: their reviews, their customer-app data, their devices.
--
-- It can only ever delete the caller. There is no way to pass somebody
-- else's id.
-- =====================================================================

create or replace function public.delete_workshop_account()
returns jsonb language plpgsql security definer
set search_path = public, auth as $fn$
declare
  uid   uuid := auth.uid();
  shops int;
begin
  if uid is null then
    raise exception 'Sign in first.' using errcode = 'insufficient_privilege';
  end if;

  select count(*) into shops from public.garages where owner_id = uid;

  -- Bookings first, while their workshop still exists: the booking
  -- triggers (20, 22) write a notification against the workshop and tell
  -- the customer the booking is off — which, with the workshop gone, it is.
  -- Deleted with the workshop instead, those triggers fire after it has
  -- gone and the whole delete fails on a missing workshop.
  delete from public.garage_bookings
   where garage_id in (select id from public.garages where owner_id = uid);

  delete from public.garages where owner_id = uid;
  delete from public.reviews where profile_id = uid;
  delete from public.garage_invites
   where email = (select lower(email) from auth.users where id = uid);

  -- Everything else hangs off the login and goes with it.
  delete from auth.users where id = uid;

  return jsonb_build_object('deleted', uid, 'workshops', shops);
end $fn$;

revoke execute on function public.delete_workshop_account() from public, anon;
grant execute on function public.delete_workshop_account() to authenticated;

-- Check: expects true.
select has_function_privilege('authenticated', 'public.delete_workshop_account()',
                              'execute') as delete_account_ready;
