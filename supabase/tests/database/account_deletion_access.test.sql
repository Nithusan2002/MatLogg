begin;
select plan(7);
insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at) values
('00000000-0000-0000-0000-000000000000','a0000000-0000-4000-8000-000000000001','authenticated','authenticated','deletion-a@example.test','',now(),now(),now()),
('00000000-0000-0000-0000-000000000000','a0000000-0000-4000-8000-000000000002','authenticated','authenticated','deletion-b@example.test','',now(),now(),now());
insert into public.products(id,owner_id,name,nutrients_per_100g,source,updated_at) values
('b0000000-0000-4000-8000-000000000001','a0000000-0000-4000-8000-000000000001','Private product','{}','user',now()),
('b0000000-0000-4000-8000-000000000002','a0000000-0000-4000-8000-000000000002','Other product','{}','user',now());
insert into public.food_logs(id,owner_id,date,meal,amount,unit,kcal,protein,carbs,fat) values ('c0000000-0000-4000-8000-000000000001','a0000000-0000-4000-8000-000000000001',now(),'lunsj',100,'g',100,1,2,3);
insert into public.goals(owner_id,kcal_target,protein_target,carb_target,fat_target) values ('a0000000-0000-4000-8000-000000000001',2000,100,200,70);
insert into public.weights(id,owner_id,date,weight_kg) values ('c0000000-0000-4000-8000-000000000002','a0000000-0000-4000-8000-000000000001',now(),70);
insert into public.water_logs(id,owner_id,date,created_at) values ('c0000000-0000-4000-8000-000000000003','a0000000-0000-4000-8000-000000000001',now(),now());
insert into public.favorites(owner_id,product_id) values ('a0000000-0000-4000-8000-000000000001','b0000000-0000-4000-8000-000000000001');
insert into public.saved_meals(id,owner_id,name,updated_at) values ('c0000000-0000-4000-8000-000000000004','a0000000-0000-4000-8000-000000000001','Private meal',now());
insert into public.saved_meal_items(id,saved_meal_id,product_id,product_name,amount,unit,kcal,protein,carbs,fat,nutrition_source,sort_index) values ('c0000000-0000-4000-8000-000000000005','c0000000-0000-4000-8000-000000000004','b0000000-0000-4000-8000-000000000001','Private item',100,'g',100,1,2,3,'user',0);
insert into public.event_inbox(event_id,owner_id,device_id,type,created_at,schema_version,payload_json) values ('c0000000-0000-4000-8000-000000000006','a0000000-0000-4000-8000-000000000001','c0000000-0000-4000-8000-000000000007','log.upsert',now(),1,'{}');
insert into private.sync_rate_windows(owner_id,window_start,request_count) values ('a0000000-0000-4000-8000-000000000001',now(),1);
select is(has_function_privilege('anon','public.is_account_active_v1()','execute'),false,'anonymous callers cannot inspect account status');
set local role authenticated;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"a0000000-0000-4000-8000-000000000001"}',true);
select set_config('request.jwt.claim.sub','a0000000-0000-4000-8000-000000000001',true);
select is(public.is_account_active_v1(),true,'active account can read');
select is(((select count(*) from public.profiles where id='a0000000-0000-4000-8000-000000000001') +
  (select count(*) from public.event_inbox where owner_id='a0000000-0000-4000-8000-000000000001') +
  (select count(*) from public.food_logs where owner_id='a0000000-0000-4000-8000-000000000001') +
  (select count(*) from public.goals where owner_id='a0000000-0000-4000-8000-000000000001') +
  (select count(*) from public.favorites where owner_id='a0000000-0000-4000-8000-000000000001') +
  (select count(*) from public.weights where owner_id='a0000000-0000-4000-8000-000000000001') +
  (select count(*) from public.products where owner_id='a0000000-0000-4000-8000-000000000001') +
  (select count(*) from public.saved_meals where owner_id='a0000000-0000-4000-8000-000000000001') +
  (select count(*) from public.water_logs where owner_id='a0000000-0000-4000-8000-000000000001') +
  (select count(*) from public.saved_meal_items where saved_meal_id='c0000000-0000-4000-8000-000000000004'))::integer,10,'active owner can read all owned categories');
reset role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
select public.request_account_deletion_admin_v1('a0000000-0000-4000-8000-000000000001');
set local role authenticated;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"a0000000-0000-4000-8000-000000000001"}',true);
select is(public.is_account_active_v1(),false,'deletion immediately deactivates read access');
select is(((select count(*) from public.profiles where id='a0000000-0000-4000-8000-000000000001') +
  (select count(*) from public.event_inbox where owner_id='a0000000-0000-4000-8000-000000000001') +
  (select count(*) from public.food_logs where owner_id='a0000000-0000-4000-8000-000000000001') +
  (select count(*) from public.goals where owner_id='a0000000-0000-4000-8000-000000000001') +
  (select count(*) from public.favorites where owner_id='a0000000-0000-4000-8000-000000000001') +
  (select count(*) from public.weights where owner_id='a0000000-0000-4000-8000-000000000001') +
  (select count(*) from public.products where owner_id='a0000000-0000-4000-8000-000000000001') +
  (select count(*) from public.saved_meals where owner_id='a0000000-0000-4000-8000-000000000001') +
  (select count(*) from public.water_logs where owner_id='a0000000-0000-4000-8000-000000000001') +
  (select count(*) from public.saved_meal_items where saved_meal_id='c0000000-0000-4000-8000-000000000004'))::integer,0,'old token cannot read any owned category before purge');
select set_config('request.jwt.claims','{"role":"authenticated","sub":"a0000000-0000-4000-8000-000000000002"}',true);
select set_config('request.jwt.claim.sub','a0000000-0000-4000-8000-000000000002',true);
select is(public.is_account_active_v1(),true,'other owner remains active');
select is((select count(*)::integer from public.products where owner_id='a0000000-0000-4000-8000-000000000002'),1,'other owner retains read access');
select * from finish();
rollback;
