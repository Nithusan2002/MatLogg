#!/usr/bin/env bash
set -euo pipefail
set -m
sync_workdir="${1:-.}"
sync_script_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
sync_log="$(mktemp)"
npx supabase functions serve --workdir "$sync_workdir" > "$sync_log" 2>&1 &
sync_function_pid=$!
trap 'kill -- "-$sync_function_pid" 2>/dev/null || true; rm -f "$sync_log"' EXIT
sync_status_json="$(npx supabase status --workdir "$sync_workdir" -o json)"
sync_api_url="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["API_URL"])' <<< "$sync_status_json")"
sync_anon_key="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["ANON_KEY"])' <<< "$sync_status_json")"
if [[ "$sync_api_url" != http://127.0.0.1:* && "$sync_api_url" != http://localhost:* ]]; then
  echo 'Only local Supabase is allowed' >&2
  exit 1
fi
for ((sync_attempt=0; sync_attempt<30; sync_attempt++)); do
  sync_response="$(curl --silent --request POST --header "Authorization: Bearer $sync_anon_key" "$sync_api_url/functions/v1/sync-events" || true)"
  if [[ "$sync_response" == *'"code":"UNAUTHORIZED"'* ]]; then
    python3 "$sync_script_dir/sync-http-e2e.py" --workdir "$sync_workdir"
    exit 0
  fi
  sleep 1
done
echo 'Local sync function did not become ready' >&2
exit 1
