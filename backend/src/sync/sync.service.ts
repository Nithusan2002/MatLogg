import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { SyncEventsRequestDto, SyncEventDto } from './dto';
import { z } from 'zod';
import { randomUUID } from 'crypto';

const MAX_EVENTS = 50;
const MAX_PAYLOAD_BYTES = 64 * 1024;

const eventTypes = new Set([
  'log.create',
  'log.update',
  'log.delete',
  'goal.set',
  'favorite.add',
  'favorite.remove',
  'weight.add',
  'product.upsert',
]);

const logPayloadSchema = z.object({
  id: z.string(),
  date: z.string(),
  meal: z.string(),
  grams: z.number(),
  kcal: z.number(),
  protein: z.number(),
  carbs: z.number(),
  fat: z.number(),
  productRef: z.string().optional().nullable(),
});

const goalPayloadSchema = z.object({
  kcalTarget: z.number(),
  proteinTarget: z.number(),
  carbTarget: z.number(),
  fatTarget: z.number(),
});

const favoritePayloadSchema = z.object({
  productId: z.string(),
});

const weightPayloadSchema = z.object({
  id: z.string().optional(),
  date: z.string(),
  weightKg: z.number(),
});

const productPayloadSchema = z.object({
  id: z.string(),
  name: z.string(),
  brand: z.string().optional().nullable(),
  barcode: z.string().optional().nullable(),
  nutrientsPer100g: z.record(z.any()),
  imageUrl: z.string().optional().nullable(),
  source: z.string(),
});

@Injectable()
export class SyncService {
  constructor(private readonly prisma: PrismaService) {}

  async syncEvents(userId: string, body: SyncEventsRequestDto) {
    const acked: string[] = [];
    const rejected: { eventId: string; code: string; message: string }[] = [];

    if (body.events.length > MAX_EVENTS) {
      return {
        ackedEventIds: [],
        rejected: body.events.map((event) => ({
          eventId: event.eventId,
          code: 'VALIDATION_ERROR',
          message: `Maks ${MAX_EVENTS} events per batch`,
        })),
      };
    }

    for (const event of body.events) {
      const result = await this.handleEvent(userId, body.deviceId, event).catch((error) => ({
        status: 'rejected' as const,
        eventId: event.eventId,
        code: 'SERVER_ERROR',
        message: error instanceof Error ? error.message : 'Server error',
      }));

      if (result.status === 'acked') {
        acked.push(result.eventId);
      } else {
        rejected.push({
          eventId: result.eventId,
          code: result.code,
          message: result.message,
        });
      }
    }

    return { ackedEventIds: acked, rejected };
  }

  private async handleEvent(userId: string, deviceId: string, event: SyncEventDto) {
    if (!eventTypes.has(event.type)) {
      return { status: 'rejected' as const, eventId: event.eventId, code: 'UNSUPPORTED_TYPE', message: 'Ukjent type' };
    }

    let payloadBuffer: Buffer;
    try {
      payloadBuffer = Buffer.from(event.payload, 'base64');
    } catch {
      return { status: 'rejected' as const, eventId: event.eventId, code: 'VALIDATION_ERROR', message: 'Ugyldig base64' };
    }

    if (payloadBuffer.byteLength > MAX_PAYLOAD_BYTES) {
      return { status: 'rejected' as const, eventId: event.eventId, code: 'VALIDATION_ERROR', message: 'Payload for stor' };
    }

    let payloadJson: any;
    try {
      payloadJson = JSON.parse(payloadBuffer.toString('utf8'));
    } catch {
      return { status: 'rejected' as const, eventId: event.eventId, code: 'VALIDATION_ERROR', message: 'Ugyldig JSON' };
    }

    const existing = await this.prisma.eventInbox.findUnique({
      where: { eventId: event.eventId },
    });
    if (existing) {
      return { status: 'acked' as const, eventId: event.eventId };
    }

    try {
      await this.prisma.$transaction(async (tx) => {
        await tx.eventInbox.create({
          data: {
            eventId: event.eventId,
            userId,
            deviceId,
            type: event.type,
            createdAt: new Date(event.createdAt),
            schemaVersion: event.schemaVersion,
            payloadJson,
          },
        });

        await this.applyEvent(tx, userId, event, payloadJson);
      });
    } catch (error) {
      if (error instanceof ValidationError) {
        return {
          status: 'rejected' as const,
          eventId: event.eventId,
          code: 'VALIDATION_ERROR',
          message: error.message,
        };
      }
      return {
        status: 'rejected' as const,
        eventId: event.eventId,
        code: 'SERVER_ERROR',
        message: error instanceof Error ? error.message : 'Server error',
      };
    }

    return { status: 'acked' as const, eventId: event.eventId };
  }

  private async applyEvent(tx: PrismaService, userId: string, event: SyncEventDto, payloadJson: any) {
    switch (event.type) {
      case 'log.create':
      case 'log.update': {
        const parsed = logPayloadSchema.safeParse(payloadJson);
        if (!parsed.success) {
          throw new ValidationError('Ugyldig logg-payload');
        }
        const log = parsed.data;
        await tx.log.upsert({
          where: { id: log.id },
          update: {
            date: new Date(log.date),
            meal: log.meal,
            grams: log.grams,
            kcal: Math.round(log.kcal),
            protein: log.protein,
            carbs: log.carbs,
            fat: log.fat,
            productRef: log.productRef ?? null,
          },
          create: {
            id: log.id,
            userId,
            date: new Date(log.date),
            meal: log.meal,
            grams: log.grams,
            kcal: Math.round(log.kcal),
            protein: log.protein,
            carbs: log.carbs,
            fat: log.fat,
            productRef: log.productRef ?? null,
          },
        });
        break;
      }
      case 'log.delete': {
        const parsed = z.object({ id: z.string() }).safeParse(payloadJson);
        if (!parsed.success) {
          throw new ValidationError('Ugyldig logg-delete payload');
        }
        await tx.log.deleteMany({ where: { id: parsed.data.id, userId } });
        break;
      }
      case 'goal.set': {
        const parsed = goalPayloadSchema.safeParse(payloadJson);
        if (!parsed.success) {
          throw new ValidationError('Ugyldig mål-payload');
        }
        await tx.goal.upsert({
          where: { userId },
          update: {
            kcalTarget: Math.round(parsed.data.kcalTarget),
            proteinTarget: parsed.data.proteinTarget,
            carbTarget: parsed.data.carbTarget,
            fatTarget: parsed.data.fatTarget,
          },
          create: {
            userId,
            kcalTarget: Math.round(parsed.data.kcalTarget),
            proteinTarget: parsed.data.proteinTarget,
            carbTarget: parsed.data.carbTarget,
            fatTarget: parsed.data.fatTarget,
          },
        });
        break;
      }
      case 'favorite.add': {
        const parsed = favoritePayloadSchema.safeParse(payloadJson);
        if (!parsed.success) {
          throw new ValidationError('Ugyldig favoritt-payload');
        }
        await tx.favorite.upsert({
          where: { userId_productId: { userId, productId: parsed.data.productId } },
          update: {},
          create: { userId, productId: parsed.data.productId },
        });
        break;
      }
      case 'favorite.remove': {
        const parsed = favoritePayloadSchema.safeParse(payloadJson);
        if (!parsed.success) {
          throw new ValidationError('Ugyldig favoritt-payload');
        }
        await tx.favorite.deleteMany({
          where: { userId, productId: parsed.data.productId },
        });
        break;
      }
      case 'weight.add': {
        const parsed = weightPayloadSchema.safeParse(payloadJson);
        if (!parsed.success) {
          throw new ValidationError('Ugyldig vekt-payload');
        }
        const id = parsed.data.id ?? randomUUID();
        await tx.weight.create({
          data: {
            id,
            userId,
            date: new Date(parsed.data.date),
            weightKg: parsed.data.weightKg,
          },
        });
        break;
      }
      case 'product.upsert': {
        const parsed = productPayloadSchema.safeParse(payloadJson);
        if (!parsed.success) {
          throw new ValidationError('Ugyldig produkt-payload');
        }
        await tx.product.upsert({
          where: { id: parsed.data.id },
          update: {
            name: parsed.data.name,
            brand: parsed.data.brand ?? null,
            barcode: parsed.data.barcode ?? null,
            nutrientsPer100g: parsed.data.nutrientsPer100g,
            imageUrl: parsed.data.imageUrl ?? null,
            source: parsed.data.source,
          },
          create: {
            id: parsed.data.id,
            userId,
            name: parsed.data.name,
            brand: parsed.data.brand ?? null,
            barcode: parsed.data.barcode ?? null,
            nutrientsPer100g: parsed.data.nutrientsPer100g,
            imageUrl: parsed.data.imageUrl ?? null,
            source: parsed.data.source,
          },
        });
        break;
      }
      default:
        throw new ValidationError('Ukjent type');
    }
  }
}

class ValidationError extends Error {}
