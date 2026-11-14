begin;
select plan(21);
update public.app_config set value='true'::jsonb where key='sync_enabled';
insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
values ('00000000-0000-0000-0000-000000000000','86000000-0000-4000-8000-000000000001','authenticated','authenticated','food-group@example.test','',now(),now(),now()),
('00000000-0000-0000-0000-000000000000','86000000-0000-4000-8000-000000000002','authenticated','authenticated','food-group-other@example.test','',now(),now(),now());
create function pg_temp.food_group_event(extra jsonb, event_id uuid default gen_random_uuid())
returns jsonb language sql as $$
 select public.apply_sync_event_v1('88000000-0000-4000-8000-000000000001',event_id,'product.upsert',now(),
 '87000000-0000-4000-8000-000000000001',1,
 '{"id":"87000000-0000-4000-8000-000000000001","name":"Synthetic food","source":"user","nutrientsPer100g":{"kcal":100}}'::jsonb || extra);
$$;
set local role authenticated;
select set_config('request.jwt.claim.sub','86000000-0000-4000-8000-000000000001',true);
select is(pg_temp.food_group_event('{"selectedFoodGroup":"bread"}','89000000-0000-4000-8000-000000000001')->>'status','acked','selected group accepted');
select is((select selected_food_group from public.products where id='87000000-0000-4000-8000-000000000001'),'bread','selected group persisted');
select is(pg_temp.food_group_event('{}')->>'status','acked','legacy event without group accepted');
select is((select selected_food_group from public.products where id='87000000-0000-4000-8000-000000000001'),'bread','omission preserves group');
select is(pg_temp.food_group_event(jsonb_build_object('selectedFoodGroup', value))->>'code','VALIDATION_ERROR','invalid group rejected')
from jsonb_array_elements('["unknown","",1,{},[],true]'::jsonb);
select is((select count(*)::integer from public.event_inbox where owner_id='86000000-0000-4000-8000-000000000001'),2,'rejected groups leave no inbox rows');
select is((select selected_food_group from public.products where id='87000000-0000-4000-8000-000000000001'),'bread','invalid events preserve group');
select is(pg_temp.food_group_event('{"selectedFoodGroup":null}')->>'status','acked','explicit null accepted');
select is((select selected_food_group from public.products where id='87000000-0000-4000-8000-000000000001'),null::text,'explicit null clears group');
select is(pg_temp.food_group_event('{"selectedFoodGroup":"bread"}','89000000-0000-4000-8000-000000000001')->>'status','acked','replay acknowledged');
select is((select selected_food_group from public.products where id='87000000-0000-4000-8000-000000000001'),null::text,'replay does not restore cleared group');
select is((select count(*)::integer from public.event_inbox where owner_id='86000000-0000-4000-8000-000000000001'),3,'replay does not create inbox duplicate');
select is((select nutrients_per_100g from public.products where id='87000000-0000-4000-8000-000000000001'),'{"kcal":100}'::jsonb,'nutrition preserved');
select set_config('request.jwt.claim.sub','86000000-0000-4000-8000-000000000002',true);
select is(pg_temp.food_group_event('{"selectedFoodGroup":"meat"}')->>'code','FORBIDDEN','other owner cannot change visual group');
select is((select count(*)::integer from public.event_inbox where owner_id='86000000-0000-4000-8000-000000000002'),0,'forbidden update leaves no inbox');
reset role;
select is((select selected_food_group from public.products where id='87000000-0000-4000-8000-000000000001'),null::text,'forbidden update leaves original group unchanged');
select * from finish();
rollback;
