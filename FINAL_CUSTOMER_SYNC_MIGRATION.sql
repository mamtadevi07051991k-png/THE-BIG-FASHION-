-- THE BIG FASHION: customer catalog + account-scoped live order sync
-- Run once in Supabase SQL Editor AFTER the customer schema and ADMIN_SETUP.sql.
-- Safe to re-run. Uses only the public/publishable client key in browser apps.

begin;

-- Public storefront catalog. Admin management remains protected by the
-- admin-only policy created in ADMIN_SETUP.sql.
grant select on public.products to anon, authenticated;
drop policy if exists products_storefront_read_active on public.products;
create policy products_storefront_read_active
  on public.products for select to anon, authenticated
  using (is_active = true);

-- Return only the orders belonging to the currently authenticated customer.
-- The customer link is created by place_store_order() through customers.auth_user_id.
create or replace function public.get_my_store_orders()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_result jsonb;
begin
  if v_user_id is null then
    raise exception 'Please log in to view your orders';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'order_number', o.order_number,
        'status', o.status,
        'payment_method', o.payment_method,
        'payment_status', o.payment_status,
        'total_paise', o.total_paise,
        'delivery_address', o.delivery_address,
        'city', o.city,
        'postal_code', o.postal_code,
        'created_at', o.created_at,
        'items', coalesce((
          select jsonb_agg(jsonb_build_object(
            'id', oi.product_id,
            'name', oi.product_name,
            'qty', oi.quantity,
            'size', oi.size,
            'color', oi.color,
            'unit_price_paise', oi.unit_price_paise,
            'line_total_paise', oi.line_total_paise
          ) order by oi.created_at, oi.id)
          from public.order_items oi
          where oi.order_id = o.id
        ), '[]'::jsonb)
      ) order by o.created_at desc
    ), '[]'::jsonb
  ) into v_result
  from public.orders o
  join public.customers c on c.id = o.customer_id
  where c.auth_user_id = v_user_id;

  return v_result;
end;
$$;

revoke all on function public.get_my_store_orders() from public, anon;
grant execute on function public.get_my_store_orders() to authenticated;

commit;

-- Verification (run separately after the migration):
-- select public.get_my_store_orders(); -- run while authenticated in app, not SQL Editor
-- select id,name,price_paise,image_url,is_active from public.products order by id limit 10;
