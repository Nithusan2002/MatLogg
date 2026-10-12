-- Preparation is separate from unit; existing rows retain legacy as-sold behavior.
alter table public.products add column nutrition_preparation text not null default 'as_sold'
  check (nutrition_preparation in ('as_sold', 'prepared'));
alter table public.food_logs add column nutrition_preparation text not null default 'as_sold'
  check (nutrition_preparation in ('as_sold', 'prepared'));
alter table public.saved_meal_items add column nutrition_preparation text not null default 'as_sold'
  check (nutrition_preparation in ('as_sold', 'prepared'));

-- Preserve the current RPC's ownership, quota and atomic inbox behavior.
do $migration$
declare
  definition text;
  previous text;
  target regprocedure;
begin
  target := coalesce(
    to_regprocedure('matlogg_internal.apply_sync_event_unthrottled_v1(uuid,uuid,text,timestamptz,uuid,integer,jsonb)'),
    to_regprocedure('matlogg_internal.apply_sync_event_v1(uuid,uuid,text,timestamptz,uuid,integer,jsonb)'));
  if target is null then raise exception 'Sync persistence function missing'; end if;
  select pg_get_functiondef(target) into definition;
  previous := definition;
  definition := replace(definition, $old$image_url, source, updated_at, nutrition_basis, servings, manual_nutrition_input)$old$, $new$image_url, source, updated_at, nutrition_basis, servings, manual_nutrition_input, nutrition_preparation)$new$);
  if definition = previous then raise exception 'Preparation migration anchor 1 missing'; end if;
  previous := definition;
  definition := replace(definition, $old$p_payload->'servings', p_payload->'manualNutritionInput')$old$, $new$p_payload->'servings', p_payload->'manualNutritionInput', coalesce(p_payload->>'nutritionPreparation', 'as_sold'))$new$);
  if definition = previous then raise exception 'Preparation migration anchor 2 missing'; end if;
  previous := definition;
  definition := replace(definition, $old$source = excluded.source, updated_at = now(), nutrition_basis =$old$, $new$source = excluded.source, updated_at = now(), nutrition_preparation = case when p_payload ? 'nutritionPreparation' then excluded.nutrition_preparation else public.products.nutrition_preparation end, nutrition_basis =$new$);
  if definition = previous then raise exception 'Preparation migration anchor 3 missing'; end if;
  previous := definition;
  definition := replace(definition, $old$product_ref, portion_selection, updated_at)$old$, $new$product_ref, portion_selection, nutrition_preparation, updated_at)$new$);
  if definition = previous then raise exception 'Preparation migration anchor 4 missing'; end if;
  previous := definition;
  definition := replace(definition, $old$nullif(p_payload->'portionSelection', 'null'::jsonb), now())$old$, $new$nullif(p_payload->'portionSelection', 'null'::jsonb), coalesce(p_payload->>'nutritionPreparation', 'as_sold'), now())$new$);
  if definition = previous then raise exception 'Preparation migration anchor 5 missing'; end if;
  previous := definition;
  definition := replace(definition, $old$fat = excluded.fat, product_ref = excluded.product_ref,$old$, $new$fat = excluded.fat, product_ref = excluded.product_ref,
      nutrition_preparation = case when p_payload ? 'nutritionPreparation' then excluded.nutrition_preparation
        when public.food_logs.product_ref is not distinct from excluded.product_ref then public.food_logs.nutrition_preparation
        else 'as_sold' end,$new$);
  if definition = previous then raise exception 'Preparation migration anchor 6 missing'; end if;
  previous := definition;
  definition := replace(definition, $old$'amount', amount, 'unit', unit, 'portion', portion_selection)$old$, $new$'amount', amount, 'unit', unit, 'portion', portion_selection, 'preparation', nutrition_preparation)$new$);
  if definition = previous then raise exception 'Preparation migration anchor 7 missing'; end if;
  previous := definition;
  definition := replace(definition, $old$nutrition_source, sort_index, portion_selection)$old$, $new$nutrition_source, sort_index, portion_selection, nutrition_preparation)$new$);
  if definition = previous then raise exception 'Preparation migration anchor 8 missing'; end if;
  previous := definition;
  definition := replace(definition, $old$v_item->>'nutritionSource', (v_item->>'sortIndex')::integer, v_portion);$old$, $new$v_item->>'nutritionSource', (v_item->>'sortIndex')::integer, v_portion,
        coalesce(v_item->>'nutritionPreparation',
          case when v_old_items->(v_item->>'id')->>'productId' = v_item->>'productId'
            then v_old_items->(v_item->>'id')->>'preparation' end, 'as_sold'));$new$);
  if definition = previous then raise exception 'Preparation migration anchor 9 missing'; end if;
  execute definition;
end;
$migration$;
