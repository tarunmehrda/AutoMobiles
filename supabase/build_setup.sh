#!/bin/sh
# Regenerates setup_all.sql from the numbered schema files.
# Run from anywhere; it works on its own directory.
set -e
cd "$(dirname "$0")"
{
  cat <<'HDR'
-- =====================================================================
-- GaragePro — COMPLETE SETUP, in one file.
-- =====================================================================
-- This is 01_customer.sql + 02_garage.sql + 03_sync.sql + 04_roles.sql +
-- 05_attendance.sql + 06_notifications.sql + 07_share.sql +
-- 08_platform.sql + 09_marketplace.sql + 10_open_booking.sql
-- concatenated in
-- the order they must run. Paste the whole thing into the Supabase SQL
-- editor once. Nothing else needs running.
--
-- GENERATED FILE — do not edit. Edit the numbered files and re-run
-- ./build_setup.sh. Each still works individually; this exists so
-- the run order cannot go wrong.
--
-- Later sections deliberately redefine what earlier ones create:
-- handle_new_user() is written three times, each superseding the last.
-- That is why the order matters and why this must not be reordered.
--
-- It does NOT reset anything. To start clean, run 00_reset.sql first.
-- =====================================================================
HDR
  for f in 01_customer.sql 02_garage.sql 03_sync.sql 04_roles.sql 05_attendance.sql 06_notifications.sql 07_share.sql 08_platform.sql 09_marketplace.sql 10_open_booking.sql; do
    echo ""
    echo "-- #####################################################################"
    echo "-- ###  BEGIN $f"
    echo "-- #####################################################################"
    echo ""
    cat "$f"
    echo ""
  done
} > setup_all.sql.new
mv setup_all.sql.new setup_all.sql
echo "setup_all.sql rebuilt ($(wc -l < setup_all.sql) lines)"
