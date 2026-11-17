-- History identity + immutable, resumable log-only bootstrap. Gates remain unchanged.
alter table private.log_sync_v2_owners add column history_epoch uuid not null default gen_random_uuid();
create table private.log_sync_v2_snapshots (
 id uuid primary key,
 owner_id uuid not null references auth.users(id) on delete cascade,
 history_epoch uuid not null,
 upper_cursor bigint not null,
 total_count integer not null,
 expires_at timestamptz not null default now()+interval '24 hours'
);
create table private.log_sync_v2_snapshot_items (
 snapshot_id uuid not null references private.log_sync_v2_snapshots(id) on delete cascade,
 entity_id uuid not null,
 change jsonb not null,
 primary key(snapshot_id,entity_id)
);
alter table private.log_sync_v2_snapshots enable row level security;
alter table private.log_sync_v2_snapshot_items enable row level security;
revoke all on private.log_sync_v2_snapshots,private.log_sync_v2_snapshot_items from public,anon,authenticated;

create function matlogg_internal.log_sync_head_v2() returns jsonb
language plpgsql security definer set search_path='' as $$
declare o private.log_sync_v2_owners%rowtype;
begin
 if auth.uid() is null or not matlogg_internal.is_account_active_v1() then raise exception 'UNAUTHORIZED' using errcode='42501'; end if;
 if not exists(select 1 from public.app_config where key='log_sync_v2_enabled' and value='true'::jsonb) then raise exception 'SYNC_DISABLED'; end if;
 select * into o from private.log_sync_v2_owners where owner_id=auth.uid() and enabled;
 if not found then raise exception 'SYNC_DISABLED'; end if;
 return jsonb_build_object('owner',o.owner_id,'historyEpoch',o.history_epoch,'cursor',o.cursor);
end $$;

alter function matlogg_internal.push_log_v2(jsonb) rename to push_log_before_epoch_v2;
revoke all on function matlogg_internal.push_log_before_epoch_v2(jsonb) from public,anon,authenticated;
create function matlogg_internal.push_log_v2(mutation jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare head jsonb;
begin
 -- Lock the same owner row as the underlying writer, before checking the epoch.
 perform 1 from private.log_sync_v2_owners where owner_id=auth.uid() for update;
 head := matlogg_internal.log_sync_head_v2();
 if mutation->>'historyEpoch' is null then raise exception 'HISTORY_EPOCH_REQUIRED'; end if;
 if (mutation->>'historyEpoch')::uuid is distinct from (head->>'historyEpoch')::uuid then raise exception 'HISTORY_EPOCH_MISMATCH'; end if;
 return matlogg_internal.push_log_before_epoch_v2(mutation) || jsonb_build_object('historyEpoch',head->>'historyEpoch');
exception when invalid_text_representation then raise exception 'VALIDATION_ERROR';
end $$;
-- Rebind SQL wrappers explicitly: dependencies on the old function survive RENAME.
create or replace function public.push_log_v2(mutation jsonb) returns jsonb language sql security invoker set search_path='' as $$ select matlogg_internal.push_log_v2(mutation) $$;

alter function matlogg_internal.pull_logs_v2(bigint) rename to pull_logs_before_epoch_v2;
revoke all on function matlogg_internal.pull_logs_before_epoch_v2(bigint) from public,anon,authenticated;
create function matlogg_internal.pull_logs_v2(after_cursor bigint, history_epoch uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare head jsonb;
begin
 perform 1 from private.log_sync_v2_owners where owner_id=auth.uid() for share;
 head := matlogg_internal.log_sync_head_v2();
 if history_epoch is null then raise exception 'HISTORY_EPOCH_REQUIRED'; end if;
 if history_epoch is distinct from (head->>'historyEpoch')::uuid then raise exception 'HISTORY_EPOCH_MISMATCH'; end if;
 return matlogg_internal.pull_logs_before_epoch_v2(after_cursor) || jsonb_build_object('historyEpoch',head->>'historyEpoch');
end $$;
create function public.pull_logs_v2(after_cursor bigint,history_epoch uuid) returns jsonb language sql security invoker set search_path='' as $$ select matlogg_internal.pull_logs_v2(after_cursor,history_epoch) $$;
create or replace function public.pull_logs_v2(after_cursor bigint) returns jsonb language plpgsql security invoker set search_path='' as $$ begin perform after_cursor; raise exception 'HISTORY_EPOCH_REQUIRED'; end $$;

create function matlogg_internal.begin_log_bootstrap_v2(snapshot_id uuid,expected_epoch uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare head jsonb; s private.log_sync_v2_snapshots%rowtype; n integer;
begin
 perform 1 from private.log_sync_v2_owners where owner_id=auth.uid() for update;
 head := matlogg_internal.log_sync_head_v2();
 if expected_epoch is distinct from (head->>'historyEpoch')::uuid then raise exception 'HISTORY_EPOCH_MISMATCH'; end if;
 if snapshot_id is null then raise exception 'VALIDATION_ERROR'; end if;
 select * into s from private.log_sync_v2_snapshots where id=snapshot_id;
 if found then
  if s.owner_id<>auth.uid() then raise exception 'SNAPSHOT_NOT_FOUND'; end if;
  if s.history_epoch<>expected_epoch then raise exception 'HISTORY_EPOCH_MISMATCH'; end if;
  if s.expires_at<=now() then raise exception 'SNAPSHOT_EXPIRED'; end if;
 else
  delete from private.log_sync_v2_snapshots where owner_id=auth.uid() and (expires_at<=now() or history_epoch<>expected_epoch);
  if (select count(*) from private.log_sync_v2_snapshots where owner_id=auth.uid())>=10 then raise exception 'SNAPSHOT_LIMIT'; end if;
  select count(*)::integer into n from private.log_sync_v2_entities where owner_id=auth.uid();
  insert into private.log_sync_v2_snapshots(id,owner_id,history_epoch,upper_cursor,total_count)
  values(snapshot_id,auth.uid(),expected_epoch,(head->>'cursor')::bigint,n) returning * into s;
  insert into private.log_sync_v2_snapshot_items
  select snapshot_id,entity_id,jsonb_build_object('entityId',entity_id,'revision',revision,'deleted',deleted,'payload',payload)
  from private.log_sync_v2_entities where owner_id=auth.uid();
 end if;
 return jsonb_build_object('owner',s.owner_id,'snapshotId',s.id,'historyEpoch',s.history_epoch,'upperCursor',s.upper_cursor,'totalCount',s.total_count);
exception when unique_violation then raise exception 'SNAPSHOT_NOT_FOUND';
end $$;

create function matlogg_internal.read_log_bootstrap_v2(snapshot_id uuid,page_offset integer) returns jsonb
language plpgsql security definer set search_path='' as $$
declare head jsonb; s private.log_sync_v2_snapshots%rowtype; changes jsonb;
begin
 perform 1 from private.log_sync_v2_owners where owner_id=auth.uid() for share;
 head := matlogg_internal.log_sync_head_v2();
 select * into s from private.log_sync_v2_snapshots where id=snapshot_id and owner_id=auth.uid();
 if not found then raise exception 'SNAPSHOT_NOT_FOUND'; end if;
 if s.history_epoch is distinct from (head->>'historyEpoch')::uuid then raise exception 'HISTORY_EPOCH_MISMATCH'; end if;
 if s.expires_at<=now() then raise exception 'SNAPSHOT_EXPIRED'; end if;
 if page_offset is null or page_offset<0 or page_offset>s.total_count or page_offset%100<>0 then raise exception 'INVALID_CURSOR'; end if;
 select coalesce(jsonb_agg(change order by entity_id),'[]'::jsonb) into changes
 from (select entity_id,change from private.log_sync_v2_snapshot_items where log_sync_v2_snapshot_items.snapshot_id=read_log_bootstrap_v2.snapshot_id order by entity_id limit 100 offset page_offset) page;
 return jsonb_build_object('owner',s.owner_id,'snapshotId',s.id,'historyEpoch',s.history_epoch,'upperCursor',s.upper_cursor,'totalCount',s.total_count,
 'offset',page_offset,'changes',changes,'complete',page_offset+jsonb_array_length(changes)=s.total_count);
end $$;

create function public.log_sync_head_v2() returns jsonb language sql security invoker set search_path='' as $$ select matlogg_internal.log_sync_head_v2() $$;
create function public.begin_log_bootstrap_v2(snapshot_id uuid,expected_epoch uuid) returns jsonb language sql security invoker set search_path='' as $$ select matlogg_internal.begin_log_bootstrap_v2(snapshot_id,expected_epoch) $$;
create function public.read_log_bootstrap_v2(snapshot_id uuid,page_offset integer) returns jsonb language sql security invoker set search_path='' as $$ select matlogg_internal.read_log_bootstrap_v2(snapshot_id,page_offset) $$;
revoke all on function matlogg_internal.log_sync_head_v2(),matlogg_internal.push_log_v2(jsonb),matlogg_internal.pull_logs_v2(bigint,uuid),matlogg_internal.begin_log_bootstrap_v2(uuid,uuid),matlogg_internal.read_log_bootstrap_v2(uuid,integer),public.log_sync_head_v2(),public.pull_logs_v2(bigint,uuid),public.begin_log_bootstrap_v2(uuid,uuid),public.read_log_bootstrap_v2(uuid,integer) from public,anon;
grant execute on function matlogg_internal.log_sync_head_v2(),matlogg_internal.push_log_v2(jsonb),matlogg_internal.pull_logs_v2(bigint,uuid),matlogg_internal.begin_log_bootstrap_v2(uuid,uuid),matlogg_internal.read_log_bootstrap_v2(uuid,integer),public.log_sync_head_v2(),public.pull_logs_v2(bigint,uuid),public.begin_log_bootstrap_v2(uuid,uuid),public.read_log_bootstrap_v2(uuid,integer) to authenticated;
