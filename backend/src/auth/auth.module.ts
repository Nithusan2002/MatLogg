import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { AuthService } from './auth.service';
import { AuthController, UserController } from './auth.controller';
import { JwtStrategy } from './jwt.strategy';
import { jwtSecret } from './auth.config';
import { AppleTokenVerifier } from './apple-token-verifier';

@Module({
  imports: [
    PassportModule,
    JwtModule.register({
      secret: jwtSecret(),
      signOptions: { expiresIn: process.env.JWT_EXPIRES_IN || '15m' },
    }),
  ],
  controllers: [AuthController, UserController],
  providers: [AuthService, JwtStrategy, AppleTokenVerifier],
  exports: [AuthService],
})
export class AuthModule {}
