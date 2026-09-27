-- Undo an approval made in error: put the listing back into review.
-- "Alloy", Maruti Suzuki Swift VXi, Rs 2,000 — approved at ~14:30 on
-- 2026-09-21 by a mis-aimed tap during testing, not by a decision.

-- Look first: confirm this is the row you expect.
select id, title, price, status, updated_at
  from public.part_listings
 where status = 'approved'
 order by updated_at desc;

-- Then put it back. Narrow the where clause to the id above if there is
-- more than one approved row you want to keep.
update public.part_listings
   set status = 'pending'
 where title = 'Alloy'
   and status = 'approved';
