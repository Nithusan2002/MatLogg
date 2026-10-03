-- Additive product metadata. Existing authentication, ownership and atomic inbox writes are retained.
alter table public.products
  add column nutrition_basis text not null default 'per100g' check (nutrition_basis in ('per100g', 'per100ml')),
  add column servings jsonb,
  add column manual_nutrition_input jsonb;

-- Patch only product persistence, preserving any existing RPC safeguards and other event branches.
do $migration$
declare
  definition text;
  updated_definition text;
begin
  select pg_get_functiondef('public.apply_sync_event_v1(uuid,uuid,text,timestamptz,uuid,integer,jsonb)'::regprocedure) into definition;
  updated_definition := replace(definition, $old$  elsif p_type = 'product.upsert' then
    insert into public.products(id, owner_id, name, brand, barcode, nutrients_per_100g, image_url, source, updated_at)
    values ((p_payload->>'id')::uuid, v_owner, p_payload->>'name', p_payload->>'brand', p_payload->>'barcode',
      p_payload->'nutrientsPer100g', p_payload->>'imageUrl', p_payload->>'source', now())
    on conflict (id) do update set name = excluded.name, brand = excluded.brand, barcode = excluded.barcode,
      nutrients_per_100g = excluded.nutrients_per_100g, image_url = excluded.image_url,
      source = excluded.source, updated_at = now()
    where public.products.owner_id = v_owner;
$old$, $new$  elsif p_type = 'product.upsert' then
    insert into public.products(id, owner_id, name, brand, barcode, nutrients_per_100g, image_url, source, updated_at, nutrition_basis, servings, manual_nutrition_input)
    values ((p_payload->>'id')::uuid, v_owner, p_payload->>'name', p_payload->>'brand', p_payload->>'barcode',
      p_payload->'nutrientsPer100g', p_payload->>'imageUrl', p_payload->>'source', now(), coalesce(p_payload->>'nutritionBasis', 'per100g'),
      p_payload->'servings', p_payload->'manualNutritionInput')
    on conflict (id) do update set name = excluded.name, brand = excluded.brand, barcode = excluded.barcode,
      nutrients_per_100g = excluded.nutrients_per_100g, image_url = excluded.image_url,
      source = excluded.source, updated_at = now(), nutrition_basis = case when p_payload ? 'nutritionBasis' then excluded.nutrition_basis else public.products.nutrition_basis end,
      servings = case when p_payload ? 'servings' then excluded.servings else public.products.servings end,
      manual_nutrition_input = case when p_payload ? 'manualNutritionInput' then excluded.manual_nutrition_input else public.products.manual_nutrition_input end
    where public.products.owner_id = v_owner;
$new$);
  if updated_definition = definition then
    raise exception 'Expected product persistence branch was not found';
  end if;
  execute updated_definition;
end;
$migration$;
