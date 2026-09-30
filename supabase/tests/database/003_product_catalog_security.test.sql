begin;
select plan(18);

select has_table('public', 'catalog_products', 'catalog products exist');
select has_table('public', 'product_submissions', 'product submissions exist');
select has_table('public', 'submission_images', 'submission images exist');
select has_table('public', 'catalog_reports', 'catalog reports exist');
select has_table('public', 'moderation_actions', 'moderation audit exists');
select is((select relrowsecurity from pg_class where oid = 'public.catalog_products'::regclass), true, 'catalog products have RLS');
select is((select relrowsecurity from pg_class where oid = 'public.product_submissions'::regclass), true, 'submissions have RLS');
select is((select relrowsecurity from pg_class where oid = 'public.submission_images'::regclass), true, 'images have RLS');
select is((select has_table_privilege('anon', 'public.catalog_products', 'select')), false, 'anon cannot read catalog table directly');
select is((select has_table_privilege('authenticated', 'public.product_submissions', 'select')), false, 'authenticated cannot read submissions directly');
select is((select value from public.app_config where key = 'nutrition_label_ai_enabled'), 'false'::jsonb, 'AI starts disabled');
select is((select value from public.app_config where key = 'shared_catalog_read_enabled'), 'false'::jsonb, 'catalog read starts disabled');
select is((select value from public.app_config where key = 'catalog_contributions_enabled'), 'false'::jsonb, 'contributions start disabled');
select is((select value from public.app_config where key = 'catalog_auto_publish_enabled'), 'false'::jsonb, 'autopublish starts disabled');
select has_function('public', 'consume_catalog_quota_v1', array['text','text','integer'], 'catalog rate-limit function exists');
select has_function('public', 'consume_ai_daily_quota_v1', array['uuid'], 'AI daily quota exists');
select has_function('public', 'catalog_duplicate_candidates_v1', array['text','text','double precision'], 'fuzzy duplicate lookup exists');
select is((select public.feature_enabled_v1('catalog_auto_publish_enabled')), false, 'autopublish kill switch is off');

select * from finish();
rollback;
