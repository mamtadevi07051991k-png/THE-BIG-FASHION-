# THE BIG FASHION Customer App — Update 2.2

## Account order privacy
- Added current authenticated-user validation before loading order history.
- Removed cross-account local order cache usage and stale account order counts.
- Clear cached order/profile details on login, signup and logout.
- A requested tracking number must belong to the currently signed-in account; no first-order fallback.
- Added `supabase/ACCOUNT_ORDER_PRIVACY_FIX.sql` to explicitly recreate the account-scoped orders RPC.

## Deployment
1. Run `supabase/ACCOUNT_ORDER_PRIVACY_FIX.sql` once in the same Supabase project.
2. Build/reinstall the Customer APK from this ZIP (do not keep using the previous APK).
3. Test with two distinct Supabase Auth users and confirm each sees only their own orders.

Live Supabase account testing is not claimed by this package; it must be verified against the project's actual Auth users and order data.
