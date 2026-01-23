import { Body, Controller, Post, Req, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { SyncService } from './sync.service';
import { SyncEventsRequestDto } from './dto';

@ApiTags('sync')
@ApiBearerAuth()
@Controller('v1/sync')
export class SyncController {
  constructor(private readonly syncService: SyncService) {}

  @UseGuards(JwtAuthGuard)
  @Post('events')
  async syncEvents(@Req() req: any, @Body() body: SyncEventsRequestDto) {
    const userId = req.user.userId as string;
    const result = await this.syncService.syncEvents(userId, body);
    return {
      ...result,
      serverTime: new Date().toISOString(),
    };
  }
}
