-- =====================================================================
-- GaragePro — exactly two Super Admins
-- =====================================================================
-- Run after 27_partner_heads.sql. Idempotent: safe to re-run.
--
-- The platform (Settings -> Platform, and every partner's commission)
-- belongs to these two Gmail accounts and nobody else:
--
--   vjalaria@gmail.com              (development / system lead)
--   balajiautomobiles088@gmail.com  (client / owner)
--
-- firefringe@gmail.com was a head in 27 and is removed here. It keeps its
-- own workshop; it just stops seeing the platform.
--
-- Either head can still switch the other off and on from Platform -> Heads.
-- Adding a third means editing this file. No screen can add one.
-- =====================================================================

-- EDIT THIS to change who the Super Admins are.
delete from public.platform_heads
 where email not in ('vjalaria@gmail.com', 'balajiautomobiles088@gmail.com');

insert into public.platform_heads (email, enabled) values
  ('vjalaria@gmail.com', true),
  ('balajiautomobiles088@gmail.com', true)
on conflict (email) do update set enabled = true, updated_at = now();

-- `profiles.role = 'platform'` has granted nothing since 27, but the old
-- platform account still carries it. Read it forward like everybody else:
-- an owner if it owns a workshop, a customer if not.
update public.profiles p
   set role = case when exists (select 1 from public.garages g
                                 where g.owner_id = p.id)
                   then 'owner' else 'customer' end
 where p.role = 'platform';

-- Check: two rows, both enabled. `signed_in` false means that person has
-- not signed in to the admin app with that Gmail yet (or has not
-- confirmed it); they become Super Admin the moment they do.
select h.email, h.enabled,
       u.id is not null                     as signed_in,
       u.email_confirmed_at is not null     as confirmed
  from public.platform_heads h
  left join auth.users u on lower(u.email) = h.email
 order by h.email;
