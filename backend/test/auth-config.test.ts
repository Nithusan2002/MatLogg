import * as assert from 'node:assert/strict';
import { isDevLoginEnabled, jwtSecret } from '../src/auth/auth.config';

assert.throws(() => jwtSecret({}), /JWT_SECRET must be configured/);
assert.equal(jwtSecret({ JWT_SECRET: 'test-only-secret' }), 'test-only-secret');
assert.throws(
  () => jwtSecret({ JWT_SECRET: 'dev-secret', NODE_ENV: 'production' }),
  /development value/,
);
assert.equal(isDevLoginEnabled({ DEV_LOGIN_ENABLED: 'true' }), true);
assert.equal(isDevLoginEnabled({ DEV_LOGIN_ENABLED: 'false' }), false);
assert.equal(isDevLoginEnabled({ DEV_LOGIN_ENABLED: 'true', NODE_ENV: 'production' }), false);

console.log('Auth configuration tests passed');
