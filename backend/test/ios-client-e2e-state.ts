import * as assert from 'node:assert/strict';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();
const email = 'ios-client-e2e@integration.matlogg';
const productId = '11111111-1111-4111-8111-111111111111';
const eventId = '22222222-2222-4222-8222-222222222222';

async function cleanup() {
  const user = await prisma.user.findUnique({ where: { email } });
  await prisma.eventInbox.deleteMany({ where: { eventId } });
  await prisma.product.deleteMany({ where: { id: productId } });
  if (user) {
    await prisma.user.delete({ where: { id: user.id } });
  }
}

async function run() {
  const mode = process.argv[2];
  if (mode === 'prepare') {
    await cleanup();
    console.log('iOS client E2E state prepared');
    return;
  }
  if (mode !== 'verify') {
    throw new Error('Expected mode: prepare or verify');
  }

  try {
    const user = await prisma.user.findUniqueOrThrow({ where: { email } });
    const product = await prisma.product.findUniqueOrThrow({ where: { id: productId } });
    assert.equal(product.userId, user.id);
    assert.equal(product.name, 'iOS E2E-produkt');
    assert.equal(await prisma.product.count({ where: { id: productId } }), 1);
    assert.equal(await prisma.eventInbox.count({ where: { eventId } }), 1);
    console.log('iOS client to PostgreSQL E2E state verified');
  } finally {
    await cleanup();
  }
}

run()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
