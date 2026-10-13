#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/coverage
rehearsal_output="$(mktemp -d build/coverage/staging-rehearsal.XXXXXX)"
rehearsal_workdir="$rehearsal_output/project"
cleanup() {
  npx supabase stop --no-backup --workdir "$rehearsal_workdir" > /dev/null 2>&1 || true
}
trap cleanup EXIT
python3 - "$rehearsal_workdir" <<'PY'
from pathlib import Path
import shutil,sys
source=Path('supabase')
target=Path(sys.argv[1])/'supabase'
target.mkdir(parents=True)
config=(source/'config.toml').read_text().replace('project_id = "matlogg"','project_id = "matlogg-staging-rehearsal-qa"').replace('553','563')
assert 'project_id = "matlogg-staging-rehearsal-qa"' in config
(target/'config.toml').write_text(config)
shutil.copy2(source/'seed.sql',target/'seed.sql')
shutil.copytree(source/'functions',target/'functions')
(target/'migrations').mkdir()
for p in (source/'migrations').glob('*.sql'):
    version=p.name.split('_',1)[0]
    if version <= '20261007144356' and version != '20261003090000':
        shutil.copy2(p,target/'migrations'/p.name)
assert len(list((target/'migrations').glob('*.sql'))) == 8, 'Expected the observed eight staging migrations'
PY
# Discard startup stdout because it includes disposable local API keys.
npx supabase start --workdir "$rehearsal_workdir" > /dev/null
# Seed a synthetic legacy row and old batch credit before the upgrade.
docker exec -i supabase_db_matlogg-staging-rehearsal-qa psql -U postgres -d postgres -v ON_ERROR_STOP=1 > "$rehearsal_output/legacy-data.log" <<'SQL'
insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
values ('00000000-0000-0000-0000-000000000000','75000000-0000-4000-8000-000000000001','authenticated','authenticated','rehearsal@example.test','',now(),now(),now());
insert into public.products(id,owner_id,name,nutrients_per_100g,source,updated_at)
values ('75000000-0000-4000-8000-000000000002','75000000-0000-4000-8000-000000000001','Synthetic legacy product','{"kcal":123.75,"protein":8}'::jsonb,'user',now());
insert into private.sync_rate_windows(owner_id,window_start,request_count)
values ('75000000-0000-4000-8000-000000000001',date_trunc('minute',now()),7);
SQL
cp supabase/migrations/*.sql "$rehearsal_workdir/supabase/migrations/"
cp -R supabase/tests "$rehearsal_workdir/supabase/tests"
npx supabase db push --local --include-all --workdir "$rehearsal_workdir" > "$rehearsal_output/migrations.log" 2>&1
docker exec -i supabase_db_matlogg-staging-rehearsal-qa psql -U postgres -d postgres -v ON_ERROR_STOP=1 >> "$rehearsal_output/legacy-data.log" <<'SQL'
do $$ begin
  if not exists (select 1 from public.products where id='75000000-0000-4000-8000-000000000002'
    and nutrients_per_100g='{"kcal":123.75,"protein":8}'::jsonb and nutrition_basis='per100g') then
    raise exception 'Legacy nutrition data changed during upgrade';
  end if;
  if not exists (select 1 from private.sync_rate_windows where owner_id='75000000-0000-4000-8000-000000000001'
    and request_count=7 and event_count=0) then
    raise exception 'Existing batch credit changed during upgrade';
  end if;
end $$;
delete from private.sync_rate_windows where owner_id='75000000-0000-4000-8000-000000000001';
delete from auth.users where id='75000000-0000-4000-8000-000000000001';
SQL
npx supabase test db --workdir "$rehearsal_workdir" > "$rehearsal_output/tests.log" 2>&1
npx supabase db lint --local --workdir "$rehearsal_workdir" --schema public --schema private --schema matlogg_internal --level warning > "$rehearsal_output/lint.log" 2>&1
echo "PASS: historical staging state -> current migrations, pgTAP and schema lint ($rehearsal_output)"
