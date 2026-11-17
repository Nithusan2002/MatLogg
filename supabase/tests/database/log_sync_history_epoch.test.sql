begin;
select no_plan();
update public.app_config set value='true' where key='log_sync_v2_enabled';
insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
values ('00000000-0000-0000-0000-000000000000','92000000-0000-4000-8000-000000000001','authenticated','authenticated','epoch-one@example.test','',now(),now(),now()),
('00000000-0000-0000-0000-000000000000','92000000-0000-4000-8000-000000000002','authenticated','authenticated','epoch-two@example.test','',now(),now(),now());
insert into private.log_sync_v2_owners(owner_id,enabled) values('92000000-0000-4000-8000-000000000001',true),('92000000-0000-4000-8000-000000000002',true);
create function pg_temp.epoch() returns uuid language sql security definer set search_path='' as $$ select history_epoch from private.log_sync_v2_owners where owner_id=auth.uid() $$;
create function pg_temp.mutation(event uuid, base bigint default 0, kind text default 'log.upsert', amount numeric default 125) returns jsonb language sql as $$
select jsonb_build_object('schemaVersion',2,'historyEpoch',pg_temp.epoch(),'eventId',event,'deviceId','93000000-0000-4000-8000-000000000001','entityId','94000000-0000-4000-8000-000000000001','type',kind,'baseRevision',base,
'payload',case when kind='log.delete' then null else jsonb_build_object('log',jsonb_build_object('id','94000000-0000-4000-8000-000000000001','userId','92000000-0000-4000-8000-000000000001','productId','95000000-0000-4000-8000-000000000001','isSynced',false,'mealType','lunsj','amountG',amount,'amountUnit','ml','calories',123.75,'proteinG',1.25,'carbsG',2.5,'fatG',3.75,'loggedDate',1000,'loggedTime',2000,'createdAt',3000),
'product',jsonb_build_object('id','95000000-0000-4000-8000-000000000001','name','Synthetic test','isSynced',true,'isVerified',false,'source','user','kind','packaged','imageSource','user','verificationStatus','unverified','createdAt',3000,'nutritionSource','user','caloriesPer100g',98.5,'proteinGPer100g',1.25,'carbsGPer100g',2.5,'fatGPer100g',3.75)) end);
$$;
set local role authenticated;
select set_config('request.jwt.claim.sub','92000000-0000-4000-8000-000000000001',true);
select set_config('test.old_epoch',pg_temp.epoch()::text,true);
select throws_ok($q$select public.pull_logs_v2(0)$q$,'P0001','HISTORY_EPOCH_REQUIRED','old read API cannot bypass epoch');
select throws_ok($q$select public.push_log_v2(pg_temp.mutation('96000000-0000-4000-8000-000000000001')-'historyEpoch')$q$,'P0001','HISTORY_EPOCH_REQUIRED','old writer blocked');
select is(public.push_log_v2(pg_temp.mutation('96000000-0000-4000-8000-000000000001'))->>'status','applied','epoch-bound create');
select is(public.begin_log_bootstrap_v2('97000000-0000-4000-8000-000000000001',pg_temp.epoch())->>'upperCursor','1','snapshot freezes high-water mark');
select is(public.push_log_v2(pg_temp.mutation('96000000-0000-4000-8000-000000000002',1,'log.upsert',200))->>'status','applied','write after snapshot');
select is(public.begin_log_bootstrap_v2('97000000-0000-4000-8000-000000000001',pg_temp.epoch())->>'upperCursor','1','retry begin returns same snapshot');
select is(public.read_log_bootstrap_v2('97000000-0000-4000-8000-000000000001',0)->'changes'->0->'payload'->'log'->>'amountG','125','snapshot does not change when live entity changes');
select is(public.read_log_bootstrap_v2('97000000-0000-4000-8000-000000000001',0)->>'complete','true','last page marked complete');
select is(public.pull_logs_v2(1,pg_temp.epoch())->'changes'->0->'payload'->'log'->>'amountG','200','delta after snapshot contains later write');
select throws_ok($q$select public.read_log_bootstrap_v2('97000000-0000-4000-8000-000000000001',-1)$q$,'P0001','INVALID_CURSOR','invalid snapshot offset rejected');
select ok(not has_function_privilege('authenticated','matlogg_internal.push_log_before_epoch_v2(jsonb)','execute'),'old internal writer unavailable');
select ok(not has_function_privilege('authenticated','matlogg_internal.pull_logs_before_epoch_v2(bigint)','execute'),'old internal reader unavailable');
select set_config('request.jwt.claim.sub','92000000-0000-4000-8000-000000000002',true);
select throws_ok($q$select public.read_log_bootstrap_v2('97000000-0000-4000-8000-000000000001',0)$q$,'P0001','SNAPSHOT_NOT_FOUND','other owner cannot read snapshot');
select throws_ok($q$select public.begin_log_bootstrap_v2('97000000-0000-4000-8000-000000000001',pg_temp.epoch())$q$,'P0001','SNAPSHOT_NOT_FOUND','other owner cannot reuse snapshot ID');
select is(public.begin_log_bootstrap_v2('97000000-0000-4000-8000-000000000002',pg_temp.epoch())->>'totalCount','0','empty account supported');
select is(jsonb_array_length(public.read_log_bootstrap_v2('97000000-0000-4000-8000-000000000002',0)->'changes'),0,'empty snapshot page');
reset role;
update private.log_sync_v2_snapshots set expires_at=now()-interval '1 second' where id='97000000-0000-4000-8000-000000000002';
update private.log_sync_v2_owners set history_epoch=gen_random_uuid() where owner_id='92000000-0000-4000-8000-000000000001';
set local role authenticated;
select throws_ok($q$select public.read_log_bootstrap_v2('97000000-0000-4000-8000-000000000002',0)$q$,'P0001','SNAPSHOT_EXPIRED','expired page rejected');
select set_config('request.jwt.claim.sub','92000000-0000-4000-8000-000000000001',true);
select throws_ok($q$select public.pull_logs_v2(0,current_setting('test.old_epoch')::uuid)$q$,'P0001','HISTORY_EPOCH_MISMATCH','even numerically valid old cursor rejected after rotation');
select throws_ok($q$select public.push_log_v2(jsonb_set(pg_temp.mutation('96000000-0000-4000-8000-000000000001'),'{historyEpoch}',to_jsonb(current_setting('test.old_epoch'))))$q$,'P0001','HISTORY_EPOCH_MISMATCH','old ACK cannot authorize replay in new epoch');
select throws_ok($q$select public.read_log_bootstrap_v2('97000000-0000-4000-8000-000000000001',0)$q$,'P0001','HISTORY_EPOCH_MISMATCH','old snapshot invalid after rotation');
select is(public.begin_log_bootstrap_v2('97000000-0000-4000-8000-000000000003',pg_temp.epoch())->>'upperCursor','2','new epoch can bootstrap unchanged revision numbers');
select * from finish();
rollback;
