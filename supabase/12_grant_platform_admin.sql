-- Make one account the platform admin.
--
-- Without this the Buy & Sell screen is empty: part_listings RLS
-- (09_marketplace.sql:223-240) shows a row only to its owner, to anybody
-- once it is 'approved', or to a platform admin. A freshly posted listing
-- is 'pending' and belongs to the customer, so the garage account sees
-- nothing and the screen draws "Nothing to review".
--
-- Run in the Supabase SQL editor, then sign out and back in on the phone.
-- Requires 08_platform.sql to have been applied first (it is what allows
-- 'platform' in the profiles role check, and defines is_platform_admin).

update public.profiles
   set role = 'platform'
 where id = (select id from auth.users
              where email = 'firefringe@gmail.com');

-- Confirm: expects one row, role = 'platform'.
select p.id, u.email, p.role
  from public.profiles p
  join auth.users u on u.id = p.id
 where u.email = 'firefringe@gmail.com';
