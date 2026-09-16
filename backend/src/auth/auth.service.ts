import { ConflictException, GoneException, Injectable, OnModuleDestroy, OnModuleInit, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../prisma/prisma.service';
import { randomBytes, scrypt as nodeScrypt, timingSafeEqual } from 'node:crypto';
import { promisify } from 'node:util';

const scrypt = promisify(nodeScrypt);
const deletionRetentionMs = 30 * 24 * 60 * 60 * 1000;

@Injectable()
export class AuthService implements OnModuleInit, OnModuleDestroy {
  private purgeTimer?: NodeJS.Timeout;

  constructor(private readonly jwtService: JwtService, private readonly prisma: PrismaService) {}

  onModuleInit() {
    this.purgeTimer = setInterval(() => void this.purgeDeletedUsers(), 24 * 60 * 60 * 1000);
    this.purgeTimer.unref();
  }

  onModuleDestroy() {
    if (this.purgeTimer) clearInterval(this.purgeTimer);
  }

  async devLogin(email: string) {
    let user = await this.prisma.user.findUnique({ where: { email } });
    if (!user) {
      user = await this.prisma.user.create({ data: { email } });
    }

    const payload = { sub: user.id, email: user.email };
    const accessToken = await this.jwtService.signAsync(payload);
    return { accessToken };
  }

  async register(input: { email: string; password: string; first_name: string; last_name: string }) {
    const email = input.email.trim().toLowerCase();
    const existing = await this.prisma.user.findUnique({ where: { email } });
    if (existing) throw new ConflictException({ code: 'EMAIL_ALREADY_REGISTERED', message: 'E-postadressen er allerede registrert' });

    const user = await this.prisma.user.create({
      data: {
        email,
        firstName: input.first_name.trim(),
        lastName: input.last_name.trim(),
        passwordHash: await this.hashPassword(input.password),
        authProvider: 'email',
      },
    });
    return this.authResponse(user);
  }

  async login(emailInput: string, password: string) {
    const user = await this.prisma.user.findUnique({ where: { email: emailInput.trim().toLowerCase() } });
    if (!user || !user.passwordHash || !(await this.verifyPassword(password, user.passwordHash))) {
      throw new UnauthorizedException({ code: 'INVALID_CREDENTIALS', message: 'E-post eller passord er feil' });
    }
    if (user.deletedAt) {
      throw new GoneException({ code: 'ACCOUNT_PENDING_DELETION', message: 'Kontoen er markert for sletting' });
    }
    return this.authResponse(user);
  }

  async markAccountForDeletion(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new UnauthorizedException({ code: 'INVALID_TOKEN', message: 'Ugyldig bruker' });
    const deletedAt = user.deletedAt ?? new Date();
    if (!user.deletedAt) await this.prisma.user.update({ where: { id: userId }, data: { deletedAt } });
    return {
      code: 'ACCOUNT_PENDING_DELETION',
      message: 'Kontoen er markert for sletting',
      permanentDeletionAt: new Date(deletedAt.getTime() + deletionRetentionMs).toISOString(),
    };
  }

  async purgeDeletedUsers(now = new Date()) {
    const cutoff = new Date(now.getTime() - deletionRetentionMs);
    const users = await this.prisma.user.findMany({ where: { deletedAt: { lte: cutoff } }, select: { id: true } });
    for (const { id } of users) {
      await this.prisma.$transaction(async (tx) => {
        await tx.eventInbox.deleteMany({ where: { userId: id } });
        await tx.log.deleteMany({ where: { userId: id } });
        await tx.goal.deleteMany({ where: { userId: id } });
        await tx.favorite.deleteMany({ where: { userId: id } });
        await tx.weight.deleteMany({ where: { userId: id } });
        await tx.product.updateMany({ where: { userId: id }, data: { userId: null } });
        await tx.user.delete({ where: { id } });
      });
    }
    return users.length;
  }

  private async authResponse(user: { id: string; email: string; firstName: string | null; lastName: string | null; authProvider: string; createdAt: Date }) {
    const token = await this.jwtService.signAsync({ sub: user.id, email: user.email });
    return {
      user_id: user.id,
      email: user.email,
      first_name: user.firstName ?? '',
      last_name: user.lastName ?? '',
      auth_provider: user.authProvider,
      created_at: user.createdAt,
      token,
    };
  }

  private async hashPassword(password: string) {
    const salt = randomBytes(16);
    const derived = await scrypt(password, salt, 64) as Buffer;
    return `scrypt:${salt.toString('hex')}:${derived.toString('hex')}`;
  }

  private async verifyPassword(password: string, encoded: string) {
    const [algorithm, saltHex, hashHex] = encoded.split(':');
    if (algorithm !== 'scrypt' || !saltHex || !hashHex) return false;
    const expected = Buffer.from(hashHex, 'hex');
    const actual = await scrypt(password, Buffer.from(saltHex, 'hex'), expected.length) as Buffer;
    return actual.length === expected.length && timingSafeEqual(actual, expected);
  }
}
