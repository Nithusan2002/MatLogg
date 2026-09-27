import * as assert from 'node:assert/strict';
import { JwtService } from '@nestjs/jwt';
import { AuthService } from '../src/auth/auth.service';
import { PrismaService } from '../src/prisma/prisma.service';

async function run() {
  const cleanupCutoffs: Date[] = [];
  const prisma = {
    refreshSession: {
      deleteMany: async ({ where }: { where: { expiresAt: { lte: Date } } }) => {
        cleanupCutoffs.push(where.expiresAt.lte);
        return { count: 2 };
      },
    },
    user: {
      findMany: async () => [],
    },
  } as unknown as PrismaService;

  const service = new AuthService({} as JwtService, prisma);
  await service.onModuleInit();
  service.onModuleDestroy();

  assert.equal(cleanupCutoffs.length, 1);
  assert.ok(cleanupCutoffs[0] instanceof Date);
  assert.ok(cleanupCutoffs[0].getTime() <= Date.now());

  const purged = await service.purgeExpiredRefreshSessions(new Date(0));
  assert.equal(purged, 2);
  assert.equal(cleanupCutoffs[1].getTime(), 0);

  console.log('Auth maintenance tests passed');
}

run().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
