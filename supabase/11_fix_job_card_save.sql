-- =====================================================================
-- 11_fix_job_card_save.sql — job cards could not be saved at all
--
-- Symptom seen on device, 21 Sep 2026: every job card created in the
-- console vanished the next time the app was restarted. Reproduced three
-- times, including a card that had been closed and settled by UPI.
--
-- The app was telling us, in its own log, the whole time:
--
--   push step "job card A0921-003" failed (local state is still
--   authoritative): PostgrestException(message: function
--   gen_random_bytes(integer) does not exist, code: 42883)
--
-- `save_job_card()` mints a share token, `mint_share_token()` calls
-- `gen_random_bytes()`, and that function lives in **pgcrypto**. The
-- extension is created in `02_garage.sql` and `setup_all.sql` — but
-- `catch_up_05_to_10.sql`, which `docs/08-first-run-testing.md` tells
-- people to run, defines `mint_share_token()` and never creates it. On a
-- project brought up that way every single save_job_card() raises 42883.
--
-- The console swallows that (`_step` in garage_gateway.dart keeps a
-- failed step local and carries on), so nothing on screen says the save
-- failed. The card lives on the phone until the next hydrate, which
-- overwrites the local list with the server's empty one — and the card,
-- the bill and the payment are gone.
--
-- Safe to run more than once, and safe on a project that is already fine.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. The extension
-- ---------------------------------------------------------------------
-- Supabase puts extensions in their own schema. Create it there if that
-- is where it belongs, and fall back to public on a plain Postgres.
create extension if not exists "pgcrypto" with schema extensions;

-- ---------------------------------------------------------------------
-- 2. Make the token function find it
-- ---------------------------------------------------------------------
-- Creating the extension is not on its own enough. `mint_share_token()`
-- is called from inside `save_job_card()`, which runs with a pinned
-- search_path; a function sitting in `extensions` is invisible to it and
-- the call still raises 42883. Naming the schema explicitly is what
-- actually fixes it, and it keeps working whichever schema pgcrypto
-- ended up in.
create or replace function public.mint_share_token()
returns text
language sql
volatile
set search_path = public, extensions, pg_temp
as $fn$
  select translate(encode(gen_random_bytes(24), 'base64'), '+/=', '-_');
$fn$;

-- ---------------------------------------------------------------------
-- 3. Every other function that reaches for pgcrypto
-- ---------------------------------------------------------------------
-- This section originally named `claim_listing_code` alone, on the
-- assumption that `mint_share_token` was the only call that mattered in
-- practice. It was not. Re-testing on 21 Sep 2026 found
-- `book_commission` failing with the identical 42883: it also mints an id
-- with `encode(gen_random_bytes(12), 'hex')` and also pins
-- `search_path = public`. Recording a commission was impossible on this
-- project, and the console could only say "Could not record that
-- commission."
--
-- Rather than name them one at a time and be wrong a third time, find
-- every function in `public` whose body calls gen_random_bytes and re-pin
-- its search_path so the extension schema is on it. A function that
-- already has `extensions` on its path is rewritten to the same value,
-- which changes nothing.
do $blk$
declare
  fn record;
begin
  for fn in
    select p.oid::regprocedure as sig
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.prosrc like '%gen_random_bytes%'
  loop
    execute format(
      'alter function %s set search_path = public, extensions, pg_temp',
      fn.sig);
    raise notice 'pinned search_path on %', fn.sig;
  end loop;
end
$blk$;

-- ---------------------------------------------------------------------
-- 4. Check it
-- ---------------------------------------------------------------------
-- Should return a 32-character token rather than raising 42883.
select public.mint_share_token() as token_ok;

-- The commission ledger fails the same way, so check it too:
--   select public.book_commission(
--            jsonb_build_object('garage_id', '<a garage id>', 'amount', 1));
-- It should return a row rather than raising 42883. (It still refuses
-- unless the caller is a platform admin. That is a different check, and
-- the correct one.)

-- Then, in the console: open a job card, force-stop the app, reopen it.
-- The card must still be there. That is the test this file exists for.
--
-- On the app side, as of 21 Sep 2026 the console no longer loses the card
-- when this save fails: `hydrate()` merges rather than overwrites, so a
-- card the server has never accepted stays on the phone and is offered
-- again on the next push. Running this file is still what gets the card
-- upstream. Without it, every job card lives on one handset and nowhere
-- else.
