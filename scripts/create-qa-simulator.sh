#!/usr/bin/env bash
set -euo pipefail

qa_sdk_version=$(xcodebuild -version -sdk iphonesimulator ProductVersion)
qa_runtimes=$(mktemp)
trap 'rm -f "$qa_runtimes"' EXIT
xcrun simctl list runtimes --json > "$qa_runtimes"
qa_runtime_id=$(python3 - "$qa_runtimes" "$qa_sdk_version" <<'PY'
import json
import sys

def version(value):
    parts = tuple(int(part) for part in value.split("."))
    return parts + (0,) * (3 - len(parts))

with open(sys.argv[1]) as source:
    runtimes = json.load(source)["runtimes"]
compatible = [
    runtime for runtime in runtimes
    if runtime.get("isAvailable") and runtime["name"].startswith("iOS ")
    and (18, 0, 0) <= version(runtime["version"]) <= version(sys.argv[2])
]
if not compatible:
    sys.exit("No available iOS runtime compatible with the selected Xcode and iPhone 16 Pro")
print(max(compatible, key=lambda runtime: version(runtime["version"]))["identifier"])
PY
)
qa_simulator_id=$(xcrun simctl create "MatLogg Coverage QA" com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro "$qa_runtime_id")
xcrun simctl boot "$qa_simulator_id" >&2
xcrun simctl bootstatus "$qa_simulator_id" -b >&2
printf '%s\n' "$qa_simulator_id"
