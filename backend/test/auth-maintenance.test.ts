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

  const deletedTables: string[] = [];
  const ownerId = '00000000-0000-4000-8000-000000000001';
  const tx: Record<string, unknown> = {};
  for (const table of ['eventInbox', 'log', 'goal', 'favorite', 'weight', 'product']) {
    tx[table] = { deleteMany: async ({ where }: { where: { userId: string } }) => {
      assert.equal(where.userId, ownerId);
      deletedTables.push(table);
    } };
  }
  tx.user = { delete: async ({ where }: { where: { id: string } }) => {
    assert.equal(where.id, ownerId);
    deletedTables.push('user');
  } };
  const purgePrisma = {
    user: { findMany: async ({ where }: { where: { deletedAt: { lte: Date } } }) => {
      assert.equal(where.deletedAt.lte.getTime(), 0);
      return [{ id: ownerId }];
    } },
    $transaction: async (action: (transaction: unknown) => Promise<void>) => action(tx),
  } as unknown as PrismaService;
  const purgeService = new AuthService({} as JwtService, purgePrisma);
  assert.equal(await purgeService.purgeDeletedUsers(new Date(0)), 1);
  assert.deepEqual(deletedTables, ['eventInbox', 'log', 'goal', 'favorite', 'weight', 'product', 'user']);

  let onlyOwner: string | undefined;
  let failPurge = false;
  const immediatePrisma = {
    user: {
      findUnique: async () => ({ id: ownerId, deletedAt: new Date(0) }),
      findMany: async ({ where }: { where: { id?: string; deletedAt: { lte: Date } } }) => {
        onlyOwner = where.id;
        assert.ok(where.deletedAt.lte.getTime() >= 0);
        return [{ id: ownerId }];
      },
    },
    $transaction: async (action: (transaction: unknown) => Promise<void>) => {
      if (failPurge) throw new Error('Synthetic transaction failure');
      return action(tx);
    },
  } as unknown as PrismaService;
  const immediateService = new AuthService({} as JwtService, immediatePrisma);
  assert.equal((await immediateService.markAccountForDeletion(ownerId)).permanentDeletionAt, new Date(0).toISOString());
  assert.equal(onlyOwner, ownerId, 'request must only purge the authenticated owner');
  failPurge = true;
  assert.equal((await immediateService.markAccountForDeletion(ownerId)).code, 'ACCOUNT_PENDING_DELETION',
    'persisted deletion remains accepted when immediate purge fails');

  console.log('Auth maintenance tests passed');
}

run().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
