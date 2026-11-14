-- Keep the existing 30-batch/min Edge quota; bound every authenticated apply call as well.
-- 1500 attempts/min = 30 full batches of 50. Replay and rejected attempts consume credit.
alter table private.sync_rate_windows
  add column event_count integer not null default 0 check (event_count >= 0);

-- Only the guarded wrapper may invoke the existing domain/inbox transaction.
alter function matlogg_internal.apply_sync_event_v1(uuid, uuid, text, timestamptz, uuid, integer, jsonb)
  rename to apply_sync_event_unthrottled_v1;
revoke all on function matlogg_internal.apply_sync_event_unthrottled_v1(uuid, uuid, text, timestamptz, uuid, integer, jsonb)
  from public, anon, authenticated, service_role;

create function matlogg_internal.apply_sync_event_v1(
  p_device_id uuid, p_event_id uuid, p_type text, p_created_at timestamptz,
  p_entity_id uuid, p_schema_version integer, p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_owner uuid := auth.uid();
  v_window timestamptz := date_trunc('minute', now());
  v_count integer;
begin
  if not public.is_sync_enabled() then
    return jsonb_build_object('status', 'rejected', 'code', 'SYNC_DISABLED', 'message', 'Synkronisering er midlertidig deaktivert');
  end if;
  if v_owner is null then
    return jsonb_build_object('status', 'rejected', 'code', 'UNAUTHORIZED', 'message', 'Mangler gyldig bruker');
  end if;
  if not exists (select 1 from public.profiles where id = v_owner and deletion_requested_at is null) then
    return jsonb_build_object('status', 'rejected', 'code', 'ACCOUNT_DELETED', 'message', 'Kontoen er deaktivert');
  end if;

  insert into private.sync_rate_windows(owner_id, window_start, request_count, event_count)
  values (v_owner, v_window, 0, 1)
  on conflict (owner_id, window_start) do update
    set event_count = least(private.sync_rate_windows.event_count + 1, 1501)
  returning event_count into v_count;
  delete from private.sync_rate_windows
    where owner_id = v_owner and window_start < now() - interval '2 hours';
  if v_count > 1500 then
    return jsonb_build_object('status', 'rejected', 'code', 'RATE_LIMITED', 'message', 'For mange synkhendelser; prøv igjen senere');
  end if;

  return matlogg_internal.apply_sync_event_unthrottled_v1(
    p_device_id, p_event_id, p_type, p_created_at,
    p_entity_id, p_schema_version, p_payload
  );
end;
$$;
revoke all on function matlogg_internal.apply_sync_event_v1(uuid, uuid, text, timestamptz, uuid, integer, jsonb)
  from public, anon, service_role;
grant execute on function matlogg_internal.apply_sync_event_v1(uuid, uuid, text, timestamptz, uuid, integer, jsonb)
  to authenticated;

-- Rebind the public wrapper to the guarded function and invalidate cached SQL plans.
create or replace function public.apply_sync_event_v1(
  p_device_id uuid, p_event_id uuid, p_type text, p_created_at timestamptz,
  p_entity_id uuid, p_schema_version integer, p_payload jsonb
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
