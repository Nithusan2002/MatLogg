import * as assert from 'node:assert/strict';
import { createHash, generateKeyPairSync } from 'node:crypto';
import * as jwt from 'jsonwebtoken';
import { AppleTokenVerifier } from '../src/auth/apple-token-verifier';

async function run() {
  const originalFetch = global.fetch;
  const originalClientId = process.env.APPLE_CLIENT_ID;
  const { privateKey, publicKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
  const jwk = publicKey.export({ format: 'jwk' });
  const key = { ...jwk, kid: 'test-key', alg: 'RS256', use: 'sig' };
  global.fetch = (async () => new Response(JSON.stringify({ keys: [key] }), { status: 200 })) as typeof fetch;
  process.env.APPLE_CLIENT_ID = 'com.nithusan.MatLogg';
  try {
    const nonce = 'raw-nonce-with-enough-entropy';
    const token = jwt.sign(
      {
        sub: 'apple-subject',
        email: 'Relay@PrivateRelay.AppleID.com',
        nonce: createHash('sha256').update(nonce, 'utf8').digest('hex'),
      },
      privateKey,
      {
        algorithm: 'RS256',
        keyid: 'test-key',
        issuer: 'https://appleid.apple.com',
        audience: 'com.nithusan.MatLogg',
        expiresIn: '5m',
      },
    );
    const verifier = new AppleTokenVerifier();
    const identity = await verifier.verify(token, nonce);
    assert.deepEqual(identity, { subject: 'apple-subject', email: 'relay@privaterelay.appleid.com' });
    await assert.rejects(() => verifier.verify(token, 'wrong-nonce'), /INVALID_APPLE_NONCE/);
    console.log('Apple token verifier tests passed');
  } finally {
    global.fetch = originalFetch;
    if (originalClientId === undefined) delete process.env.APPLE_CLIENT_ID;
    else process.env.APPLE_CLIENT_ID = originalClientId;
  }
}

run().catch((error) => { console.error(error); process.exitCode = 1; });
