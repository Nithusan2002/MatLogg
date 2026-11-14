-- Rate-limit bookkeeping also contains owner IDs and must be purged.
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
  delete from private.sync_rate_windows where owner_id = p_owner_id;
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
