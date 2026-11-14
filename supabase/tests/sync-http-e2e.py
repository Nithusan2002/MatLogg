"""HTTP/Auth/RPC sync regression checks against a disposable local Supabase only."""
import argparse
import base64
import hashlib
import hmac
import json
import secrets
import subprocess
import time
import urllib.error
import urllib.request
import uuid
from urllib.parse import urlparse

parser = argparse.ArgumentParser()
parser.add_argument('--workdir', default='.')
args = parser.parse_args()
status = subprocess.run(['npx', 'supabase', 'status', '--workdir', args.workdir, '-o', 'json'],
                        capture_output=True, text=True, check=True)
config = json.loads(status.stdout)
base = config['API_URL']
assert urlparse(base).hostname in ('127.0.0.1', 'localhost'), 'Only local Supabase is allowed'
anon, service = config['ANON_KEY'], config['SERVICE_ROLE_KEY']


def request(path, method='POST', payload=None, token=None, raw=None):
    headers = {'apikey': anon, 'Content-Type': 'application/json'}
    if token is not None:
        headers['Authorization'] = 'Bearer ' + token
    data = raw if raw is not None else (json.dumps(payload).encode() if payload is not None else None)
    req = urllib.request.Request(base + path, data=data, headers=headers, method=method)
    try:
        response = urllib.request.urlopen(req, timeout=30)
    except urllib.error.HTTPError as error:
        response = error
    with response:
        body = response.read()
        return response.status, json.loads(body) if body else None


def event(entity_id=None, event_id=None):
    entity_id = entity_id or str(uuid.uuid4())
    payload = {'id': entity_id, 'date': '2026-10-12T12:00:00Z', 'meal': 'lunsj',
               'grams': 125, 'unit': 'g', 'kcal': 123.75, 'protein': 10, 'carbs': 12, 'fat': 2}
    return {'eventId': event_id or str(uuid.uuid4()), 'type': 'log.upsert',
            'entityId': entity_id, 'schemaVersion': 1, 'createdAt': '2026-10-12T12:00:00Z',
            'payload': base64.b64encode(json.dumps(payload).encode()).decode()}


def envelope(events):
    return {'deviceId': str(uuid.uuid4()), 'clientTime': '2026-10-12T12:00:00Z', 'events': events}


def rows(table, query, token=service):
    code, body = request('/rest/v1/' + table + '?' + query, 'GET', token=token)
    assert code == 200, 'Local row query failed'
    return body


owners = []
original = rows('app_config', 'key=eq.sync_enabled&select=value')[0]['value']
try:
    tokens = []
    for _ in range(2):
        email, password = f'sync-{uuid.uuid4()}@example.test', secrets.token_urlsafe(24)
        code, user = request('/auth/v1/admin/users', payload={'email': email, 'password': password,
                                                           'email_confirm': True}, token=service)
        assert code in (200, 201), 'Synthetic account creation failed'
        owners.append(user['id'])
        code, session = request('/auth/v1/token?grant_type=password',
                                payload={'email': email, 'password': password}, token=anon)
        assert code == 200, 'Synthetic sign-in failed'
        tokens.append(session['access_token'])
    endpoint = '/functions/v1/sync-events'
    body = envelope([event()])
    for token in (None, anon, 'invalid-token'):
        code, _ = request(endpoint, payload=body, token=token)
        assert code == 401, 'Missing or invalid user token must be rejected'

    # A correctly signed, expired local JWT must also be rejected (no secret is printed).
    def b64(data):
        return base64.urlsafe_b64encode(data).rstrip(b'=')
    header = b64(json.dumps({'alg': 'HS256', 'typ': 'JWT'}).encode())
    claims = b64(json.dumps({'sub': owners[0], 'aud': 'authenticated', 'role': 'authenticated',
                             'exp': int(time.time()) - 3600}).encode())
    unsigned = header + b'.' + claims
    signature = b64(hmac.new(config['JWT_SECRET'].encode(), unsigned, hashlib.sha256).digest())
    code, _ = request(endpoint, payload=body, token=(unsigned + b'.' + signature).decode())
    assert code == 401, 'Expired user token must be rejected'

    code, _ = request('/rest/v1/app_config?key=eq.sync_enabled', 'PATCH', {'value': False}, service)
    assert code == 204
    code, result = request(endpoint, payload=body, token=tokens[0])
    assert code == 503 and result['code'] == 'SYNC_DISABLED'
    code, _ = request('/rest/v1/app_config?key=eq.sync_enabled', 'PATCH', {'value': True}, service)
    assert code == 204
    code, result = request(endpoint, 'GET', token=tokens[0])
    assert code == 405 and result['code'] == 'METHOD_NOT_ALLOWED'
    for raw in (b'not-json', b'{}'):
        code, result = request(endpoint, raw=raw, token=tokens[0])
        assert code == 400 and result['code'] == 'VALIDATION_ERROR'

    first, invalid = event(), event()
    invalid['schemaVersion'] = 999
    code, result = request(endpoint, payload=envelope([first, invalid]), token=tokens[0])
    assert code == 201 and result['ackedEventIds'] == [first['eventId']]
    assert result['rejected'][0]['eventId'] == invalid['eventId']
    assert result['rejected'][0]['code'] == 'UNSUPPORTED_SCHEMA'
    assert rows('event_inbox', 'event_id=eq.' + invalid['eventId'] + '&select=event_id') == []
    saved = rows('food_logs', 'id=eq.' + first['entityId'] + '&select=id,kcal,amount,unit,owner_id')
    assert len(saved) == 1 and saved[0]['owner_id'] == owners[0]
    assert saved[0]['kcal'] == 123.75 and saved[0]['amount'] == 125 and saved[0]['unit'] == 'g'

    # Server has committed; pretend its ACK was lost and deliver the identical event after restart.
    persisted = json.loads(json.dumps(first))
    code, replay = request(endpoint, payload=envelope([persisted]), token=tokens[0])
    assert code == 201 and replay['ackedEventIds'] == [first['eventId']] and replay['rejected'] == []
    assert len(rows('food_logs', 'id=eq.' + first['entityId'] + '&select=id')) == 1
    assert len(rows('event_inbox', 'event_id=eq.' + first['eventId'] + '&select=event_id')) == 1

    # Both foreign replay and fresh overwrite must fail through the authenticated RPC.
    for foreign in (first, event(entity_id=first['entityId'])):
        code, result = request(endpoint, payload=envelope([foreign]), token=tokens[1])
        assert code == 201 and result['ackedEventIds'] == [] and len(result['rejected']) == 1
    assert rows('food_logs', 'id=eq.' + first['entityId'] + '&select=id', tokens[1]) == []

    oversized = [event() for _ in range(51)]
    code, result = request(endpoint, payload=envelope(oversized), token=tokens[0])
    assert code == 201 and result['ackedEventIds'] == [] and len(result['rejected']) == 51
    assert all(item['code'] == 'VALIDATION_ERROR' for item in result['rejected'])
    assert rows('food_logs', 'owner_id=eq.' + owners[0] + '&select=id') == [{'id': first['entityId']}]
    print('PASS: sync HTTP auth, expired token, disabled gate, validation, partial ACK, replay and owner isolation')
finally:
    cleanup_errors = []
    code, _ = request('/rest/v1/app_config?key=eq.sync_enabled', 'PATCH', {'value': original}, service)
    if code != 204:
        cleanup_errors.append('restore sync gate')
    for owner in owners:
        code, _ = request('/auth/v1/admin/users/' + owner, 'DELETE', token=service)
        if code not in (200, 204, 404):
            cleanup_errors.append('delete synthetic account')
    if cleanup_errors:
        raise RuntimeError('Local cleanup failed: ' + ', '.join(cleanup_errors))
