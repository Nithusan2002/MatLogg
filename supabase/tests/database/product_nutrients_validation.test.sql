begin;
select plan(26);
update public.app_config set value='true'::jsonb where key='sync_enabled';
insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
values ('00000000-0000-0000-0000-000000000000','76000000-0000-4000-8000-000000000001','authenticated','authenticated','nutrients@example.test','',now(),now(),now());
create function pg_temp.send_product(nutrients jsonb, event_id uuid default gen_random_uuid(), include_nutrients boolean default true)
returns jsonb language sql as $$
 select public.apply_sync_event_v1('78000000-0000-4000-8000-000000000001',event_id,'product.upsert',now(),
 '77000000-0000-4000-8000-000000000001',1,
 jsonb_build_object('id','77000000-0000-4000-8000-000000000001','name','Synthetic product','source','user','nutritionBasis','per100ml')
 || case when include_nutrients then jsonb_build_object('nutrientsPer100g',nutrients) else '{}'::jsonb end);
$$;
set local role authenticated;
select set_config('request.jwt.claim.sub','76000000-0000-4000-8000-000000000001',true);
select is(pg_temp.send_product('{"kcal":100.25,"customNutrient":0}', '79000000-0000-4000-8000-000000000001')->>'status','acked','partial numeric data and unknown numeric keys are accepted');
select is((select nutrients_per_100g from public.products where id='77000000-0000-4000-8000-000000000001'),'{"kcal":100.25,"customNutrient":0}'::jsonb,'raw decimal values preserved without filling missing nutrients');
select is((select nutrition_basis from public.products where id='77000000-0000-4000-8000-000000000001'),'per100ml','explicit unit basis preserved');
select is((select source from public.products where id='77000000-0000-4000-8000-000000000001'),'user','source preserved');
select is(pg_temp.send_product('{}','79000000-0000-4000-8000-000000000002')->>'status','acked','empty legacy object accepted');
select is((select nutrients_per_100g from public.products where id='77000000-0000-4000-8000-000000000001'),'{}'::jsonb,'empty object is not populated with guesses');
select is(pg_temp.send_product(value,'79000000-0000-4000-8000-000000000003')->>'code','VALIDATION_ERROR','invalid nutrient case ' || ordinality::text)
from jsonb_array_elements('[{"kcal":"100"},{"kcal":-1},{"kcal":null},{"kcal":{}},[],null,{"kcal":true},{"kcal":1e309}]'::jsonb) with ordinality;
select is(pg_temp.send_product(null,'79000000-0000-4000-8000-000000000004',false)->>'code','VALIDATION_ERROR','missing nutrients object rejected');
select is((select nutrients_per_100g from public.products where id='77000000-0000-4000-8000-000000000001'),'{}'::jsonb,'rejected mutations leave existing product unchanged');
select is((select count(*)::integer from public.event_inbox where owner_id='76000000-0000-4000-8000-000000000001'),2,'rejected events leave no inbox rows');
select is(pg_temp.send_product('{"kcal":100.25}','79000000-0000-4000-8000-000000000003')->>'status','acked','corrected payload retries with the rejected event ID');
select is(pg_temp.send_product('{"kcal":100.25}','79000000-0000-4000-8000-000000000003')->>'status','acked','accepted event replay remains idempotent');
select is((select count(*)::integer from public.event_inbox where owner_id='76000000-0000-4000-8000-000000000001'),3,'retry writes one new inbox row');
select is((select nutrients_per_100g from public.products where id='77000000-0000-4000-8000-000000000001'),'{"kcal":100.25}'::jsonb,'retry preserves the partial decimal snapshot');
reset role;
-- Simulate a historical event accepted before validation was tightened.
insert into public.event_inbox(event_id,owner_id,device_id,type,created_at,schema_version,payload_json)
values ('79000000-0000-4000-8000-000000000099','76000000-0000-4000-8000-000000000001','78000000-0000-4000-8000-000000000001','product.upsert',now(),1,'{"nutrientsPer100g":{"kcal":"legacy"}}');
set local role authenticated;
select is(pg_temp.send_product('{"kcal":"legacy"}','79000000-0000-4000-8000-000000000099')->>'status','acked','historical ACK survives stricter validation on replay');
select is((select count(*)::integer from public.event_inbox where owner_id='76000000-0000-4000-8000-000000000001'),4,'historical replay does not insert another inbox row');
select is((select nutrients_per_100g from public.products where id='77000000-0000-4000-8000-000000000001'),'{"kcal":100.25}'::jsonb,'historical replay does not write invalid data');
reset role;
select is((select event_count from private.sync_rate_windows where owner_id='76000000-0000-4000-8000-000000000001' and window_start=date_trunc('minute',now())),14,'direct rejected attempts and replay still consume quota');
select ok(not has_function_privilege('authenticated','matlogg_internal.apply_sync_event_unthrottled_v1(uuid,uuid,text,timestamptz,uuid,integer,jsonb)','EXECUTE'),'validation does not reopen the unguarded implementation');
select * from finish();
rollback;
