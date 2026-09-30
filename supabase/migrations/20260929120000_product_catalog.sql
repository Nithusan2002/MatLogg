create extension if not exists pg_trgm with schema extensions;

create table public.catalog_products (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(btrim(name)) between 1 and 200),
  normalized_name text not null,
  brand text not null check (length(btrim(brand)) between 1 and 160),
  normalized_brand text not null,
  barcode text,
  nutrition_basis text not null check (nutrition_basis in ('per100g', 'per100ml')),
  nutrients jsonb not null,
  front_image_path text not null,
  front_image_phash text not null,
  status text not null check (status in ('public_unverified', 'verified')),
  source_submission_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint catalog_products_barcode_format check (barcode is null or barcode ~ '^[0-9]{8,14}$'),
  constraint catalog_products_nutrients_object check (jsonb_typeof(nutrients) = 'object')
);
create unique index catalog_products_barcode_unique_idx on public.catalog_products(barcode) where barcode is not null;
create index catalog_products_name_trgm_idx on public.catalog_products using gin ((normalized_name || ' ' || normalized_brand) extensions.gin_trgm_ops);

create table public.product_submissions (
  id uuid primary key,
  owner_id uuid not null references auth.users(id) on delete cascade,
  -- Deliberately not coupled to public.products: catalog contributions are a
  -- separate, feature-flagged channel while production sync remains disabled.
  product_id uuid not null,
  catalog_product_id uuid references public.catalog_products(id) on delete set null,
  status text not null check (status in ('pending_processing', 'needs_review', 'public_unverified', 'verified', 'rejected', 'merged', 'expired')),
  payload jsonb not null,
  explicit_consent boolean not null check (explicit_consent),
  ai_fields_confirmed boolean not null default false,
  validation_flags text[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  decided_at timestamptz,
  expires_at timestamptz not null default now() + interval '90 days'
);
create index product_submissions_owner_created_idx on public.product_submissions(owner_id, created_at desc);

create table public.submission_images (
  id uuid primary key,
  submission_id uuid references public.product_submissions(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  kind text not null check (kind in ('nutrition_label', 'front')),
  storage_path text not null unique,
  content_type text not null check (content_type in ('image/jpeg', 'image/png', 'image/heic')),
  byte_size integer not null check (byte_size > 0 and byte_size <= 5242880),
  perceptual_hash text,
  created_at timestamptz not null default now(),
  delete_after timestamptz not null default now() + interval '90 days'
);
create index submission_images_cleanup_idx on public.submission_images(delete_after);

create table public.catalog_reports (
  id uuid primary key default gen_random_uuid(),
  catalog_product_id uuid not null references public.catalog_products(id) on delete cascade,
  reporter_id uuid references auth.users(id) on delete set null,
  reason text not null check (length(btrim(reason)) between 3 and 500),
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

create table public.moderation_actions (
  id uuid primary key default gen_random_uuid(),
  submission_id uuid not null references public.product_submissions(id) on delete cascade,
  moderator_id uuid not null references auth.users(id),
  action text not null check (action in ('approve', 'reject', 'merge')),
  reason text check (reason is null or length(reason) <= 1000),
  target_catalog_product_id uuid references public.catalog_products(id),
  created_at timestamptz not null default now()
);

create table private.catalog_rate_windows (
  subject_hash text not null,
  action text not null,
  window_start timestamptz not null,
  request_count integer not null check (request_count >= 0),
  primary key(subject_hash, action, window_start)
);
create table private.ai_daily_quotas (
  owner_id uuid not null,
  quota_date date not null,
  request_count integer not null check (request_count >= 0),
  primary key(owner_id, quota_date)
);

alter table public.catalog_products enable row level security;
alter table public.product_submissions enable row level security;
alter table public.submission_images enable row level security;
alter table public.catalog_reports enable row level security;
alter table public.moderation_actions enable row level security;
revoke all on public.catalog_products, public.product_submissions, public.submission_images,
  public.catalog_reports, public.moderation_actions from anon, authenticated;

insert into public.app_config(key, value) values
  ('nutrition_label_ai_enabled', 'false'::jsonb),
  ('shared_catalog_read_enabled', 'false'::jsonb),
  ('catalog_contributions_enabled', 'false'::jsonb),
  ('catalog_auto_publish_enabled', 'false'::jsonb),
  ('nutrition_label_ai_daily_quota', '10'::jsonb)
on conflict (key) do nothing;

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('product-submissions', 'product-submissions', false, 5242880, array['image/jpeg', 'image/png', 'image/heic'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('catalog-product-images', 'catalog-product-images', true, 5242880, array['image/jpeg', 'image/png', 'image/heic'])
on conflict (id) do update set public = true, file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create or replace function public.feature_enabled_v1(p_key text)
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce((select value = 'true'::jsonb from public.app_config where key = p_key), false)
$$;

create or replace function public.consume_catalog_quota_v1(p_subject_hash text, p_action text, p_limit integer)
returns boolean language plpgsql security definer set search_path = '' as $$
declare v_window timestamptz := date_trunc('minute', now()); v_count integer;
begin
  if coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then raise exception 'service role required' using errcode = '42501'; end if;
  insert into private.catalog_rate_windows(subject_hash, action, window_start, request_count)
  values (p_subject_hash, p_action, v_window, 1)
  on conflict (subject_hash, action, window_start) do update
    set request_count = private.catalog_rate_windows.request_count + 1
  returning request_count into v_count;
  delete from private.catalog_rate_windows where window_start < now() - interval '2 hours';
  return v_count <= p_limit;
end $$;

create or replace function public.consume_ai_daily_quota_v1(p_owner_id uuid)
returns boolean language plpgsql security definer set search_path = '' as $$
declare v_count integer; v_limit integer;
begin
  if coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then raise exception 'service role required' using errcode = '42501'; end if;
  select coalesce((value #>> '{}')::integer, 10) into v_limit from public.app_config where key = 'nutrition_label_ai_daily_quota';
  insert into private.ai_daily_quotas(owner_id, quota_date, request_count) values (p_owner_id, current_date, 1)
  on conflict (owner_id, quota_date) do update set request_count = private.ai_daily_quotas.request_count + 1
  returning request_count into v_count;
  delete from private.ai_daily_quotas where quota_date < current_date - 7;
  return v_count <= coalesce(v_limit, 10);
end $$;

create or replace function public.catalog_duplicate_candidates_v1(p_name text, p_brand text, p_threshold double precision default 0.70)
returns table(id uuid, similarity_score real)
language sql stable security definer set search_path = '' as $$
  select cp.id,
    extensions.similarity(cp.normalized_name || ' ' || cp.normalized_brand,
      lower(regexp_replace(btrim(p_name || ' ' || p_brand), '[^[:alnum:]]+', ' ', 'g'))) as similarity_score
  from public.catalog_products cp
  where cp.status in ('public_unverified', 'verified')
    and extensions.similarity(cp.normalized_name || ' ' || cp.normalized_brand,
      lower(regexp_replace(btrim(p_name || ' ' || p_brand), '[^[:alnum:]]+', ' ', 'g'))) >= p_threshold
  order by similarity_score desc limit 10
$$;

revoke all on function public.feature_enabled_v1(text) from public, anon, authenticated;
revoke all on function public.consume_catalog_quota_v1(text, text, integer) from public, anon, authenticated;
revoke all on function public.consume_ai_daily_quota_v1(uuid) from public, anon, authenticated;
revoke all on function public.catalog_duplicate_candidates_v1(text, text, double precision) from public, anon, authenticated;
grant execute on function public.feature_enabled_v1(text), public.consume_catalog_quota_v1(text, text, integer),
  public.consume_ai_daily_quota_v1(uuid) to service_role;
grant execute on function public.catalog_duplicate_candidates_v1(text, text, double precision) to service_role;
