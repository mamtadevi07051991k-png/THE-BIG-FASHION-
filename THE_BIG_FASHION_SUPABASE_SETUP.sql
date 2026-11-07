-- =============================================================================
-- THE BIG FASHION — SUPABASE DATABASE
-- Compatible with the supplied storefront integration (place_store_order RPC).
-- Run the ENTIRE script once in Supabase Dashboard > SQL Editor > New query.
-- Money is stored as integer paise: ₹1 = 100 paise.
-- Safe to re-run for the objects defined here (catalog seed is upserted).
-- =============================================================================

begin;

create extension if not exists pgcrypto;

-- 1) CUSTOMER MASTER
create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(),
  full_name text not null check (char_length(trim(full_name)) between 2 and 100),
  phone text not null unique check (phone ~ '^[0-9]{10}$'),
  email text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Link each storefront customer to the verified Supabase Auth account.
alter table public.customers
  add column if not exists auth_user_id uuid references auth.users(id) on delete set null;
create unique index if not exists customers_auth_user_id_uidx
  on public.customers(auth_user_id) where auth_user_id is not null;

-- 2) PRODUCT CATALOG
create table if not exists public.products (
  id bigint primary key,
  name text not null,
  category text not null,
  price_paise bigint not null check (price_paise >= 0),
  image_url text,
  description text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 3) CUSTOMER ADDRESSES
create table if not exists public.customer_addresses (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.customers(id) on delete cascade,
  recipient_name text not null,
  phone text not null check (phone ~ '^[0-9]{10}$'),
  address_line text not null,
  city text not null,
  postal_code text not null check (postal_code ~ '^[0-9]{6}$'),
  is_default boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists customer_addresses_customer_idx
  on public.customer_addresses(customer_id);

-- 4) COUPONS
create table if not exists public.coupons (
  code text primary key,
  discount_type text not null check (discount_type in ('percentage','fixed')),
  discount_value integer not null check (discount_value > 0),
  minimum_order_paise bigint not null default 0 check (minimum_order_paise >= 0),
  maximum_discount_paise bigint check (maximum_discount_paise is null or maximum_discount_paise >= 0),
  is_active boolean not null default true,
  starts_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz not null default now()
);

insert into public.coupons(code, discount_type, discount_value, minimum_order_paise, maximum_discount_paise, is_active)
values
  ('WELCOME10', 'percentage', 10, 0, null, true),
  ('STYLE200', 'fixed', 20000, 0, 20000, true),
  ('BIGEDIT15', 'percentage', 15, 0, null, true)
on conflict (code) do update set
  discount_type = excluded.discount_type,
  discount_value = excluded.discount_value,
  minimum_order_paise = excluded.minimum_order_paise,
  maximum_discount_paise = excluded.maximum_discount_paise,
  is_active = excluded.is_active;

-- 5) ORDERS
create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number text not null unique,
  customer_id uuid not null references public.customers(id),
  status text not null default 'Order placed'
    check (status in ('Order placed','Confirmed','Processing','Shipped','Out for delivery','Delivered','Cancelled')),
  payment_method text not null default 'Cash on Delivery'
    check (payment_method in ('Cash on Delivery')),
  payment_status text not null default 'Pending'
    check (payment_status in ('Pending','Paid','Failed','Refunded')),
  subtotal_paise bigint not null check (subtotal_paise >= 0),
  delivery_fee_paise bigint not null check (delivery_fee_paise >= 0),
  discount_paise bigint not null default 0 check (discount_paise >= 0),
  total_paise bigint not null check (total_paise >= 0),
  delivery_address text not null,
  city text not null,
  postal_code text not null check (postal_code ~ '^[0-9]{6}$'),
  coupon_code text references public.coupons(code),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists orders_customer_created_idx
  on public.orders(customer_id, created_at desc);
create index if not exists orders_status_created_idx
  on public.orders(status, created_at desc);

-- 6) ORDER LINE ITEMS (price/name snapshots preserve history if catalog changes)
create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id bigint not null references public.products(id),
  product_name text not null,
  unit_price_paise bigint not null check (unit_price_paise >= 0),
  quantity integer not null check (quantity between 1 and 20),
  size text,
  color text,
  line_total_paise bigint not null check (line_total_paise >= 0),
  created_at timestamptz not null default now()
);
create index if not exists order_items_order_idx on public.order_items(order_id);
create index if not exists order_items_product_idx on public.order_items(product_id);

-- 7) PAYMENT RECORDS
-- This phase supports Cash on Delivery only. Online gateway is not connected.
create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references public.orders(id) on delete cascade,
  method text not null check (method in ('Cash on Delivery')),
  status text not null default 'Pending'
    check (status in ('Pending','Paid','Failed','Refunded')),
  amount_paise bigint not null check (amount_paise >= 0),
  transaction_reference text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 8) ORDER STATUS AUDIT TRAIL
create table if not exists public.order_status_history (
  id bigint generated always as identity primary key,
  order_id uuid not null references public.orders(id) on delete cascade,
  old_status text,
  new_status text not null,
  note text,
  changed_at timestamptz not null default now()
);
create index if not exists order_status_history_order_idx
  on public.order_status_history(order_id, changed_at desc);

-- Keep products aligned with js/products.js (31 products).
insert into public.products(id, name, category, price_paise, image_url, description)
values
  (1, 'Classic Oversized T-Shirt', 'Men', 59900, 'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?auto=format&fit=crop&w=700&q=84', 'Soft cotton • Relaxed fit'),
  (2, 'Everyday Linen Shirt', 'Men', 129900, 'https://images.unsplash.com/photo-1598033129183-c4f50c736f10?auto=format&fit=crop&w=700&q=84', 'Breathable linen blend'),
  (3, 'Urban Denim Jacket', 'Men', 189900, 'https://images.unsplash.com/photo-1551028719-00167b16eac5?auto=format&fit=crop&w=700&q=84', 'A timeless wardrobe layer'),
  (4, 'Relaxed Fit Jeans', 'Men', 149900, 'https://images.unsplash.com/photo-1542272604-787c3835535d?auto=format&fit=crop&w=700&q=84', 'Comfort stretch denim'),
  (5, 'Floral Summer Dress', 'Women', 179900, 'https://images.unsplash.com/photo-1595777457583-95e059d581b8?auto=format&fit=crop&w=700&q=84', 'Lightweight summer edit'),
  (6, 'Satin Evening Dress', 'Women', 249900, 'https://images.unsplash.com/photo-1566174053879-31528523f8ae?auto=format&fit=crop&w=700&q=84', 'Made for special moments'),
  (7, 'Minimal Co-ord Set', 'Women', 199900, 'https://images.unsplash.com/photo-1529139574466-a303027c1d8b?auto=format&fit=crop&w=700&q=84', 'Effortless matching set'),
  (8, 'Everyday Handbag', 'Women', 159900, 'https://images.unsplash.com/photo-1584917865442-de89df76afd3?auto=format&fit=crop&w=700&q=84', 'Roomy, polished, versatile'),
  (9, 'Kids Graphic Tee', 'Kids', 39900, 'https://images.unsplash.com/photo-1503342217505-b0a15ec3261c?auto=format&fit=crop&w=700&q=84', 'Play-ready cotton comfort'),
  (10, 'Kids Casual Outfit', 'Kids', 89900, 'https://images.unsplash.com/photo-1519238263530-99bdd11df2ea?auto=format&fit=crop&w=700&q=84', 'Easy everyday styling'),
  (11, 'Classic White Sneakers', 'Footwear', 179900, 'https://images.unsplash.com/photo-1542291026-7eec264c27ff?auto=format&fit=crop&w=700&q=84', 'A clean everyday essential'),
  (12, 'Street Runner Sneakers', 'Footwear', 219900, 'https://images.unsplash.com/photo-1600185365483-26d7a4cc7519?auto=format&fit=crop&w=700&q=84', 'Sporty comfort, modern style'),
  (13, 'Leather Crossbody Bag', 'Accessories', 129900, 'https://images.unsplash.com/photo-1548036328-c9fa89d128fa?auto=format&fit=crop&w=700&q=84', 'Compact daily carry'),
  (14, 'Aviator Sunglasses', 'Accessories', 79900, 'https://images.unsplash.com/photo-1511499767150-a48a237f0083?auto=format&fit=crop&w=700&q=84', 'UV protection with attitude'),
  (15, 'Premium Wrist Watch', 'Accessories', 249900, 'https://images.unsplash.com/photo-1523275335684-37898b6baf30?auto=format&fit=crop&w=700&q=84', 'Minimal, timeless detailing'),
  (16, 'Textured Knit Polo', 'Men', 99900, 'https://images.unsplash.com/photo-1618354691373-d851c5c3a990?auto=format&fit=crop&w=700&q=84', 'Smart-casual favourite'),
  (17, 'Tailored Blazer', 'Men', 299900, 'https://images.unsplash.com/photo-1591047139829-d91aecb6caea?auto=format&fit=crop&w=700&q=84', 'Sharp fit for every occasion'),
  (18, 'Wide Leg Trousers', 'Women', 129900, 'https://images.unsplash.com/photo-1551232864-3f0890e580d9?auto=format&fit=crop&w=700&q=84', 'A versatile tailored silhouette'),
  (19, 'Everyday Tote Bag', 'Women', 99900, 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?auto=format&fit=crop&w=700&q=84', 'Your everyday carry-all'),
  (20, 'Soft Knit Sweatshirt', 'Men', 119900, 'https://images.unsplash.com/photo-1556821840-3a63f95609a7?auto=format&fit=crop&w=700&q=84', 'Soft layer for cooler days'),
  (21, 'Flatform Sandals', 'Footwear', 109900, 'https://images.unsplash.com/photo-1543163521-1bf539c55dd2?auto=format&fit=crop&w=700&q=84', 'Easy all-day comfort'),
  (22, 'Minimal Heels', 'Footwear', 149900, 'https://images.unsplash.com/photo-1543163521-1bf539c55dd2?auto=format&fit=crop&w=700&q=84', 'A dress-up essential'),
  (23, 'Kids Colourblock Hoodie', 'Kids', 79900, 'https://images.unsplash.com/photo-1519238263530-99bdd11df2ea?auto=format&fit=crop&w=700&q=84', 'Cosy, colourful and fun'),
  (24, 'Cotton Kurta Set', 'Women', 169900, 'https://images.unsplash.com/photo-1597983073493-88cd35cf93e0?auto=format&fit=crop&w=700&q=84', 'Modern ethnic elegance'),
  (25, 'Printed Resort Shirt', 'Men', 89900, 'https://images.unsplash.com/photo-1620012253295-c15a3e6f14b0?auto=format&fit=crop&w=700&q=84', 'Weekend-ready print'),
  (26, 'Statement Earrings', 'Accessories', 49900, 'https://images.unsplash.com/photo-1535632066927-ab7c9ab60908?auto=format&fit=crop&w=700&q=84', 'A little shine goes a long way'),
  (27, 'Premium Backpack', 'Accessories', 149900, 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?auto=format&fit=crop&w=700&q=84', 'Built for everyday movement'),
  (28, 'Running Performance Tee', 'Men', 69900, 'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?auto=format&fit=crop&w=700&q=84', 'Lightweight performance fabric'),
  (29, 'Soft Lounge Set', 'Women', 139900, 'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?auto=format&fit=crop&w=700&q=84', 'Relaxed comfort, elevated'),
  (30, 'Classic Loafers', 'Footwear', 189900, 'https://images.unsplash.com/photo-1543163521-1bf539c55dd2?auto=format&fit=crop&w=700&q=84', 'Smart style from day to night'),
  (31, 'Everyday Beauty Set', 'Beauty', 89900, 'https://images.unsplash.com/photo-1608571423902-eed4a5ad8108?auto=format&fit=crop&w=700&q=84', 'Everyday essentials for your beauty ritual')
on conflict (id) do update set
  name = excluded.name,
  category = excluded.category,
  price_paise = excluded.price_paise,
  image_url = excluded.image_url,
  description = excluded.description,
  is_active = true,
  updated_at = now();

-- Touch updated_at automatically for customer/product/order/payment edits.
create or replace function public.set_updated_at()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists customers_set_updated_at on public.customers;
create trigger customers_set_updated_at before update on public.customers
for each row execute function public.set_updated_at();
drop trigger if exists products_set_updated_at on public.products;
create trigger products_set_updated_at before update on public.products
for each row execute function public.set_updated_at();
drop trigger if exists orders_set_updated_at on public.orders;
create trigger orders_set_updated_at before update on public.orders
for each row execute function public.set_updated_at();
drop trigger if exists payments_set_updated_at on public.payments;
create trigger payments_set_updated_at before update on public.payments
for each row execute function public.set_updated_at();

-- 9) ATOMIC ORDER PLACEMENT
-- Public storefront can execute this one constrained RPC. It cannot read or
-- write private customer/order tables directly. Prices/coupons are DB-derived.
create or replace function public.place_store_order(
  p_customer_name text,
  p_phone text,
  p_email text,
  p_address text,
  p_city text,
  p_postal_code text,
  p_items jsonb,
  p_coupon_code text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_customer_id uuid;
  v_auth_email text;
  v_order_id uuid;
  v_order_number text;
  v_subtotal bigint := 0;
  v_delivery bigint := 0;
  v_discount bigint := 0;
  v_total bigint := 0;
  v_coupon text := upper(trim(coalesce(p_coupon_code, '')));
  v_item_count integer;
  v_valid_count integer;
  v_coupon_type text;
  v_coupon_value integer;
  v_coupon_min bigint;
  v_coupon_max bigint;
  v_coupon_active boolean;
  v_coupon_start timestamptz;
  v_coupon_expiry timestamptz;
begin
  if auth.uid() is null then
    raise exception 'Please log in before placing an order';
  end if;
  v_auth_email := lower(trim(coalesce(auth.jwt()->>'email', '')));
  if v_auth_email = '' then
    raise exception 'A verified email account is required to place an order';
  end if;
  if length(trim(coalesce(p_customer_name, ''))) not between 2 and 100 then
    raise exception 'Please enter a valid customer name';
  end if;
  if coalesce(p_phone, '') !~ '^[0-9]{10}$' then
    raise exception 'Please enter a valid 10-digit mobile number';
  end if;
  if length(trim(coalesce(p_address, ''))) not between 5 and 500 then
    raise exception 'Please enter a valid delivery address';
  end if;
  if length(trim(coalesce(p_city, ''))) not between 2 and 100 then
    raise exception 'Please enter a valid city';
  end if;
  if coalesce(p_postal_code, '') !~ '^[0-9]{6}$' then
    raise exception 'Please enter a valid PIN code';
  end if;
  if jsonb_typeof(p_items) is distinct from 'array' then
    raise exception 'Your cart data is invalid';
  end if;
  if jsonb_array_length(p_items) = 0 then
    raise exception 'Your cart is empty';
  end if;

  select count(*) into v_item_count from jsonb_array_elements(p_items);
  if v_item_count > 30 then
    raise exception 'Too many different items in one order';
  end if;

  -- Validate item JSON before any casts or writes.
  if exists (
    select 1 from jsonb_array_elements(p_items) i
    where case
      when coalesce(i->>'product_id','') ~ '^[1-9][0-9]{0,17}$'
       and coalesce(i->>'quantity','') ~ '^[0-9]{1,2}$'
      then (i->>'quantity')::integer between 1 and 20
      else false
    end is not true
  ) then
    raise exception 'One or more product IDs or quantities are invalid';
  end if;

  select count(*) into v_valid_count
  from jsonb_array_elements(p_items) i
  join public.products p on p.id = (i->>'product_id')::bigint and p.is_active;
  if v_valid_count <> v_item_count then
    raise exception 'One or more products are unavailable';
  end if;

  -- Reuse only this authenticated account's customer row. A legacy phone row
  -- may be linked only when its stored email already matches the verified JWT.
  select id into v_customer_id
  from public.customers
  where auth_user_id = auth.uid()
  for update;

  if v_customer_id is null then
    select id into v_customer_id
    from public.customers
    where phone = p_phone
      and lower(coalesce(email, '')) = v_auth_email
      and auth_user_id is null
    for update;

    if v_customer_id is not null then
      update public.customers
      set auth_user_id = auth.uid(), full_name = trim(p_customer_name),
          email = v_auth_email, updated_at = now()
      where id = v_customer_id;
    else
      insert into public.customers(auth_user_id, full_name, phone, email)
      values (auth.uid(), trim(p_customer_name), p_phone, v_auth_email)
      returning id into v_customer_id;
    end if;
  else
    update public.customers
    set full_name = trim(p_customer_name), phone = p_phone,
        email = v_auth_email, updated_at = now()
    where id = v_customer_id;
  end if;

  -- Store/refresh the supplied delivery address for this customer.
  insert into public.customer_addresses(customer_id, recipient_name, phone, address_line, city, postal_code, is_default)
  values (v_customer_id, trim(p_customer_name), p_phone, trim(p_address), trim(p_city), p_postal_code, true);

  select coalesce(sum(p.price_paise * (i->>'quantity')::integer), 0)
  into v_subtotal
  from jsonb_array_elements(p_items) i
  join public.products p on p.id = (i->>'product_id')::bigint and p.is_active;

  v_delivery := case when v_subtotal >= 99900 then 0 else 9900 end;

  if v_coupon <> '' then
    select discount_type, discount_value, minimum_order_paise,
           maximum_discount_paise, is_active, starts_at, expires_at
    into v_coupon_type, v_coupon_value, v_coupon_min,
         v_coupon_max, v_coupon_active, v_coupon_start, v_coupon_expiry
    from public.coupons where code = v_coupon;

    if not found or not v_coupon_active
       or (v_coupon_start is not null and now() < v_coupon_start)
       or (v_coupon_expiry is not null and now() > v_coupon_expiry) then
      raise exception 'Coupon is invalid or expired';
    end if;
    if v_subtotal < v_coupon_min then
      raise exception 'Minimum order amount for this coupon is not reached';
    end if;

    if v_coupon_type = 'percentage' then
      v_discount := round(v_subtotal * v_coupon_value / 100.0)::bigint;
    else
      v_discount := v_coupon_value;
    end if;
    if v_coupon_max is not null then
      v_discount := least(v_discount, v_coupon_max);
    end if;
    v_discount := least(v_discount, v_subtotal);
  end if;

  v_total := greatest(0, v_subtotal + v_delivery - v_discount);
  v_order_number := 'BF' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10));

  insert into public.orders(
    order_number, customer_id, payment_method, subtotal_paise,
    delivery_fee_paise, discount_paise, total_paise,
    delivery_address, city, postal_code, coupon_code
  ) values (
    v_order_number, v_customer_id, 'Cash on Delivery', v_subtotal,
    v_delivery, v_discount, v_total,
    trim(p_address), trim(p_city), p_postal_code, nullif(v_coupon, '')
  ) returning id into v_order_id;

  insert into public.order_items(
    order_id, product_id, product_name, unit_price_paise,
    quantity, size, color, line_total_paise
  )
  select v_order_id, p.id, p.name, p.price_paise,
    (i->>'quantity')::integer,
    nullif(left(coalesce(i->>'size',''), 30), ''),
    nullif(left(coalesce(i->>'color',''), 40), ''),
    p.price_paise * (i->>'quantity')::integer
  from jsonb_array_elements(p_items) i
  join public.products p on p.id = (i->>'product_id')::bigint and p.is_active;

  insert into public.payments(order_id, method, status, amount_paise)
  values (v_order_id, 'Cash on Delivery', 'Pending', v_total);

  insert into public.order_status_history(order_id, old_status, new_status, note)
  values (v_order_id, null, 'Order placed', 'Order created from storefront');

  return jsonb_build_object(
    'order_id', v_order_id,
    'order_number', v_order_number,
    'subtotal_amount', v_subtotal / 100.0,
    'delivery_amount', v_delivery / 100.0,
    'discount_amount', v_discount / 100.0,
    'total_amount', v_total / 100.0
  );
end;
$$;

-- Lock down all tables for browser roles. Supabase project owner can still
-- inspect/manage rows in Dashboard Table Editor.
alter table public.customers enable row level security;
alter table public.products enable row level security;
alter table public.customer_addresses enable row level security;
alter table public.coupons enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.payments enable row level security;
alter table public.order_status_history enable row level security;

revoke all on table public.customers, public.products, public.customer_addresses,
  public.coupons, public.orders, public.order_items, public.payments,
  public.order_status_history from anon, authenticated;

revoke all on function public.place_store_order(text,text,text,text,text,text,jsonb,text) from public, anon;
grant execute on function public.place_store_order(text,text,text,text,text,text,jsonb,text)
  to authenticated;

commit;

-- EXPECTED TABLES:
-- customers, products, customer_addresses, coupons, orders, order_items,
-- payments, order_status_history
