import { ConflictException, GoneException, Injectable, Logger, OnModuleDestroy, OnModuleInit, ServiceUnavailableException, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../prisma/prisma.service';
import { createHash, randomBytes, scrypt as nodeScrypt, timingSafeEqual } from 'node:crypto';
import { promisify } from 'node:util';
import { AppleTokenVerifier } from './apple-token-verifier';

const scrypt = promisify(nodeScrypt);
const deletionRetentionMs = 30 * 24 * 60 * 60 * 1000;
const refreshTokenLifetimeMs = 30 * 24 * 60 * 60 * 1000;

@Injectable()
export class AuthService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(AuthService.name);
  private purgeTimer?: NodeJS.Timeout;

  constructor(
    private readonly jwtService: JwtService,
    private readonly prisma: PrismaService,
    private readonly appleTokenVerifier: AppleTokenVerifier = new AppleTokenVerifier(),
  ) {}

  async onModuleInit() {
    await this.runMaintenance();
    this.purgeTimer = setInterval(() => void this.runMaintenance(), 24 * 60 * 60 * 1000);
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

  async register(input: { email: string; password: string }) {
    const email = input.email.trim().toLowerCase();
    const existing = await this.prisma.user.findUnique({ where: { email } });
    if (existing) throw new ConflictException({ code: 'EMAIL_ALREADY_REGISTERED', message: 'E-postadressen er allerede registrert' });

    const passwordHash = await this.hashPassword(input.password);
    const refreshToken = this.generateRefreshToken();
    const user = await this.prisma.$transaction(async (tx) => {
      const created = await tx.user.create({
        data: {
          email,
          passwordHash,
          authProvider: 'email',
        },
      });
      await tx.refreshSession.create({
        data: {
          userId: created.id,
          tokenHash: this.hashRefreshToken(refreshToken),
          expiresAt: new Date(Date.now() + refreshTokenLifetimeMs),
        },
      });
      return created;
    });
    return this.authResponse(user, refreshToken);
  }

  async loginApple(identityToken: string, nonce: string) {
    let identity;
    try {
      identity = await this.appleTokenVerifier.verify(identityToken, nonce);
    } catch (error) {
      if (error instanceof Error && error.message === 'APPLE_CLIENT_ID_NOT_CONFIGURED') {
        throw new ServiceUnavailableException({ code: 'APPLE_AUTH_NOT_CONFIGURED', message: 'Apple-innlogging er ikke konfigurert' });
      }
      throw new UnauthorizedException({ code: 'INVALID_APPLE_CREDENTIAL', message: 'Apple-innloggingen kunne ikke verifiseres' });
    }

    let user = await this.prisma.user.findUnique({ where: { appleSubject: identity.subject } });
    if (user?.deletedAt) throw new GoneException({ code: 'ACCOUNT_PENDING_DELETION', message: 'Kontoen er markert for sletting' });
    if (!user) {
      if (!identity.email) {
        throw new UnauthorizedException({ code: 'APPLE_EMAIL_REQUIRED', message: 'Apple må dele en e-postadresse første gang kontoen opprettes' });
      }
      const emailOwner = await this.prisma.user.findUnique({ where: { email: identity.email } });
      if (emailOwner) {
        throw new ConflictException({ code: 'EMAIL_ACCOUNT_EXISTS', message: 'Denne e-posten har allerede en konto. Logg inn med e-post.' });
      }
      user = await this.prisma.user.create({
        data: { email: identity.email, appleSubject: identity.subject, authProvider: 'apple' },
      });
    }
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

  async refresh(refreshToken: string) {
    const tokenHash = this.hashRefreshToken(refreshToken);
    const session = await this.prisma.refreshSession.findUnique({
      where: { tokenHash },
      include: { user: true },
    });
    if (!session || session.expiresAt <= new Date() || session.user.deletedAt) {
      throw new UnauthorizedException({ code: 'INVALID_REFRESH_TOKEN', message: 'Sesjonen er utløpt' });
    }
    if (session.revokedAt) {
      await this.prisma.refreshSession.updateMany({
        where: { userId: session.userId, revokedAt: null },
        data: { revokedAt: new Date() },
      });
      throw new UnauthorizedException({ code: 'REFRESH_TOKEN_REUSED', message: 'Sesjonen er ikke lenger gyldig' });
    }

    const now = new Date();
    const nextRefreshToken = this.generateRefreshToken();
    const rotated = await this.prisma.$transaction(async (tx) => {
      const revoked = await tx.refreshSession.updateMany({
        where: { id: session.id, revokedAt: null, expiresAt: { gt: now } },
        data: { revokedAt: now },
      });
      if (revoked.count !== 1) return false;
      await tx.refreshSession.create({
        data: {
          userId: session.userId,
          tokenHash: this.hashRefreshToken(nextRefreshToken),
          expiresAt: new Date(now.getTime() + refreshTokenLifetimeMs),
        },
      });
      return true;
    });
    if (!rotated) {
      await this.prisma.refreshSession.updateMany({
        where: { userId: session.userId, revokedAt: null },
        data: { revokedAt: new Date() },
      });
      throw new UnauthorizedException({ code: 'REFRESH_TOKEN_REUSED', message: 'Sesjonen er ikke lenger gyldig' });
    }

    return this.tokenResponse(session.user, nextRefreshToken);
  }

  async revokeRefreshToken(refreshToken: string) {
    await this.prisma.refreshSession.updateMany({
      where: { tokenHash: this.hashRefreshToken(refreshToken), revokedAt: null },
      data: { revokedAt: new Date() },
    });
    return { code: 'SESSION_REVOKED' };
  }

  async markAccountForDeletion(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new UnauthorizedException({ code: 'INVALID_TOKEN', message: 'Ugyldig bruker' });
    const deletedAt = user.deletedAt ?? new Date();
    if (!user.deletedAt) {
      await this.prisma.$transaction([
        this.prisma.user.update({ where: { id: userId }, data: { deletedAt } }),
        this.prisma.refreshSession.updateMany({ where: { userId, revokedAt: null }, data: { revokedAt: deletedAt } }),
      ]);
    }
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

  async purgeExpiredRefreshSessions(now = new Date()) {
    const result = await this.prisma.refreshSession.deleteMany({
      where: { expiresAt: { lte: now } },
    });
    return result.count;
  }

  private async runMaintenance() {
    try {
      await this.purgeExpiredRefreshSessions();
      await this.purgeDeletedUsers();
    } catch (error) {
      this.logger.error('Scheduled auth maintenance failed', error instanceof Error ? error.stack : undefined);
    }
  }

  private async authResponse(
    user: { id: string; email: string; firstName: string | null; lastName: string | null; authProvider: string; createdAt: Date },
    issuedRefreshToken?: string,
  ) {
    const refreshToken = issuedRefreshToken ?? this.generateRefreshToken();
    if (!issuedRefreshToken) {
      await this.prisma.refreshSession.create({
        data: {
          userId: user.id,
          tokenHash: this.hashRefreshToken(refreshToken),
          expiresAt: new Date(Date.now() + refreshTokenLifetimeMs),
        },
      });
    }
    const tokens = await this.tokenResponse(user, refreshToken);
    return {
      user_id: user.id,
      email: user.email,
      first_name: user.firstName ?? '',
      last_name: user.lastName ?? '',
      auth_provider: user.authProvider,
      created_at: user.createdAt,
      ...tokens,
    };
  }

  private async tokenResponse(user: { id: string; email: string }, refreshToken: string) {
    const token = await this.jwtService.signAsync({ sub: user.id, email: user.email });
    const decoded = this.jwtService.decode(token) as { exp?: number; iat?: number } | null;
    return {
      token,
      refresh_token: refreshToken,
      expires_in: decoded?.exp && decoded?.iat ? decoded.exp - decoded.iat : null,
    };
  }

  private generateRefreshToken() {
    return randomBytes(32).toString('base64url');
  }

  private hashRefreshToken(token: string) {
    return createHash('sha256').update(token, 'utf8').digest('hex');
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
