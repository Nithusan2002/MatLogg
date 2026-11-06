-- Visual metadata only. Additive; no nutrition, ownership, RLS or upload-policy changes.
alter table public.products add column selected_food_group text
  check (selected_food_group in ('rice_pasta', 'bread', 'grain', 'meat', 'poultry', 'fish', 'egg',
    'dairy', 'cheese', 'oil_fat', 'fruit', 'vegetables', 'nuts', 'drinks', 'other'));

do $migration$
declare
  definition text;
  previous text;
begin
  select pg_get_functiondef('matlogg_internal.apply_sync_event_unthrottled_v1(uuid,uuid,text,timestamptz,uuid,integer,jsonb)'::regprocedure) into definition;
  previous := definition;
  definition := replace(definition,
    $old$  if p_type = 'product.upsert' then
    if jsonb_typeof(p_payload->'nutrientsPer100g')$old$,
    $new$  if p_type = 'product.upsert' then
    if p_payload ? 'selectedFoodGroup' and p_payload->'selectedFoodGroup' <> 'null'::jsonb then
      if jsonb_typeof(p_payload->'selectedFoodGroup') <> 'string'
        or p_payload->>'selectedFoodGroup' not in ('rice_pasta', 'bread', 'grain', 'meat', 'poultry', 'fish', 'egg',
          'dairy', 'cheese', 'oil_fat', 'fruit', 'vegetables', 'nuts', 'drinks', 'other') then
        return jsonb_build_object('status', 'rejected', 'code', 'VALIDATION_ERROR', 'message', 'Ugyldig matgruppe');
      end if;
    end if;
    if jsonb_typeof(p_payload->'nutrientsPer100g')$new$);
  if definition = previous then raise exception 'Food group validation anchor missing'; end if;
  previous := definition;
  definition := replace(definition,
    $old$manual_nutrition_input, nutrition_preparation)$old$,
    $new$manual_nutrition_input, nutrition_preparation, selected_food_group)$new$);
  if definition = previous then raise exception 'Food group insert columns anchor missing'; end if;
  previous := definition;
  definition := replace(definition,
    $old$p_payload->'manualNutritionInput', coalesce(p_payload->>'nutritionPreparation', 'as_sold'))$old$,
    $new$p_payload->'manualNutritionInput', coalesce(p_payload->>'nutritionPreparation', 'as_sold'), p_payload->>'selectedFoodGroup')$new$);
  if definition = previous then raise exception 'Food group insert values anchor missing'; end if;
  previous := definition;
  definition := replace(definition,
    $old$source = excluded.source, updated_at = now(), nutrition_preparation =$old$,
    $new$selected_food_group = case when p_payload ? 'selectedFoodGroup' then excluded.selected_food_group else public.products.selected_food_group end,
      source = excluded.source, updated_at = now(), nutrition_preparation =$new$);
  if definition = previous then raise exception 'Food group update anchor missing'; end if;
  execute definition;
end;
$migration$;
