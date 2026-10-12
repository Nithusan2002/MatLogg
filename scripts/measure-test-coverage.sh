#!/usr/bin/env bash
set -euo pipefail

# Use a fresh output directory so profiles from different runs cannot mix.
mode="${1:-}"
if [[ "$mode" != ios && "$mode" != functions ]]; then
  echo "Usage: $0 ios '<simulator destination>' | functions" >&2
  exit 2
fi
if [[ "$mode" == ios && -z "${2:-}" ]]; then
  echo "Provide a dedicated QA simulator destination." >&2
  exit 2
fi
cd "$(dirname "$0")/.."
mkdir -p build/coverage
output=$(mktemp -d "build/coverage/${mode}.XXXXXX")
git rev-parse HEAD > "$output/commit.txt"
git status --short > "$output/working-tree.txt"
if [[ "$mode" == ios ]]; then
  xcodebuild -version > "$output/tool-version.txt"
  set +e
  xcodebuild test -project MatLogg.xcodeproj -scheme MatLogg \
    -destination "$2" -only-testing:MatLoggTests \
    -enableCodeCoverage YES -parallel-testing-enabled NO \
    -resultBundlePath "$output/tests.xcresult" CODE_SIGNING_ALLOWED=NO \
    2>&1 | tee "$output/test.log"
  test_status=${PIPESTATUS[0]}
  set -e
  xcrun xccov view --report --json "$output/tests.xcresult" > "$output/report.json"
  xcrun xccov view --report "$output/tests.xcresult" > "$output/report.txt"
  echo "Coverage results: $output"
  exit "$test_status"
else
  deno --version > "$output/tool-version.txt"
  deno test --allow-env --coverage="$output/profiles" supabase/functions/tests \
    2>&1 | tee "$output/test.log"
fi
echo "Coverage results: $output"
