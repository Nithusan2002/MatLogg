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
cp supabase/migrations/*.sql "$rehearsal_workdir/supabase/migrations/"
cp -R supabase/tests "$rehearsal_workdir/supabase/tests"
npx supabase db push --local --include-all --workdir "$rehearsal_workdir" > "$rehearsal_output/migrations.log" 2>&1
npx supabase test db --workdir "$rehearsal_workdir" > "$rehearsal_output/tests.log" 2>&1
npx supabase db lint --local --workdir "$rehearsal_workdir" --schema public --schema private --schema matlogg_internal --level warning > "$rehearsal_output/lint.log" 2>&1
echo "PASS: historical staging state -> current migrations, pgTAP and schema lint ($rehearsal_output)"
