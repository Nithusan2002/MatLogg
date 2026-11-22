#!/bin/sh
set -eu

# This path is exclusively a generated resource folder inside the build product.
destination="${TARGET_BUILD_DIR:?}/${UNLOCALIZED_RESOURCES_FOLDER_PATH:?}/SporMascotQA"
case "${CONFIGURATION:-}" in
    Debug|Debug-SporMascotQA) qa_configuration=YES ;;
    *) qa_configuration=NO ;;
esac
if [ "$qa_configuration" != "YES" ] || [ "${SPOR_MASCOT_QA:-NO}" != "YES" ]; then
    if [ -d "$destination" ]; then rm -rf "$destination"; fi
    exit 0
fi
case " ${SWIFT_ACTIVE_COMPILATION_CONDITIONS:-} " in
    *" SPOR_MASCOT_QA "*) ;;
    *) echo 'error: Mascot QA resources require SPOR_MASCOT_QA compilation condition.' >&2; exit 1 ;;
esac
source_dir="${SRCROOT:?}/qa-assets/spor"
mkdir -p "$destination"
for resource in manifest.json poster.png spor-idle.usdz spor-greeting.usdz spor-walk.usdz; do
    test -f "$source_dir/$resource"
    cp "$source_dir/$resource" "$destination/$resource"
done
