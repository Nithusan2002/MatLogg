begin;
update public.app_config set value = 'true'::jsonb where key = 'sync_enabled';
select plan(35);
insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
values ('00000000-0000-0000-0000-000000000000','10000000-0000-4000-8000-000000000011','authenticated','authenticated','portion-a@example.test','',now(),now(),now()),
('00000000-0000-0000-0000-000000000000','20000000-0000-4000-8000-000000000022','authenticated','authenticated','portion-b@example.test','',now(),now(),now());
create function pg_temp.portion() returns jsonb language sql as $$
 select '{"servingId":"50000000-0000-8000-8000-000000000055","label":"Polarbrød","count":2,"amountPerServing":37.5,"unit":"g","source":"openFoodFacts","kind":"piece"}'::jsonb;
$$;
create function pg_temp.log_payload(extra jsonb) returns jsonb language sql as $$
 select '{"id":"30000000-0000-4000-8000-000000000033","date":"2026-10-02T10:00:00Z","meal":"frokost","grams":75,"unit":"g","kcal":195,"protein":7.5,"carbs":30,"fat":3}'::jsonb || extra;
$$;
create function pg_temp.send_log(extra jsonb, event_id uuid default gen_random_uuid()) returns jsonb language sql as $$
 select public.apply_sync_event_v1('40000000-0000-4000-8000-000000000044',event_id,'log.upsert',now(),'30000000-0000-4000-8000-000000000033',1,pg_temp.log_payload(extra));
$$;
create function pg_temp.send_meal(portion jsonb, include_portion boolean default true, amount double precision default 75)
returns jsonb language sql as $$
 select public.apply_sync_event_v1('40000000-0000-4000-8000-000000000044',gen_random_uuid(),'saved_meal.upsert',now(),
 '70000000-0000-4000-8000-000000000077',1,jsonb_build_object(
 'id','70000000-0000-4000-8000-000000000077','name','Portion fixture','updatedAt','2026-10-02T10:00:00Z',
 'items',jsonb_build_array(jsonb_build_object(
 'id','80000000-0000-4000-8000-000000000088','productId','90000000-0000-4000-8000-000000000099',
 'productName','Fixture bread','amountG',amount,'amountUnit','g','calories',195,
 'protein',7.5,'carbs',30,'fat',3,'nutritionSource','openFoodFacts','sortIndex',0)
 || case when include_portion then jsonb_build_object('portionSelection',portion) else '{}'::jsonb end)));
$$;
set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000011',true);
select is(pg_temp.send_log(jsonb_build_object('portionSelection',pg_temp.portion()),'60000000-0000-4000-8000-000000000066')->>'status','acked','snapshot stored');
select is((select portion_selection from public.food_logs),pg_temp.portion(),'historical basis roundtrip');
select is(pg_temp.send_log(jsonb_build_object('portionSelection',pg_temp.portion()),'60000000-0000-4000-8000-000000000066')->>'status','acked','duplicate delivery acked');
select is((select count(*)::integer from public.food_logs),1,'no duplicate log');
select is(pg_temp.send_log('{"meal":"lunsj"}')->>'status','acked','old client meal change accepted');
select is((select portion_selection from public.food_logs),pg_temp.portion(),'missing field preserves unchanged amount');
select is(pg_temp.send_log(jsonb_build_object('portionSelection', pg_temp.portion() || '{"count":3}'::jsonb))->>'code','VALIDATION_ERROR','inconsistent count rejected');
select is((select count(*)::integer from public.event_inbox),2,'invalid event inbox rolled back');
select is(pg_temp.send_log('{"portionSelection":null}')->>'status','acked','explicit null accepted');
select ok((select portion_selection is null from public.food_logs),'explicit null clears metadata');
select is(pg_temp.send_log(jsonb_build_object('portionSelection',pg_temp.portion()))->>'status','acked','metadata restored');
select is(pg_temp.send_log('{"grams":100}')->>'status','acked','old amount edit accepted');
select ok((select portion_selection is null from public.food_logs),'old changed total clears obsolete snapshot');
select is(pg_temp.send_log(jsonb_build_object('portionSelection',pg_temp.portion()))->>'status','acked','snapshot restored before product replacement');
select is(pg_temp.send_log('{"productRef":"90000000-0000-4000-8000-000000000099"}')->>'status','acked','legacy product reference change accepted');
select ok((select portion_selection is null from public.food_logs),'product replacement clears prior portion');
select set_config('request.jwt.claim.sub','20000000-0000-4000-8000-000000000022',true);
select is((select count(*)::integer from public.food_logs),0,'RLS hides portion log');
select is(pg_temp.send_log(jsonb_build_object('portionSelection',pg_temp.portion()))->>'code','FORBIDDEN','cannot overwrite other owner');
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000011',true);
select ok(not public.valid_portion_selection_v1(pg_temp.portion() || '{"unit":"ml"}'::jsonb,75,'g'),'unit mismatch rejected');
select ok(not public.valid_portion_selection_v1(pg_temp.portion() || '{"count":0}'::jsonb,75,'g'),'zero count rejected');
select ok(not public.valid_portion_selection_v1(pg_temp.portion() || '{"kind":"baseAmount"}'::jsonb,75,'g'),'base amount is not a portion');
select ok(not public.valid_portion_selection_v1(pg_temp.portion() || '{"amountPerServing":1e308}'::jsonb,75,'g'),'overflow rejected');
select ok(public.valid_portion_selection_v1(null,75,'g'),'legacy row allowed');
select is(pg_temp.send_meal(pg_temp.portion())->>'status','acked','saved meal snapshot stored');
select is((select portion_selection from public.saved_meal_items),pg_temp.portion(),'saved meal snapshot roundtrip');
select is(pg_temp.send_meal(null,false)->>'status','acked','legacy saved meal update accepted');
select is((select portion_selection from public.saved_meal_items),pg_temp.portion(),'legacy unchanged item preserves snapshot');
select is(pg_temp.send_meal(null,false,100)->>'status','acked','legacy saved amount edit accepted');
select ok((select portion_selection is null from public.saved_meal_items),'changed saved amount clears obsolete snapshot');
select is(pg_temp.send_meal(pg_temp.portion())->>'status','acked','saved snapshot restored');
select is(pg_temp.send_meal(pg_temp.portion() || '{"count":3}'::jsonb)->>'code','VALIDATION_ERROR','saved snapshot mismatch rejected');
select is((select portion_selection from public.saved_meal_items),pg_temp.portion(),'failed aggregate replacement rolls back deletion');
select is(pg_temp.send_meal(null)->>'status','acked','saved explicit clear accepted');
select ok((select portion_selection is null from public.saved_meal_items),'saved explicit null clears snapshot');
select set_config('request.jwt.claim.sub','20000000-0000-4000-8000-000000000022',true);
select is(pg_temp.send_meal(pg_temp.portion())->>'code','FORBIDDEN','saved meal ownership retained');
select * from finish();
rollback;
