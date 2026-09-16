import * as assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { PrismaClient } from '@prisma/client';
import { AppModule } from '../src/app.module';

const prisma = new PrismaClient();
const ownerEmail = `${randomUUID()}@http-integration.matlogg`;
const otherEmail = `${randomUUID()}@http-integration.matlogg`;
const productId = randomUUID();
const validEventId = randomUUID();
const invalidEventId = randomUUID();
const forbiddenEventId = randomUUID();
const deviceId = randomUUID();

function productEvent(eventId: string, name: string) {
  return {
    eventId,
    type: 'product.upsert',
    createdAt: new Date().toISOString(),
    entityId: productId,
    schemaVersion: 1,
    payload: Buffer.from(JSON.stringify({
      id: productId,
      name,
      brand: 'MatLogg HTTP-test',
      barcode: null,
      nutrientsPer100g: { kcal: 42, protein: 1, carbs: 9, fat: 0 },
      imageUrl: null,
      source: 'user',
    }), 'utf8').toString('base64'),
  };
}

async function postJson(baseUrl: string, path: string, body: unknown, token?: string) {
  const response = await fetch(`${baseUrl}${path}`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify(body),
  });
  const json = await response.json();
  return { status: response.status, json: json as any };
}

async function login(baseUrl: string, email: string) {
  const response = await postJson(baseUrl, '/auth/dev-login', { email });
  assert.equal(response.status, 201);
  assert.equal(typeof response.json.accessToken, 'string');
  return response.json.accessToken as string;
}

async function run() {
  const app = await NestFactory.create(AppModule, { logger: false });
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
  await app.listen(0, '127.0.0.1');
  const baseUrl = await app.getUrl();

  try {
    const ownerToken = await login(baseUrl, ownerEmail);
    const otherToken = await login(baseUrl, otherEmail);
    const owner = await prisma.user.findUniqueOrThrow({ where: { email: ownerEmail } });

    const request = {
      deviceId,
      clientTime: new Date().toISOString(),
      events: [
        productEvent(validEventId, 'HTTP-integrasjonstestprodukt'),
        productEvent(invalidEventId, ''),
      ],
    };

    const unauthorized = await postJson(baseUrl, '/v1/sync/events', request);
    assert.equal(unauthorized.status, 401);

    const partial = await postJson(baseUrl, '/v1/sync/events', request, ownerToken);
    assert.equal(partial.status, 201);
    assert.deepEqual(partial.json.ackedEventIds, [validEventId]);
    assert.deepEqual(partial.json.rejected, [{
      eventId: invalidEventId,
      code: 'VALIDATION_ERROR',
      message: 'Ugyldig produkt-payload',
    }]);

    // Behandle responsen over som et tapt ACK: replay må være trygt selv om
    // klienten ikke rakk å lagre resultatet lokalt.

    const replay = await postJson(baseUrl, '/v1/sync/events', {
      ...request,
      events: [productEvent(validEventId, 'Skal ikke dupliseres')],
    }, ownerToken);
    assert.equal(replay.status, 201);
    assert.deepEqual(replay.json.ackedEventIds, [validEventId]);
    assert.deepEqual(replay.json.rejected, []);

    const forbidden = await postJson(baseUrl, '/v1/sync/events', {
      ...request,
      events: [productEvent(forbiddenEventId, 'Skal ikke overskrive')],
    }, otherToken);
    assert.equal(forbidden.status, 201);
    assert.deepEqual(forbidden.json.ackedEventIds, []);
    assert.deepEqual(forbidden.json.rejected, [{
      eventId: forbiddenEventId,
      code: 'FORBIDDEN',
      message: 'Produktet kan ikke endres av denne brukeren',
    }]);

    const product = await prisma.product.findUniqueOrThrow({ where: { id: productId } });
    assert.equal(product.userId, owner.id);
    assert.equal(product.name, 'HTTP-integrasjonstestprodukt');
    assert.equal(await prisma.product.count({ where: { id: productId } }), 1);
    assert.equal(await prisma.eventInbox.count({ where: { eventId: validEventId } }), 1);
    assert.equal(await prisma.eventInbox.count({ where: { eventId: invalidEventId } }), 0);
    assert.equal(await prisma.eventInbox.count({ where: { eventId: forbiddenEventId } }), 0);

    console.log('Authenticated HTTP sync integration tests passed');
  } finally {
    const users = await prisma.user.findMany({
      where: { email: { in: [ownerEmail, otherEmail] } },
      select: { id: true },
    });
    const userIds = users.map((user) => user.id);
    await prisma.eventInbox.deleteMany({ where: { userId: { in: userIds } } });
    await prisma.product.deleteMany({ where: { id: productId } });
    await prisma.user.deleteMany({ where: { id: { in: userIds } } });
    await prisma.$disconnect();
    await app.close();
  }
}

run().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
