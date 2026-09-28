begin;
select plan(15);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at
) values
  ('00000000-0000-0000-0000-000000000000', '10000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'one@example.test', '', now(), now(), now()),
  ('00000000-0000-0000-0000-000000000000', '20000000-0000-4000-8000-000000000002', 'authenticated', 'authenticated', 'two@example.test', '', now(), now(), now());

select is((select count(*)::integer from public.profiles where id in (
  '10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000002'
)), 2, 'auth trigger creates profiles');

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated"}', true);

select is(
  public.apply_sync_event_v1(
    '30000000-0000-4000-8000-000000000003',
    '31000000-0000-4000-8000-000000000003',
    'log.delete', now(),
    '32000000-0000-4000-8000-000000000003', 1,
    '{"id":"33000000-0000-4000-8000-000000000003"}'::jsonb
  )->>'code',
  'VALIDATION_ERROR',
  'entity id must match an entity payload'
);

select is(
  public.apply_sync_event_v1(
    '30000000-0000-4000-8000-000000000003',
    '34000000-0000-4000-8000-000000000003',
    'goal.set', now(), null, 1,
    jsonb_build_object('padding', repeat('x', 66000))
  )->>'code',
  'VALIDATION_ERROR',
  'RPC rejects oversized payloads even when called directly'
);

select is(
  public.apply_sync_event_v1(
    '30000000-0000-4000-8000-000000000003',
    '40000000-0000-4000-8000-000000000004',
    'log.upsert', now(),
    '50000000-0000-4000-8000-000000000005', 1,
    jsonb_build_object(
      'id', '50000000-0000-4000-8000-000000000005',
      'date', now(), 'meal', 'lunsj', 'grams', 100, 'unit', 'g',
      'kcal', 100, 'protein', 10, 'carbs', 12, 'fat', 2
    )
  )->>'status',
  'acked',
  'owner can apply a valid event'
);

reset role;
select is((select owner_id from public.food_logs where id = '50000000-0000-4000-8000-000000000005'),
  '10000000-0000-4000-8000-000000000001'::uuid, 'owner always comes from auth.uid');
select is((select count(*)::integer from public.event_inbox where event_id = '40000000-0000-4000-8000-000000000004'),
  1, 'event and domain row are written together');

set local role authenticated;
select set_config('request.jwt.claim.sub', '20000000-0000-4000-8000-000000000002', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claims', '{"sub":"20000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
select is(
  public.apply_sync_event_v1(
    '30000000-0000-4000-8000-000000000003',
    '40000000-0000-4000-8000-000000000004',
    'log.delete', now(),
    '50000000-0000-4000-8000-000000000005', 1,
    '{"id":"50000000-0000-4000-8000-000000000005"}'::jsonb
  )->>'code',
  'FORBIDDEN',
  'global event replay is rejected across owners'
);

select is(
  public.apply_sync_event_v1(
    '30000000-0000-4000-8000-000000000003',
    '60000000-0000-4000-8000-000000000006',
    'log.delete', now(),
    '50000000-0000-4000-8000-000000000005', 1,
    '{"id":"50000000-0000-4000-8000-000000000005"}'::jsonb
  )->>'code',
  'FORBIDDEN',
  'entity mutation is rejected across owners'
);

select throws_ok(
  $$insert into public.favorites(owner_id, product_id) values (
    '20000000-0000-4000-8000-000000000002', '70000000-0000-4000-8000-000000000007'
  )$$,
  '42501',
  'permission denied for table favorites',
  'authenticated clients cannot write domain tables directly'
);

select is((select count(*)::integer from public.food_logs), 0, 'RLS only reveals rows owned by the active user');
reset role;

insert into public.products(id, owner_id, name, nutrients_per_100g, source)
values ('80000000-0000-4000-8000-000000000008', '10000000-0000-4000-8000-000000000001', 'Test', '{}'::jsonb, 'user');
update public.profiles
set deletion_requested_at = now() - interval '31 days', purge_at = now() - interval '1 day'
where id = '10000000-0000-4000-8000-000000000001';

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select is(
  public.apply_sync_event_v1(
    '30000000-0000-4000-8000-000000000003',
    '90000000-0000-4000-8000-000000000009',
    'weight.delete', now(),
    'a0000000-0000-4000-8000-00000000000a', 1,
    '{"id":"a0000000-0000-4000-8000-00000000000a"}'::jsonb
  )->>'code',
  'ACCOUNT_DELETED',
  'deletion request blocks sync immediately'
);
reset role;

set local role service_role;
select set_config('request.jwt.claim.role', 'service_role', true);
select set_config('request.jwt.claims', '{"role":"service_role"}', true);
select lives_ok(
  $$select public.purge_account_data_admin_v1('10000000-0000-4000-8000-000000000001')$$,
  'due account purge is idempotent at the data boundary'
);
reset role;

select is((select count(*)::integer from public.food_logs where owner_id = '10000000-0000-4000-8000-000000000001'),
  0, 'purge removes personal domain data');
select is((select owner_id from public.products where id = '80000000-0000-4000-8000-000000000008'),
  null::uuid, 'purge anonymizes contributed products');
select is((select count(*)::integer from public.event_inbox where owner_id = '10000000-0000-4000-8000-000000000001'),
  0, 'purge removes inbox events');

select * from finish();
rollback;
