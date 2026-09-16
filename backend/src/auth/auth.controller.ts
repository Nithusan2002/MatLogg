import { Body, Controller, Delete, Post, Req, UseGuards } from '@nestjs/common';
import { AuthService } from './auth.service';
import { IsEmail, IsString, MinLength } from 'class-validator';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from './jwt-auth.guard';

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

  @IsString()
  @MinLength(1)
  first_name!: string;

  @IsString()
  @MinLength(1)
  last_name!: string;
}

class LoginDto {
  @IsEmail()
  email!: string;

  @IsString()
  @MinLength(1)
  password!: string;
}

@ApiTags('auth')
@Controller(['auth', 'v1/auth'])
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('dev-login')
  async devLogin(@Body() body: DevLoginDto) {
    return this.authService.devLogin(body.email);
  }

  @Post('register')
  async register(@Body() body: RegisterDto) {
    return this.authService.register(body);
  }

  @Post('login')
  async login(@Body() body: LoginDto) {
    return this.authService.login(body.email, body.password);
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
