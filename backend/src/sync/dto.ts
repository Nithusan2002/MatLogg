import { IsArray, IsISO8601, IsInt, IsOptional, IsString, IsUUID, Max, MaxLength, Min, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';
import { MAX_SYNC_PAYLOAD_BASE64_CHARS } from './sync.contract';

export class SyncEventDto {
  @IsUUID()
  eventId!: string;

  @IsString()
  @MaxLength(120)
  type!: string;

  @IsISO8601()
  createdAt!: string;

  @IsOptional()
  @IsUUID()
  entityId!: string | null;

  @IsInt()
  @Min(1)
  @Max(1)
  schemaVersion!: number;

  @IsString()
  @MaxLength(MAX_SYNC_PAYLOAD_BASE64_CHARS)
  payload!: string;
}

export class SyncEventsRequestDto {
  @IsUUID()
  deviceId!: string;

  @IsISO8601()
  clientTime!: string;

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => SyncEventDto)
  events!: SyncEventDto[];
}
