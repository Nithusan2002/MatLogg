import * as assert from 'node:assert/strict';
import { runtimeConfig } from '../src/config/runtime.config';
import {
  AUTH_RATE_LIMIT,
  GLOBAL_RATE_LIMIT,
  RATE_LIMIT_WINDOW_MS,
  SYNC_RATE_LIMIT,
  TOKEN_RATE_LIMIT,
} from '../src/security/rate-limit.config';

const development = runtimeConfig({});
assert.equal(development.isProduction, false);
assert.equal(development.port, 4000);
assert.equal(development.swaggerEnabled, true);
assert.deepEqual(development.corsAllowedOrigins, []);

const production = runtimeConfig({
  NODE_ENV: 'production',
  DATABASE_URL: 'postgresql://matlogg:secret@db:5432/matlogg',
  JWT_SECRET: 'a-production-secret-that-is-longer-than-32-characters',
  PORT: '8080',
  TRUST_PROXY_HOPS: '1',
  CORS_ALLOWED_ORIGINS: 'https://matlogg.app,https://admin.matlogg.app',
});
assert.equal(production.isProduction, true);
assert.equal(production.port, 8080);
assert.equal(production.trustProxyHops, 1);
assert.equal(production.swaggerEnabled, false);
assert.deepEqual(production.corsAllowedOrigins, ['https://matlogg.app', 'https://admin.matlogg.app']);

assert.throws(() => runtimeConfig({ NODE_ENV: 'preview' }), /NODE_ENV/);
assert.throws(() => runtimeConfig({ NODE_ENV: 'production' }), /DATABASE_URL/);
assert.throws(() => runtimeConfig({
  NODE_ENV: 'production',
  DATABASE_URL: 'postgresql://db',
  JWT_SECRET: 'too-short',
}), /at least 32 characters/);
assert.throws(() => runtimeConfig({ PORT: '0' }), /PORT/);
assert.throws(() => runtimeConfig({ TRUST_PROXY_HOPS: '-1' }), /TRUST_PROXY_HOPS/);
assert.throws(() => runtimeConfig({
  NODE_ENV: 'production',
  DATABASE_URL: 'postgresql://db',
  JWT_SECRET: 'a-production-secret-that-is-longer-than-32-characters',
  CORS_ALLOWED_ORIGINS: 'http://matlogg.app',
}), /HTTPS origins/);

assert.equal(RATE_LIMIT_WINDOW_MS, 60_000);
assert.equal(GLOBAL_RATE_LIMIT, 120);
assert.equal(AUTH_RATE_LIMIT, 10);
assert.equal(TOKEN_RATE_LIMIT, 30);
assert.equal(SYNC_RATE_LIMIT, 30);

console.log('Runtime configuration tests passed');
