create extension if not exists pgcrypto with schema extensions;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  deletion_requested_at timestamptz,
  purge_at timestamptz,
  constraint profiles_deletion_dates_check check (
    (deletion_requested_at is null and purge_at is null)
    or (deletion_requested_at is not null and purge_at >= deletion_requested_at)
  )
);

create table public.event_inbox (
  event_id uuid primary key,
  owner_id uuid not null references auth.users(id) on delete cascade,
  device_id uuid not null,
  type text not null,
  created_at timestamptz not null,
  schema_version integer not null,
  payload_json jsonb not null,
  received_at timestamptz not null default now()
);
create index event_inbox_owner_received_idx on public.event_inbox(owner_id, received_at desc);

create table public.food_logs (
  id uuid primary key,
  owner_id uuid not null references auth.users(id) on delete cascade,
  date timestamptz not null,
  meal text not null,
  amount double precision not null check (amount > 0),
  unit text not null default 'g' check (unit in ('g', 'ml')),
  kcal double precision not null check (kcal >= 0),
  protein double precision not null check (protein >= 0),
  carbs double precision not null check (carbs >= 0),
  fat double precision not null check (fat >= 0),
  product_ref uuid,
  updated_at timestamptz not null default now()
);
create index food_logs_owner_date_idx on public.food_logs(owner_id, date desc);

create table public.goals (
  owner_id uuid primary key references auth.users(id) on delete cascade,
  kcal_target integer not null check (kcal_target > 0),
  protein_target double precision not null check (protein_target >= 0),
  carb_target double precision not null check (carb_target >= 0),
  fat_target double precision not null check (fat_target >= 0),
  updated_at timestamptz not null default now()
);

create table public.favorites (
  owner_id uuid not null references auth.users(id) on delete cascade,
  product_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (owner_id, product_id)
);

create table public.weights (
  id uuid primary key,
  owner_id uuid not null references auth.users(id) on delete cascade,
  date timestamptz not null,
  weight_kg double precision not null check (weight_kg > 0),
  created_at timestamptz not null default now()
);
create index weights_owner_date_idx on public.weights(owner_id, date desc);

create table public.products (
  id uuid primary key,
  owner_id uuid references auth.users(id) on delete set null,
  name text not null check (length(btrim(name)) > 0),
  brand text,
  barcode text,
  nutrients_per_100g jsonb not null,
  image_url text,
  source text not null check (length(btrim(source)) > 0),
  updated_at timestamptz not null default now()
);
create index products_owner_idx on public.products(owner_id) where owner_id is not null;
create index products_barcode_idx on public.products(barcode) where barcode is not null;

create table public.saved_meals (
  id uuid primary key,
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (length(btrim(name)) between 1 and 80),
  suggested_meal_type text check (suggested_meal_type in ('frokost', 'lunsj', 'middag', 'snacks')),
  updated_at timestamptz not null
);
create index saved_meals_owner_updated_idx on public.saved_meals(owner_id, updated_at desc);

create table public.saved_meal_items (
  id uuid primary key,
  saved_meal_id uuid not null references public.saved_meals(id) on delete cascade,
  product_id uuid not null,
  product_name text not null check (length(btrim(product_name)) between 1 and 200),
  amount double precision not null check (amount > 0 and amount <= 10000),
  unit text not null default 'g' check (unit in ('g', 'ml')),
  kcal double precision not null check (kcal >= 0),
  protein double precision not null check (protein >= 0),
  carbs double precision not null check (carbs >= 0),
  fat double precision not null check (fat >= 0),
  nutrition_source text not null check (nutrition_source in ('matvaretabellen', 'openFoodFacts', 'user')),
  sort_index integer not null check (sort_index >= 0)
);
create index saved_meal_items_meal_sort_idx on public.saved_meal_items(saved_meal_id, sort_index);

create table public.app_config (
  key text primary key,
  value jsonb not null,
  updated_at timestamptz not null default now()
);

create table private.sync_rate_windows (
  owner_id uuid not null,
  window_start timestamptz not null,
  request_count integer not null check (request_count >= 0),
  primary key (owner_id, window_start)
);

create or replace function private.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles(id) values (new.id) on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function private.handle_new_auth_user();

alter table public.profiles enable row level security;
alter table public.event_inbox enable row level security;
alter table public.food_logs enable row level security;
alter table public.goals enable row level security;
alter table public.favorites enable row level security;
alter table public.weights enable row level security;
alter table public.products enable row level security;
alter table public.saved_meals enable row level security;
alter table public.saved_meal_items enable row level security;
alter table public.app_config enable row level security;

create policy profiles_select_own on public.profiles for select to authenticated
  using ((select auth.uid()) = id);
create policy inbox_select_own on public.event_inbox for select to authenticated
  using ((select auth.uid()) = owner_id);
create policy logs_select_own on public.food_logs for select to authenticated
  using ((select auth.uid()) = owner_id);
create policy goals_select_own on public.goals for select to authenticated
  using ((select auth.uid()) = owner_id);
create policy favorites_select_own on public.favorites for select to authenticated
  using ((select auth.uid()) = owner_id);
create policy weights_select_own on public.weights for select to authenticated
  using ((select auth.uid()) = owner_id);
create policy products_select_own on public.products for select to authenticated
  using ((select auth.uid()) = owner_id);
create policy saved_meals_select_own on public.saved_meals for select to authenticated
  using ((select auth.uid()) = owner_id);
create policy saved_meal_items_select_own on public.saved_meal_items for select to authenticated
  using (exists (
    select 1 from public.saved_meals meal
    where meal.id = saved_meal_id and meal.owner_id = (select auth.uid())
  ));

revoke all on all tables in schema public from anon, authenticated;
grant select on public.profiles, public.event_inbox, public.food_logs, public.goals,
  public.favorites, public.weights, public.products, public.saved_meals,
  public.saved_meal_items to authenticated;

create or replace function public.is_sync_enabled()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select value = 'true'::jsonb from public.app_config where key = 'sync_enabled'), false)
$$;

create or replace function public.consume_sync_quota_v1(p_owner_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_window timestamptz := date_trunc('minute', now());
  v_count integer;
begin
  if coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then
    raise exception 'service role required' using errcode = '42501';
  end if;

  insert into private.sync_rate_windows(owner_id, window_start, request_count)
  values (p_owner_id, v_window, 1)
  on conflict (owner_id, window_start)
  do update set request_count = private.sync_rate_windows.request_count + 1
  returning request_count into v_count;

  delete from private.sync_rate_windows where window_start < now() - interval '2 hours';
  return v_count <= 30;
end;
$$;

create or replace function public.apply_sync_event_v1(
  p_device_id uuid,
  p_event_id uuid,
  p_type text,
  p_created_at timestamptz,
  p_entity_id uuid,
  p_schema_version integer,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_owner uuid := auth.uid();
  v_existing_owner uuid;
  v_meal_id uuid;
  v_item jsonb;
begin
  perform p_entity_id;
  if v_owner is null then
    return jsonb_build_object('status', 'rejected', 'code', 'UNAUTHORIZED', 'message', 'Mangler gyldig bruker');
  end if;
  if not exists (select 1 from public.profiles where id = v_owner and deletion_requested_at is null) then
    return jsonb_build_object('status', 'rejected', 'code', 'ACCOUNT_DELETED', 'message', 'Kontoen er deaktivert');
  end if;
  if p_schema_version <> 1 then
    return jsonb_build_object('status', 'rejected', 'code', 'UNSUPPORTED_SCHEMA', 'message', 'Ukjent schema-versjon');
  end if;
  if p_type not in ('log.create', 'log.update', 'log.upsert', 'log.delete', 'goal.set',
    'favorite.add', 'favorite.remove', 'weight.add', 'weight.upsert', 'weight.delete',
    'product.upsert', 'saved_meal.upsert', 'saved_meal.delete') then
    return jsonb_build_object('status', 'rejected', 'code', 'UNSUPPORTED_TYPE', 'message', 'Ukjent type');
  end if;
  if jsonb_typeof(p_payload) <> 'object'
      or octet_length(convert_to(p_payload::text, 'UTF8')) > 65536 then
    return jsonb_build_object('status', 'rejected', 'code', 'VALIDATION_ERROR', 'message', 'Ugyldig hendelsespayload');
  end if;
  if p_entity_id is not null
      and p_type in ('log.create', 'log.update', 'log.upsert', 'log.delete',
        'weight.add', 'weight.upsert', 'weight.delete', 'product.upsert',
        'saved_meal.upsert', 'saved_meal.delete')
      and p_entity_id is distinct from nullif(p_payload->>'id', '')::uuid then
    return jsonb_build_object('status', 'rejected', 'code', 'VALIDATION_ERROR', 'message', 'entityId samsvarer ikke med payload');
  end if;

  select owner_id into v_existing_owner from public.event_inbox where event_id = p_event_id;
  if found then
    if v_existing_owner = v_owner then
      return jsonb_build_object('status', 'acked');
    end if;
    return jsonb_build_object('status', 'rejected', 'code', 'FORBIDDEN', 'message', 'Hendelsen tilhører en annen bruker');
  end if;

  if p_type in ('log.create', 'log.update', 'log.upsert', 'log.delete') then
    select owner_id into v_existing_owner from public.food_logs where id = (p_payload->>'id')::uuid;
    if found and v_existing_owner <> v_owner then
      return jsonb_build_object('status', 'rejected', 'code', 'FORBIDDEN', 'message', 'Loggen tilhører en annen bruker');
    end if;
  elsif p_type in ('weight.add', 'weight.upsert', 'weight.delete') then
    select owner_id into v_existing_owner from public.weights where id = (p_payload->>'id')::uuid;
    if found and v_existing_owner <> v_owner then
      return jsonb_build_object('status', 'rejected', 'code', 'FORBIDDEN', 'message', 'Vektregistreringen tilhører en annen bruker');
    end if;
  elsif p_type = 'product.upsert' then
    select owner_id into v_existing_owner from public.products where id = (p_payload->>'id')::uuid;
    if found and v_existing_owner is distinct from v_owner then
      return jsonb_build_object('status', 'rejected', 'code', 'FORBIDDEN', 'message', 'Produktet kan ikke endres av denne brukeren');
    end if;
  elsif p_type in ('saved_meal.upsert', 'saved_meal.delete') then
    select owner_id into v_existing_owner from public.saved_meals where id = (p_payload->>'id')::uuid;
    if found and v_existing_owner <> v_owner then
      return jsonb_build_object('status', 'rejected', 'code', 'FORBIDDEN', 'message', 'Det lagrede måltidet tilhører en annen bruker');
    end if;
  end if;

  insert into public.event_inbox(event_id, owner_id, device_id, type, created_at, schema_version, payload_json)
  values (p_event_id, v_owner, p_device_id, p_type, p_created_at, p_schema_version, p_payload);

  if p_type in ('log.create', 'log.update', 'log.upsert') then
    insert into public.food_logs(id, owner_id, date, meal, amount, unit, kcal, protein, carbs, fat, product_ref, updated_at)
    values ((p_payload->>'id')::uuid, v_owner, (p_payload->>'date')::timestamptz, p_payload->>'meal',
      (p_payload->>'grams')::double precision, coalesce(p_payload->>'unit', 'g'),
      (p_payload->>'kcal')::double precision, (p_payload->>'protein')::double precision,
      (p_payload->>'carbs')::double precision, (p_payload->>'fat')::double precision,
      nullif(p_payload->>'productRef', '')::uuid, now())
    on conflict (id) do update set date = excluded.date, meal = excluded.meal, amount = excluded.amount,
      unit = excluded.unit, kcal = excluded.kcal, protein = excluded.protein, carbs = excluded.carbs,
      fat = excluded.fat, product_ref = excluded.product_ref, updated_at = now()
    where public.food_logs.owner_id = v_owner;
  elsif p_type = 'log.delete' then
    delete from public.food_logs where id = (p_payload->>'id')::uuid and owner_id = v_owner;
  elsif p_type = 'goal.set' then
    insert into public.goals(owner_id, kcal_target, protein_target, carb_target, fat_target, updated_at)
    values (v_owner, round((p_payload->>'kcalTarget')::numeric), (p_payload->>'proteinTarget')::double precision,
      (p_payload->>'carbTarget')::double precision, (p_payload->>'fatTarget')::double precision, now())
    on conflict (owner_id) do update set kcal_target = excluded.kcal_target,
      protein_target = excluded.protein_target, carb_target = excluded.carb_target,
      fat_target = excluded.fat_target, updated_at = now();
  elsif p_type = 'favorite.add' then
    insert into public.favorites(owner_id, product_id) values (v_owner, (p_payload->>'productId')::uuid)
    on conflict do nothing;
  elsif p_type = 'favorite.remove' then
    delete from public.favorites where owner_id = v_owner and product_id = (p_payload->>'productId')::uuid;
  elsif p_type in ('weight.add', 'weight.upsert') then
    insert into public.weights(id, owner_id, date, weight_kg)
    values ((p_payload->>'id')::uuid, v_owner, (p_payload->>'date')::timestamptz, (p_payload->>'weightKg')::double precision)
    on conflict (id) do update set date = excluded.date, weight_kg = excluded.weight_kg
    where public.weights.owner_id = v_owner;
  elsif p_type = 'weight.delete' then
    delete from public.weights where id = (p_payload->>'id')::uuid and owner_id = v_owner;
  elsif p_type = 'product.upsert' then
    insert into public.products(id, owner_id, name, brand, barcode, nutrients_per_100g, image_url, source, updated_at)
    values ((p_payload->>'id')::uuid, v_owner, p_payload->>'name', p_payload->>'brand', p_payload->>'barcode',
      p_payload->'nutrientsPer100g', p_payload->>'imageUrl', p_payload->>'source', now())
    on conflict (id) do update set name = excluded.name, brand = excluded.brand, barcode = excluded.barcode,
      nutrients_per_100g = excluded.nutrients_per_100g, image_url = excluded.image_url,
      source = excluded.source, updated_at = now()
    where public.products.owner_id = v_owner;
  elsif p_type = 'saved_meal.upsert' then
    v_meal_id := (p_payload->>'id')::uuid;
    insert into public.saved_meals(id, owner_id, name, suggested_meal_type, updated_at)
    values (v_meal_id, v_owner, btrim(p_payload->>'name'), p_payload->>'suggestedMealType',
      (p_payload->>'updatedAt')::timestamptz)
    on conflict (id) do update set name = excluded.name, suggested_meal_type = excluded.suggested_meal_type,
      updated_at = excluded.updated_at where public.saved_meals.owner_id = v_owner;
    delete from public.saved_meal_items where saved_meal_id = v_meal_id;
    for v_item in select value from jsonb_array_elements(p_payload->'items') loop
      insert into public.saved_meal_items(id, saved_meal_id, product_id, product_name, amount, unit,
        kcal, protein, carbs, fat, nutrition_source, sort_index)
      values ((v_item->>'id')::uuid, v_meal_id, (v_item->>'productId')::uuid, v_item->>'productName',
        (v_item->>'amountG')::double precision, coalesce(v_item->>'amountUnit', 'g'),
        (v_item->>'calories')::double precision, (v_item->>'protein')::double precision,
        (v_item->>'carbs')::double precision, (v_item->>'fat')::double precision,
        v_item->>'nutritionSource', (v_item->>'sortIndex')::integer);
    end loop;
  elsif p_type = 'saved_meal.delete' then
    delete from public.saved_meals where id = (p_payload->>'id')::uuid and owner_id = v_owner;
  end if;

  return jsonb_build_object('status', 'acked');
exception
  when unique_violation then
    select owner_id into v_existing_owner from public.event_inbox where event_id = p_event_id;
    if v_existing_owner = v_owner then
      return jsonb_build_object('status', 'acked');
    end if;
    return jsonb_build_object('status', 'rejected', 'code', 'FORBIDDEN', 'message', 'Ressursen tilhører en annen bruker');
  when check_violation or not_null_violation or invalid_text_representation or datetime_field_overflow then
    return jsonb_build_object('status', 'rejected', 'code', 'VALIDATION_ERROR', 'message', 'Ugyldig hendelsespayload');
end;
$$;

create or replace function public.request_account_deletion_admin_v1(p_owner_id uuid)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare v_purge_at timestamptz := now() + interval '30 days';
begin
  if coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then
    raise exception 'service role required' using errcode = '42501';
  end if;
  update public.profiles set deletion_requested_at = now(), purge_at = v_purge_at where id = p_owner_id;
  if not found then raise exception 'profile not found'; end if;
  return v_purge_at;
end;
$$;

create or replace function public.cancel_account_deletion_admin_v1(p_owner_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then
    raise exception 'service role required' using errcode = '42501';
  end if;
  update public.profiles set deletion_requested_at = null, purge_at = null where id = p_owner_id;
end;
$$;

create or replace function public.due_account_purges_v1()
returns table(owner_id uuid)
language sql
security definer
set search_path = ''
as $$
  select id from public.profiles
  where purge_at is not null and purge_at <= now()
    and coalesce(auth.jwt() ->> 'role', '') = 'service_role'
$$;

create or replace function public.purge_account_data_admin_v1(p_owner_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then
    raise exception 'service role required' using errcode = '42501';
  end if;
  if not exists (select 1 from public.profiles where id = p_owner_id and purge_at <= now()) then
    raise exception 'account is not due for purge';
  end if;
  update public.products set owner_id = null where owner_id = p_owner_id;
  delete from public.event_inbox where owner_id = p_owner_id;
  delete from public.food_logs where owner_id = p_owner_id;
  delete from public.goals where owner_id = p_owner_id;
  delete from public.favorites where owner_id = p_owner_id;
  delete from public.weights where owner_id = p_owner_id;
  delete from public.saved_meals where owner_id = p_owner_id;
end;
$$;

revoke all on function public.is_sync_enabled() from public, anon, authenticated;

insert into public.app_config (key, value)
values ('sync_enabled', 'false'::jsonb)
on conflict (key) do update set value = excluded.value;
revoke all on function public.consume_sync_quota_v1(uuid) from public, anon, authenticated;
revoke all on function public.apply_sync_event_v1(uuid, uuid, text, timestamptz, uuid, integer, jsonb) from public, anon;
revoke all on function public.request_account_deletion_admin_v1(uuid) from public, anon, authenticated;
revoke all on function public.cancel_account_deletion_admin_v1(uuid) from public, anon, authenticated;
revoke all on function public.due_account_purges_v1() from public, anon, authenticated;
revoke all on function public.purge_account_data_admin_v1(uuid) from public, anon, authenticated;
grant execute on function public.is_sync_enabled() to service_role;
grant execute on function public.consume_sync_quota_v1(uuid) to service_role;
grant execute on function public.apply_sync_event_v1(uuid, uuid, text, timestamptz, uuid, integer, jsonb) to authenticated;
grant execute on function public.request_account_deletion_admin_v1(uuid) to service_role;
grant execute on function public.cancel_account_deletion_admin_v1(uuid) to service_role;
grant execute on function public.due_account_purges_v1() to service_role;
grant execute on function public.purge_account_data_admin_v1(uuid) to service_role;
