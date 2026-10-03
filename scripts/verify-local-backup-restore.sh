#!/usr/bin/env bash
set -euo pipefail

# Restricted to the disposable, synthetic-data instance used for sync QA.
container=supabase_db_matlogg-sync-readiness
restore_db="matlogg_restore_$(date +%s)_$$"
work=$(mktemp -d)
cleanup() {
  docker exec "$container" dropdb -U supabase_admin --if-exists "$restore_db" >/dev/null 2>&1 || true
  rm -rf "$work"
}
trap cleanup EXIT

docker exec "$container" pg_dump -U supabase_admin -d postgres -Fc \
  --schema=auth --schema=public --schema=private > "$work/backup.dump"
docker exec "$container" createdb -U supabase_admin -T template0 "$restore_db"
docker exec "$container" psql -U supabase_admin -d "$restore_db" -v ON_ERROR_STOP=1 -q \
  -c 'drop schema public; create schema extensions; create extension pgcrypto with schema extensions;'
docker exec -i "$container" pg_restore -U supabase_admin -d "$restore_db" \
  --exit-on-error < "$work/backup.dump"

cat > "$work/fingerprint.sql" <<'SQL'
select format(
  'select %L || ''|'' || count(*) || ''|'' || md5(coalesce(string_agg(to_jsonb(t)::text, '''' order by to_jsonb(t)::text), '''')) from %I.%I t;',
  schemaname || '.' || tablename, schemaname, tablename
) from pg_tables where schemaname in ('auth', 'public', 'private') order by schemaname, tablename
\gexec
SQL
for database in postgres "$restore_db"; do
  docker exec -i "$container" psql -U supabase_admin -d "$database" -Atq \
    -v ON_ERROR_STOP=1 < "$work/fingerprint.sql" > "$work/$database.txt"
done
cmp "$work/postgres.txt" "$work/$restore_db.txt"
echo "PASS: auth/public/private restored with identical table counts and row fingerprints."
echo "This verifies a local logical backup only; hosted backup/PITR, Storage and operational recovery remain separate gates."
