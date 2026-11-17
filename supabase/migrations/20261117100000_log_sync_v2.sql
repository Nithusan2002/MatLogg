-- Additive log-only v2. No enrollment UI, no production activation.
insert into public.app_config(key,value) values ('log_sync_v2_enabled','false'::jsonb) on conflict do nothing;
create table private.log_sync_v2_owners (
 owner_id uuid primary key references auth.users(id) on delete cascade,
 enabled boolean not null default false,
 cursor bigint not null default 0,
 rate_minute timestamptz,
 attempts integer not null default 0
);
create table private.log_sync_v2_changes (
 owner_id uuid not null references auth.users(id) on delete cascade,
 revision bigint not null,
 entity_id uuid not null,
 deleted boolean not null,
 payload jsonb,
 primary key(owner_id,revision),
 check (deleted = (payload is null))
);
create table private.log_sync_v2_entities (
 owner_id uuid not null references auth.users(id) on delete cascade,
 entity_id uuid not null,
 revision bigint not null,
 deleted boolean not null,
 payload jsonb,
 primary key(owner_id,entity_id),
 check (deleted = (payload is null))
);
create table private.log_sync_v2_receipts (
 event_id uuid primary key,
 owner_id uuid not null references auth.users(id) on delete cascade,
 mutation jsonb not null,
 response jsonb not null
);
-- No exposed table access, even through an accidentally exposed private schema.
alter table private.log_sync_v2_owners enable row level security;
alter table private.log_sync_v2_changes enable row level security;
alter table private.log_sync_v2_entities enable row level security;
alter table private.log_sync_v2_receipts enable row level security;
revoke all on private.log_sync_v2_owners, private.log_sync_v2_changes, private.log_sync_v2_entities, private.log_sync_v2_receipts from public, anon, authenticated;

create function matlogg_internal.validate_log_v2(p jsonb, owner_id uuid, entity_id uuid) returns boolean
language plpgsql immutable set search_path='' as $$
declare l jsonb := p->'log'; product jsonb := p->'product'; k text; n numeric;
begin
 if jsonb_typeof(p) is distinct from 'object' or jsonb_typeof(l) is distinct from 'object' or jsonb_typeof(product) is distinct from 'object' then return false; end if;
 if (l->>'id')::uuid is distinct from entity_id or (l->>'userId')::uuid is distinct from owner_id
 or (l->>'productId')::uuid is distinct from (product->>'id')::uuid or l->>'productId' is null then return false; end if;
 if l->>'mealType' is null or l->>'mealType' not in ('frokost','lunsj','middag','snacks')
 or l->>'amountUnit' is null or l->>'amountUnit' not in ('g','ml')
 or jsonb_typeof(product->'name') is distinct from 'string' or length(btrim(product->>'name')) not between 1 and 500
 or product ? 'localImageData' or product ? 'imageUrl' then return false; end if;
 foreach k in array array['amountG','calories','proteinG','carbsG','fatG'] loop
  if jsonb_typeof(l->k) is distinct from 'number' then return false; end if;
  n := (l->>k)::numeric; if n<0 or n>3.402823466e38 then return false; end if;
 end loop;
 if (l->>'amountG')::numeric <= 0 then return false; end if;
 foreach k in array array['caloriesPer100g','proteinGPer100g','carbsGPer100g','fatGPer100g'] loop
  if jsonb_typeof(product->k) is distinct from 'number' then return false; end if;
  n := (product->>k)::numeric; if n<0 or n>3.402823466e38 then return false; end if;
 end loop;
 foreach k in array array['loggedDate','loggedTime','createdAt'] loop
  if jsonb_typeof(l->k) is distinct from 'number' or abs((l->>k)::numeric)>1e12 then return false; end if;
 end loop;
 if jsonb_typeof(product->'createdAt') is distinct from 'number' or abs((product->>'createdAt')::numeric)>1e12 then return false; end if;
 if jsonb_typeof(l->'isSynced') is distinct from 'boolean' or jsonb_typeof(product->'isSynced') is distinct from 'boolean'
 or jsonb_typeof(product->'isVerified') is distinct from 'boolean'
 or jsonb_typeof(product->'source') is distinct from 'string'
 or product->>'kind' is null or product->>'kind' not in ('packaged','genericFood')
 or product->>'imageSource' is null or product->>'imageSource' not in ('user','openFoodFacts','none')
 or product->>'verificationStatus' is null or product->>'verificationStatus' not in ('verified','unverified','suggestedMatch') then return false; end if;
 foreach k in array array['sugarGPer100g','fiberGPer100g','sodiumMgPer100g'] loop
  if product ? k and (jsonb_typeof(product->k) is distinct from 'number' or (product->>k)::numeric<0 or (product->>k)::numeric>3.402823466e38) then return false; end if;
 end loop;
 foreach k in array array['brand','category','selectedFoodGroup','barcodeEan','externalID'] loop
  if product ? k and jsonb_typeof(product->k) is distinct from 'string' then return false; end if;
 end loop;
 if product ? 'nutritionBasis' and product->>'nutritionBasis' not in ('per100g','per100ml') then return false; end if;
 if product ? 'nutritionPreparation' and product->>'nutritionPreparation' not in ('as_sold','prepared') then return false; end if;
 foreach k in array array['standardPortions','servings','categoryTags','dataQualityWarnings'] loop
  if product ? k and jsonb_typeof(product->k) is distinct from 'array' then return false; end if;
 end loop;
 foreach k in array array['manualNutritionInput','nutriScoreInfo','processingInfo'] loop
  if product ? k and jsonb_typeof(product->k) is distinct from 'object' then return false; end if;
 end loop;
 if l ? 'nutritionSource' and l->>'nutritionSource' not in ('user','matvaretabellen','openFoodFacts') then return false; end if;
 if l ? 'nutritionPreparation' and l->>'nutritionPreparation' not in ('as_sold','prepared') then return false; end if;
 if product->>'nutritionSource' is null or product->>'nutritionSource' not in ('user','matvaretabellen','openFoodFacts') then return false; end if;
 if l ? 'portionSelection' and jsonb_typeof(l->'portionSelection') <> 'null' then
  if jsonb_typeof(l->'portionSelection') <> 'object' then return false; end if;
  perform (l->'portionSelection'->>'servingId')::uuid;
  if l->'portionSelection'->>'servingId' is null
  or jsonb_typeof(l->'portionSelection'->'count') is distinct from 'number'
  or jsonb_typeof(l->'portionSelection'->'amountPerServing') is distinct from 'number'
  or (l->'portionSelection'->>'count')::numeric<=0
  or (l->'portionSelection'->>'amountPerServing')::numeric<=0
  or (l->'portionSelection'->>'amountPerServing')::numeric>10000
  or length(btrim(l->'portionSelection'->>'label')) not between 1 and 200
  or l->'portionSelection'->>'label' is null
  or l->'portionSelection'->>'source' is null or l->'portionSelection'->>'source' not in ('user','openFoodFacts','heuristic')
  or l->'portionSelection'->>'kind' is null or l->'portionSelection'->>'kind' not in ('portion','piece','package') then return false; end if;
  n := (l->'portionSelection'->>'count')::numeric * (l->'portionSelection'->>'amountPerServing')::numeric;
  if n is null or n<=0 or n>10000 or abs(n-(l->>'amountG')::numeric)>greatest(0.0001,abs(n)*0.000001)
    or l->'portionSelection'->>'unit' is distinct from l->>'amountUnit' then return false; end if;
 end if;
 return true;
exception when invalid_text_representation or numeric_value_out_of_range then return false;
end $$;
revoke all on function matlogg_internal.validate_log_v2(jsonb,uuid,uuid) from public, anon, authenticated;

create function matlogg_internal.push_log_v2(mutation jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
<<push_log_v2>>
declare owner_id uuid := auth.uid(); event_id uuid; entity_id uuid; base bigint; rev bigint;
 deleted boolean; current_row private.log_sync_v2_entities%rowtype;
 previous private.log_sync_v2_receipts%rowtype; change jsonb; response jsonb; status text;
begin
 if owner_id is null or not matlogg_internal.is_account_active_v1() then raise exception 'UNAUTHORIZED' using errcode='42501'; end if;
 if not exists(select 1 from public.app_config where key='log_sync_v2_enabled' and value='true'::jsonb) then raise exception 'SYNC_DISABLED'; end if;
 -- The same owner lock serializes cursor allocation AND commit order for every v2 write.
 perform 1 from private.log_sync_v2_owners o where o.owner_id=push_log_v2.owner_id and enabled for update;
 if not found then raise exception 'SYNC_DISABLED'; end if;
 update private.log_sync_v2_owners o set attempts=case when rate_minute=date_trunc('minute',now()) then attempts+1 else 1 end,rate_minute=date_trunc('minute',now()) where o.owner_id=push_log_v2.owner_id;
 if (select attempts from private.log_sync_v2_owners o where o.owner_id=push_log_v2.owner_id)>1500 then raise exception 'RATE_LIMITED'; end if;
 if jsonb_typeof(mutation) is distinct from 'object' or octet_length(mutation::text)>65536
 or jsonb_typeof(mutation->'schemaVersion') is distinct from 'number' or mutation->>'schemaVersion' is distinct from '2' or mutation->>'type' is null or mutation->>'type' not in ('log.upsert','log.delete')
 or jsonb_typeof(mutation->'baseRevision') is distinct from 'number' then raise exception 'VALIDATION_ERROR'; end if;
 event_id := (mutation->>'eventId')::uuid; entity_id := (mutation->>'entityId')::uuid;
 perform (mutation->>'deviceId')::uuid;
 base := (mutation->>'baseRevision')::bigint;
 if event_id is null or entity_id is null or mutation->>'deviceId' is null or base<0 or base::numeric<>(mutation->>'baseRevision')::numeric then raise exception 'VALIDATION_ERROR'; end if;
 select * into previous from private.log_sync_v2_receipts r where r.event_id=push_log_v2.event_id;
 if found then
  if previous.owner_id<>owner_id or previous.mutation<>mutation then raise exception 'EVENT_ID_COLLISION'; end if;
  return previous.response;
 end if;
 deleted := mutation->>'type'='log.delete';
 if not deleted and not matlogg_internal.validate_log_v2(mutation->'payload',owner_id,entity_id) then raise exception 'VALIDATION_ERROR'; end if;
 if deleted and coalesce(mutation->'payload','null'::jsonb)<>'null'::jsonb then raise exception 'VALIDATION_ERROR'; end if;
 select * into current_row from private.log_sync_v2_entities e where e.owner_id=push_log_v2.owner_id and e.entity_id=push_log_v2.entity_id;
 if (current_row.deleted and not deleted) or (base<>coalesce(current_row.revision,0) and not deleted) then
  if current_row.entity_id is null then raise exception 'INVALID_REVISION'; end if;
  status := 'conflict';
  change := jsonb_build_object('entityId',entity_id,'revision',current_row.revision,'deleted',current_row.deleted,'payload',current_row.payload);
 else
  if base>coalesce(current_row.revision,0) then raise exception 'INVALID_REVISION'; end if;
  update private.log_sync_v2_owners o set cursor=cursor+1 where o.owner_id=push_log_v2.owner_id returning cursor into rev;
  change := jsonb_build_object('entityId',entity_id,'revision',rev,'deleted',deleted,'payload',case when deleted then null else mutation->'payload' end);
  insert into private.log_sync_v2_entities values(owner_id,entity_id,rev,deleted,case when deleted then null else mutation->'payload' end)
  on conflict on constraint log_sync_v2_entities_pkey do update set revision=excluded.revision,deleted=excluded.deleted,payload=excluded.payload;
  insert into private.log_sync_v2_changes values(owner_id,rev,entity_id,deleted,case when deleted then null else mutation->'payload' end);
  status := 'applied';
 end if;
 response := jsonb_build_object('eventId',event_id,'status',status,'change',change);
 insert into private.log_sync_v2_receipts values(event_id,owner_id,mutation,response);
 return response;
exception when invalid_text_representation or numeric_value_out_of_range then raise exception 'VALIDATION_ERROR';
end $$;

create function matlogg_internal.pull_logs_v2(after_cursor bigint) returns jsonb
language plpgsql security definer set search_path='' as $$
<<pull_logs_v2>>
declare owner_id uuid := auth.uid(); high bigint; changes jsonb; next_cursor bigint;
begin
 if owner_id is null or not matlogg_internal.is_account_active_v1() then raise exception 'UNAUTHORIZED' using errcode='42501'; end if;
 if not exists(select 1 from public.app_config where key='log_sync_v2_enabled' and value='true'::jsonb) then raise exception 'SYNC_DISABLED'; end if;
 select cursor into high from private.log_sync_v2_owners o where o.owner_id=pull_logs_v2.owner_id and enabled;
 if high is null then raise exception 'SYNC_DISABLED'; end if;
 if after_cursor is null or after_cursor<0 or after_cursor>high then raise exception 'INVALID_CURSOR'; end if;
 select coalesce(jsonb_agg(jsonb_build_object('entityId',entity_id,'revision',revision,'deleted',deleted,'payload',payload) order by revision),'[]'::jsonb),coalesce(max(revision),after_cursor)
 into changes,next_cursor from (select * from private.log_sync_v2_changes c where c.owner_id=pull_logs_v2.owner_id and revision>after_cursor order by revision limit 100) page;
 return jsonb_build_object('owner',owner_id,'changes',changes,'cursor',next_cursor);
end $$;
revoke all on function matlogg_internal.push_log_v2(jsonb),matlogg_internal.pull_logs_v2(bigint) from public,anon;
grant execute on function matlogg_internal.push_log_v2(jsonb),matlogg_internal.pull_logs_v2(bigint) to authenticated;
create function public.push_log_v2(mutation jsonb) returns jsonb language sql security invoker set search_path='' as $$ select matlogg_internal.push_log_v2(mutation) $$;
create function public.pull_logs_v2(after_cursor bigint) returns jsonb language sql security invoker set search_path='' as $$ select matlogg_internal.pull_logs_v2(after_cursor) $$;
revoke all on function public.push_log_v2(jsonb),public.pull_logs_v2(bigint) from public,anon;
grant execute on function public.push_log_v2(jsonb),public.pull_logs_v2(bigint) to authenticated;
-- Refuse v1 writes for every enrolled owner, even while v2 is temporarily disabled.
-- Guard the internal implementation too, not just its public wrapper.
do $$
declare definition text; changed text;
begin
 select pg_get_functiondef('matlogg_internal.apply_sync_event_v1(uuid,uuid,text,timestamptz,uuid,integer,jsonb)'::regprocedure) into definition;
 changed := replace(definition, 'begin', 'begin
  if exists(select 1 from private.log_sync_v2_owners where owner_id=auth.uid()) then
    return jsonb_build_object(''status'',''rejected'',''code'',''V2_REQUIRED'',''message'',''Bruk synk v2'');
  end if;');
 if changed=definition then raise exception 'Missing v1 guard anchor'; end if;
 execute changed;
end $$;
