begin;
update public.app_config set value = 'true'::jsonb where key = 'sync_enabled';
select plan(7);
insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
values ('00000000-0000-0000-0000-000000000000','10000000-0000-4000-8000-000000000011','authenticated','authenticated','manual@example.test','',now(),now(),now());
create function pg_temp.send_product(extra jsonb, event_id uuid default gen_random_uuid()) returns jsonb language sql as $$
 select public.apply_sync_event_v1('40000000-0000-4000-8000-000000000044',event_id,'product.upsert',now(),
 '30000000-0000-4000-8000-000000000033',1,
 '{"id":"30000000-0000-4000-8000-000000000033","name":"Drikke","source":"user","nutrientsPer100g":{"kcal":40}}'::jsonb || extra);
$$;
set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000011',true);
select is(pg_temp.send_product('{"nutritionBasis":"per100ml","servings":[],"manualNutritionInput":{"basis":"per100ml","amount":100,"unit":"ml","calories":40,"protein":0,"carbs":10,"fat":0}}', '60000000-0000-4000-8000-000000000066')->>'status','acked','explicit basis accepted');
select is((select nutrition_basis from public.products),'per100ml','ml preserved');
select is((select manual_nutrition_input->>'calories' from public.products),'40','original input preserved');
select is(pg_temp.send_product('{}', '60000000-0000-4000-8000-000000000066')->>'status','acked','retry deduplicated');
select is((select nutrition_basis from public.products),'per100ml','retry cannot overwrite basis');
select is(pg_temp.send_product('{"nutritionBasis":"perPiece"}')->>'code','VALIDATION_ERROR','invalid basis rejected');
select is((select count(*)::integer from public.event_inbox),1,'invalid input leaves inbox unchanged');
select * from finish();
rollback;
