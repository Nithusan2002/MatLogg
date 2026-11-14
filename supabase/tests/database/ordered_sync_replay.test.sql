-- Client delivery must serialize each resource; ACK replay must preserve the latest applied state.
begin;
create extension if not exists pgtap with schema extensions;
update public.app_config set value = 'true'::jsonb where key = 'sync_enabled';
select plan(8);
insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values ('00000000-0000-0000-0000-000000000000', '71000000-0000-4000-8000-000000000001',
  'authenticated', 'authenticated', 'ordered-sync@example.test', '', now(), now(), now());
set local role authenticated;
select set_config('request.jwt.claim.sub', '71000000-0000-4000-8000-000000000001', true);
select set_config('request.jwt.claims', '{"sub":"71000000-0000-4000-8000-000000000001","role":"authenticated"}', true);

select is(public.apply_sync_event_v1('71000000-0000-4000-8000-000000000002',
  '71000000-0000-4000-8000-000000000003', 'log.upsert', now(), '71000000-0000-4000-8000-000000000004', 1,
  '{"id":"71000000-0000-4000-8000-000000000004","date":"2026-11-06T10:00:00Z","meal":"lunsj","grams":100,"kcal":100,"protein":1,"carbs":2,"fat":3}'::jsonb)->>'status',
  'acked', 'first write is committed before its successor');
select is(public.apply_sync_event_v1('71000000-0000-4000-8000-000000000002',
  '71000000-0000-4000-8000-000000000005', 'log.upsert', now(), '71000000-0000-4000-8000-000000000004', 1,
  '{"id":"71000000-0000-4000-8000-000000000004","date":"2026-11-06T10:00:00Z","meal":"lunsj","grams":200,"kcal":200,"protein":1,"carbs":2,"fat":3}'::jsonb)->>'status',
  'acked', 'later edit is committed');
select is(public.apply_sync_event_v1('71000000-0000-4000-8000-000000000002',
  '71000000-0000-4000-8000-000000000003', 'log.upsert', now(), '71000000-0000-4000-8000-000000000004', 1,
  '{"id":"71000000-0000-4000-8000-000000000004","date":"2026-11-06T10:00:00Z","meal":"lunsj","grams":100,"kcal":100,"protein":1,"carbs":2,"fat":3}'::jsonb)->>'status',
  'acked', 'lost ACK replay is acknowledged without reapplying an older write');
select is((select amount from public.food_logs where id='71000000-0000-4000-8000-000000000004'),
  200::double precision, 'older replay does not replace the latest amount');
select is(public.apply_sync_event_v1('71000000-0000-4000-8000-000000000002',
  '71000000-0000-4000-8000-000000000006', 'log.delete', now(), '71000000-0000-4000-8000-000000000004', 1,
  '{"id":"71000000-0000-4000-8000-000000000004"}'::jsonb)->>'status', 'acked', 'delete follows the acknowledged edits');
select is(public.apply_sync_event_v1('71000000-0000-4000-8000-000000000002',
  '71000000-0000-4000-8000-000000000005', 'log.upsert', now(), '71000000-0000-4000-8000-000000000004', 1,
  '{"id":"71000000-0000-4000-8000-000000000004","date":"2026-11-06T10:00:00Z","meal":"lunsj","grams":200,"kcal":200,"protein":1,"carbs":2,"fat":3}'::jsonb)->>'status',
  'acked', 'replay after delete remains idempotent');
select is((select count(*)::integer from public.food_logs where id='71000000-0000-4000-8000-000000000004'),
  0, 'committed deletion is not resurrected by replay');
select is((select count(*)::integer from public.event_inbox where owner_id='71000000-0000-4000-8000-000000000001'),
  3, 'only three distinct events are registered');
select * from finish();
rollback;
