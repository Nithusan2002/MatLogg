import * as assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { PrismaClient } from '@prisma/client';
import { AppModule } from '../src/app.module';
import { AuthService } from '../src/auth/auth.service';

const prisma = new PrismaClient();
const email = `${randomUUID()}@auth-integration.matlogg`;

async function request(baseUrl: string, path: string, method: string, body?: unknown, token?: string) {
  const response = await fetch(`${baseUrl}${path}`, {
    method,
    headers: {
      ...(body ? { 'content-type': 'application/json' } : {}),
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  return { status: response.status, json: await response.json() as any };
}

async function run() {
  const app = await NestFactory.create(AppModule, { logger: false });
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
  await app.listen(0, '127.0.0.1');
  const baseUrl = await app.getUrl();

  try {
    const registration = await request(baseUrl, '/v1/auth/register', 'POST', {
      email,
      password: 'correct-horse-battery',
      first_name: 'Auth',
      last_name: 'Test',
    });
    assert.equal(registration.status, 201);
    assert.equal(typeof registration.json.token, 'string');
    assert.equal('passwordHash' in registration.json, false);

    const stored = await prisma.user.findUniqueOrThrow({ where: { email } });
    assert.match(stored.passwordHash ?? '', /^scrypt:/);
    assert.notEqual(stored.passwordHash, 'correct-horse-battery');

    const duplicate = await request(baseUrl, '/v1/auth/register', 'POST', {
      email,
      password: 'correct-horse-battery',
      first_name: 'Auth',
      last_name: 'Test',
    });
    assert.equal(duplicate.status, 409);
    assert.equal(duplicate.json.code, 'EMAIL_ALREADY_REGISTERED');

    const invalidLogin = await request(baseUrl, '/v1/auth/login', 'POST', { email, password: 'wrong-password' });
    assert.equal(invalidLogin.status, 401);
    assert.equal(invalidLogin.json.code, 'INVALID_CREDENTIALS');

    const login = await request(baseUrl, '/v1/auth/login', 'POST', { email, password: 'correct-horse-battery' });
    assert.equal(login.status, 201);
    const token = login.json.token as string;

    const deletion = await request(baseUrl, '/v1/user', 'DELETE', undefined, token);
    assert.equal(deletion.status, 200);
    assert.equal(deletion.json.code, 'ACCOUNT_PENDING_DELETION');

    const repeatedWithRevokedToken = await request(baseUrl, '/v1/user', 'DELETE', undefined, token);
    assert.equal(repeatedWithRevokedToken.status, 401);
    const deletedLogin = await request(baseUrl, '/v1/auth/login', 'POST', { email, password: 'correct-horse-battery' });
    assert.equal(deletedLogin.status, 410);

    await prisma.user.update({ where: { id: stored.id }, data: { deletedAt: new Date(0) } });
    const purged = await app.get(AuthService).purgeDeletedUsers(new Date());
    assert.equal(purged, 1);
    assert.equal(await prisma.user.count({ where: { id: stored.id } }), 0);

    console.log('Auth and account deletion integration tests passed');
  } finally {
    const user = await prisma.user.findUnique({ where: { email } });
    if (user) {
      await prisma.eventInbox.deleteMany({ where: { userId: user.id } });
      await prisma.log.deleteMany({ where: { userId: user.id } });
      await prisma.goal.deleteMany({ where: { userId: user.id } });
      await prisma.favorite.deleteMany({ where: { userId: user.id } });
      await prisma.weight.deleteMany({ where: { userId: user.id } });
      await prisma.product.updateMany({ where: { userId: user.id }, data: { userId: null } });
      await prisma.user.delete({ where: { id: user.id } });
    }
    await prisma.$disconnect();
    await app.close();
  }
}

run().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
