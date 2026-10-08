#!/usr/bin/env bash
set -euo pipefail
# Give the functions server its own process group so wrapper and CLI both stop.
set -m

project_workdir="${1:-.}"
script_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
deletion_env_file="$(mktemp)"
python3 -c 'import secrets; print("PURGE_CRON_SECRET=" + secrets.token_hex(32))' > "$deletion_env_file"
npx supabase functions serve --workdir "$project_workdir" --env-file "$deletion_env_file" > /tmp/matlogg-account-deletion-functions.log 2>&1 &
deletion_function_pid=$!
trap 'kill -- "-$deletion_function_pid" 2>/dev/null || true; rm -f "$deletion_env_file"' EXIT

deletion_api_url="$(npx supabase status --workdir "$project_workdir" -o json | python3 -c 'import json,sys; print(json.load(sys.stdin)["API_URL"])')"
if [[ "$deletion_api_url" != http://127.0.0.1:* && "$deletion_api_url" != http://localhost:* ]]; then
  echo 'Only local Supabase is allowed' >&2
  exit 1
fi
for ((deletion_attempt=0; deletion_attempt<30; deletion_attempt++)); do
  deletion_response="$(curl --silent --request POST "$deletion_api_url/functions/v1/purge-accounts" || true)"
  if [[ "$deletion_response" == *'"code":"UNAUTHORIZED"'* ]]; then
    python3 "$script_dir/account-deletion-e2e.py" --workdir "$project_workdir" --env-file "$deletion_env_file"
    exit 0
  fi
  sleep 1
done
echo 'Local deletion functions did not become ready' >&2
exit 1
