#!/bin/bash
# Local Release archive and device variants; never uploads to App Store Connect.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
if ! mkdir build/.app-size-lock 2>/dev/null; then
  echo "Another size measurement is running (build/.app-size-lock)." >&2
  exit 1
fi
trap 'rmdir build/.app-size-lock' EXIT
output="${1:-$PWD/build/app-size/$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$output"
output="$(cd "$output" && pwd)"
archive="$output/MatLogg.xcarchive"
if [[ -e "$archive" ]]; then
  echo "Archive already exists: $archive. Use a new output directory." >&2
  exit 1
fi
{
  git rev-parse HEAD
  git status --short
  xcodebuild -version
} > "$output/build-context.txt"
xcodebuild -project MatLogg.xcodeproj -scheme MatLogg \
  -configuration Release -destination 'generic/platform=iOS' \
  -disableAutomaticPackageResolution -archivePath "$archive" \
  archive > "$output/archive.log" 2>&1 || {
    tail -40 "$output/archive.log"
    exit 1
  }
python3 - "$archive" "$output" <<'PY'
import json
import sys
from pathlib import Path

archive, output = map(Path, sys.argv[1:])
app = archive / "Products/Applications/MatLogg.app"
files = sorted((p for p in app.rglob("*") if p.is_file()),
               key=lambda p: p.stat().st_size, reverse=True)
report = {
    "measurement": "local signed Release archive; not App Store download size",
    "bundle_bytes": sum(p.stat().st_size for p in files),
    "files": [{"path": str(p.relative_to(app)), "bytes": p.stat().st_size}
              for p in files],
}
(output / "bundle-size.json").write_text(json.dumps(report, indent=2) + "\n")
print(f"Release bundle: {report['bundle_bytes'] / 1_000_000:.2f} MB")
PY
cat > "$output/ExportOptions.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>method</key><string>debugging</string>
<key>destination</key><string>export</string>
<key>signingStyle</key><string>automatic</string>
<key>thinning</key><string>&lt;thin-for-all-variants&gt;</string>
<key>stripSwiftSymbols</key><true/>
</dict></plist>
PLIST
xcodebuild -exportArchive -archivePath "$archive" \
  -exportOptionsPlist "$output/ExportOptions.plist" \
  -exportPath "$output/export" > "$output/export.log" 2>&1 || {
    echo "Archive measured, but device export failed. See $output/export.log" >&2
    tail -40 "$output/export.log"
    exit 1
  }
echo "Reports: $output/bundle-size.json and $output/export/App Thinning Size Report.txt"
