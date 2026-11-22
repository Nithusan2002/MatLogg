#!/bin/sh
set -eu
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
scratch=$(mktemp -d /tmp/spor-packaging.XXXXXX)
trap 'rm -rf "$scratch"' EXIT HUP INT TERM
export SRCROOT="$repo_root" TARGET_BUILD_DIR="$scratch" UNLOCALIZED_RESOURCES_FOLDER_PATH=Probe.app
script="$repo_root/scripts/copy-spor-qa-assets.sh"
destination="$scratch/Probe.app/SporMascotQA"

CONFIGURATION=Debug SPOR_MASCOT_QA=YES SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG SPOR_MASCOT_QA' /bin/sh "$script"
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
echo 'SPOR_PACKAGING_OK: QA copies, normal Debug cleans stale files, Release excludes, missing compile condition fails.'
