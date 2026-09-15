import { IsArray, IsISO8601, IsInt, IsOptional, IsString, IsUUID, Max, MaxLength, Min, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';

export class SyncEventDto {
  @IsUUID()
  eventId!: string;

  @IsString()
  @MaxLength(120)
  type!: string;

  @IsISO8601()
  createdAt!: string;

  @IsOptional()
  entityId!: string | null;

  @IsInt()
  @Min(1)
  @Max(1)
  schemaVersion!: number;

  @IsString()
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
