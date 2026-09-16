import * as assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { PrismaService } from '../src/prisma/prisma.service';
import { SyncService } from '../src/sync/sync.service';

const prisma = new PrismaService();
const syncService = new SyncService(prisma);
const ownerId = randomUUID();
const otherUserId = randomUUID();
const productId = randomUUID();
const firstEventId = randomUUID();
const forbiddenEventId = randomUUID();
const deviceId = randomUUID();

function event(eventId: string, name: string) {
  return {
    eventId,
    type: 'product.upsert',
    createdAt: new Date().toISOString(),
    entityId: productId,
    schemaVersion: 1,
    payload: Buffer.from(JSON.stringify({
      id: productId,
      name,
      brand: 'MatLogg test',
      barcode: null,
      nutrientsPer100g: { kcal: 42, protein: 1, carbs: 9, fat: 0 },
      imageUrl: null,
      source: 'user',
    }), 'utf8').toString('base64'),
  };
}

async function run() {
  await prisma.$connect();
  try {
    await prisma.user.createMany({
      data: [
        { id: ownerId, email: `${ownerId}@integration.matlogg` },
        { id: otherUserId, email: `${otherUserId}@integration.matlogg` },
      ],
    });

    const request = {
      deviceId,
      clientTime: new Date().toISOString(),
      events: [event(firstEventId, 'Integrasjonstestprodukt')],
    };

    const first = await syncService.syncEvents(ownerId, request);
    assert.deepEqual(first, { ackedEventIds: [firstEventId], rejected: [] });

    const retry = await syncService.syncEvents(ownerId, request);
    assert.deepEqual(retry, { ackedEventIds: [firstEventId], rejected: [] });
    assert.equal(await prisma.eventInbox.count({ where: { eventId: firstEventId } }), 1);
    assert.equal(await prisma.product.count({ where: { id: productId } }), 1);

    const forbidden = await syncService.syncEvents(otherUserId, {
      ...request,
      events: [event(forbiddenEventId, 'Skal ikke overskrive')],
    });
    assert.deepEqual(forbidden, {
      ackedEventIds: [],
      rejected: [{
        eventId: forbiddenEventId,
        code: 'FORBIDDEN',
        message: 'Produktet kan ikke endres av denne brukeren',
      }],
    });

    const product = await prisma.product.findUniqueOrThrow({ where: { id: productId } });
    assert.equal(product.userId, ownerId);
    assert.equal(product.name, 'Integrasjonstestprodukt');
    assert.equal(await prisma.eventInbox.count({ where: { eventId: forbiddenEventId } }), 0);

    console.log('PostgreSQL sync integration tests passed');
  } finally {
    await prisma.eventInbox.deleteMany({ where: { eventId: { in: [firstEventId, forbiddenEventId] } } });
    await prisma.product.deleteMany({ where: { id: productId } });
    await prisma.user.deleteMany({ where: { id: { in: [ownerId, otherUserId] } } });
    await prisma.$disconnect();
  }
}

run().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
