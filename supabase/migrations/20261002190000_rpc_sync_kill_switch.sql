-- Enforce the operational kill switch at the database write boundary as well.
-- Authentication, ownership rules and grants remain unchanged.
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
  v_old_items jsonb;
  v_portion jsonb;
begin
  if not public.is_sync_enabled() then
    return jsonb_build_object('status', 'rejected', 'code', 'SYNC_DISABLED', 'message', 'Synkronisering er midlertidig deaktivert');
  end if;
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
    insert into public.food_logs(id, owner_id, date, meal, amount, unit, kcal, protein, carbs, fat, product_ref, portion_selection, updated_at)
    values ((p_payload->>'id')::uuid, v_owner, (p_payload->>'date')::timestamptz, p_payload->>'meal',
      (p_payload->>'grams')::double precision, coalesce(p_payload->>'unit', 'g'),
      (p_payload->>'kcal')::double precision, (p_payload->>'protein')::double precision,
      (p_payload->>'carbs')::double precision, (p_payload->>'fat')::double precision,
      nullif(p_payload->>'productRef', '')::uuid, nullif(p_payload->'portionSelection', 'null'::jsonb), now())
    on conflict (id) do update set date = excluded.date, meal = excluded.meal, amount = excluded.amount,
      unit = excluded.unit, kcal = excluded.kcal, protein = excluded.protein, carbs = excluded.carbs,
      fat = excluded.fat, product_ref = excluded.product_ref,
      portion_selection = case
        when p_payload ? 'portionSelection' then excluded.portion_selection
        when public.food_logs.amount = excluded.amount and public.food_logs.unit = excluded.unit
          and public.food_logs.product_ref is not distinct from excluded.product_ref
          then public.food_logs.portion_selection
        else null end, updated_at = now()
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
    select coalesce(jsonb_object_agg(id::text, jsonb_build_object('productId', product_id,
      'amount', amount, 'unit', unit, 'portion', portion_selection)), '{}'::jsonb)
      into v_old_items from public.saved_meal_items where saved_meal_id = v_meal_id;
    delete from public.saved_meal_items where saved_meal_id = v_meal_id;
    for v_item in select value from jsonb_array_elements(p_payload->'items') loop
      v_portion := nullif(v_item->'portionSelection', 'null'::jsonb);
      if not (v_item ? 'portionSelection')
          and (v_old_items->(v_item->>'id')->>'productId')::uuid = (v_item->>'productId')::uuid
          and (v_old_items->(v_item->>'id')->>'amount')::double precision = (v_item->>'amountG')::double precision
          and v_old_items->(v_item->>'id')->>'unit' = coalesce(v_item->>'amountUnit', 'g') then
        v_portion := nullif(v_old_items->(v_item->>'id')->'portion', 'null'::jsonb);
      end if;
      insert into public.saved_meal_items(id, saved_meal_id, product_id, product_name, amount, unit,
        kcal, protein, carbs, fat, nutrition_source, sort_index, portion_selection)
      values ((v_item->>'id')::uuid, v_meal_id, (v_item->>'productId')::uuid, v_item->>'productName',
        (v_item->>'amountG')::double precision, coalesce(v_item->>'amountUnit', 'g'),
        (v_item->>'calories')::double precision, (v_item->>'protein')::double precision,
        (v_item->>'carbs')::double precision, (v_item->>'fat')::double precision,
        v_item->>'nutritionSource', (v_item->>'sortIndex')::integer, v_portion);
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
