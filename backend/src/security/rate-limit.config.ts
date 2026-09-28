import { ThrottlerModuleOptions } from '@nestjs/throttler';

export const RATE_LIMIT_WINDOW_MS = 60_000;
export const GLOBAL_RATE_LIMIT = 120;
export const AUTH_RATE_LIMIT = 10;
export const TOKEN_RATE_LIMIT = 30;
export const SYNC_RATE_LIMIT = 30;

export function rateLimitOptions(environment: NodeJS.ProcessEnv = process.env): ThrottlerModuleOptions {
  return {
    skipIf: () => environment.NODE_ENV === 'test',
    throttlers: [{
      name: 'default',
      ttl: RATE_LIMIT_WINDOW_MS,
      limit: GLOBAL_RATE_LIMIT,
    }],
  };
}
