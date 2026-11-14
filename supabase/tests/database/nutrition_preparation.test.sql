begin;
update public.app_config set value = 'true'::jsonb where key = 'sync_enabled';
select plan(10);
insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
values ('00000000-0000-0000-0000-000000000000','10000000-0000-4000-8000-000000000011','authenticated','authenticated','preparation@example.test','',now(),now(),now());
create function pg_temp.send_prepared(kind text, extra jsonb) returns jsonb language sql as $$
 select public.apply_sync_event_v1('40000000-0000-4000-8000-000000000044',gen_random_uuid(),kind,now(),
 '30000000-0000-4000-8000-000000000033',1,
 '{"id":"30000000-0000-4000-8000-000000000033"}'::jsonb || extra);
$$;
set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000011',true);
select is(pg_temp.send_prepared('product.upsert','{"name":"Fixture","source":"openfoodfacts","nutrientsPer100g":{"kcal":76},"nutritionPreparation":"prepared"}')->>'status','acked','prepared product accepted');
select is((select nutrition_preparation from public.products),'prepared','product status persisted');
select is(pg_temp.send_prepared('product.upsert','{"name":"Fixture","source":"openfoodfacts","nutrientsPer100g":{"kcal":76}}')->>'status','acked','legacy update accepted');
select is((select nutrition_preparation from public.products),'prepared','legacy update preserves status');
select is(pg_temp.send_prepared('log.upsert','{"date":"2026-10-12T10:00:00Z","meal":"middag","grams":200,"unit":"g","kcal":152,"protein":3.8,"carbs":21.2,"fat":5.6,"nutritionPreparation":"prepared"}')->>'status','acked','prepared log accepted');
select is((select nutrition_preparation from public.food_logs),'prepared','historical status persisted');
select is(pg_temp.send_prepared('saved_meal.upsert','{"name":"Fixture meal","updatedAt":"2026-10-12T10:00:00Z","items":[{"id":"80000000-0000-4000-8000-000000000088","productId":"30000000-0000-4000-8000-000000000033","productName":"Fixture","amountG":200,"amountUnit":"g","calories":152,"protein":3.8,"carbs":21.2,"fat":5.6,"nutritionSource":"openFoodFacts","sortIndex":0,"nutritionPreparation":"prepared"}]}')->>'status','acked','prepared meal accepted');
select is((select nutrition_preparation from public.saved_meal_items),'prepared','meal snapshot persisted');
select is(pg_temp.send_prepared('product.upsert','{"name":"Fixture","source":"openfoodfacts","nutrientsPer100g":{"kcal":76},"nutritionPreparation":"unknown"}')->>'code','VALIDATION_ERROR','invalid preparation rejected');
select is((select count(*)::integer from public.event_inbox),4,'invalid event does not enter inbox');
select * from finish();
rollback;
