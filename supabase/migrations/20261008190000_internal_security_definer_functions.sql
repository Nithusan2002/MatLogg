-- Keep privileged implementations outside PostgREST's exposed schemas.
-- ALTER SET SCHEMA preserves function OIDs, so RLS dependencies remain intact.
create schema matlogg_internal;
revoke all on schema matlogg_internal from public, anon;
grant usage on schema matlogg_internal to authenticated, service_role;

alter function public.is_account_active_v1() set schema matlogg_internal;
alter function public.apply_sync_event_v1(uuid, uuid, text, timestamptz, uuid, integer, jsonb)
  set schema matlogg_internal;

-- Preserve the existing sync RPC contract and caller JWT identity.
-- This wrapper has no elevated privileges; ownership and transaction handling
-- remain in the internal implementation. Direct RPC still bypasses Edge quota.
create function public.apply_sync_event_v1(
  p_device_id uuid,
  p_event_id uuid,
  p_type text,
  p_created_at timestamptz,
  p_entity_id uuid,
  p_schema_version integer,
  p_payload jsonb
)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select matlogg_internal.apply_sync_event_v1(
    p_device_id, p_event_id, p_type, p_created_at,
    p_entity_id, p_schema_version, p_payload
  )
$$;
revoke all on function public.apply_sync_event_v1(uuid, uuid, text, timestamptz, uuid, integer, jsonb)
  from public, anon;
grant execute on function public.apply_sync_event_v1(uuid, uuid, text, timestamptz, uuid, integer, jsonb)
  to authenticated;
