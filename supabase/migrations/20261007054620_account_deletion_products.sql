-- Delete owned product content rather than treating detached ownership as anonymization.
create or replace function public.purge_account_data_admin_v1(p_owner_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then
    raise exception 'service role required' using errcode = '42501';
  end if;
  if not exists (select 1 from public.profiles where id = p_owner_id and purge_at <= now()) then
    raise exception 'account is not due for purge';
  end if;
  delete from public.event_inbox where owner_id = p_owner_id;
  delete from public.food_logs where owner_id = p_owner_id;
  delete from public.goals where owner_id = p_owner_id;
  delete from public.favorites where owner_id = p_owner_id;
  delete from public.water_logs where owner_id = p_owner_id;
  delete from public.weights where owner_id = p_owner_id;
  delete from public.saved_meals where owner_id = p_owner_id;
  delete from public.products where owner_id = p_owner_id;
end;
$$;

-- Repeated deletion requests must not extend the original retention deadline.
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
      purge_at = coalesce(purge_at, now() + interval '30 days')
  where id = p_owner_id
  returning purge_at into v_purge_at;
  if not found then raise exception 'profile not found'; end if;
  return v_purge_at;
end;
$$;
