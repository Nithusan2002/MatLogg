insert into public.app_config (key, value)
values ('sync_enabled', 'false'::jsonb)
on conflict (key) do update set value = excluded.value;
