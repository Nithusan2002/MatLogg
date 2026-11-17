-- ONLY install in disposable loopback QA. Not a production migration or sync API.
-- The spike stores opaque complete snapshots to establish lossless local roundtrip.
create table public.qa_log_snapshots (
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  id uuid not null,
  schema_version integer not null check (schema_version = 1),
  snapshot jsonb not null check (jsonb_typeof(snapshot) = 'object'),
  primary key (owner_id, id),
  check (snapshot ? 'userId' and (snapshot->>'userId') is not null and (snapshot->>'userId')::uuid = owner_id),
  check (snapshot ? 'id' and (snapshot->>'id') is not null and (snapshot->>'id')::uuid = id)
);
alter table public.qa_log_snapshots enable row level security;
revoke all on public.qa_log_snapshots from public, anon, authenticated;
grant select, insert on public.qa_log_snapshots to authenticated;
create policy owner_read on public.qa_log_snapshots for select to authenticated using (owner_id = auth.uid());
create policy owner_insert on public.qa_log_snapshots for insert to authenticated with check (owner_id = auth.uid());
-- No update/delete grant: this is an immutable transport fixture, not conflict handling.
