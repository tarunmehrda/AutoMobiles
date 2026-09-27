-- =====================================================================
-- GaragePro — set up balajiautomobiles088@gmail.com by hand
-- =====================================================================
-- For when the confirmation / reset emails do not arrive (the built-in
-- Supabase mailer sends about 2 emails an hour for the whole project).
-- Run in the Supabase SQL editor. Idempotent: safe to re-run.
--
-- It does three things for that one account:
--   1. confirms the email and sets the password below, so it can sign
--      in straight away with no email;
--   2. creates the workshop (or updates it, if the account already has
--      one) and makes the account its owner;
--   3. lists and verifies the workshop, so customers can find it.
--
-- If the account does not exist yet, this creates it, already confirmed.
-- =====================================================================

do $blk$
declare
  -- EDIT THESE if anything is wrong.
  acct_email constant text := 'balajiautomobiles088@gmail.com';
  acct_pass  constant text := 'balaji automobiles@088';
  shop_name  constant text := 'Balaji Automobiles';
  shop_pin   constant text := '333503';
  shop_phone constant text := '9462153613';
  shop_city  constant text := 'Chandigarh';
  shop_state constant text := 'Chandigarh';
  -- Chandigarh city centre. Set the exact spot later from the app:
  -- Settings -> Business Details -> Use current location.
  shop_lat   constant double precision := 30.7333;
  shop_lng   constant double precision := 76.7794;

  uid uuid;
  gid uuid;
begin
  -- pgcrypto sits in `extensions` on Supabase (or `public` on an old
  -- project); looking in both finds crypt() either way.
  perform set_config('search_path', 'public, extensions', true);

  select id into uid from auth.users where lower(email) = lower(acct_email);
  -- No account yet: create it here, confirmed, exactly as a sign-up
  -- would. The token columns must be '' rather than null or the auth
  -- server refuses the sign-in.
  if uid is null then
    uid := gen_random_uuid();
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password,
      email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
      created_at, updated_at, confirmation_token, recovery_token,
      email_change_token_new, email_change)
    values (
      '00000000-0000-0000-0000-000000000000', uid, 'authenticated',
      'authenticated', lower(acct_email), crypt(acct_pass, gen_salt('bf')),
      now(), '{"provider":"email","providers":["email"]}'::jsonb,
      jsonb_build_object('full_name', shop_name, 'phone', shop_phone,
                         'role', 'owner'),
      now(), now(), '', '', '', '');

    insert into auth.identities (
      id, provider_id, user_id, identity_data, provider,
      last_sign_in_at, created_at, updated_at)
    values (
      gen_random_uuid(), uid::text, uid,
      jsonb_build_object('sub', uid::text, 'email', lower(acct_email),
                         'email_verified', true),
      'email', now(), now(), now());
    raise notice 'Created the account for %.', acct_email;
  end if;

  -- 1. Sign-in without email ------------------------------------------
  update auth.users
     set encrypted_password = crypt(acct_pass, gen_salt('bf')),
         email_confirmed_at = coalesce(email_confirmed_at, now()),
         banned_until       = null,
         updated_at         = now()
   where id = uid;

  insert into public.profiles (id, name, phone, email)
  values (uid, shop_name, shop_phone, acct_email)
  on conflict (id) do update
    set phone = excluded.phone,
        email = excluded.email,
        name  = case when public.profiles.name = '' then excluded.name
                     else public.profiles.name end;

  -- 2. The workshop ---------------------------------------------------
  select id into gid from public.garages
   where owner_id = uid order by created_at limit 1;

  if gid is null then
    insert into public.garages (
      owner_id, name, phone, email, city, state, pin, terms, plan_expiry)
    values (
      uid, shop_name, shop_phone, acct_email, shop_city, shop_state, shop_pin,
      concat_ws(E'\n',
        'Goods once sold will not be taken back.',
        'Warranty as per manufacturer policy only.',
        'Vehicle is parked at owner risk.',
        'Payment due on delivery.'),
      now() + interval '365 days')
    returning id into gid;
  else
    update public.garages
       set name = shop_name, phone = shop_phone, city = shop_city,
           state = shop_state, pin = shop_pin,
           email = coalesce(nullif(email, ''), acct_email)
     where id = gid;
  end if;

  insert into public.garage_members (garage_id, profile_id, role)
  values (gid, uid, 'owner')
  on conflict do nothing;

  update public.profiles set role = 'owner'
   where id = uid and role is distinct from 'platform';

  -- 3. On the map, listed and verified --------------------------------
  update public.garages
     set lat = shop_lat, lng = shop_lng,
         located_at = coalesce(located_at, now()),
         listed = true, verified = true
   where id = gid and lat is null;
  update public.garages set listed = true, verified = true where id = gid;

  raise notice 'Done: % can sign in, workshop % (%).', acct_email, shop_name, gid;
end
$blk$;

-- Check: one row, confirmed = true, and the workshop with its PIN.
select u.email,
       u.email_confirmed_at is not null as confirmed,
       g.name, g.pin, g.phone, g.city, g.listed, g.verified, m.role
  from auth.users u
  left join public.garages g on g.owner_id = u.id
  left join public.garage_members m on m.garage_id = g.id and m.profile_id = u.id
 where lower(u.email) = 'balajiautomobiles088@gmail.com';
