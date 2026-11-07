-- Run after THE_BIG_FASHION_SUPABASE_SETUP.sql
select routine_name, specific_name
from information_schema.routines
where routine_schema = 'public'
  and routine_name = 'place_store_order';

select column_name, data_type
from information_schema.columns
where table_schema = 'public' and table_name = 'customers'
  and column_name = 'auth_user_id';

select
  has_function_privilege('authenticated',
    'public.place_store_order(text,text,text,text,text,text,jsonb,text)', 'EXECUTE') as authenticated_can_place_order,
  has_function_privilege('anon',
    'public.place_store_order(text,text,text,text,text,text,jsonb,text)', 'EXECUTE') as anon_cannot_place_order;

notify pgrst, 'reload schema';
