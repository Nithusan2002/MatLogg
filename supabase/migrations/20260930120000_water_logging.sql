-- One row per glass. Profile deletion cascades to water history.
create table public.water_logs (
  id uuid primary key,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  date timestamptz not null,
  created_at timestamptz not null
);
create index water_logs_owner_date_idx on public.water_logs(owner_id, date);
alter table public.water_logs enable row level security;
create policy water_logs_select_own on public.water_logs for select to authenticated
  using (owner_id = (select auth.uid()));
revoke all on public.water_logs from anon, authenticated;
grant select on public.water_logs to authenticated;

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
    'product.upsert', 'saved_meal.upsert', 'saved_meal.delete', 'water.upsert', 'water.delete') then
    return jsonb_build_object('status', 'rejected', 'code', 'UNSUPPORTED_TYPE', 'message', 'Ukjent type');
  end if;
  if jsonb_typeof(p_payload) <> 'object'
      or octet_length(convert_to(p_payload::text, 'UTF8')) > 65536 then
    return jsonb_build_object('status', 'rejected', 'code', 'VALIDATION_ERROR', 'message', 'Ugyldig hendelsespayload');
  end if;
  if p_entity_id is not null
      and p_type in ('log.create', 'log.update', 'log.upsert', 'log.delete',
        'weight.add', 'weight.upsert', 'weight.delete', 'product.upsert',
        'saved_meal.upsert', 'saved_meal.delete', 'water.upsert', 'water.delete')
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
  elsif p_type in ('water.upsert', 'water.delete') then
    select owner_id into v_existing_owner from public.water_logs where id = (p_payload->>'id')::uuid;
    if found and v_existing_owner <> v_owner then
      return jsonb_build_object('status', 'rejected', 'code', 'FORBIDDEN', 'message', 'Vannregistreringen tilhører en annen bruker');
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
  elsif p_type = 'water.upsert' then
    insert into public.water_logs(id, owner_id, date, created_at)
    values ((p_payload->>'id')::uuid, v_owner, (p_payload->>'date')::timestamptz, (p_payload->>'createdAt')::timestamptz)
    on conflict(id) do update set date = excluded.date, created_at = excluded.created_at
    where public.water_logs.owner_id = v_owner;
  elsif p_type = 'water.delete' then
    delete from public.water_logs where id = (p_payload->>'id')::uuid and owner_id = v_owner;
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
  delete from public.water_logs where owner_id = p_owner_id;
  delete from public.weights where owner_id = p_owner_id;
  delete from public.saved_meals where owner_id = p_owner_id;
end;
$$;
