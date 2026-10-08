-- New requests are immediately eligible. Existing pending accounts retain
-- their previously communicated deadline until explicitly requested again.
create or replace function public.request_account_deletion_admin_v1(p_owner_id uuid)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare v_purge_at timestamptz;
begin
  if coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then
    raise exception 'service role required' using errcode = '42501';
  end if;
  update public.profiles
  set deletion_requested_at = coalesce(deletion_requested_at, now()),
      purge_at = least(coalesce(purge_at, now()), now())
  where id = p_owner_id
  returning purge_at into v_purge_at;
  if not found then raise exception 'profile not found'; end if;
  return v_purge_at;
end;
$$;
