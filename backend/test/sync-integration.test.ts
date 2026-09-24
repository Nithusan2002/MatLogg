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
const collidedEventId = randomUUID();
const savedMealId = randomUUID();
const savedMealEventId = randomUUID();
const forbiddenSavedMealEventId = randomUUID();
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

function savedMealEvent(eventId: string, name: string) {
  return {
    eventId,
    type: 'saved_meal.upsert',
    createdAt: new Date().toISOString(),
    entityId: savedMealId,
    schemaVersion: 1,
    payload: Buffer.from(JSON.stringify({
      id: savedMealId,
      name,
      suggestedMealType: 'frokost',
      updatedAt: new Date().toISOString(),
      items: [{
        id: randomUUID(), productId, productName: 'Integrasjonstestprodukt',
        amountG: 80, calories: 200, protein: 8, carbs: 30, fat: 4,
        nutritionSource: 'user', sortIndex: 0,
      }],
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

    const savedMealRequest = {
      deviceId,
      clientTime: new Date().toISOString(),
      events: [savedMealEvent(savedMealEventId, 'Vanlig frokost')],
    };
    const savedMealResult = await syncService.syncEvents(ownerId, savedMealRequest);
    assert.deepEqual(savedMealResult, { ackedEventIds: [savedMealEventId], rejected: [] });
    assert.equal(await prisma.savedMeal.count({ where: { id: savedMealId, userId: ownerId } }), 1);
    assert.equal(await prisma.savedMealItem.count({ where: { savedMealId } }), 1);

    const savedMealRetry = await syncService.syncEvents(ownerId, savedMealRequest);
    assert.deepEqual(savedMealRetry, { ackedEventIds: [savedMealEventId], rejected: [] });
    assert.equal(await prisma.savedMealItem.count({ where: { savedMealId } }), 1);

    const forbiddenMeal = await syncService.syncEvents(otherUserId, {
      ...savedMealRequest,
      events: [savedMealEvent(forbiddenSavedMealEventId, 'Skal ikke overskrive')],
    });
    assert.deepEqual(forbiddenMeal, {
      ackedEventIds: [],
      rejected: [{
        eventId: forbiddenSavedMealEventId,
        code: 'FORBIDDEN',
        message: 'Det lagrede måltidet tilhører en annen bruker',
      }],
    });
    assert.equal((await prisma.savedMeal.findUniqueOrThrow({ where: { id: savedMealId } })).name, 'Vanlig frokost');
    assert.equal(await prisma.eventInbox.count({ where: { eventId: forbiddenSavedMealEventId } }), 0);

    await prisma.eventInbox.create({
      data: {
        eventId: collidedEventId,
        userId: ownerId,
        deviceId,
        type: 'product.upsert',
        createdAt: new Date(),
        schemaVersion: 1,
        payloadJson: {},
      },
    });
    const collided = await syncService.syncEvents(otherUserId, {
      ...request,
      events: [event(collidedEventId, 'Skal ikke bekreftes')],
    });
    assert.deepEqual(collided, {
      ackedEventIds: [],
      rejected: [{
        eventId: collidedEventId,
        code: 'FORBIDDEN',
        message: 'Hendelsen tilhører en annen bruker',
      }],
    });

    console.log('PostgreSQL sync integration tests passed');
  } finally {
    await prisma.eventInbox.deleteMany({
      where: { eventId: { in: [firstEventId, forbiddenEventId, collidedEventId, savedMealEventId, forbiddenSavedMealEventId] } },
    });
    await prisma.savedMeal.deleteMany({ where: { id: savedMealId } });
    await prisma.product.deleteMany({ where: { id: productId } });
    await prisma.user.deleteMany({ where: { id: { in: [ownerId, otherUserId] } } });
    await prisma.$disconnect();
  }
}

run().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
