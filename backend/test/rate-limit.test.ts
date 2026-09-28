import 'reflect-metadata';
import * as assert from 'node:assert/strict';
import { Controller, Get, Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { NestFactory } from '@nestjs/core';
import { Throttle, ThrottlerModule } from '@nestjs/throttler';
import { MatLoggThrottlerGuard } from '../src/security/matlogg-throttler.guard';
import { RATE_LIMIT_WINDOW_MS, rateLimitOptions } from '../src/security/rate-limit.config';

@Controller('limited')
class LimitedController {
  @Get()
  @Throttle({ default: { limit: 1, ttl: RATE_LIMIT_WINDOW_MS } })
  get() {
    return { status: 'ok' };
  }
}

@Module({
  imports: [ThrottlerModule.forRoot(rateLimitOptions({ NODE_ENV: 'production' }))],
  controllers: [LimitedController],
  providers: [{ provide: APP_GUARD, useClass: MatLoggThrottlerGuard }],
})
class RateLimitTestModule {}

async function run() {
  const app = await NestFactory.create(RateLimitTestModule, { logger: false });
  await app.listen(0, '127.0.0.1');
  const baseUrl = await app.getUrl();

  try {
    const accepted = await fetch(`${baseUrl}/limited`);
    assert.equal(accepted.status, 200);

    const rejected = await fetch(`${baseUrl}/limited`);
    assert.equal(rejected.status, 429);
    assert.ok(Number(rejected.headers.get('retry-after')) > 0);
    assert.deepEqual(await rejected.json(), {
      code: 'RATE_LIMITED',
      message: 'For mange forespørsler. Prøv igjen senere.',
    });
  } finally {
    await app.close();
  }

  console.log('Rate limit tests passed');
}

run().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
