import * as assert from 'node:assert/strict';
import { createHash, randomUUID } from 'node:crypto';
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
    const disabledDevLogin = await request(baseUrl, '/v1/auth/dev-login', 'POST', { email });
    assert.equal(disabledDevLogin.status, 404);
    assert.equal(disabledDevLogin.json.code, 'DEV_LOGIN_DISABLED');

    const registration = await request(baseUrl, '/v1/auth/register', 'POST', {
      email,
      password: 'correct-horse-battery',
    });
    assert.equal(registration.status, 201);
    assert.equal(typeof registration.json.token, 'string');
    assert.equal(typeof registration.json.refresh_token, 'string');
    assert.ok(registration.json.expires_in > 0);
    assert.equal('passwordHash' in registration.json, false);

    const stored = await prisma.user.findUniqueOrThrow({ where: { email } });
    assert.match(stored.passwordHash ?? '', /^scrypt:/);
    assert.notEqual(stored.passwordHash, 'correct-horse-battery');

    const duplicate = await request(baseUrl, '/v1/auth/register', 'POST', {
      email,
      password: 'correct-horse-battery',
    });
    assert.equal(duplicate.status, 409);
    assert.equal(duplicate.json.code, 'EMAIL_ALREADY_REGISTERED');

    const invalidLogin = await request(baseUrl, '/v1/auth/login', 'POST', { email, password: 'wrong-password' });
    assert.equal(invalidLogin.status, 401);
    assert.equal(invalidLogin.json.code, 'INVALID_CREDENTIALS');

    const login = await request(baseUrl, '/v1/auth/login', 'POST', { email, password: 'correct-horse-battery' });
    assert.equal(login.status, 201);
    assert.equal(typeof login.json.refresh_token, 'string');

    const refreshed = await request(baseUrl, '/v1/auth/refresh', 'POST', {
      refresh_token: login.json.refresh_token,
    });
    assert.equal(refreshed.status, 201);
    assert.equal(typeof refreshed.json.token, 'string');
    assert.equal(typeof refreshed.json.refresh_token, 'string');
    assert.notEqual(refreshed.json.refresh_token, login.json.refresh_token);

    const reused = await request(baseUrl, '/v1/auth/refresh', 'POST', {
      refresh_token: login.json.refresh_token,
    });
    assert.equal(reused.status, 401);
    assert.equal(reused.json.code, 'REFRESH_TOKEN_REUSED');

    const revokedRotatedToken = await request(baseUrl, '/v1/auth/refresh', 'POST', {
      refresh_token: refreshed.json.refresh_token,
    });
    assert.equal(revokedRotatedToken.status, 401);

    const logoutLogin = await request(baseUrl, '/v1/auth/login', 'POST', { email, password: 'correct-horse-battery' });
    const logout = await request(baseUrl, '/v1/auth/logout', 'POST', {
      refresh_token: logoutLogin.json.refresh_token,
    });
    assert.equal(logout.status, 201);
    assert.equal(logout.json.code, 'SESSION_REVOKED');
    const refreshAfterLogout = await request(baseUrl, '/v1/auth/refresh', 'POST', {
      refresh_token: logoutLogin.json.refresh_token,
    });
    assert.equal(refreshAfterLogout.status, 401);

    const concurrentLogin = await request(baseUrl, '/v1/auth/login', 'POST', { email, password: 'correct-horse-battery' });
    const concurrentRefreshes = await Promise.all([
      request(baseUrl, '/v1/auth/refresh', 'POST', { refresh_token: concurrentLogin.json.refresh_token }),
      request(baseUrl, '/v1/auth/refresh', 'POST', { refresh_token: concurrentLogin.json.refresh_token }),
    ]);
    assert.deepEqual(concurrentRefreshes.map(({ status }) => status).sort(), [201, 401]);
    const concurrentWinner = concurrentRefreshes.find(({ status }) => status === 201);
    const concurrentLoser = concurrentRefreshes.find(({ status }) => status === 401);
    assert.equal(concurrentLoser?.json.code, 'REFRESH_TOKEN_REUSED');
    assert.equal(typeof concurrentWinner?.json.refresh_token, 'string');
    const revokedConcurrentWinner = await request(baseUrl, '/v1/auth/refresh', 'POST', {
      refresh_token: concurrentWinner?.json.refresh_token,
    });
    assert.equal(revokedConcurrentWinner.status, 401);

    const expiringLogin = await request(baseUrl, '/v1/auth/login', 'POST', { email, password: 'correct-horse-battery' });
    const expiringTokenHash = createHash('sha256').update(expiringLogin.json.refresh_token, 'utf8').digest('hex');
    await prisma.refreshSession.update({
      where: { tokenHash: expiringTokenHash },
      data: { expiresAt: new Date(0) },
    });
    const expiredRefresh = await request(baseUrl, '/v1/auth/refresh', 'POST', {
      refresh_token: expiringLogin.json.refresh_token,
    });
    assert.equal(expiredRefresh.status, 401);
    assert.equal(expiredRefresh.json.code, 'INVALID_REFRESH_TOKEN');
    const purgedRefreshSessions = await app.get(AuthService).purgeExpiredRefreshSessions(new Date());
    assert.ok(purgedRefreshSessions >= 1);
    assert.equal(await prisma.refreshSession.count({ where: { tokenHash: expiringTokenHash } }), 0);

    const token = refreshed.json.token as string;

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
