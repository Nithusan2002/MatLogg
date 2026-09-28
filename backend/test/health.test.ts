import * as assert from 'node:assert/strict';
import { ServiceUnavailableException } from '@nestjs/common';
import { HealthController } from '../src/health/health.controller';
import { PrismaService } from '../src/prisma/prisma.service';

async function run() {
  const healthyPrisma = {
    $queryRaw: async () => [{ '?column?': 1 }],
  } as unknown as PrismaService;
  const healthy = new HealthController(healthyPrisma);
  assert.deepEqual(await healthy.health(), { status: 'ok' });

  const unavailablePrisma = {
    $queryRaw: async () => { throw new Error('database details must not leak'); },
  } as unknown as PrismaService;
  const unavailable = new HealthController(unavailablePrisma);
  await assert.rejects(
    () => unavailable.health(),
    (error: unknown) => {
      assert.ok(error instanceof ServiceUnavailableException);
      assert.deepEqual(error.getResponse(), {
        code: 'DEPENDENCY_UNAVAILABLE',
        message: 'Tjenesten er ikke klar',
      });
      return true;
    },
  );

  console.log('Health tests passed');
}

run().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
