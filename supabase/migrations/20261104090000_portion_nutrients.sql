create function matlogg_internal.valid_portion_nutrients(snapshot jsonb)
returns boolean language sql immutable set search_path = '' as $$
  select case
    when snapshot is null then true
    when jsonb_typeof(snapshot) <> 'object' then false
    else not exists (
      select 1 from jsonb_each(snapshot) as nutrient
      where nutrient.key not in ('fiber', 'vitaminD', 'vitaminB12', 'folate', 'vitaminC')
        or case when jsonb_typeof(nutrient.value) = 'number' then
          (nutrient.value #>> '{}')::numeric not between 0 and 1.7976931348623157e308::numeric
        else true end
    )
  end;
$$;
revoke all on function matlogg_internal.valid_portion_nutrients(jsonb) from public;

alter table public.food_logs add column nutrients jsonb;
alter table public.saved_meal_items add column nutrients jsonb;

-- Keep nutrient snapshots inside the existing inbox and ownership transaction.
do $migration$
declare
  definition text;
  previous text;
begin
  select pg_get_functiondef(
    'matlogg_internal.apply_sync_event_unthrottled_v1(uuid,uuid,text,timestamptz,uuid,integer,jsonb)'::regprocedure
  ) into definition;

  previous := definition;
  definition := replace(definition, 'product_ref, portion_selection, nutrition_preparation, updated_at)',
    'product_ref, portion_selection, nutrition_preparation, nutrients, updated_at)');
  if definition = previous then raise exception 'Missing food log column anchor'; end if;

  previous := definition;
  definition := replace(definition, $old$coalesce(p_payload->>'nutritionPreparation', 'as_sold'), now())$old$,
    $new$coalesce(p_payload->>'nutritionPreparation', 'as_sold'), p_payload->'nutrients', now())$new$);
  if definition = previous then raise exception 'Missing food log value anchor'; end if;

  previous := definition;
  definition := replace(definition, 'fat = excluded.fat, product_ref = excluded.product_ref,',
    'fat = excluded.fat, product_ref = excluded.product_ref, nutrients = excluded.nutrients,');
  if definition = previous then raise exception 'Missing food log update anchor'; end if;

  previous := definition;
  definition := replace(definition, 'nutrition_source, sort_index, portion_selection, nutrition_preparation)',
    'nutrition_source, sort_index, portion_selection, nutrition_preparation, nutrients)');
  if definition = previous then raise exception 'Missing saved meal column anchor'; end if;

  previous := definition;
  definition := replace(definition, $old$->>'preparation' end, 'as_sold'));$old$,
    $new$->>'preparation' end, 'as_sold'), v_item->'nutrients');$new$);
  if definition = previous then raise exception 'Missing saved meal value anchor'; end if;

  previous := definition;
  definition := replace(definition,
    $old$  if p_type in ('log.create', 'log.update', 'log.upsert', 'log.delete') then$old$,
    $new$  if p_type in ('log.create', 'log.update', 'log.upsert')
    and not matlogg_internal.valid_portion_nutrients(p_payload->'nutrients') then
    return jsonb_build_object('status', 'rejected', 'code', 'VALIDATION_ERROR', 'message', 'Ugyldige næringsverdier');
  end if;
  if p_type = 'saved_meal.upsert' and jsonb_typeof(p_payload->'items') = 'array' then
    if exists (
      select 1 from jsonb_array_elements(p_payload->'items') as item
      where not matlogg_internal.valid_portion_nutrients(item->'nutrients')
    ) then
      return jsonb_build_object('status', 'rejected', 'code', 'VALIDATION_ERROR', 'message', 'Ugyldige næringsverdier');
    end if;
  end if;
  if p_type in ('log.create', 'log.update', 'log.upsert', 'log.delete') then$new$);
  if definition = previous then raise exception 'Missing nutrient validation anchor'; end if;

  execute definition;
end;
$migration$;
