create or replace function matlogg_internal.valid_portion_nutrients(snapshot jsonb)
returns boolean language sql immutable set search_path = '' as $$
  select case
    when snapshot is null then true
    when jsonb_typeof(snapshot) <> 'object' then false
    else not exists (
      select 1 from jsonb_each(snapshot) as nutrient
      where nutrient.key not in ('fiber', 'vitaminD', 'vitaminB12', 'folate', 'vitaminC', 'salt', 'saturatedFat', 'iron', 'calcium', 'iodine')
        or case when jsonb_typeof(nutrient.value) = 'number' then
          (nutrient.value #>> '{}')::numeric not between 0 and 1.7976931348623157e308::numeric
        else true end
    )
  end;
$$;
revoke all on function matlogg_internal.valid_portion_nutrients(jsonb) from public;
