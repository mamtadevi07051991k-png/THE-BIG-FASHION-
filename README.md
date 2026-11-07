# THE BIG FASHION — Customer App (Supabase-connected release)

## What is connected
- Supabase Auth email/password signup, login, password reset and logout.
- Product catalog reads active products from the shared Supabase `products` table. The existing local catalog remains a fallback if the catalog query is unavailable.
- Checkout calls the `place_store_order` database RPC. The database calculates the final price and creates the order; the browser does not write order rows directly.
- My Orders and Track My Order call `get_my_store_orders`, which returns only orders linked to the signed-in customer. Admin status changes are therefore reflected from the database when the customer opens or refreshes the order screen.
- Cart and wishlist remain browser-local; order and product records are server-backed.

## One-time Supabase action required
1. Confirm the main customer schema has already been run.
2. Confirm `Admin_App/sql/ADMIN_SETUP.sql` has already been run and the admin Auth user has been inserted into `public.admin_users`.
3. Run `supabase/FINAL_CUSTOMER_SYNC_MIGRATION.sql` in Supabase Dashboard → SQL Editor → New query.
4. Deploy this folder to the same HTTPS hosting origin as before. Do not open the app as a `file://` URL.

## Configuration
`js/supabase-config.js` contains the shared project URL and the public publishable key. The matching Admin App config must use the same values. Never put a `service_role` or secret key in either frontend ZIP.

## Payment / delivery limitations
This release supports Cash on Delivery only, matching the database schema. Online payment gateway processing and live courier GPS tracking are not connected. The order status timeline is driven by Admin App status changes.

## Quick checks
- Open login page; sign up with a real email and complete any verification required by Supabase Auth settings.
- Sign in and confirm the active product catalog loads.
- Place a COD test order; confirm it appears in Admin App → Orders.
- Change its status in Admin App; refresh Customer App → My Orders / Track My Order and verify the status and completed steps.
- Add or edit a product in Admin App; refresh the customer catalog.


## Web entry experience
The browser home page first shows a bottom-sheet choice: Download APK or Continue in Web. Continue in Web keeps browsing available and opens the sign-in overlay 10 seconds later. Add the final APK HTTPS URL to `window.BF_APK_DOWNLOAD_URL` in `js/supabase-config.js` before public launch. The APK URL is currently blank because the final APK link has not yet been supplied.
