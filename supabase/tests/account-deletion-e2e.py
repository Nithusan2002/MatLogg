"""Local-only Auth -> delete-account -> purge-accounts regression test.
Run with local functions served using --env-file containing PURGE_CRON_SECRET.
No hosted project or production credentials are accepted.
"""
import argparse
import json
import secrets
import subprocess
import urllib.error
import urllib.request
import uuid
from pathlib import Path
from urllib.parse import urlparse

parser = argparse.ArgumentParser()
parser.add_argument('--workdir', required=True)
parser.add_argument('--env-file', required=True)
args = parser.parse_args()
status = subprocess.run(['npx', 'supabase', 'status', '--workdir', args.workdir, '-o', 'json'],
                        capture_output=True, text=True, check=True)
config = json.loads(status.stdout)
base = config['API_URL']
assert urlparse(base).hostname in ('127.0.0.1', 'localhost'), 'Only local Supabase is allowed'
service = config['SERVICE_ROLE_KEY']
anon = config['ANON_KEY']
cron_secret = next(line.split('=', 1)[1] for line in Path(args.env_file).read_text().splitlines()
                   if line.startswith('PURGE_CRON_SECRET='))


def request(path, method='GET', payload=None, token=None, headers=None):
    merged = {'apikey': anon, 'Authorization': 'Bearer ' + (token or service),
              'Content-Type': 'application/json'}
    if headers:
        merged.update(headers)
    req = urllib.request.Request(base + path,
        data=None if payload is None else json.dumps(payload).encode(), headers=merged, method=method)
    try:
        response = urllib.request.urlopen(req, timeout=30)
    except urllib.error.HTTPError as error:
        response = error
    with response:
        body = response.read()
        return response.status, json.loads(body) if body else None


owners = []
products = []
try:
    accounts = []
    for index in range(2):
        email = f'deletion-{uuid.uuid4()}@example.test'
        password = secrets.token_urlsafe(24)
        code, user = request('/auth/v1/admin/users', 'POST',
                             {'email': email, 'password': password, 'email_confirm': True})
        assert code in (200, 201), 'Synthetic Auth account creation failed'
        owners.append(user['id'])
        accounts.append((email, password))
        product = str(uuid.uuid4())
        products.append(product)
        code, _ = request('/rest/v1/products', 'POST',
                          {'id': product, 'owner_id': user['id'], 'name': 'Synthetic private product',
                           'source': 'user', 'nutrients_per_100g': {}, 'updated_at': '2026-10-07T00:00:00Z'})
        assert code == 201, 'Synthetic product creation failed'

    email, password = accounts[0]
    code, session = request('/auth/v1/token?grant_type=password', 'POST',
                            {'email': email, 'password': password}, token=anon)
    assert code == 200
    code, _ = request('/functions/v1/delete-account', 'POST', {}, token=anon)
    assert code == 401, 'Unauthenticated deletion must fail'
    code, receipt = request('/functions/v1/delete-account', 'POST', {}, token=session['access_token'])
    assert code == 200 and receipt['code'] == 'ACCOUNT_PENDING_DELETION', 'Deletion must be confirmed'
    assert receipt['deletionCompleted'] is True, 'Deletion must finish in the same request'
    code, _ = request('/auth/v1/token?grant_type=password', 'POST',
                      {'email': email, 'password': password}, token=anon)
    assert code >= 400, 'Deleted account must not sign in'
    code, rows = request('/rest/v1/products?id=eq.' + products[0] + '&select=id', token=session['access_token'])
    assert code == 200 and rows == [], 'Old token must lose RLS read access immediately'
    code, _ = request('/functions/v1/purge-accounts', 'POST', {}, token=anon)
    assert code == 401, 'Purge requires the cron secret'
    code, result = request('/functions/v1/purge-accounts', 'POST', {},
                           headers={'X-Cron-Secret': cron_secret})
    assert code == 200 and result['purged'] == 0 and result['failed'] == 0, 'Completed immediate deletion must leave no queued purge'
    code, _ = request('/auth/v1/admin/users/' + owners[0])
    assert code == 404, 'Auth user must be hard deleted'
    code, rows = request('/rest/v1/products?id=eq.' + products[0] + '&select=id')
    assert code == 200 and rows == [], 'Owned product must be deleted'
    code, rows = request('/rest/v1/products?id=eq.' + products[1] + '&select=id')
    assert code == 200 and len(rows) == 1, 'Other owner product must survive'
    code, _ = request('/auth/v1/admin/users/' + owners[1])
    assert code == 200, 'Other Auth account must survive'
    code, _ = request('/rest/v1/profiles?id=eq.' + owners[1], 'PATCH',
                      {'deletion_requested_at': '2026-01-01T00:00:00Z', 'purge_at': '2026-01-01T00:00:00Z'})
    assert code == 204
    code, result = request('/functions/v1/purge-accounts', 'POST', {},
                           headers={'X-Cron-Secret': cron_secret})
    assert code == 200 and result == {'purged': 1, 'failed': 0}, 'Queued deletion must retry successfully'
    code, _ = request('/auth/v1/admin/users/' + owners[1])
    assert code == 404, 'Retry must hard delete Auth'
    code, result = request('/functions/v1/purge-accounts', 'POST', {},
                           headers={'X-Cron-Secret': cron_secret})
    assert code == 200 and result == {'purged': 0, 'failed': 0}, 'Repeated purge must be safe'
    print('PASS: local Auth deletion, sign-in denial, product purge, owner isolation and repeated purge')
finally:
    for product in products:
        request('/rest/v1/products?id=eq.' + product, 'DELETE')
    for owner in owners:
        request('/auth/v1/admin/users/' + owner, 'DELETE')
