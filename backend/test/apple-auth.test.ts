import * as assert from 'node:assert/strict';
import { ConflictException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { AuthService } from '../src/auth/auth.service';
import { AppleTokenVerifier } from '../src/auth/apple-token-verifier';
import { PrismaService } from '../src/prisma/prisma.service';

async function run() {
  const users: any[] = [];
  const prisma = {
    user: {
      findUnique: async ({ where }: any) => users.find((user) =>
        where.appleSubject ? user.appleSubject === where.appleSubject : user.email === where.email,
      ) ?? null,
      create: async ({ data }: any) => {
        const user = { id: '00000000-0000-4000-8000-000000000101', firstName: null, lastName: null, deletedAt: null, createdAt: new Date(), ...data };
        users.push(user);
        return user;
      },
      findMany: async () => [],
    },
    refreshSession: { create: async () => ({}), deleteMany: async () => ({ count: 0 }) },
  } as unknown as PrismaService;
  const jwtService = {
    signAsync: async () => 'access-token',
    decode: () => ({ iat: 1, exp: 901 }),
  } as unknown as JwtService;
  const verifier = { verify: async () => ({ subject: 'apple-subject', email: 'apple@example.com' }) } as unknown as AppleTokenVerifier;
  const service = new AuthService(jwtService, prisma, verifier);
  const created = await service.loginApple('identity-token', 'raw-nonce');
  assert.equal(created.auth_provider, 'apple');
  assert.equal(created.email, 'apple@example.com');

  users.push({ id: 'existing', email: 'collision@example.com', appleSubject: null, deletedAt: null, createdAt: new Date() });
  const collisionVerifier = { verify: async () => ({ subject: 'new-subject', email: 'collision@example.com' }) } as unknown as AppleTokenVerifier;
  await assert.rejects(
    () => new AuthService(jwtService, prisma, collisionVerifier).loginApple('identity-token', 'raw-nonce'),
    ConflictException,
  );
  console.log('Apple auth tests passed');
}

run().catch((error) => { console.error(error); process.exitCode = 1; });
