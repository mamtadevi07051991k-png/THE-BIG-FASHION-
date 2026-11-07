-- THE BIG FASHION: account-isolated customer order history
-- Run once in Supabase SQL Editor. Safe to re-run.
-- This RPC always filters orders by the currently authenticated auth.uid().

begin;

alter table public.customers
  add column if not exists auth_user_id uuid references auth.users(id) on delete set null;

create unique index if not exists customers_auth_user_id_uidx
  on public.customers(auth_user_id)
  where auth_user_id is not null;

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
  inner join public.customers c on c.id = o.customer_id
  where c.auth_user_id = v_user_id;

  return v_result;
end;
$$;

revoke all on function public.get_my_store_orders() from public, anon;
grant execute on function public.get_my_store_orders() to authenticated;

commit;

-- Optional verification (run in an authenticated app session, not SQL Editor):
-- select auth.uid();
-- select public.get_my_store_orders();
