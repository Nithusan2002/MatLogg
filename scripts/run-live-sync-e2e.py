#!/usr/bin/env python3
"""Run two iOS test hosts against disposable loopback Supabase; never a hosted project."""
import argparse
import json
import os
import pathlib
import plistlib
import re
import secrets
import signal
import subprocess
import tempfile
import time
import urllib.error
import urllib.request
import uuid
from urllib.parse import urlparse

parser = argparse.ArgumentParser()
parser.add_argument('--workdir', required=True, help='Running disposable Supabase workdir')
parser.add_argument('--xctestrun', required=True, help='Output of xcodebuild build-for-testing')
parser.add_argument('--simulator', required=True, help='Dedicated QA simulator UUID')
args = parser.parse_args()
workdir = pathlib.Path(args.workdir).resolve()
project = re.search(r'^project_id\s*=\s*"([^"]+)"', (workdir / 'supabase/config.toml').read_text(), re.M)
assert project and project[1] in ('matlogg-coverage-qa', 'matlogg-live-sync-qa'), 'Requires a dedicated live-sync QA project'
status = subprocess.run(['npx', 'supabase', 'status', '--workdir', str(workdir), '-o', 'json'],
                        capture_output=True, text=True, check=True)
config = json.loads(status.stdout)
base = config['API_URL']
assert urlparse(base).scheme == 'http' and urlparse(base).hostname in ('127.0.0.1', 'localhost'), 'Only loopback is allowed'
service, anon = config['SERVICE_ROLE_KEY'], config['ANON_KEY']
output = pathlib.Path(tempfile.mkdtemp(prefix='live-sync.', dir='build/coverage')).resolve()
original_run = pathlib.Path(args.xctestrun).resolve()
# Keep beside the original so __TESTROOT__ continues to resolve to Build/Products.
private_run = original_run.parent / ('live-sync-' + str(uuid.uuid4()) + '.xctestrun')
owner = None
functions = None
original_gate = None


def request(path, method='GET', payload=None, token=service):
    req = urllib.request.Request(base + path,
        data=None if payload is None else json.dumps(payload).encode(),
        headers={'apikey': anon, 'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json'}, method=method)
    try:
        response = urllib.request.urlopen(req, timeout=30)
    except urllib.error.HTTPError as error:
        response = error
    with response:
        body = response.read()
        return response.status, json.loads(body) if body else None


try:
    with (output / 'functions.log').open('w') as function_log:
        functions = subprocess.Popen(['npx', 'supabase', 'functions', 'serve', '--workdir', str(workdir)],
                                      stdout=function_log, stderr=subprocess.STDOUT, start_new_session=True)
    for attempt in range(40):
        code, response = request('/functions/v1/sync-events', 'POST', {}, token=anon)
        if code == 401 and isinstance(response, dict) and response.get('code') == 'UNAUTHORIZED':
            break
        time.sleep(1)
    else:
        raise RuntimeError('Local sync function did not become ready')
    code, rows = request('/rest/v1/app_config?key=eq.sync_enabled&select=value')
    assert code == 200 and len(rows) == 1
    original_gate = rows[0]['value']
    code, _ = request('/rest/v1/app_config?key=eq.sync_enabled', 'PATCH', {'value': True})
    assert code == 204
    email, password = f'live-sync-{uuid.uuid4()}@example.test', secrets.token_urlsafe(24)
    code, user = request('/auth/v1/admin/users', 'POST', {'email': email, 'password': password, 'email_confirm': True})
    assert code in (200, 201), 'Synthetic account creation failed'
    owner = user['id']
    env = {'MATLOGG_LIVE_SYNC_RUN': str(uuid.uuid4()), 'MATLOGG_LIVE_SYNC_URL': base,
           'MATLOGG_LIVE_SYNC_KEY': anon, 'MATLOGG_LIVE_SYNC_EMAIL': email, 'MATLOGG_LIVE_SYNC_PASSWORD': password}
    run = plistlib.loads(original_run.read_bytes())
    targets = [t for c in run['TestConfigurations'] for t in c['TestTargets'] if t['BlueprintName'] == 'MatLoggTests']
    assert len(targets) == 1, 'Expected a single unit test target'
    targets[0].setdefault('EnvironmentVariables', {}).update(env)
    private_run.write_bytes(plistlib.dumps(run))
    os.chmod(private_run, 0o600)
    for index, stage in enumerate(('uploadStopsAfterServerCommitBeforeLocalAck', 'newProcessReplaysSameEventsWithoutDuplicates'), 1):
        with (output / f'stage-{index}.log').open('w') as log:
            result = subprocess.run(['xcodebuild', 'test-without-building', '-xctestrun', str(private_run),
                '-destination', 'platform=iOS Simulator,id=' + args.simulator,
                '-only-testing:MatLoggTests/LiveSupabaseSyncTests/' + stage + '()',
                '-parallel-testing-enabled', 'NO', '-test-timeouts-enabled', 'YES',
                '-default-test-execution-time-allowance', '60', '-maximum-test-execution-time-allowance', '90',
                '-resultBundlePath', str(output / f'stage-{index}.xcresult')], stdout=log, stderr=subprocess.STDOUT)
        assert result.returncode == 0, f'Live sync stage {index} failed; see {output}/stage-{index}.log'
        text = (output / f'stage-{index}.log').read_text()
        assert 'Test run with 1 test' in text and 'passed after' in text, f'Stage {index} did not execute exactly one test'
        print(f'PASS: live sync stage {index}', flush=True)
    code, logs = request('/rest/v1/food_logs?owner_id=eq.' + owner + '&select=id,kcal,amount,unit')
    assert code == 200 and len(logs) == 1 and logs[0]['kcal'] == 123.75 and logs[0]['amount'] == 125 and logs[0]['unit'] == 'g'
    code, inbox = request('/rest/v1/event_inbox?owner_id=eq.' + owner + '&select=event_id')
    assert code == 200 and len(inbox) == 2
    print(f'PASS: two separate iOS processes, real Supabase, stable replay, one log; results: {output}', flush=True)
finally:
    private_run.unlink(missing_ok=True)
    cleanup_errors = []
    if original_gate is not None:
        code, _ = request('/rest/v1/app_config?key=eq.sync_enabled', 'PATCH', {'value': original_gate})
        if code != 204:
            cleanup_errors.append('restore sync gate')
    if owner is not None:
        # Products can be referenced by logs; remove synthetic logs before their product.
        for table in ('food_logs', 'products'):
            code, _ = request('/rest/v1/' + table + '?owner_id=eq.' + owner, 'DELETE')
            if code != 204:
                cleanup_errors.append('delete synthetic ' + table)
        code, _ = request('/auth/v1/admin/users/' + owner, 'DELETE')
        if code not in (200, 204, 404):
            cleanup_errors.append('delete synthetic account')
    if functions is not None:
        try:
            os.killpg(functions.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        try:
            functions.wait(timeout=10)
        except subprocess.TimeoutExpired:
            os.killpg(functions.pid, signal.SIGKILL)
            functions.wait()
    if cleanup_errors:
        raise RuntimeError('Local cleanup failed: ' + ', '.join(cleanup_errors))
