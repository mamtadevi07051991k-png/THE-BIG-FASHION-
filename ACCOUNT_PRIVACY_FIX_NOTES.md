# Customer account order privacy fix

- My Orders and Track My Order now require a valid current Supabase Auth user before calling the account-scoped RPC.
- The app no longer uses shared localStorage order history as a fallback or as the account order count.
- Login, signup, and logout clear any stale local order cache from a previous account.
- Track My Order no longer falls back to showing the first order when the requested order number is not present in the signed-in account's result.
- Run `supabase/ACCOUNT_ORDER_PRIVACY_FIX.sql` once in the same Supabase project before deploying this update.

The server-side RPC filters strictly with `customers.auth_user_id = auth.uid()`. Do not expose a service-role key in the app.
