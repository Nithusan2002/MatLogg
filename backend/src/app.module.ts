import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { ThrottlerModule } from '@nestjs/throttler';
import { AuthModule } from './auth/auth.module';
import { SyncModule } from './sync/sync.module';
import { HealthModule } from './health/health.module';
import { PrismaModule } from './prisma/prisma.module';
import { rateLimitOptions } from './security/rate-limit.config';
import { MatLoggThrottlerGuard } from './security/matlogg-throttler.guard';

@Module({
  imports: [
    ThrottlerModule.forRoot(rateLimitOptions()),
    PrismaModule,
    AuthModule,
    SyncModule,
    HealthModule,
  ],
  providers: [{ provide: APP_GUARD, useClass: MatLoggThrottlerGuard }],
})
export class AppModule {}
