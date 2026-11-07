# QA report — Customer App

Checks completed in this build environment:
- JavaScript syntax validation (`node --check`) for app.js, products.js, supabase-client.js, supabase-config.js and service-worker.js.
- Compared Customer and Admin project URL / publishable key and corrected the Customer key mismatch.
- Verified ordered script loading: Supabase SDK → config → client → app.
- Verified checkout calls `place_store_order` and order read calls `get_my_store_orders`.
- Verified product catalog maps database fields to the existing storefront UI model.
- Verified order status steps use the same status labels as Admin App.
- ZIP integrity validation performed after packaging.

Not verified from this environment:
- Live Supabase authentication, SQL execution against the user's project, Storage upload permissions, and real customer/admin transactions. These require the user's deployed Supabase project and a real browser session.
- A local headless-browser smoke test was attempted but Chromium did not complete within the execution limit; it is not counted as a passed test.

Required before live use: run `supabase/FINAL_CUSTOMER_SYNC_MIGRATION.sql` once, then perform the real test flow in README.md.
