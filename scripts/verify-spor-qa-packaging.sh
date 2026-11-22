#!/bin/sh
set -eu
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
scratch=$(mktemp -d /tmp/spor-packaging.XXXXXX)
trap 'rm -rf "$scratch"' EXIT HUP INT TERM
export SRCROOT="$repo_root" TARGET_BUILD_DIR="$scratch" UNLOCALIZED_RESOURCES_FOLDER_PATH=Probe.app
script="$repo_root/scripts/copy-spor-qa-assets.sh"
destination="$scratch/Probe.app/SporMascotQA"

CONFIGURATION=Debug-SporMascotQA SPOR_MASCOT_QA=YES SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG SPOR_MASCOT_QA' /bin/sh "$script"
for name in manifest.json poster.png spor-idle.usdz spor-greeting.usdz spor-walk.usdz; do
    cmp "$repo_root/qa-assets/spor/$name" "$destination/$name"
done
CONFIGURATION=Debug SPOR_MASCOT_QA=NO /bin/sh "$script"
test ! -e "$destination"
CONFIGURATION=Debug SPOR_MASCOT_QA=YES SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG SPOR_MASCOT_QA' /bin/sh "$script"
CONFIGURATION=Release SPOR_MASCOT_QA=YES /bin/sh "$script"
test ! -e "$destination"
if CONFIGURATION=Debug SPOR_MASCOT_QA=YES SWIFT_ACTIVE_COMPILATION_CONDITIONS=DEBUG /bin/sh "$script" 2>/dev/null; then
    echo 'QA resources were accepted without the compiler condition.' >&2
    exit 1
fi
test ! -e "$destination"
echo 'SPOR_PACKAGING_OK: QA scheme copies, legacy Debug opt-in copies, normal Debug cleans stale files, Release excludes, missing compile condition fails.'

# Exercise Xcode's literal output permissions, which an unsandboxed copy misses.
if [ "$(uname -s)" = Darwin ] && command -v sandbox-exec >/dev/null 2>&1; then
    python3 - "$repo_root" "$scratch" <<'PY'
import json
import os
from pathlib import Path
import plistlib
import subprocess
import sys

repo, scratch = (Path(p).resolve() for p in sys.argv[1:])
project = plistlib.loads(subprocess.check_output([
    'plutil', '-convert', 'xml1', '-o', '-', str(repo / 'MatLogg.xcodeproj/project.pbxproj')
]))
phase = project['objects']['A80000000000000000000001']
build = scratch / 'sandboxed-build'
(build / 'Probe.app').mkdir(parents=True)
outputs = [p.replace('$(TARGET_BUILD_DIR)', str(build)).replace(
    '$(UNLOCALIZED_RESOURCES_FOLDER_PATH)', 'Probe.app') for p in phase['outputPaths']]
profile = scratch / 'outputs.sb'
profile.write_text('(version 1)\n(allow default)\n'
    + '(deny file-write* (subpath ' + json.dumps(str(build)) + '))\n'
    + '\n'.join('(allow file-read* file-write* (literal ' + json.dumps(p) + '))' for p in outputs))
env = dict(os.environ, TARGET_BUILD_DIR=str(build), CONFIGURATION='Debug-SporMascotQA',
    SPOR_MASCOT_QA='YES', SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG SPOR_MASCOT_QA')
command = ['sandbox-exec', '-f', str(profile), '/bin/sh', str(repo / 'scripts/copy-spor-qa-assets.sh')]
for _ in range(2):
    subprocess.run(command, env=env, check=True)
    for source in (repo / 'qa-assets/spor').iterdir():
        assert (build / 'Probe.app/SporMascotQA' / source.name).read_bytes() == source.read_bytes()
subprocess.run(command, env=dict(env, CONFIGURATION='Debug', SPOR_MASCOT_QA='NO'), check=True)
assert not (build / 'Probe.app/SporMascotQA').exists()
print('SPOR_SANDBOX_OK: Initial copy, overwrite and stale QA cleanup respect declared outputs.')
PY
fi
