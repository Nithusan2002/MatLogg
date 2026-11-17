begin;
select no_plan();
insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
values ('00000000-0000-0000-0000-000000000000','92000000-0000-4000-8000-000000000001','authenticated','authenticated','v2-one@example.test','',now(),now(),now()),
('00000000-0000-0000-0000-000000000000','92000000-0000-4000-8000-000000000002','authenticated','authenticated','v2-two@example.test','',now(),now(),now());
insert into private.log_sync_v2_owners(owner_id,enabled) values('92000000-0000-4000-8000-000000000001',true),('92000000-0000-4000-8000-000000000002',true);
create function pg_temp.epoch() returns uuid language sql security definer set search_path='' as $$ select history_epoch from private.log_sync_v2_owners where owner_id=auth.uid() $$;
create function pg_temp.pull_logs_v2(c bigint) returns jsonb language sql as $$ select public.pull_logs_v2(c,pg_temp.epoch()) $$;
create function pg_temp.mutation(event uuid, base bigint default 0, kind text default 'log.upsert', amount numeric default 125) returns jsonb language sql as $$
select jsonb_build_object('schemaVersion',2,'historyEpoch',pg_temp.epoch(),'eventId',event,'deviceId','93000000-0000-4000-8000-000000000001','entityId','94000000-0000-4000-8000-000000000001','type',kind,'baseRevision',base,
'payload',case when kind='log.delete' then null else jsonb_build_object('log',jsonb_build_object('id','94000000-0000-4000-8000-000000000001','userId','92000000-0000-4000-8000-000000000001','productId','95000000-0000-4000-8000-000000000001','isSynced',false,'mealType','lunsj','amountG',amount,'amountUnit','ml','calories',123.75,'proteinG',1.25,'carbsG',2.5,'fatG',3.75,'loggedDate',1000,'loggedTime',2000,'createdAt',3000),
'product',jsonb_build_object('id','95000000-0000-4000-8000-000000000001','name','Synthetic test','isSynced',true,'isVerified',false,'source','user','kind','packaged','imageSource','user','verificationStatus','unverified','createdAt',3000,'nutritionSource','user','caloriesPer100g',98.5,'proteinGPer100g',1.25,'carbsGPer100g',2.5,'fatGPer100g',3.75)) end);
$$;
select ok(not has_table_privilege('authenticated','private.log_sync_v2_entities','SELECT'),'no direct entity read');
select ok(not has_function_privilege('anon','public.push_log_v2(jsonb)','EXECUTE'),'anonymous cannot push');
set local role authenticated;
select set_config('request.jwt.claim.sub','92000000-0000-4000-8000-000000000001',true);
select throws_ok($$select pg_temp.pull_logs_v2(0)$$,'P0001','SYNC_DISABLED','global gate blocks read');
reset role;
update public.app_config set value='true' where key='log_sync_v2_enabled';
set local role authenticated;
select is(public.push_log_v2(pg_temp.mutation('96000000-0000-4000-8000-000000000001'))->>'status','applied','create');
select is(public.push_log_v2(pg_temp.mutation('96000000-0000-4000-8000-000000000001'))->'change'->>'revision','1','replay same revision');
select throws_ok($$select public.push_log_v2(pg_temp.mutation('96000000-0000-4000-8000-000000000001',0,'log.upsert',200))$$,'P0001','EVENT_ID_COLLISION','changed payload same event rejected');
select is(public.push_log_v2(pg_temp.mutation('96000000-0000-4000-8000-000000000002',1,'log.upsert',200))->>'status','applied','edit at revision');
select is(public.push_log_v2(pg_temp.mutation('96000000-0000-4000-8000-000000000003',1,'log.upsert',300))->>'status','conflict','concurrent edit retained');
select is(pg_temp.pull_logs_v2(0)->>'cursor','2','conflict does not advance domain cursor');
select is(pg_temp.pull_logs_v2(0)->'changes'->0->'payload'->'log'->>'calories','123.75','decimals preserved');
select is(public.push_log_v2(pg_temp.mutation('96000000-0000-4000-8000-000000000004',1,'log.delete'))->>'status','applied','stale delete wins');
select is(public.push_log_v2(pg_temp.mutation('96000000-0000-4000-8000-000000000005',2,'log.upsert',400))->>'status','conflict','tombstone prevents resurrection');
select is(pg_temp.pull_logs_v2(2)->'changes'->0->>'deleted','true','tombstone delivered');
select throws_ok($$select pg_temp.pull_logs_v2(999)$$,'P0001','INVALID_CURSOR','future cursor rejected');
select is(public.apply_sync_event_v1('93000000-0000-4000-8000-000000000001',gen_random_uuid(),'log.delete',now(),'94000000-0000-4000-8000-000000000001',1,'{}')->>'code','V2_REQUIRED','v1 blocked for enrolled owner');
select set_config('request.jwt.claim.sub','92000000-0000-4000-8000-000000000002',true);
select is(jsonb_array_length(pg_temp.pull_logs_v2(0)->'changes'),0,'other owner sees empty history');
select throws_ok($$select public.push_log_v2(pg_temp.mutation('96000000-0000-4000-8000-000000000006'))$$,'P0001','VALIDATION_ERROR','forged owner rejected');
select throws_ok($$select public.push_log_v2(pg_temp.mutation('96000000-0000-4000-8000-000000000001'))$$,'P0001','EVENT_ID_COLLISION','cross-owner event collision rejected');
reset role;
select is((select count(*)::integer from private.log_sync_v2_changes),3,'only accepted mutations in change log');
select is((select count(*)::integer from private.log_sync_v2_receipts where response->>'status'='conflict'),2,'both conflict candidates retained');
select is((select mutation->'payload'->'log'->>'amountG' from private.log_sync_v2_receipts where event_id='96000000-0000-4000-8000-000000000003'),'300','local conflict candidate preserved');
set local role authenticated;
select set_config('request.jwt.claim.sub','92000000-0000-4000-8000-000000000001',true);
select throws_ok($q$select public.push_log_v2(jsonb_set(pg_temp.mutation('96000000-0000-4000-8000-000000000007'),'{schemaVersion}','"2"'::jsonb))$q$,'P0001','VALIDATION_ERROR','string schema version rejected');
select throws_ok($q$select public.push_log_v2(jsonb_set(pg_temp.mutation('96000000-0000-4000-8000-000000000008'),'{payload,log,amountG}','"125"'::jsonb))$q$,'P0001','VALIDATION_ERROR','numeric string rejected');
select throws_ok($q$select public.push_log_v2(jsonb_set(pg_temp.mutation('96000000-0000-4000-8000-000000000009'),'{payload,product,localImageData}','"private"'::jsonb))$q$,'P0001','VALIDATION_ERROR','images cannot sneak into log payload');
select * from finish();
rollback;
