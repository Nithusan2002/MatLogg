begin;
select plan(12);

select has_table('public', 'event_inbox', 'event inbox exists');
select has_table('public', 'food_logs', 'food logs exist');
select has_table('public', 'saved_meals', 'saved meals exist');
select has_function('public', 'apply_sync_event_v1', array['uuid','uuid','text','timestamp with time zone','uuid','integer','jsonb'], 'sync RPC exists');
select is((select relrowsecurity from pg_class where oid = 'public.event_inbox'::regclass), true, 'event inbox has RLS');
select is((select relrowsecurity from pg_class where oid = 'public.food_logs'::regclass), true, 'food logs have RLS');
select is((select relrowsecurity from pg_class where oid = 'public.products'::regclass), true, 'products have RLS');
select col_is_pk('public', 'event_inbox', 'event_id', 'event id is the idempotency key');
select fk_ok('public', 'event_inbox', 'owner_id', 'auth', 'users', 'id', 'inbox owner references auth user');
select is((select value from public.app_config where key = 'sync_enabled'), 'false'::jsonb, 'sync starts disabled');
select has_check('public', 'food_logs', 'food logs have value constraints');
select has_check('public', 'profiles', 'profile deletion dates are constrained');

select * from finish();
rollback;
