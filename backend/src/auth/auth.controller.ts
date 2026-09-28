import { Body, Controller, Delete, NotFoundException, Post, Req, UseGuards } from '@nestjs/common';
import { AuthService } from './auth.service';
import { IsEmail, IsOptional, IsString, MinLength } from 'class-validator';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from './jwt-auth.guard';
import { isDevLoginEnabled } from './auth.config';
import { Throttle } from '@nestjs/throttler';
import { AUTH_RATE_LIMIT, RATE_LIMIT_WINDOW_MS, TOKEN_RATE_LIMIT } from '../security/rate-limit.config';

class DevLoginDto {
  @IsEmail()
  email!: string;
}

class RegisterDto {
  @IsEmail()
  email!: string;

  @IsString()
  @MinLength(8)
  password!: string;

}

class AppleLoginDto {
  @IsString()
  @MinLength(1)
  identity_token!: string;

  @IsOptional()
  @IsString()
  authorization_code?: string;

  @IsString()
  @MinLength(16)
  nonce!: string;
}

class LoginDto {
  @IsEmail()
  email!: string;

  @IsString()
  @MinLength(1)
  password!: string;
}

class RefreshDto {
  @IsString()
  @MinLength(32)
  refresh_token!: string;
}

@ApiTags('auth')
@Controller(['auth', 'v1/auth'])
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('dev-login')
  @Throttle({ default: { limit: AUTH_RATE_LIMIT, ttl: RATE_LIMIT_WINDOW_MS } })
  async devLogin(@Body() body: DevLoginDto) {
    if (!isDevLoginEnabled()) {
      throw new NotFoundException({ code: 'DEV_LOGIN_DISABLED', message: 'Endepunktet er ikke tilgjengelig' });
    }
    return this.authService.devLogin(body.email);
  }

  @Post('register')
  @Throttle({ default: { limit: AUTH_RATE_LIMIT, ttl: RATE_LIMIT_WINDOW_MS } })
  async register(@Body() body: RegisterDto) {
    return this.authService.register(body);
  }

  @Post('login')
  @Throttle({ default: { limit: AUTH_RATE_LIMIT, ttl: RATE_LIMIT_WINDOW_MS } })
  async login(@Body() body: LoginDto) {
    return this.authService.login(body.email, body.password);
  }

  @Post('apple')
  @Throttle({ default: { limit: AUTH_RATE_LIMIT, ttl: RATE_LIMIT_WINDOW_MS } })
  async apple(@Body() body: AppleLoginDto) {
    return this.authService.loginApple(body.identity_token, body.nonce);
  }

  @Post('refresh')
  @Throttle({ default: { limit: TOKEN_RATE_LIMIT, ttl: RATE_LIMIT_WINDOW_MS } })
  async refresh(@Body() body: RefreshDto) {
    return this.authService.refresh(body.refresh_token);
  }

  @Post('logout')
  @Throttle({ default: { limit: TOKEN_RATE_LIMIT, ttl: RATE_LIMIT_WINDOW_MS } })
  async logout(@Body() body: RefreshDto) {
    return this.authService.revokeRefreshToken(body.refresh_token);
  }
}

@ApiTags('user')
@ApiBearerAuth()
@Controller('v1/user')
export class UserController {
  constructor(private readonly authService: AuthService) {}

  @UseGuards(JwtAuthGuard)
  @Delete()
  async deleteAccount(@Req() req: any) {
    return this.authService.markAccountForDeletion(req.user.userId as string);
  }
}
