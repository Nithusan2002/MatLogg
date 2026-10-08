-- Staging maintenance only, after explicit approval.
-- Inspect the count first; these owner IDs no longer have an Auth account.
select count(*) as orphan_rate_windows
from private.sync_rate_windows w
where not exists (select 1 from auth.users u where u.id = w.owner_id);

-- No active account's rows are deleted. Do not print owner IDs.
begin;
lock table private.sync_rate_windows in share row exclusive mode;
do $$begin
  if (select count(*) from private.sync_rate_windows w
      where not exists (select 1 from auth.users u where u.id = w.owner_id)) <> 4 then
    raise exception 'orphan count changed; review before cleanup';
  end if;
end$$;
with removed as (
  delete from private.sync_rate_windows w
  where not exists (select 1 from auth.users u where u.id = w.owner_id)
  returning 1
)
select count(*) as removed_orphan_rate_windows from removed;
commit;
