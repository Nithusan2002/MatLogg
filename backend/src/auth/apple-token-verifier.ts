import { Injectable } from '@nestjs/common';
import { createHash, createPublicKey } from 'node:crypto';
import * as jwt from 'jsonwebtoken';

type AppleJwk = JsonWebKey & { kid?: string; alg?: string };

export type AppleIdentity = { subject: string; email?: string };

@Injectable()
export class AppleTokenVerifier {
  private cachedKeys?: { expiresAt: number; keys: AppleJwk[] };

  async verify(identityToken: string, rawNonce: string): Promise<AppleIdentity> {
    const clientId = process.env.APPLE_CLIENT_ID?.trim();
    if (!clientId) throw new Error('APPLE_CLIENT_ID_NOT_CONFIGURED');
    const decoded = jwt.decode(identityToken, { complete: true });
    if (!decoded || typeof decoded === 'string' || decoded.header.alg !== 'RS256' || !decoded.header.kid) {
      throw new Error('INVALID_APPLE_TOKEN');
    }
    const key = (await this.keys()).find((candidate) => candidate.kid === decoded.header.kid);
    if (!key) throw new Error('UNKNOWN_APPLE_KEY');
    const publicKey = createPublicKey({ key: key as any, format: 'jwk' });
    const payload = jwt.verify(identityToken, publicKey, {
      algorithms: ['RS256'],
      issuer: 'https://appleid.apple.com',
      audience: clientId,
    }) as jwt.JwtPayload;
    const expectedNonce = createHash('sha256').update(rawNonce, 'utf8').digest('hex');
    if (payload.nonce !== expectedNonce || typeof payload.sub !== 'string') throw new Error('INVALID_APPLE_NONCE');
    return {
      subject: payload.sub,
      email: typeof payload.email === 'string' ? payload.email.trim().toLowerCase() : undefined,
    };
  }

  private async keys(): Promise<AppleJwk[]> {
    if (this.cachedKeys && this.cachedKeys.expiresAt > Date.now()) return this.cachedKeys.keys;
    const response = await fetch('https://appleid.apple.com/auth/keys');
    if (!response.ok) throw new Error('APPLE_KEYS_UNAVAILABLE');
    const body = await response.json() as { keys?: AppleJwk[] };
    if (!Array.isArray(body.keys) || body.keys.length === 0) throw new Error('APPLE_KEYS_UNAVAILABLE');
    this.cachedKeys = { keys: body.keys, expiresAt: Date.now() + 60 * 60 * 1000 };
    return body.keys;
  }
}
