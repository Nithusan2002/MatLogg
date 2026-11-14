begin;
select plan(14);
update public.app_config set value = 'true'::jsonb where key = 'sync_enabled';
insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
values ('00000000-0000-0000-0000-000000000000','71000000-0000-4000-8000-000000000001','authenticated','authenticated','quota-a@example.test','',now(),now(),now()),
('00000000-0000-0000-0000-000000000000','71000000-0000-4000-8000-000000000002','authenticated','authenticated','quota-b@example.test','',now(),now(),now());
create function pg_temp.send_quota_event(event_id uuid default '72000000-0000-4000-8000-000000000001') returns jsonb
language sql as $$
 select public.apply_sync_event_v1('73000000-0000-4000-8000-000000000001',event_id,'water.upsert',now(),
 '74000000-0000-4000-8000-000000000001',1,
 '{"id":"74000000-0000-4000-8000-000000000001","date":"2026-10-12T00:00:00Z","createdAt":"2026-10-12T00:00:00Z"}'::jsonb);
$$;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"71000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select set_config('request.jwt.claim.sub','71000000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claim.role','authenticated',true);
select is((select count(*)::integer from generate_series(1,1500) where pg_temp.send_quota_event()->>'status'='acked'),1500,'1500 attempts including replay are allowed');
select is(pg_temp.send_quota_event('72000000-0000-4000-8000-000000000002')->>'code','RATE_LIMITED','direct RPC attempt 1501 is limited');
select is((select count(*)::integer from public.event_inbox),1,'limited attempt does not write inbox');
select is((select count(*)::integer from public.water_logs),1,'replay and quota rejection do not duplicate domain data');
reset role;
select is((select event_count from private.sync_rate_windows where owner_id='71000000-0000-4000-8000-000000000001' and window_start=date_trunc('minute',now())),1501,'event budget is stored and capped');
select is((select request_count from private.sync_rate_windows where owner_id='71000000-0000-4000-8000-000000000001' and window_start=date_trunc('minute',now())),0,'direct RPC does not consume batch quota');
select ok(not has_function_privilege('authenticated','matlogg_internal.apply_sync_event_unthrottled_v1(uuid,uuid,text,timestamptz,uuid,integer,jsonb)','EXECUTE'),'authenticated cannot bypass quota implementation');
select ok(not has_function_privilege('anon','matlogg_internal.apply_sync_event_v1(uuid,uuid,text,timestamptz,uuid,integer,jsonb)','EXECUTE'),'anon cannot call protected implementation');
-- A different owner has an independent budget; the original owner's row remains protected.
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"71000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select set_config('request.jwt.claim.sub','71000000-0000-4000-8000-000000000002',true);
select is(pg_temp.send_quota_event('72000000-0000-4000-8000-000000000003')->>'code','FORBIDDEN','another owner is not rate limited but cannot overwrite domain row');
reset role;
select is((select event_count from private.sync_rate_windows where owner_id='71000000-0000-4000-8000-000000000002'),1,'budget owner is derived from JWT');
-- Move the old window aside to simulate a fresh minute without sleeping or changing production limits.
update private.sync_rate_windows set window_start=window_start-interval '1 minute' where owner_id='71000000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"71000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select set_config('request.jwt.claim.sub','71000000-0000-4000-8000-000000000001',true);
select is(pg_temp.send_quota_event('72000000-0000-4000-8000-000000000002')->>'status','acked','same rejected event succeeds in a fresh window');
reset role;
update public.app_config set value='false'::jsonb where key='sync_enabled';
set local role authenticated;
select is(pg_temp.send_quota_event('72000000-0000-4000-8000-000000000004')->>'code','SYNC_DISABLED','kill switch remains effective');
reset role;
select is((select event_count from private.sync_rate_windows where owner_id='71000000-0000-4000-8000-000000000001' and window_start=date_trunc('minute',now())),1,'disabled sync consumes no event credit');
select is((select count(*)::integer from public.event_inbox where owner_id='71000000-0000-4000-8000-000000000001'),2,'successful retry writes exactly one new inbox entry');
select * from finish();
rollback;
