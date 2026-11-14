-- Validate new product events at the database boundary as well as in Edge.
-- Replays already accepted by this owner retain their ACK and do not write again.
do $migration$
declare
  definition text;
  updated_definition text;
begin
  select pg_get_functiondef('matlogg_internal.apply_sync_event_unthrottled_v1(uuid,uuid,text,timestamptz,uuid,integer,jsonb)'::regprocedure) into definition;
  updated_definition := replace(definition,
    $anchor$  if p_type in ('log.create', 'log.update', 'log.upsert', 'log.delete') then
    select owner_id into v_existing_owner from public.food_logs$anchor$,
    $guard$  if p_type = 'product.upsert' then
    if jsonb_typeof(p_payload->'nutrientsPer100g') is distinct from 'object' then
      return jsonb_build_object('status', 'rejected', 'code', 'VALIDATION_ERROR', 'message', 'Ugyldige næringsverdier');
    end if;
    -- Match finite non-negative JavaScript numbers; no nutrition-specific ceiling.
    if exists (
      select 1 from jsonb_each(p_payload->'nutrientsPer100g') as nutrient
      where case when jsonb_typeof(nutrient.value) = 'number' then
        (nutrient.value #>> '{}')::numeric < 0
        or (nutrient.value #>> '{}')::numeric > 1.7976931348623157e308::numeric
      else true end
    ) then
      return jsonb_build_object('status', 'rejected', 'code', 'VALIDATION_ERROR', 'message', 'Ugyldige næringsverdier');
    end if;
  end if;

  if p_type in ('log.create', 'log.update', 'log.upsert', 'log.delete') then
    select owner_id into v_existing_owner from public.food_logs$guard$);
  if updated_definition = definition then
    raise exception 'Expected ownership validation anchor was not found';
  end if;
  execute updated_definition;
end;
$migration$;
